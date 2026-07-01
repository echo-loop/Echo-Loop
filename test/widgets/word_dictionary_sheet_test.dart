/// WordDictionarySheet Widget 测试
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
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/intensive_listen/word_dictionary_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/mock_providers.dart';

/// 词典设置读取的 SharedPreferences（在 setUp 注入），供 [_buildTestPage] override
late SharedPreferences _prefs;

/// 记录桩控制器每次 [TtsController.prewarmTexts] 的入参（在 setUp 清空），
/// 供断言「打开弹窗即以单词本身预热」。
final List<List<String>> _prewarmCalls = [];

/// 桩 [TtsController]：弹窗内嵌发音按钮、查词完成会自动触发例句预热，
/// 真实控制器会经平台 TTS 引擎/method channel 异步合成，在 widget 测试中
/// 永不完成而拖住 pumpAndSettle（并发跑时确定性挂起）。这里把预热/发音/停止
/// 全部置空，使本测试只验证弹窗 UI、不触碰真实 TTS 栈。
class _StubTtsController extends TtsController {
  @override
  TtsControllerState build() => const TtsControllerState();
  @override
  Future<void> speak(String text, {String? key}) async {}
  @override
  Future<void> prewarmTexts(List<String> texts) async {
    _prewarmCalls.add(texts);
  }
  @override
  void cancelTextsPrewarm() {}
  @override
  Future<void> stop() async {}
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

/// 构建打开弹窗的测试页面
Widget _buildTestPage(String word, {String? sentenceText}) {
  return ProviderScope(
    overrides: [
      analyticsOverride(),
      dictionaryOverride(),
      sharedPreferencesProvider.overrideWithValue(_prefs),
      ttsControllerProvider.overrideWith(_StubTtsController.new),
    ],
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
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showWordDictionarySheet(
              context: context,
              word: word,
              sentenceText: sentenceText,
            ),
            child: const Text('Open'),
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
    db = _createTestDb();
    oldInstance = DictionaryService.replaceInstance(
      DictionaryService.withDatabase(db),
    );
  });

  tearDown(() {
    DictionaryService.replaceInstance(oldInstance);
    db.dispose();
  });

  group('WordDictionarySheet', () {
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

      // normalizeWord：剥首尾引号、小写，但保留右撇号
      expect(find.text("dogs'"), findsOneWidget);
      expect(find.text('Word not found in dictionary'), findsOneWidget);
    });

    testWidgets('翻译为 null 时不崩溃', (tester) async {
      await _openSheet(tester, 'test');

      expect(find.text('test'), findsAtLeast(1));
      // 不应崩溃，只显示单词和音标
      expect(find.text('/test/'), findsOneWidget);
    });

    testWidgets('词形还原 fallback（running → run）', (tester) async {
      await _openSheet(tester, 'running');

      // 应通过词形还原找到 run
      expect(find.text('run'), findsOneWidget);
      expect(find.text('/rʌn/'), findsOneWidget);
    });

    testWidgets('大小写不敏感（Abandon → abandon）', (tester) async {
      await _openSheet(tester, 'Abandon');

      expect(find.text('abandon'), findsOneWidget);
      expect(find.text('/əbændən/'), findsOneWidget);
    });

    // NOTE: AI 解析功能已暂时隐藏（见 word_dictionary_sheet.dart），
    // 相关测试待功能恢复后重新添加。

    testWidgets('打开弹窗即以单词本身预热（不等 AI 查询返回）', (tester) async {
      await tester.pumpWidget(_buildTestPage('running'));
      await tester.tap(find.text('Open'));
      // 仅 pump 一帧：弹窗刚插入、initState 已执行，查词 microtask 尚未落定。
      await tester.pump();

      // 首次预热应为单词本身（归一化词形），先于查词完成的完整批次。
      expect(_prewarmCalls, isNotEmpty);
      expect(_prewarmCalls.first, ['running']);

      // 查词完成后：完整批次照旧触发（本地源 running→run，headword='run'），
      // 且作为最后发起的批次持最新 token、完整跑完，不被 initState 单词预热干扰。
      await tester.pumpAndSettle();
      expect(_prewarmCalls.length, greaterThanOrEqualTo(2));
      expect(_prewarmCalls.last, ['run']);
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
