/// SelectableSentenceText（可点词 + 自有选区 + 平台手柄画笔）交互测试
///
/// 组件与 DictionaryPanelHost 组合验证：点词查词（词边界来自自家 tokenizer）、
/// 点空白不触发、自定义操作条、字符级拖选、面板与选区同步关闭、
/// onBeforeLookup 时机，以及「选区不依赖焦点」的一组回归。
library;

import 'dart:async';

import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/database/daos/saved_word_dao.dart';
import 'package:echo_loop/database/daos/saved_sense_group_dao.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/providers/saved_sense_group_provider.dart';
import 'package:echo_loop/providers/saved_word_provider.dart';
import 'package:echo_loop/providers/favorite_vocabulary_lifecycle_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:echo_loop/widgets/practice/selectable_sentence_text.dart';
import 'package:echo_loop/widgets/selection/app_selectable_text.dart';
import 'package:echo_loop/widgets/selection/platform_selection_handles.dart';
import 'package:echo_loop/widgets/selection/text_selection_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

class _MockDictionaryService extends Mock implements DictionaryService {}

/// 单测只验证收藏 DAO 与 UI 状态，不启动真实记忆调度器。
class _TestFavoriteVocabularyLifecycle extends FavoriteVocabularyLifecycle {
  _TestFavoriteVocabularyLifecycle(this._ref) : super(_ref);

  final Ref _ref;

  @override
  Future<void> removeWord(String word) =>
      _ref.read(savedWordDaoProvider).removeWord(word);

  @override
  Future<void> removeSenseGroup(String phraseText) =>
      _ref.read(savedSenseGroupDaoProvider).removeSenseGroup(phraseText);

  @override
  Future<void> saveWord({
    required String word,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) => _ref
      .read(savedWordDaoProvider)
      .saveWord(
        word: word,
        audioItemId: audioItemId,
        sentenceIndex: sentenceIndex,
        sentenceText: sentenceText,
        sentenceStartMs: sentenceStartMs,
        sentenceEndMs: sentenceEndMs,
      );

  @override
  Future<void> saveSenseGroup({
    required String phraseText,
    required String displayText,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
    int? groupStartMs,
    int? groupEndMs,
  }) => _ref
      .read(savedSenseGroupDaoProvider)
      .saveSenseGroup(
        phraseText: phraseText,
        displayText: displayText,
        audioItemId: audioItemId,
        sentenceIndex: sentenceIndex,
        sentenceText: sentenceText,
        sentenceStartMs: sentenceStartMs,
        sentenceEndMs: sentenceEndMs,
        groupStartMs: groupStartMs,
        groupEndMs: groupEndMs,
      );
}

/// 固定收藏单词集合的 fake（绕过 DB）
class _FakeSavedWordTexts extends SavedWordTexts {
  final Set<String> value;
  _FakeSavedWordTexts(this.value);
  @override
  Stream<Set<String>> build() => Stream.value(value);
}

/// 固定收藏意群集合的 fake（绕过 DB）
class _FakeSavedSenseGroupTexts extends SavedSenseGroupTexts {
  final Set<String> value;
  _FakeSavedSenseGroupTexts(this.value);
  @override
  Stream<Set<String>> build() => Stream.value(value);
}

/// 记录选区收藏参数的 SavedWordDao，并提供可流式更新的收藏 key。
class _RecordingSavedWordDao implements SavedWordDao {
  _RecordingSavedWordDao([Set<String> initialWords = const {}])
    : storedWords = {...initialWords};

  final Set<String> storedWords;
  final StreamController<Set<String>> _savedWordsController =
      StreamController<Set<String>>.broadcast();

  String? savedWord;
  String? removedWord;
  String? audioItemId;
  int? sentenceIndex;
  String? sentenceText;
  int? sentenceStartMs;
  int? sentenceEndMs;

  @override
  Stream<List<SavedWord>> watchAll() => Stream.value(const <SavedWord>[]);

  @override
  Stream<Set<String>> watchSavedWordTexts() async* {
    yield Set<String>.unmodifiable(storedWords);
    yield* _savedWordsController.stream;
  }

