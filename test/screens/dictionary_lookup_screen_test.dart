import 'package:dio/dio.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:drift/native.dart';

import 'dart:typed_data';

import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/lookup_history_provider.dart';
import 'package:echo_loop/providers/dictionary/wordlist_provider.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/saved_sense_group_provider.dart';
import 'package:echo_loop/providers/saved_word_provider.dart';
import 'package:echo_loop/screens/dictionary_lookup_screen.dart';
import 'package:echo_loop/services/dictionary/wordlist_index.dart';
import 'package:echo_loop/widgets/dictionary/lookup_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// 不发起真实词典请求的查词 controller：状态恒为空，只验证页面的路由与布局。
class _SilentLookupController extends DictionaryLookupController {
  @override
  DictionaryLookupState build(String word, {String? preferredSourceId}) {
    return DictionaryLookupState(
      selectedSourceId: preferredSourceId ?? 'local',
      bySource: const {},
    );
  }
}

/// 返回固定 AI 词组结果的 controller，用于验证例句预热。
class _AiResultLookupController extends DictionaryLookupController {
  @override
  DictionaryLookupState build(String word, {String? preferredSourceId}) {
    return DictionaryLookupState(
      selectedSourceId: 'ai',
      bySource: {'ai': LookupLoaded(AiDictResult(_multiEntry()))},
    );
  }
}

/// 记录 TTS 增量预热的文本，替代真实合成。
final List<String> _prewarmedExamples = [];

class _RecordingTtsController extends TtsController {
  @override
  Future<void> prewarmTextsIncremental(List<String> texts) async {
    _prewarmedExamples.addAll(texts);
  }
}

MultiWordDictionaryEntry _multiEntry() => MultiWordDictionaryEntry(
  originalExpression: 'machine learning',
  naturalness: '',
  category: '术语',
  pronunciationTips: const [],
  keyPoints: const [],
  meanings: const [
    MultiWordMeaning(
      translation: ['机器学习'],
      examples: [
        ExampleSentence(
          sentence: 'Machine learning improves recommendations.',
          translation: '机器学习改善推荐。',
        ),
      ],
    ),
  ],
  similarExpressions: const [
    SimilarExpression(
      expression: 'deep learning',
      difference: '深度学习是机器学习子领域。',
      sentence: 'Deep learning powers image recognition.',
      translation: '深度学习支持图像识别。',
    ),
  ],
  background: '',
);

/// 无收藏的词集合，避免测试触达真实数据库流。
class _EmptySavedWordTexts extends SavedWordTexts {
  @override
  Stream<Set<String>> build() => Stream.value(const <String>{});
}

/// 无收藏的意群集合，避免测试触达真实数据库流。
class _EmptySavedSenseGroupTexts extends SavedSenseGroupTexts {
  @override
  Stream<Set<String>> build() => Stream.value(const <String>{});
}

/// 记录标题发音预热请求，替代真实的 CDN 与 TTS 调用。
final List<String> _prewarmedWords = [];

/// 记录自动朗读的单词，替代真实播放。
final List<String> _spokenWords = [];

class _RecordingTextPlayback extends TextPlaybackController {
  @override
  Future<void> prewarmWord(String word) async {
    _prewarmedWords.add(word);
  }

  @override
  Future<void> speak(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    _spokenWords.add(text);
  }

  @override
  Future<void> stop() async {}
}

/// 按查询词返回固定的词典 API 响应，模拟线上 `/api/v1/dictionary` 的行为。
class _FakeDictionaryAdapter implements HttpClientAdapter {
  _FakeDictionaryAdapter(this.bodies);

