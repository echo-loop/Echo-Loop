/// DictionaryPanel 内容渲染测试（本地词典源各数据场景）
///
/// 使用内存 SQLite 数据库替换 DictionaryService 单例，
/// 验证弹窗在各种数据场景下的 UI 渲染。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/saved_word_provider.dart';
import 'package:echo_loop/utils/saved_text_index.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:echo_loop/widgets/tts/speak_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../helpers/mock_providers.dart';

/// 词典设置读取的 SharedPreferences（在 setUp 注入），供 [_buildTestPage] override
late SharedPreferences _prefs;

/// 记录桩控制器每次 TTS 文本预热的入参（在 setUp 清空），
/// 供断言「打开弹窗即以单词本身预热」。
final List<List<String>> _prewarmCalls = [];

/// 记录面板交给统一朗读入口预热的标题单词（在 setUp 清空）。
final List<String> _headwordPrewarmCalls = [];
final List<String> _autoSpeakCalls = [];
final List<bool> _autoSpeakPromptFlags = [];
String? _initialSpeakingKey;
int _ttsStopCalls = 0;
int _textPlaybackStopCalls = 0;
bool _forwardTextPlaybackToTts = false;

/// 桩 [TtsController]：弹窗内嵌发音按钮、查词完成会自动触发例句预热，
/// 真实控制器会经平台 TTS 引擎/method channel 异步合成，在 widget 测试中
/// 永不完成而拖住 pumpAndSettle（并发跑时确定性挂起）。这里把预热/发音/停止
/// 全部置空，使本测试只验证弹窗 UI、不触碰真实 TTS 栈。
class _StubTtsController extends TtsController {
  @override
  TtsControllerState build() =>
      TtsControllerState(speakingKey: _initialSpeakingKey);
  @override
  Future<void> speak(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    state = TtsControllerState(speakingKey: key ?? text);
  }

  @override
  Future<void> prewarmTexts(List<String> texts) async {
    _prewarmCalls.add(texts);
  }

  @override
  Future<void> prewarmTextsIncremental(List<String> texts) async {
    _prewarmCalls.add(texts);
  }

  @override
  void cancelTextsPrewarm() {}
  @override
  Future<void> stop() async {
    _ttsStopCalls++;
  }
}

/// 记录词典自动发音调用，避免测试触碰真实音频播放器。
class _StubTextPlaybackController extends TextPlaybackController {
  @override
  TextPlaybackState build() => const TextPlaybackState();

  @override
  Future<void> speak(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    _autoSpeakCalls.add(text);
    _autoSpeakPromptFlags.add(promptIfModelMissing);
    state = TextPlaybackState(playingKey: key ?? text);
    if (_forwardTextPlaybackToTts) {
      await ref
          .read(ttsControllerProvider.notifier)
          .speak(text, key: key, promptIfModelMissing: promptIfModelMissing);
    }
  }

  @override
  Future<void> prewarmWord(String word) async {
    _headwordPrewarmCalls.add(word);
  }

  @override
  Future<void> stop() async {
    _textPlaybackStopCalls++;
  }
}