  @override
  Future<void> saveWord({
    required String word,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) async {
    savedWord = word;
    this.audioItemId = audioItemId;
    this.sentenceIndex = sentenceIndex;
    this.sentenceText = sentenceText;
    this.sentenceStartMs = sentenceStartMs;
    this.sentenceEndMs = sentenceEndMs;
    storedWords.add(word);
    _savedWordsController.add(Set<String>.unmodifiable(storedWords));
  }

  @override
  Future<void> removeWord(String word) async {
    removedWord = word;
    storedWords.remove(word);
    _savedWordsController.add(Set<String>.unmodifiable(storedWords));
  }

  @override
  Future<SavedWord?> getByWord(String word) async {
    final now = DateTime(2026);
    return SavedWord(
      id: 1,
      word: word,
      practiceCount: 0,
      totalStudyMs: 0,
      viewedBack: false,
      createdAt: now,
      updatedAt: now,
      syncStatus: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 记录查词面板取消收藏时的意群删除，并提供收藏文本流。
class _RecordingSavedSenseGroupDao implements SavedSenseGroupDao {
  _RecordingSavedSenseGroupDao([Set<String> initialPhrases = const {}])
    : storedPhrases = {...initialPhrases};

  final Set<String> storedPhrases;
  final StreamController<Set<String>> _phrasesController =
      StreamController<Set<String>>.broadcast();

  String? removedPhrase;

  @override
  Stream<List<SavedSenseGroup>> watchAll() =>
      Stream.value(const <SavedSenseGroup>[]);

  @override
  Stream<Set<String>> watchSavedPhraseTexts() async* {
    yield Set<String>.unmodifiable(storedPhrases);
    yield* _phrasesController.stream;
  }

  @override
  Future<void> removeSenseGroup(String phraseText) async {
    removedPhrase = phraseText;
    storedPhrases.remove(phraseText);
    _phrasesController.add(Set<String>.unmodifiable(storedPhrases));
  }

  @override
  Future<SavedSenseGroup?> getByPhraseText(String phraseText) async {
    if (!storedPhrases.contains(phraseText)) return null;
    final now = DateTime(2026);
    return SavedSenseGroup(
      id: 1,
      phraseText: phraseText,
      displayText: phraseText,
      practiceCount: 0,
      totalStudyMs: 0,
      viewedBack: false,
      createdAt: now,
      updatedAt: now,
      syncStatus: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 回显查询词的 fake 本地源（记录收到的查询）
class _EchoLocalSource implements DictionarySource {
  final List<String> queries = [];
  @override
  String get id => 'local';
  @override
  IconData get icon => Icons.abc;
  @override
  bool get canBeDisabled => false;
  @override
  bool get requiresNetwork => false;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    queries.add(request.word);
    return LocalDictResult(
      DictEntry(word: request.word, phonetic: 'x', translation: '释义'),
    );
  }
}

/// 记录查询的 fake AI 源；只验证面板切源，不进入真实流式网络链路。
class _EchoAiSource implements DictionarySource {
  final List<String> queries = [];
  @override
  String get id => 'ai';
  @override
  IconData get icon => Icons.auto_awesome;
  @override
  bool get canBeDisabled => true;
  @override
  bool get requiresNetwork => true;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    queries.add(request.word);
    return LocalDictResult(
      DictEntry(word: request.word, phonetic: 'x', translation: 'AI 释义'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService oldInstance;
  late SharedPreferences prefs;
  late _EchoLocalSource source;
  String? clipboardText;
  final hapticCalls = <Object?>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final mock = _MockDictionaryService();
    when(() => mock.isAvailable).thenReturn(true);
    oldInstance = DictionaryService.replaceInstance(mock);
    source = _EchoLocalSource();
    clipboardText = null;
    hapticCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments;
            if (arguments is Map) {
              final text = arguments['text'];
              if (text is String) clipboardText = text;
            }
          }
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call.arguments);
          }
          return null;
        });
  });

  tearDown(() {
    DictionaryService.replaceInstance(oldInstance);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final hostKey = GlobalKey<DictionaryPanelHostState>();

  Widget wrap({
    String text = 'alpha beta gamma',
    List<SpeechTranscriptSegment>? segments,
    Locale locale = const Locale('en'),
    DictionaryLookupOrigin origin = const DictionaryLookupOrigin(
      sentenceText: 'ctx',
    ),
    VoidCallback? onBeforeLookup,
    Widget Function(Widget sentence)? layout,
    List<Override> overrides = const [],
    ThemeMode themeMode = ThemeMode.light,
    TextStyle? style,
  }) => ProviderScope(
    // 调用方 overrides 置于列表末尾：Riverpod 重复 override 为 last-wins，
    // 保证调用方能覆盖同名默认 provider（与 createTestApp 约定一致）
    overrides: [
      analyticsOverride(),
      favoriteVocabularyLifecycleProvider.overrideWith(
        _TestFavoriteVocabularyLifecycle.new,
      ),
      dictionaryOverride(),
      sharedPreferencesProvider.overrideWithValue(prefs),
      dictionarySourcesProvider.overrideWithValue([source]),
      dictionarySourcesByIdProvider.overrideWithValue({'local': source}),
      resolvedDefaultSourceIdProvider.overrideWithValue('local'),
      savedWordDaoProvider.overrideWithValue(_RecordingSavedWordDao()),
      savedSenseGroupDaoProvider.overrideWithValue(
        _RecordingSavedSenseGroupDao(),
      ),
      dictionaryLookupContextProvider.overrideWithValue(
        const DictionaryLookupContext(
          accessToken: 'tok',
          targetLanguage: 'zh-CN',
        ),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(
        body: DictionaryPanelHost(
          key: hostKey,
          child: Builder(
            builder: (context) {
              final sentence = SelectableSentenceText(
                text: text,
                style: style,
                highlightedSegments: segments,
                origin: origin,
                onBeforeLookup: onBeforeLookup,
              );
              if (layout != null) return layout(sentence);
              return Align(alignment: Alignment.topLeft, child: sentence);
            },
          ),
        ),
      ),
    ),
  );

  /// 取自有选区组件的 state（选区真相源与几何入口）。
  AppSelectableTextState selectionState(WidgetTester tester) =>
      tester.state<AppSelectableTextState>(find.byType(AppSelectableText));

  /// 取句中某个词的几何中心（全局坐标）。
  Offset wordCenter(WidgetTester tester, String word) {
    final paragraph = selectionState(tester).contentParagraph!;
    final text = (paragraph.text as TextSpan).toPlainText();
    final start = text.indexOf(word);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    return paragraph.localToGlobal(boxes.first.toRect().center);
  }

  /// 点击句中某个词的中心。
  Future<void> tapWord(WidgetTester tester, String word) async {
    await tester.tapAt(wordCenter(tester, word));
  }

  /// 当前选中文本。
  String selectedText(WidgetTester tester) =>
      selectionState(tester).selectedText;

  /// 取句中某个词左边界的几何位置（从词首开始拖选用）。
  Offset wordLeftEdge(WidgetTester tester, String word) {
    final paragraph = selectionState(tester).contentParagraph!;
    final text = (paragraph.text as TextSpan).toPlainText();
    final start = text.indexOf(word);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    final rect = boxes.first.toRect();
    return paragraph.localToGlobal(Offset(rect.left + 1, rect.center.dy));
  }

  /// 取句中某个词右边界的几何位置（拖选到「含该词」用）。
  Offset wordRightEdge(WidgetTester tester, String word) {
    final paragraph = selectionState(tester).contentParagraph!;
    final text = (paragraph.text as TextSpan).toPlainText();
    final start = text.indexOf(word);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    final rect = boxes.last.toRect();
    return paragraph.localToGlobal(Offset(rect.right - 1, rect.center.dy));
  }

  /// 取某个字符偏移的几何中心（全局坐标）。
  Offset charCenter(WidgetTester tester, int offset) {
    final paragraph = selectionState(tester).contentParagraph!;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    return paragraph.localToGlobal(boxes.first.toRect().center);
  }

  /// 走真实手势建立多词选区：长按 [from] 选中该词 → 拖到 [to] → 松手提交。
  Future<void> longPressSelect(
    WidgetTester tester, {
    required Offset from,
    required Offset to,
  }) async {
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// 操作条外壳（可见性断言用）。
  final toolbarSurface = find.byKey(
    const ValueKey('selection_toolbar_surface'),
  );

  /// 取正文的全部子 span。
  List<TextSpan> sentenceSpans(WidgetTester tester) {
    final paragraph = selectionState(tester).contentParagraph!;
    return (paragraph.text as TextSpan).children!.cast<TextSpan>();
  }

  testWidgets('点词：打开面板查询该词（剥标点交给归一化），onBeforeLookup 先触发', (tester) async {
    var beforeCalls = 0;
    await tester.pumpWidget(wrap(onBeforeLookup: () => beforeCalls++));
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    expect(beforeCalls, 1);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(source.queries, ['beta']);
    expect(selectedText(tester), 'beta');
    expect(toolbarSurface, findsOneWidget);
  });

  testWidgets('点连字符/缩写词：高亮、查询与收藏三者同一个词', (tester) async {
    // 词边界的唯一来源必须是自家 tokenizer。平台 ICU 边界会在连字符处断词
    // （co-op → co/-/op），导致「高亮 / 面板查询 / 操作条收藏 / 面板书签收藏」
    // 四处不一致。
    final dao = _RecordingSavedWordDao();
    await tester.pumpWidget(
      wrap(
        text: 'a co-op and e.g. here',
        overrides: [
          savedWordDaoProvider.overrideWithValue(dao),
          usageOverride(),
          notificationPermissionOverride(),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tapWord(tester, 'co-op');
    await tester.pumpAndSettle();

    expect(selectedText(tester), 'co-op');
    expect(source.queries, ['co-op']);

    await tester.tap(find.byKey(const Key('selection_toolbar_button_Save')));
    await tester.pumpAndSettle();
    expect(dao.savedWord, 'co-op');
  });

  testWidgets('点缩写词：选区剥掉尾部句点，与归一化后的查询词一致', (tester) async {
    await tester.pumpWidget(wrap(text: 'a co-op and e.g. here'));
    await tester.pumpAndSettle();
    await tapWord(tester, 'e.g');
    await tester.pumpAndSettle();

    expect(selectedText(tester), 'e.g');
    expect(source.queries, ['e.g']);
  });

  testWidgets(
    'Apple 平台：选中背景用系统蓝、手柄用 Cupertino 平台画笔，高亮矩形贴字形',
    (tester) async {
      await tester.pumpWidget(wrap());
      final context = tester.element(find.byType(AppSelectableText));
      final expectedColor = CupertinoColors.systemBlue
          .resolveFrom(context)
          .withValues(alpha: 0.2);
      expect(DefaultSelectionStyle.of(context).selectionColor, expectedColor);
      expect(
        CupertinoTheme.of(context).selectionHandleColor,
        CupertinoColors.systemBlue.resolveFrom(context),
      );
      // 手柄画笔取自平台，不自绘。
      expect(
        platformHandleControls(context),
        same(cupertinoTextSelectionHandleControls),
      );

      await tapWord(tester, 'beta');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selection_handle_start')), findsOneWidget);
      expect(find.byKey(const Key('selection_handle_end')), findsOneWidget);

      // 高亮矩形按 BoxHeightStyle.tight：高度贴字形，不含 1.6 行高的额外 leading。
      final paragraph = selectionState(tester).contentParagraph!;
      final range = selectionState(tester).selectionRange!;
      final selection = TextSelection(
        baseOffset: range.start,
        extentOffset: range.end,
      );
      final tight = paragraph
          .getBoxesForSelection(
            selection,
            boxHeightStyle: ui.BoxHeightStyle.tight,
          )
          .first
          .toRect();
      final max = paragraph
          .getBoxesForSelection(
            selection,
            boxHeightStyle: ui.BoxHeightStyle.max,
          )
          .first
          .toRect();
      expect(tight.height, lessThan(max.height));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android 句子讲解文本使用平台选择蓝与 Material 手柄画笔，不回落到 App 主题色',
    (tester) async {
      await tester.pumpWidget(wrap());
      final context = tester.element(find.byType(AppSelectableText));
      expect(
        DefaultSelectionStyle.of(context).selectionColor,
        Colors.blue.withValues(alpha: 0.4),
      );
      expect(TextSelectionTheme.of(context).selectionHandleColor, Colors.blue);
      expect(
        platformHandleControls(context),
        same(materialTextSelectionHandleControls),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    '深色主题选中背景使用高对比度蓝，避免纯黑页面选区不可见',
    (tester) async {
      await tester.pumpWidget(wrap(themeMode: ThemeMode.dark));
      final context = tester.element(find.byType(AppSelectableText));

      expect(
        DefaultSelectionStyle.of(context).selectionColor,
        AppTheme.navActiveColor.withValues(alpha: 0.6),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android 句子查词手柄位于选区下方',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tapWord(tester, 'beta');
      await tester.pumpAndSettle();

      final paragraph = selectionState(tester).contentParagraph!;
      final range = selectionState(tester).selectionRange!;
      final selectedBox = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: range.start, extentOffset: range.end),
          )
          .first
          .toRect();
      final handleCenter = paragraph.globalToLocal(
        tester.getRect(find.byKey(const Key('selection_handle_end'))).center,
      );

      expect(handleCenter.dy, greaterThan(selectedBox.bottom));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('自定义操作条显示复制、收藏和问 AI', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          remoteFeatureEnabledProvider(
            RemoteFeature.aiChatAssistant,
          ).overrideWithValue(true),
        ],
      ),
    );
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selection_toolbar_button_Copy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('selection_toolbar_button_Save')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('selection_toolbar_button_Ask AI')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('selection_toolbar_surface')),
      findsOneWidget,
    );
    expect(find.text('Share'), findsNothing);
    expect(find.text('Select all'), findsNothing);
  });

  testWidgets('AI 远程开关关闭时操作条仍显示复制和收藏', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          remoteFeatureEnabledProvider(
            RemoteFeature.aiChatAssistant,
          ).overrideWithValue(false),
        ],
      ),
    );
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selection_toolbar_button_Copy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('selection_toolbar_button_Save')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('selection_toolbar_button_Ask AI')),
      findsNothing,
    );
  });