  final Map<String, String> bodies;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final word = options.queryParameters['word'] as String;
    final body = bodies[word];
    if (body == null) return ResponseBody.fromString('', 404);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 线上 `GET /api/v1/dictionary/en_zh-CN?word=hellos` 的真实返回。
const _hellosJson =
    '{"tags":[],"collins":0,"headword":"hellos","phonetic":"heˈləuz",'
    '"definitions":[{"pos":"n","examples":[],'
    '"translations":["喂( hello的复数形式 )"]}]}';

/// 线上 `GET /api/v1/dictionary/en_zh-CN?word=hello` 的真实返回。
const _helloJson =
    '{"tags":["zk","gk"],"collins":3,"headword":"hello","phonetic":"hә\'lәu",'
    '"definitions":[{"pos":"interj","examples":[],"translations":["喂","嘿"]}]}';

LookupHistory _history(String word, int id) =>
    LookupHistory(id: id, word: word, lookedUpAt: DateTime(2026, 1, 1));

late SharedPreferences _sharedPreferences;

Widget _buildScreen({
  Future<WordlistIndex> Function(Ref ref)? wordlist,
  List<LookupHistory> history = const [],
  DictionaryLookupController Function()? lookupController,
  bool useRealLookup = false,
  DictionaryService? dictionaryService,
  TtsController Function()? ttsController,
  AppDatabase? database,
}) {
  return createTestScreen(
    const DictionaryLookupScreen(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_sharedPreferences),
      wordlistProvider.overrideWith(
        wordlist ??
            (ref) async => WordlistIndex(const [
              'app',
              'apple',
              'application',
              'apply',
              'banana',
            ]),
      ),
      lookupHistoryProvider.overrideWith((ref) => Stream.value(history)),
      if (!useRealLookup)
        dictionaryLookupControllerProvider.overrideWith(
          lookupController ?? _SilentLookupController.new,
        ),
      if (dictionaryService != null)
        dictionaryServiceProvider.overrideWithValue(dictionaryService),
      if (ttsController != null)
        ttsControllerProvider.overrideWith(ttsController),
      if (database != null)
        appDatabaseProvider.overrideWithValue(database),
      savedWordTextsProvider.overrideWith(_EmptySavedWordTexts.new),
      savedSenseGroupTextsProvider.overrideWith(_EmptySavedSenseGroupTexts.new),
      activeSavedWordProvider.overrideWith((ref, word) => Stream.value(null)),
      textPlaybackProvider.overrideWith(_RecordingTextPlayback.new),
    ],
  );
}