/// 创建测试用内存词典数据库
Database _createTestDb() {
  final db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE words (
      word TEXT PRIMARY KEY,
      phonetic TEXT NOT NULL,
      translation TEXT,
      collins INTEGER DEFAULT 0,
      tag TEXT
    )
  ''');
  db.execute(
    "INSERT INTO words (word, phonetic, translation, collins, tag) VALUES"
    " ('abandon', 'əbændən', 'vt. 放弃, 抛弃\nn. 放任, 狂热', 3, 'gk cet4 cet6 ky toefl gre'),"
    " ('hello', 'heləu', 'int. 你好', 0, ''),"
    " ('run', 'rʌn', 'vi. 跑, 奔', 5, 'zk gk cet4'),"
    " ('test', 'test', null, 0, null)",
  );
  return db;
}

/// 构建打开面板的测试页面（经 DictionaryPanelHost 非 modal 打开）
Widget _buildTestPage(
  String word, {
  String? sentenceText,
  GlobalKey<DictionaryPanelHostState>? hostKey,
}) {
  return ProviderScope(
    overrides: dedupeOverrides([
      analyticsOverride(),
      dictionaryOverride(),
      sharedPreferencesProvider.overrideWithValue(_prefs),
      ttsControllerProvider.overrideWith(_StubTtsController.new),
      textPlaybackProvider.overrideWith(_StubTextPlaybackController.new),
      savedTextIndexProvider.overrideWithValue(const SavedTextIndex.empty()),
    ]),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(
        body: DictionaryPanelHost(
          key: hostKey,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DictionaryPanelHost.of(context).show(
                DictionaryPanelQuery(word: word, sentenceText: sentenceText),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 打开弹窗并等待渲染
///
/// 先 pump 让异步 lookup 完成（避免 CircularProgressIndicator 动画
/// 导致 pumpAndSettle 永远等不到 settle），再 pumpAndSettle 等弹窗动画结束。
Future<void> _openSheet(WidgetTester tester, String word) async {
  await tester.pumpWidget(_buildTestPage(word));
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  late Database db;
  late DictionaryService oldInstance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    _prewarmCalls.clear();
    _headwordPrewarmCalls.clear();
    _autoSpeakCalls.clear();
    _autoSpeakPromptFlags.clear();
    _initialSpeakingKey = null;
    _ttsStopCalls = 0;
    _textPlaybackStopCalls = 0;
    _forwardTextPlaybackToTts = false;
    db = _createTestDb();
    oldInstance = DictionaryService.replaceInstance(
      DictionaryService.withDatabase(db),
    );
  });

  tearDown(() {
    DictionaryService.replaceInstance(oldInstance);
    db.close();
  });

  group('DictionaryPanel', () {
    testWidgets('关闭面板不会停止宿主页正在播放的句子', (tester) async {
      _initialSpeakingKey = 'favorite-vocabulary-review-source';
      await _openSheet(tester, 'run');

      await tester.tap(find.byKey(const Key('dict_panel_close')));
      await tester.pumpAndSettle();

      expect(_ttsStopCalls, 0);
    });

    testWidgets('关闭面板仍会停止词典自身发起的朗读', (tester) async {
      _initialSpeakingKey = 'run';
      await _openSheet(tester, 'run');

      await tester.tap(find.byKey(const Key('dict_panel_close')));
      await tester.pumpAndSettle();

      expect(_ttsStopCalls, greaterThan(0));
    });

    testWidgets('关闭面板立即停止自动发音', (tester) async {
      await _openSheet(tester, 'run');

      await tester.tap(find.byKey(const Key('dict_panel_close')));

      expect(_textPlaybackStopCalls, greaterThan(0));
    });

    testWidgets('TTS 开始时不会被词典面板监听器再次停止', (tester) async {
      await _prefs.setString(
        'dictionary_settings',
        '{"autoSpeakOnLookup":false}',
      );
      _forwardTextPlaybackToTts = true;
      await _openSheet(tester, 'run');

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();

      expect(_textPlaybackStopCalls, 0, reason: 'TTS 状态变化不应反向停止发起它的文本播放控制器');
    });

    testWidgets('显示完整词典内容（音标、释义、星级、标签）', (tester) async {
      await _openSheet(tester, 'abandon');

      // 单词
      expect(find.text('abandon'), findsOneWidget);
      // 音标
      expect(find.text('/əbændən/'), findsOneWidget);
      // 释义（多行）
      expect(find.text('放弃, 抛弃'), findsOneWidget);
      expect(find.text('放任, 狂热'), findsOneWidget);
      // 词性标签
      expect(find.text('vt.'), findsOneWidget);
      expect(find.text('n.'), findsOneWidget);
      // 考试标签（只显示 cet4/cet6/toefl/gre，不显示 gk/ky）
      expect(find.text('CET4'), findsOneWidget);
      expect(find.text('CET6'), findsOneWidget);
      expect(find.text('TOEFL'), findsOneWidget);
      expect(find.text('GRE'), findsOneWidget);
    });

    testWidgets('柯林斯星级渲染正确数量的星星', (tester) async {
      await _openSheet(tester, 'abandon');

      // collins=3，应有 5 个星星图标
      final starIcons = find.byIcon(Icons.star_rounded);
      expect(starIcons, findsNWidgets(5));
    });

    testWidgets('无星级时不显示星星', (tester) async {
      await _openSheet(tester, 'hello');

      // collins=0，不应有星星图标
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('无考试标签时不显示标签', (tester) async {
      await _openSheet(tester, 'hello');

      // tag 为空
      expect(find.text('CET4'), findsNothing);
      expect(find.text('CET6'), findsNothing);
      expect(find.text('TOEFL'), findsNothing);
      expect(find.text('IELTS'), findsNothing);
      expect(find.text('GRE'), findsNothing);
    });

    testWidgets('未收录单词显示提示', (tester) async {
      await _openSheet(tester, 'xyznotaword');

      expect(find.text('xyznotaword'), findsOneWidget);
      expect(find.text('Word not found in dictionary'), findsOneWidget);
    });

    testWidgets('未收录单词标题会去掉前后标点', (tester) async {
      await _openSheet(tester, 'prioritize.');

      expect(find.text('prioritize'), findsOneWidget);
      expect(find.text('prioritize.'), findsNothing);
      expect(find.text('Word not found in dictionary'), findsOneWidget);
    });

    testWidgets('标题保留右侧撇号（dogs\' 不被截断）', (tester) async {
      await _openSheet(tester, '"Dogs\'"');

      // 标题剥首尾引号、保留原大小写与右撇号
      expect(find.text("Dogs'"), findsOneWidget);
      expect(find.text('Word not found in dictionary'), findsOneWidget);
    });

    testWidgets('翻译为 null 时不崩溃', (tester) async {
      await _openSheet(tester, 'test');

      expect(find.text('test'), findsAtLeast(1));
      // 不应崩溃，只显示单词和音标
      expect(find.text('/test/'), findsOneWidget);
    });

    testWidgets('未收录变形词不回退原形', (tester) async {
      await _openSheet(tester, 'running');

      expect(find.text('running'), findsWidgets);
      expect(find.text('/rʌn/'), findsNothing);
      expect(find.text('Word not found in dictionary'), findsOneWidget);
    });

    testWidgets('标题保留大小写，本地查询仍大小写不敏感（Abandon）', (tester) async {
      await _openSheet(tester, 'Abandon');

      expect(find.text('Abandon'), findsOneWidget);
      expect(find.text('/əbændən/'), findsOneWidget);
    });

    // NOTE: AI 解析功能已暂时隐藏（见 dictionary_panel.dart），
    // 相关测试待功能恢复后重新添加。

    testWidgets('打开弹窗即以单词本身预热（不等 AI 查询返回）', (tester) async {
      await tester.pumpWidget(_buildTestPage('running'));
      await tester.tap(find.text('Open'));
      // 仅 pump 一帧：弹窗刚插入、initState 已执行，查词 microtask 尚未落定。
      await tester.pump();

      // 首次预热应为单词本身（归一化词形），先于查词完成的完整批次。
      expect(_headwordPrewarmCalls, isNotEmpty);
      expect(_headwordPrewarmCalls.first, 'running');

      // 未收录的变形词不产生原形结果，初始预热不被后续查询改写。
      await tester.pumpAndSettle();
      expect(_headwordPrewarmCalls.first, 'running');
    });

    testWidgets('默认开启时打开查词面板自动发音且不因重建重复播放', (tester) async {
      await _openSheet(tester, 'running');

      expect(_autoSpeakCalls, ['running']);
      // 自动发音不是用户主动点击，模型缺失时不得弹出下载提示。
      expect(_autoSpeakPromptFlags, [false]);
      await tester.pump();
      expect(_autoSpeakCalls, ['running']);
    });

    testWidgets('切换到新词时自动发音一次', (tester) async {
      final hostKey = GlobalKey<DictionaryPanelHostState>();
      await tester.pumpWidget(_buildTestPage('running', hostKey: hostKey));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      hostKey.currentState!.show(const DictionaryPanelQuery(word: 'walk'));
      await tester.pump();

      expect(_autoSpeakCalls, ['running', 'walk']);
    });

    testWidgets('关闭自动发音后查词不触发播放', (tester) async {
      await _prefs.setString(
        'dictionary_settings',
        '{"autoSpeakOnLookup":false}',
      );
      await _openSheet(tester, 'running');

      expect(_autoSpeakCalls, isEmpty);
    });

    testWidgets('打开弹窗时标题单词交给统一入口预热（CDN 优先，TTS 兜底）', (tester) async {
      await _openSheet(tester, 'running');

      expect(_headwordPrewarmCalls, isNotEmpty);
      expect(_headwordPrewarmCalls, everyElement('running'));
    });

    testWidgets('标题预热保留查词大小写，与标题点击朗读的文本一致', (tester) async {
      await _openSheet(tester, 'US');

      expect(_headwordPrewarmCalls, isNotEmpty);
      expect(_headwordPrewarmCalls, everyElement('US'));
    });

    testWidgets('弹窗内容可滚动', (tester) async {
      await _openSheet(tester, 'abandon');

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('滑入动画期间内容区不套 AnimatedSwitcher（防闪烁），滑入结束后启用', (tester) async {
      await tester.pumpWidget(_buildTestPage('abandon'));
      await tester.tap(find.text('Open'));
      // 滑入途中（弹窗进场动画约 250ms）：内容区应直接渲染，无切换过渡
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedSwitcher), findsNothing);

      // 滑入结束后：启用 AnimatedSwitcher 供切换数据源平滑过渡
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });
  });
}