  testWidgets('收藏多词选区：按词汇规则归一化、保存来源并保留查词现场', (tester) async {
    final dao = _RecordingSavedWordDao();
    const origin = DictionaryLookupOrigin(
      audioItemId: 'audio-1',
      sentenceIndex: 7,
      sentenceText: 'Alpha   beta, gamma',
      sentenceStartMs: 1200,
      sentenceEndMs: 3400,
    );
    await tester.pumpWidget(
      wrap(
        text: 'Alpha   beta, gamma',
        origin: origin,
        overrides: [
          savedWordDaoProvider.overrideWithValue(dao),
          usageOverride(),
          notificationPermissionOverride(),
          remoteFeatureEnabledProvider(
            RemoteFeature.aiChatAssistant,
          ).overrideWithValue(false),
        ],
      ),
    );
    // 走真实手势：长按 Alpha 建立选区，拖到 beta 末尾，松手提交多词查询。
    await longPressSelect(
      tester,
      from: wordCenter(tester, 'Alpha'),
      to: wordRightEdge(tester, 'beta'),
    );

    await tester.tap(find.byKey(const Key('selection_toolbar_button_Save')));
    await tester.pumpAndSettle();

    expect(dao.savedWord, 'alpha beta');
    expect(dao.audioItemId, 'audio-1');
    expect(dao.sentenceIndex, 7);
    expect(dao.sentenceText, 'Alpha   beta, gamma');
    expect(dao.sentenceStartMs, 1200);
    expect(dao.sentenceEndMs, 3400);
    expect(selectionState(tester).hasActiveSelection, isTrue);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(
      find.byKey(const Key('selection_toolbar_button_Save')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('selection_toolbar_button_Unsave')),
      findsOneWidget,
    );
  });