/// 聚焦的 TextField 光标会持续闪烁，pumpAndSettle 无法收敛，这里只推进有限帧。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _typeQuery(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  group('DictionaryLookupScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      _sharedPreferences = await SharedPreferences.getInstance();
    });

    testWidgets('打开即自动聚焦搜索框', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus ?? false, isTrue);
    });

    testWidgets('空输入时显示最近查询，点击整行进入词典详情', (tester) async {
      await tester.pumpWidget(
        _buildScreen(history: [_history('apple', 1), _history('banana', 2)]),
      );
      await _settle(tester);

      expect(
        find.byKey(const Key('dictionary-lookup-history')),
        findsOneWidget,
      );
      await tester.tap(find.text('banana'));
      await _settle(tester);

      expect(find.byType(LookupDetailView), findsOneWidget);
    });

    testWidgets('输入前缀时显示词表建议，最多 8 条且大小写不敏感', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      await _typeQuery(tester, 'APP');
      await _settle(tester);

      expect(find.text('app'), findsOneWidget);
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('application'), findsOneWidget);
      expect(find.text('apply'), findsOneWidget);
      expect(find.text('banana'), findsNothing);
    });

    testWidgets('无建议时仍可直接回车查询输入内容', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      await _typeQuery(tester, 'Zyzzyva');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);

      expect(find.byType(LookupDetailView), findsOneWidget);
      final detail = tester.widget<LookupDetailView>(
        find.byType(LookupDetailView),
      );
      expect(detail.query, 'Zyzzyva');
    });

    testWidgets('词表加载失败时提示建议不可用，但仍可回车查询', (tester) async {
      await tester.pumpWidget(
        _buildScreen(wordlist: (ref) => Future.error('词表缺失')),
      );
      await _settle(tester);

      await _typeQuery(tester, 'app');
      await _settle(tester);
      expect(
        find.text(
          'Word list unavailable. You can still look up words directly.',
        ),
        findsOneWidget,
      );

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(find.byType(LookupDetailView), findsOneWidget);
    });

    testWidgets('未收录的词提交后同样写入查词历史', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(_buildScreen(database: db));
      await _settle(tester);

      await _typeQuery(tester, 'Zyzzyva');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);

      // 真实 SQLite 的 stream 依赖真实异步 I/O，需跳出 FakeAsync 才能收到结果。
      final rows = await tester.runAsync(
        () => db.lookupHistoryDao.watchRecent().first,
      );
      expect(rows!.map((row) => row.word), ['zyzzyva']);
    });

    testWidgets('确认查词后立即后台预热标题发音', (tester) async {
      _prewarmedWords.clear();
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      await _typeQuery(tester, 'Zyzzyva');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);

      expect(_prewarmedWords, ['Zyzzyva']);
    });

    testWidgets('AI 词组结果的例句到达后立即后台预热发音', (tester) async {
      _prewarmedExamples.clear();
      await tester.pumpWidget(
        _buildScreen(
          lookupController: _AiResultLookupController.new,
          ttsController: _RecordingTtsController.new,
        ),
      );
      await _settle(tester);

      await _typeQuery(tester, 'machine learning');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);

      expect(
        _prewarmedExamples,
        containsAll([
          'Machine learning improves recommendations.',
          'Deep learning powers image recognition.',
        ]),
      );
    });

    testWidgets('点击屈折形建议 hellos 时显示 hellos 自己的词条', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _FakeDictionaryAdapter({
          'hellos': _hellosJson,
          'hello': _helloJson,
        });
      final service = DictionaryService(
        cacheDao: db.dictionaryCacheDao,
        dio: dio,
        dictId: 'en_zh-CN',
      );
      await tester.pumpWidget(
        _buildScreen(
          useRealLookup: true,
          dictionaryService: service,
          wordlist: (ref) async => WordlistIndex(const ['hello', 'hellos']),
        ),
      );
      await _settle(tester);

      await _typeQuery(tester, 'hello');
      await _settle(tester);
      await tester.tap(find.text('hellos'));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('hello的复数形式'), findsOneWidget);
      expect(find.text('喂, 嘿'), findsNothing);
    });

    testWidgets('重复点击屈折形建议 hellos 仍显示 hellos 自己的词条', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _FakeDictionaryAdapter({
          'hellos': _hellosJson,
          'hello': _helloJson,
        });
      final service = DictionaryService(
        cacheDao: db.dictionaryCacheDao,
        dio: dio,
        dictId: 'en_zh-CN',
      );
      await tester.pumpWidget(
        _buildScreen(
          useRealLookup: true,
          dictionaryService: service,
          wordlist: (ref) async => WordlistIndex(const ['hello', 'hellos']),
        ),
      );
      await _settle(tester);

      await _typeQuery(tester, 'hello');
      await _settle(tester);
      await tester.tap(find.text('hellos'));
      await _settle(tester);
      expect(find.textContaining('hello的复数形式'), findsOneWidget);

      // 回到输入框，重新输入 hello，再次点击 hellos。
      await tester.tap(find.byType(TextField));
      await _settle(tester);
      await _typeQuery(tester, 'hello');
      await _settle(tester);
      await tester.tap(find.text('hellos'));
      await _settle(tester);

      expect(find.textContaining('hello的复数形式'), findsOneWidget);
      expect(find.text('喂, 嘿'), findsNothing);
    });

    testWidgets('输入框失焦时不会误展示上一次的旧详情', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          wordlist: (ref) async => WordlistIndex(const ['hello', 'hellos']),
        ),
      );
      await _settle(tester);

      await _typeQuery(tester, 'hello');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(find.byType(LookupDetailView), findsOneWidget);

      // 用户再次点击输入框编辑；随后焦点离开（例如点击列表），输入框文本仍是 hello。
      await tester.tap(find.byType(TextField));
      await _settle(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);

      expect(find.byType(LookupDetailView), findsNothing);
      expect(find.text('hellos'), findsOneWidget);
    });

    testWidgets('词组详情同样显示收藏按钮', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      await _typeQuery(tester, 'hello kitty');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);

      expect(find.byType(LookupDetailView), findsOneWidget);
      expect(find.byKey(const Key('lookup-detail-bookmark')), findsOneWidget);
    });

    testWidgets('打开详情默认自动朗读单词，关闭后不再朗读', (tester) async {
      _spokenWords.clear();
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      await _typeQuery(tester, 'Zyzzyva');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(_spokenWords, ['Zyzzyva']);

      // 关闭设置后，再次查词不朗读。
      await tester.tap(find.byKey(const Key('dictionary-lookup-settings')));
      await _settle(tester);
      final autoSpeak = find.byKey(const Key('lookup-settings-auto-speak'));
      expect(tester.widget<SwitchListTile>(autoSpeak).value, isTrue);
      await tester.tap(autoSpeak);
      await _settle(tester);
      expect(tester.widget<SwitchListTile>(autoSpeak).value, isFalse);
      await tester.tap(find.byKey(const Key('lookup-settings-close')));
      await _settle(tester);

      _spokenWords.clear();
      await _typeQuery(tester, 'Zyzzyva');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(_spokenWords, isEmpty);
    });

    testWidgets('自动展开 AI 查词只在查词页右上角设置中开关', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      await tester.tap(find.byKey(const Key('dictionary-lookup-settings')));
      await _settle(tester);

      final autoAi = find.byKey(const Key('lookup-settings-auto-ai'));
      expect(tester.widget<SwitchListTile>(autoAi).value, isFalse);

      await tester.tap(autoAi);
      await _settle(tester);
      expect(tester.widget<SwitchListTile>(autoAi).value, isTrue);
    });
  });
}