  testWidgets('已收藏选区显示取消收藏，并复用词汇移除流程', (tester) async {
    final dao = _RecordingSavedWordDao({'beta'});
    await tester.pumpWidget(
      wrap(
        overrides: [
          savedWordDaoProvider.overrideWithValue(dao),
          usageOverride(),
          notificationPermissionOverride(),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selection_toolbar_button_Unsave')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('selection_toolbar_button_Unsave')));
    await tester.pumpAndSettle();

    expect(dao.removedWord, 'beta');
    expect(selectionState(tester).hasActiveSelection, isTrue);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(
      find.byKey(const Key('selection_toolbar_button_Unsave')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('selection_toolbar_button_Save')),
      findsOneWidget,
    );
  });

  testWidgets('面板收藏与取消收藏只更新收藏状态，始终保留选区和查词现场', (tester) async {
    final dao = _RecordingSavedWordDao();
    await tester.pumpWidget(
      wrap(
        overrides: [
          savedWordDaoProvider.overrideWithValue(dao),
          usageOverride(),
          notificationPermissionOverride(),
        ],
      ),
    );
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    final originalRange = selectionState(tester).selectionRange;
    expect(selectedText(tester), 'beta');
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    // 收藏态单一来源：面板书签与操作条按钮必须始终同步。
    expect(
      find.byKey(const Key('selection_toolbar_button_Save')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('dict_panel_bookmark')));
    await tester.pumpAndSettle();

    expect(dao.savedWord, 'beta');
    expect(selectionState(tester).selectionRange, originalRange);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(
      find.byKey(const Key('selection_toolbar_button_Unsave')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('dict_panel_bookmark')));
    await tester.pumpAndSettle();

    expect(dao.removedWord, 'beta');
    expect(selectionState(tester).selectionRange, originalRange);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(
      find.byKey(const Key('selection_toolbar_button_Save')),
      findsOneWidget,
    );
  });

  testWidgets('面板将意群表中的同名多词视为已收藏，取消时清理两类记录', (tester) async {
    final wordDao = _RecordingSavedWordDao();
    final senseGroupDao = _RecordingSavedSenseGroupDao({'beta gamma'});
    await tester.pumpWidget(
      wrap(
        overrides: [
          savedWordDaoProvider.overrideWithValue(wordDao),
          savedSenseGroupDaoProvider.overrideWithValue(senseGroupDao),
          usageOverride(),
          notificationPermissionOverride(),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await longPressSelect(
      tester,
      from: wordCenter(tester, 'beta'),
      to: wordRightEdge(tester, 'gamma'),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.byKey(const Key('dict_panel_bookmark')));
    await tester.pumpAndSettle();

    expect(wordDao.removedWord, 'beta gamma');
    expect(senseGroupDao.removedPhrase, 'beta gamma');
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('中文取消收藏在选区操作栏中保持单行', (tester) async {
    final dao = _RecordingSavedWordDao({'beta'});
    await tester.pumpWidget(
      wrap(
        locale: const Locale('zh'),
        overrides: [savedWordDaoProvider.overrideWithValue(dao)],
      ),
    );
    await tester.pumpAndSettle();
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('取消收藏'));
    expect(label.maxLines, 1);
    expect(label.softWrap, isFalse);
  });

  testWidgets('复制写入精确选区，并同步清除选区与词典面板', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('selection_toolbar_button_Copy')));
    await tester.pumpAndSettle();

    expect(clipboardText, 'beta');
    expect(selectionState(tester).selectionRange, isNull);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets('拖手柄保持字符级自由边界，不吸附到完整单词', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'alpha');
    await tester.pumpAndSettle();
    expect(
      selectionState(tester).selectionRange,
      const TextRange(start: 0, end: 5),
    );

    // 把结束手柄拖到 beta 内部：手柄拖拽在所有平台都是字符级，不吸附到词边界。
    final paragraph = selectionState(tester).contentParagraph!;
    final midBeta = paragraph.localToGlobal(
      paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 8, extentOffset: 9),
          )
          .first
          .toRect()
          .center,
    );
    // Android 手柄视觉中心悬在文字下方；从命中区域靠近文字的一侧开始，
    // 避免测试指针落到可选文本宿主的外层布局边界之外。
    final handleRect = tester.getRect(
      find.byKey(const Key('selection_handle_end')),
    );
    final handle = handleRect.topCenter + const Offset(0, 2);
    await tester.dragFrom(handle, midBeta - handle);
    await tester.pumpAndSettle();

    final range = selectionState(tester).selectionRange!;
    expect(range.start, 0);
    expect(range.end, greaterThan(6));
    expect(range.end, lessThan(10), reason: '未被吸附到 beta 末尾');
    expect(selectedText(tester), startsWith('alpha b'));
  });

  testWidgets(
    '长按落在词间空白后拖动仍能选择（不是死手势）',
    (tester) async {
      const text = 'alpha beta gamma';
      await tester.pumpWidget(wrap(text: text));
      final gesture = await tester.startGesture(
        charCenter(tester, text.indexOf(' ')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      // 仅长按空白：不形成选区、不查词。
      expect(selectionState(tester).selectionRange, isNull);
      expect(source.queries, isEmpty);

      await gesture.moveTo(wordRightEdge(tester, 'beta'));
      await tester.pump();
      expect(
        selectionState(tester).hasActiveSelection ||
            selectionState(tester).selectionPhase ==
                TextSelectionPhase.selecting,
        isTrue,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(source.queries, isNotEmpty);
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('桌面鼠标按住拖动即可选择（不必长按）', (tester) async {
    // 之前用 SelectableText 时这条是框架白送的；自有实现必须显式支持，否则桌面
    // 只剩点选。recognizer 限定 mouse，触屏路径不受影响。
    await tester.pumpWidget(wrap());
    // 桌面拖选是字符级、从**按下处**起算，所以从词首边缘起手。
    final from = wordLeftEdge(tester, 'alpha');
    final to = wordRightEdge(tester, 'beta');
    final gesture = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset((from.dx + to.dx) / 2, from.dy));
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    // 拖动过程中就有选区（尚未提交查询）。
    expect(selectionState(tester).selectionPhase, TextSelectionPhase.selecting);
    expect(source.queries, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectionState(tester).selectionPhase, TextSelectionPhase.active);
    expect(selectedText(tester), 'alpha beta');
    expect(source.queries, ['alpha beta']);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets(
    '鼠标点击带 2px 手抖仍按点词处理（精确指针 slop 只有 1px）',
    (tester) async {
      await tester.pumpWidget(wrap());
      final target = wordCenter(tester, 'beta');
      final gesture = await tester.startGesture(
        target,
        kind: PointerDeviceKind.mouse,
      );
      // 抖 2px：足以让 pan 赢下竞技场、tap 落败，必须由 pan 结束时兜底成点击。
      await gesture.moveTo(target + const Offset(2, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selectedText(tester), 'beta');
      expect(source.queries, ['beta']);
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('文字区域显示 I-beam 光标（桌面）', (tester) async {
    await tester.pumpWidget(wrap());
    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(AppSelectableText),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.text);
  });

  testWidgets('正文内点击空白取消选区后关闭当前句子的词典面板', (tester) async {
    // 取点必须远离两侧手柄：手柄命中区是以选区端点为中心的 36dp（Flutter 自己的
    // 手柄用 48dp），紧贴选区的空白会被手柄拖拽抢走，那属于手柄交互而非取消选择。
    const text = 'alpha beta gamma delta';
    await tester.pumpWidget(wrap(text: text));
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

    await tester.tapAt(charCenter(tester, text.indexOf(' delta')));
    await tester.pumpAndSettle();

    expect(selectionState(tester).selectionRange, isNull);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets(
    '长按纯标点不发起查词且不显示词典面板',
    (tester) async {
      await tester.pumpWidget(wrap(text: 'alpha ... beta'));

      await tester.longPressAt(wordCenter(tester, '...'));
      await tester.pumpAndSettle();

      expect(source.queries, isEmpty);
      expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('面板内切换 AI 后选区与操作条不变（选区不依赖焦点）', (tester) async {
    final ai = _EchoAiSource();
    await tester.pumpWidget(
      wrap(
        overrides: [
          dictionarySourcesProvider.overrideWithValue([source, ai]),
          dictionarySourcesByIdProvider.overrideWithValue({
            'local': source,
            'ai': ai,
          }),
        ],
      ),
    );
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    // 选区归本组件所有，不挂在任何 FocusNode 上：面板内的交互不可能影响它，
    // 因此不需要任何「失焦后恢复选区」的逻辑（那正是旧实现补丁的来源）。
    await tester.tap(find.text('AI'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(ai.queries, ['beta']);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(selectedText(tester), 'beta');
    expect(toolbarSurface, findsOneWidget);
  });

  testWidgets(
    '面板覆盖选区：操作条被面板挡住是布局结果，选区全程不变',
    (tester) async {
      final ai = _EchoAiSource();
      await tester.pumpWidget(
        wrap(
          layout: (sentence) =>
              Stack(children: [Positioned(left: 0, top: 250, child: sentence)]),
          overrides: [
            dictionarySourcesProvider.overrideWithValue([source, ai]),
            dictionarySourcesByIdProvider.overrideWithValue({
              'local': source,
              'ai': ai,
            }),
            resolvedDefaultSourceIdProvider.overrideWithValue('ai'),
          ],
        ),
      );
      await tapWord(tester, 'beta');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      const expected = TextRange(start: 6, end: 10);
      expect(selectionState(tester).selectionRange, expected);
      expect(toolbarSurface, findsOneWidget);
      final toolbarTop = tester.getTopLeft(toolbarSurface).dy;

      final handle = find.byKey(const Key('dict_drag_handle'));
      await tester.drag(handle, const Offset(0, -220));
      await tester.pump();
      await tester.pump();

      // 操作条与手柄都在正文所在的 Stack 内、位于面板之下：被面板覆盖是层序的
      // 自然结果，不再需要「算遮挡 → 隐藏 → 露出后恢复」那套状态机。
      final panelTop = tester
          .getTopLeft(find.byKey(const Key('dict_sheet_sizer')))
          .dy;
      expect(panelTop, lessThan(toolbarTop));
      expect(selectionState(tester).selectionRange, expected);
      expect(toolbarSurface, findsOneWidget);

      await tester.drag(handle, const Offset(0, 300));
      await tester.pump();
      await tester.pump();

      expect(selectionState(tester).selectionRange, expected);
      expect(toolbarSurface, findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    '前后台切换保留面板、选区与操作条（无需任何生命周期恢复代码）',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tapWord(tester, 'beta');
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
      expect(selectionState(tester).hasActiveSelection, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
      expect(selectedText(tester), 'beta');
      expect(toolbarSurface, findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'Android 长按期间不查词，松手后查询系统选中的单词',
    (tester) async {
      await tester.pumpWidget(wrap());
      final gesture = await tester.startGesture(wordCenter(tester, 'beta'));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      expect(source.queries, isEmpty);

      await gesture.up();
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'PointerUp 后必须主动请求一帧执行最终选区查询',
      );
      await tester.pumpAndSettle();
      expect(source.queries, ['beta']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    '已有面板时长按等待和拖选期间保持面板，松手后才提交最终选区',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tapWord(tester, 'beta');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

      final gesture = await tester.startGesture(wordCenter(tester, 'alpha'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
      expect(source.queries, ['beta']);

      await tester.pump(kLongPressTimeout);
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
      expect(source.queries, ['beta']);

      await gesture.moveTo(wordCenter(tester, 'gamma'));
      await tester.pump();
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
      expect(source.queries, ['beta']);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
      expect(source.queries, ['beta', 'alpha beta gamma']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android 长按统一触发选择轻反馈和平台长按反馈',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.longPressAt(wordCenter(tester, 'beta'));
      await tester.pumpAndSettle();

      expect(hapticCalls, ['HapticFeedbackType.selectionClick', null]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS 首次未聚焦和再次长按都触发相同反馈',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.longPressAt(wordCenter(tester, 'beta'));
      await tester.pumpAndSettle();

      expect(hapticCalls, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.heavyImpact',
      ]);

      hapticCalls.clear();
      await tester.longPressAt(wordCenter(tester, 'gamma'));
      await tester.pumpAndSettle();
      expect(hapticCalls, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.heavyImpact',
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android 长按拖选期间不查词，松手后查询最终选区',
    (tester) async {
      await tester.pumpWidget(wrap());
      final gesture = await tester.startGesture(wordCenter(tester, 'alpha'));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveTo(wordCenter(tester, 'gamma'));
      await tester.pump();
      expect(source.queries, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(source.queries, ['alpha beta gamma']);
      expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
      expect(toolbarSurface, findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android 长按取消不触发查词',
    (tester) async {
      await tester.pumpWidget(wrap());
      final gesture = await tester.startGesture(wordCenter(tester, 'beta'));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(source.queries, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('面板开着时：点句子里另一个词切换查询（豁免放行），点句子外空白关面板', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'alpha');
    await tester.pumpAndSettle();
    expect(source.queries, ['alpha']);

    // 点句子里另一个词：屏障豁免放行，切换查询、面板不关
    await tapWord(tester, 'gamma');
    await tester.pumpAndSettle();
    expect(source.queries, ['alpha', 'gamma']);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

    // 点句子外空白（正文中部）：屏障关面板并吸收点击
    await tester.tapAt(const Offset(400, 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
    // 未发起新查询
    expect(source.queries, ['alpha', 'gamma']);
  });

  testWidgets('面板开着时点句子紧邻上下的下层控件：关面板并吸收，不误触发下层交互', (tester) async {
    // 复现真机反馈：句子上方一小条区域点击触发了「隐藏字幕」、解析按钮
    // 被误触发——旧实现豁免区是组件 bounds 上下外扩 36dp 的粗矩形。
    var aboveTaps = 0;
    var belowTaps = 0;
    await tester.pumpWidget(
      wrap(
        layout: (sentence) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: const Key('above_area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => aboveTaps++,
              child: const SizedBox(width: 600, height: 30),
            ),
            sentence,
            GestureDetector(
              key: const Key('below_area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => belowTaps++,
              child: const SizedBox(width: 600, height: 30),
            ),
          ],
        ),
      ),
    );
    // 面板关闭时下层控件正常可点（取右侧远离手柄横坐标的点，下同）
    final abovePoint = Offset(
      500,
      tester.getRect(find.byKey(const Key('above_area'))).center.dy,
    );
    await tester.tapAt(abovePoint);
    expect(aboveTaps, 1);

    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

    // 面板开着：点句子上方紧邻控件 → 屏障关面板并吸收，下层不触发
    await tester.tapAt(abovePoint);
    await tester.pumpAndSettle();
    expect(aboveTaps, 1);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);

    // 再开面板：点句子下方紧邻控件同理
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();
    final belowPoint = Offset(
      500,
      tester.getRect(find.byKey(const Key('below_area'))).center.dy,
    );
    await tester.tapAt(belowPoint);
    await tester.pumpAndSettle();
    expect(belowTaps, 0);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets('面板关闭即结束查词会话：选区、手柄与操作条一起消失', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.longPressAt(wordCenter(tester, 'beta'));
    await tester.pumpAndSettle();
    expect(selectionState(tester).hasActiveSelection, isTrue);
    expect(find.byKey(const Key('selection_handle_start')), findsOneWidget);
    expect(toolbarSurface, findsOneWidget);

    hostKey.currentState!.close();
    await tester.pumpAndSettle();

    expect(selectionState(tester).selectionRange, isNull);
    expect(find.byKey(const Key('selection_handle_start')), findsNothing);
    expect(toolbarSurface, findsNothing);
  });

  testWidgets('学习内容字号：正文样式按偏好倍率放大', (tester) async {
    await prefs.setDouble('reading_font_scale', 1.5);
    await tester.pumpWidget(wrap(style: const TextStyle(fontSize: 16)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSelectableText>(find.byType(AppSelectableText))
          .style
          ?.fontSize,
      24,
    );
  });

  testWidgets('学习内容字号：默认倍率保持正文样式原样', (tester) async {
    await tester.pumpWidget(wrap(style: const TextStyle(fontSize: 16)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSelectableText>(find.byType(AppSelectableText))
          .style
          ?.fontSize,
      16,
    );
  });

  testWidgets('评分片段染色仍生效（命中片段绿色）', (tester) async {
    await tester.pumpWidget(
      wrap(
        segments: const [
          SpeechTranscriptSegment(text: 'alpha ', isMatched: true),
          SpeechTranscriptSegment(text: 'beta gamma', isMatched: false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final spans = sentenceSpans(tester);
    // 首 token alpha 应为绿色
    expect(spans.first.text, 'alpha');
    expect(spans.first.style?.color, const Color(0xFF2E9B51));
    // beta 不染色
    final beta = spans.firstWhere((s) => s.text == 'beta');
    expect(beta.style?.color, isNull);
  });

  testWidgets('收藏单词渲染橙色点状下划线，未收藏词无标记', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          savedWordTextsProvider.overrideWith(
            () => _FakeSavedWordTexts({'beta'}),
          ),
        ],
      ),
    );
    await tester.pump(); // 等收藏集合流发射

    final spans = sentenceSpans(tester);
    final beta = spans.firstWhere((s) => s.text == 'beta');
    expect(beta.style?.decoration, TextDecoration.underline);
    expect(beta.style?.decorationStyle, TextDecorationStyle.dotted);
    expect(beta.style?.decorationColor, Colors.orange.shade400);
    final alpha = spans.firstWhere((s) => s.text == 'alpha');
    expect(alpha.style?.decoration, isNull);
  });

  testWidgets('收藏词组下划线连续横跨词间空白', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          savedWordTextsProvider.overrideWith(
            () => _FakeSavedWordTexts({'beta gamma'}),
          ),
        ],
      ),
    );
    await tester.pump();

    final spans = sentenceSpans(tester);
    // beta、词间空白、gamma 三个 span 都带下划线，alpha 及其后空白不带
    for (final text in ['beta', ' ', 'gamma']) {
      final span = spans.lastWhere((s) => s.text == text);
      expect(
        span.style?.decoration,
        TextDecoration.underline,
        reason: 'span "$text" 应带下划线',
      );
    }
    final alpha = spans.firstWhere((s) => s.text == 'alpha');
    expect(alpha.style?.decoration, isNull);
    final firstSpace = spans.firstWhere((s) => s.text == ' ');
    expect(firstSpace.style?.decoration, isNull);
  });

  testWidgets('收藏意群（normalizeSenseGroupPhrase 规则）也命中标记', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          savedSenseGroupTextsProvider.overrideWith(
            () => _FakeSavedSenseGroupTexts({'alpha beta'}),
          ),
        ],
      ),
    );
    await tester.pump();

    final spans = sentenceSpans(tester);
    expect(
      spans.firstWhere((s) => s.text == 'alpha').style?.decoration,
      TextDecoration.underline,
    );
    expect(
      spans.firstWhere((s) => s.text == 'beta').style?.decoration,
      TextDecoration.underline,
    );
    expect(
      spans.firstWhere((s) => s.text == 'gamma').style?.decoration,
      isNull,
    );
  });

  testWidgets('收藏下划线与评分染色可同时渲染', (tester) async {
    await tester.pumpWidget(
      wrap(
        segments: const [
          SpeechTranscriptSegment(text: 'alpha ', isMatched: true),
          SpeechTranscriptSegment(text: 'beta gamma', isMatched: false),
        ],
        overrides: [
          savedWordTextsProvider.overrideWith(
            () => _FakeSavedWordTexts({'alpha'}),
          ),
        ],
      ),
    );
    await tester.pump();

    final alpha = sentenceSpans(tester).firstWhere((s) => s.text == 'alpha');
    expect(alpha.style?.color, const Color(0xFF2E9B51));
    expect(alpha.style?.decoration, TextDecoration.underline);
  });
}
