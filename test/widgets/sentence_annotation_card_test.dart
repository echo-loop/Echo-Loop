import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sense_group_result.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/utils/sense_group_timing.dart';
import 'package:echo_loop/widgets/common/shimmer_placeholder.dart';
import 'package:echo_loop/widgets/practice/sense_group_text.dart';
import 'package:echo_loop/widgets/practice/sentence_annotation_card.dart';

import '../helpers/test_app.dart';

/// 用 (标签, 详解) 列表构造结构化解析。
SentenceAnalysis _analysis({
  List<(String, String)> grammar = const [],
  List<(String, String)> vocabulary = const [],
  List<(String, String)> listening = const [],
}) => SentenceAnalysis(
  grammar: [for (final (p, e) in grammar) GrammarPoint(point: p, note: e)],
  vocabulary: [
    for (final (t, n) in vocabulary) VocabularyItem(term: t, note: n),
  ],
  listening: [
    for (final (p, n) in listening) ListeningPoint(phrase: p, note: n),
  ],
);

/// 单帧解析流（模拟一次到齐）。
Stream<SentenceAnalysis> _stream(SentenceAnalysis a) => Stream.value(a);

/// 占位解析流：仅用于启用解析按钮（不校验内容）。
Stream<SentenceAnalysis> _dummyStream(
  CancelToken _,
  SentenceAiRequestSource __,
) => _stream(_analysis(grammar: const [('g', 'e')]));

/// 单帧译文流回调（一次到齐）。
Stream<String> Function(CancelToken, SentenceAiRequestSource) _translate(
  String t,
) =>
    (_, __) => Stream.value(t);

/// 收集当前树内所有 RichText 的可见纯文本（结构化 bullet 走 Text.rich，
/// find.text 无法直接匹配，故用拼接后 contains 断言）。
String _renderedRichText() {
  final buf = StringBuffer();
  for (final el in find.byType(RichText).evaluate()) {
    final rt = el.widget as RichText;
    rt.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) buf.write(span.text);
      return true;
    });
  }
  return buf.toString();
}

void main() {
  group('SentenceAnnotationCard — 基本渲染', () {
    testWidgets('显示句子文本', (tester) async {
      await tester.pumpWidget(
        createTestApp(SentenceAnnotationCard(text: 'Hello world')),
      );

      // 句子文本通过 RichText 渲染
      expect(find.byType(RichText), findsWidgets);
    });
  });

  group('SentenceAnnotationCard — 三按钮工具栏', () {
    testWidgets('有 AI 回调时显示三个工具栏按钮', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: _translate('翻译'),
            onRequestAnalysis: _dummyStream,
            hasWordTimestamps: true,
            onRequestSenseGroups: () async {},
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
      expect(find.byIcon(Icons.translate), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
    });

    testWidgets('无词级时间戳时拆意群按钮仍可用', (tester) async {
      var requested = false;
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: _translate('翻译'),
            onRequestAnalysis: _dummyStream,
            hasWordTimestamps: false,
            onRequestSenseGroups: () async {
              requested = true;
            },
          ),
        ),
      );

      expect(find.text('Groups'), findsOneWidget);

      // 点击拆意群按钮可正常触发请求
      await tester.tap(find.text('Groups'));
      await tester.pump();
      expect(requested, isTrue);
    });

    testWidgets('无 AI 回调和缓存时翻译/解析按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestApp(SentenceAnnotationCard(text: 'Test')),
      );

      // 无回调/缓存时按钮不渲染（因为三个按钮都无法使用）
      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.byIcon(Icons.auto_fix_high), findsNothing);
    });
  });

  group('SentenceAnnotationCard — 翻译交互', () {
    testWidgets('点击翻译按钮触发请求并展示结果', (tester) async {
      var requested = false;
      final completer = Completer<String>();

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence',
            onRequestTranslation: (_, __) {
              requested = true;
              return completer.future.asStream();
            },
            onRequestAnalysis: _dummyStream,
          ),
        ),
      );

      // 初始无翻译内容
      expect(find.text('这是翻译结果'), findsNothing);

      // 点击翻译按钮
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pump();
      expect(requested, isTrue);

      // 返回结果
      completer.complete('这是翻译结果');
      await tester.pumpAndSettle();
      expect(find.text('这是翻译结果'), findsOneWidget);
    });

    testWidgets('翻译请求中显示单行骨架屏且按钮保留圆形进度', (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) return controller.close();
      });

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence',
            onRequestTranslation: (_, __) => controller.stream,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pump();

      expect(find.byType(ShimmerPlaceholder), findsOneWidget);
      final shimmer = tester.widget<ShimmerPlaceholder>(
        find.byType(ShimmerPlaceholder),
      );
      expect(shimmer.singleLine, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.add('这是翻译结果');
      await controller.close();
      await tester.pumpAndSettle();

      expect(find.byType(ShimmerPlaceholder), findsNothing);
      expect(find.text('这是翻译结果'), findsOneWidget);
    });

    testWidgets('cachedTranslation 初始自动展开，不触发请求', (tester) async {
      var requested = false;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            cachedTranslation: '已缓存的翻译',
            onRequestTranslation: (_, __) {
              requested = true;
              return Stream.value('新翻译');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // 初始自动展开缓存
      expect(find.text('已缓存的翻译'), findsOneWidget);
      expect(requested, isFalse);
    });

    testWidgets('翻译请求失败显示 SnackBar', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: (_, __) {
              callCount++;
              return Stream<String>.error('network error');
            },
            onRequestAnalysis: _dummyStream,
          ),
        ),
      );

      // 点击翻译按钮
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      // 翻译失败时显示 SnackBar
      expect(find.text('Translation failed, please retry'), findsOneWidget);
      expect(callCount, 1);
    });

    testWidgets('翻译额度异常后恢复待点击状态并允许重试', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: (_, __) {
              callCount++;
              return Stream<String>.error(
                const AiFeatureQuotaExceededException(),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ShimmerPlaceholder), findsNothing);

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets('展开后再次点击可折叠', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: _translate('翻译内容'),
            onRequestAnalysis: _dummyStream,
          ),
        ),
      );

      // 展开翻译
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(find.text('翻译内容'), findsOneWidget);

      // 再次点击折叠
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(find.text('翻译内容'), findsNothing);
    });
  });

  group('SentenceAnnotationCard — 自动加载', () {
    testWidgets('首帧后自动请求翻译和解析，不请求意群，加载中禁止重复点击', (tester) async {
      var translationCalls = 0;
      var analysisCalls = 0;
      var senseGroupCalls = 0;
      final translationController = StreamController<String>();
      final analysisController = StreamController<SentenceAnalysis>();

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Auto',
            autoLoadTranslation: true,
            autoLoadAnalysis: true,
            onRequestTranslation: (_, __) {
              translationCalls++;
              return translationController.stream;
            },
            onRequestAnalysis: (_, __) {
              analysisCalls++;
              return analysisController.stream;
            },
            onRequestSenseGroups: () async {
              senseGroupCalls++;
            },
          ),
        ),
      );

      await tester.pump();

      expect(translationCalls, 1);
      expect(analysisCalls, 1);
      expect(senseGroupCalls, 0);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('translation')));
      await tester.tap(find.byKey(const ValueKey('analysis')));
      await tester.pump();

      expect(translationCalls, 1);
      expect(analysisCalls, 1);

      translationController.add('自动翻译');
      analysisController.add(_analysis(grammar: const [('自动解析', '')]));
      await translationController.close();
      await analysisController.close();
      await tester.pumpAndSettle();

      expect(find.text('自动翻译'), findsOneWidget);
      expect(_renderedRichText().contains('自动解析'), isTrue);
    });

    testWidgets('有缓存时自动加载不触发请求且保持展开', (tester) async {
      var translationCalls = 0;
      var analysisCalls = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Cached',
            autoLoadTranslation: true,
            autoLoadAnalysis: true,
            cachedTranslation: '缓存翻译',
            cachedAnalysis: _analysis(grammar: const [('缓存解析', '')]),
            onRequestTranslation: (_, __) {
              translationCalls++;
              return Stream.value('不应请求');
            },
            onRequestAnalysis: (_, __) {
              analysisCalls++;
              return _stream(_analysis(grammar: const [('不应请求', '')]));
            },
          ),
        ),
      );

      await tester.pump();

      expect(translationCalls, 0);
      expect(analysisCalls, 0);
      expect(find.text('缓存翻译'), findsOneWidget);
      expect(_renderedRichText().contains('缓存解析'), isTrue);
    });

    testWidgets('自动加载解析流无内容结束时退出 loading 并允许重试', (tester) async {
      var analysisCalls = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Empty analysis',
            autoLoadAnalysis: true,
            onRequestAnalysis: (_, __) {
              analysisCalls++;
              return Stream.value(const SentenceAnalysis());
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(analysisCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ShimmerPlaceholder), findsNothing);

      await tester.tap(find.byKey(const ValueKey('analysis')));
      await tester.pumpAndSettle();

      expect(analysisCalls, 2);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ShimmerPlaceholder), findsNothing);
    });
  });

  group('SentenceAnnotationCard — 解析交互', () {
    testWidgets('点击解析按钮触发流式请求并逐帧渐显', (tester) async {
      var requested = false;
      final controller = StreamController<SentenceAnalysis>();

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence',
            onRequestTranslation: _translate('翻译'),
            onRequestAnalysis: (_, __) {
              requested = true;
              return controller.stream;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      expect(requested, isTrue);

      // 首帧：只有语法到达
      controller.add(_analysis(grammar: const [('语法结果', '')]));
      await tester.pump();
      expect(_renderedRichText().contains('语法结果'), isTrue);

      // 后续帧：词汇/听力到齐
      controller.add(
        _analysis(
          grammar: const [('语法结果', '')],
          vocabulary: const [('词汇结果', '')],
          listening: const [('用法结果', '')],
        ),
      );
      await controller.close();
      await tester.pumpAndSettle();

      final rendered = _renderedRichText();
      expect(rendered.contains('语法结果'), isTrue);
      expect(rendered.contains('词汇结果'), isTrue);
      expect(rendered.contains('用法结果'), isTrue);
    });

    testWidgets('解析流进行中销毁卡片会取消 CancelToken', (tester) async {
      final controller = StreamController<SentenceAnalysis>();
      addTearDown(controller.close);
      CancelToken? captured;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            onRequestAnalysis: (cancelToken, _) {
              captured = cancelToken;
              return controller.stream;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      expect(captured, isNotNull);
      expect(captured!.isCancelled, isFalse);

      await tester.pumpWidget(createTestApp(const SizedBox.shrink()));
      await tester.pump();

      expect(captured!.isCancelled, isTrue);
    });

    testWidgets('解析额度异常后恢复待点击状态并允许重试', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            onRequestAnalysis: (_, __) {
              callCount++;
              return Stream<SentenceAnalysis>.error(
                const AiFeatureQuotaExceededException(),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ShimmerPlaceholder), findsNothing);

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets('cachedAnalysis 初始自动展开', (tester) async {
      final cached = _analysis(
        grammar: const [('语法分析', '')],
        vocabulary: const [('词汇分析', '')],
        listening: const [('用法分析', '')],
      );
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            cachedAnalysis: cached,
            onRequestAnalysis: (_, __) => _stream(cached),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // 初始自动展开缓存
      final rendered = _renderedRichText();
      expect(rendered.contains('语法分析'), isTrue);
      expect(rendered.contains('词汇分析'), isTrue);
      expect(rendered.contains('用法分析'), isTrue);
    });
  });

  group('SentenceAnnotationCard — 多内容同时展示', () {
    testWidgets('翻译和解析可同时展开', (tester) async {
      final analysis = _analysis(
        grammar: const [('语法OK', '')],
        vocabulary: const [('词汇OK', '')],
        listening: const [('用法OK', '')],
      );
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: _translate('翻译OK'),
            onRequestAnalysis: (_, __) => _stream(analysis),
          ),
        ),
      );

      // 展开翻译
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(find.text('翻译OK'), findsOneWidget);
      expect(_renderedRichText().contains('语法OK'), isFalse);

      // 展开解析
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      expect(find.text('翻译OK'), findsOneWidget);
      final rendered = _renderedRichText();
      expect(rendered.contains('语法OK'), isTrue);
      expect(rendered.contains('词汇OK'), isTrue);
      expect(rendered.contains('用法OK'), isTrue);
    });

    testWidgets('翻译和解析缓存初始自动展开', (tester) async {
      final cached = _analysis(
        grammar: const [('缓存语法', '')],
        vocabulary: const [('缓存词汇', '')],
        listening: const [('缓存用法', '')],
      );
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            cachedTranslation: '缓存翻译',
            onRequestTranslation: _translate('缓存翻译'),
            cachedAnalysis: cached,
            onRequestAnalysis: (_, __) => _stream(cached),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // 初始自动展开
      expect(find.text('缓存翻译'), findsOneWidget);
      final rendered = _renderedRichText();
      expect(rendered.contains('缓存语法'), isTrue);
      expect(rendered.contains('缓存词汇'), isTrue);
      expect(rendered.contains('缓存用法'), isTrue);
    });
  });

  group('SentenceAnnotationCard — 拆意群交互', () {
    testWidgets('点击拆意群按钮触发 onRequestSenseGroups', (tester) async {
      var requested = false;
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence here',
            onRequestTranslation: _translate('翻译'),
            hasWordTimestamps: true,
            onRequestSenseGroups: () async {
              requested = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Groups'));
      await tester.pump();
      expect(requested, isTrue);
    });

    testWidgets('有意群数据时显示色块并可 toggle', (tester) async {
      final senseGroupResult = SenseGroupResult(
        medium: ['Hello', 'world'],
        fine: ['Hello', 'world'],
      );
      final timings = [
        SenseGroupTiming(
          start: const Duration(seconds: 0),
          end: const Duration(seconds: 1),
        ),
        SenseGroupTiming(
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 2),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello world',
            onRequestTranslation: _translate('翻译'),
            senseGroupResult: senseGroupResult,
            senseGroupTimings: timings,
            hasWordTimestamps: true,
            onRequestSenseGroups: () async {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 有意群数据时自动进入 medium 模式，显示色块
      expect(find.byType(SenseGroupText), findsOneWidget);

      // 点击拆意群按钮切换（medium == fine → 直接 off）
      final senseGroupBtn = find.byKey(const ValueKey('senseGroup'));
      await tester.tap(senseGroupBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SenseGroupText), findsNothing);

      // 再次点击恢复 medium
      await tester.tap(senseGroupBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SenseGroupText), findsOneWidget);
    });

    testWidgets('加载意群时按钮显示 spinner', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: _translate('翻译'),
            hasWordTimestamps: true,
            onRequestSenseGroups: () => completer.future,
          ),
        ),
      );

      // 点击意群按钮触发请求
      await tester.tap(find.text('Groups'));
      await tester.pump();

      // 请求进行中应显示 CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 完成请求
      completer.complete();
      await tester.pumpAndSettle();

      // loading 结束
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('SentenceAnnotationCard — 内联标记渲染', () {
    /// 查找符合反引号样式的 TextSpan：文本匹配 + 设置了 background Paint
    bool hasBadgeSpan(String content) {
      bool found = false;
      for (final el in find.byType(Text).evaluate()) {
        final w = el.widget as Text;
        final root = w.textSpan;
        if (root == null) continue;
        root.visitChildren((span) {
          if (span is TextSpan &&
              span.text == content &&
              span.style?.background != null) {
            found = true;
            return false;
          }
          return true;
        });
        if (found) break;
      }
      return found;
    }

    /// 找到 IPA chip 内的 monospace Text
    Finder findIpaChip(String content) => find.byWidgetPredicate(
      (w) =>
          w is Text && w.style?.fontFamily == 'monospace' && w.data == content,
    );

    /// 找到任意 monospace Text，用于断言"没有任何 IPA chip"
    final anyIpaChipFinder = find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontFamily == 'monospace',
    );

    /// 用一条 (标签, 说明) 要点构造已缓存的解析卡（缓存自动展开）。
    /// 内联标记（反引号 / IPA）在说明中渲染。
    Future<void> pumpAnalysisCard(
      WidgetTester tester,
      String point,
      String note,
    ) async {
      final analysis = _analysis(grammar: [(point, note)]);
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            cachedAnalysis: analysis,
            onRequestAnalysis: (_, __) => _stream(analysis),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // cachedAnalysis 在 initState 中自动展开，无需额外点击
    }

    testWidgets('IPA 识别 — 含音节分界点', (tester) async {
      await pumpAnalysisCard(tester, '音标', '/ˈɪŋ.ɡlɪʃ/ 是英语的发音');
      expect(findIpaChip('/ˈɪŋ.ɡlɪʃ/'), findsOneWidget);
    });

    testWidgets('IPA 识别 — 含连字符', (tester) async {
      await pumpAnalysisCard(tester, '音标', '/pre-ˈfɪks/ 是前缀');
      expect(findIpaChip('/pre-ˈfɪks/'), findsOneWidget);
    });

    testWidgets('IPA 识别 — 单音节弱读', (tester) async {
      await pumpAnalysisCard(tester, '音标', '/tə/ 是弱读形式');
      expect(findIpaChip('/tə/'), findsOneWidget);
    });

    testWidgets('IPA 否决 — 表示或者的斜杠两侧带空格', (tester) async {
      await pumpAnalysisCard(tester, '或者', 'and / or 表示选择');
      expect(anyIpaChipFinder, findsNothing);
    });

    testWidgets('IPA 否决 — 含中文与斜杠', (tester) async {
      await pumpAnalysisCard(tester, '搭配', 'English / 英语 互译');
      expect(anyIpaChipFinder, findsNothing);
    });

    testWidgets('IPA 否决 — 路径不被误判', (tester) async {
      await pumpAnalysisCard(tester, '路径', '/path/to/file 是文件路径');
      expect(anyIpaChipFinder, findsNothing);
    });

    testWidgets('IPA 否决 — 冠词 a/an', (tester) async {
      await pumpAnalysisCard(tester, '冠词', 'a/an 视下一词首音决定');
      expect(anyIpaChipFinder, findsNothing);
    });

    testWidgets('反引号渲染为内联 badge（背景色 + 自然换行）', (tester) async {
      await pumpAnalysisCard(tester, '词义', '`run` 表示经营');
      expect(hasBadgeSpan('run'), isTrue);
    });

    testWidgets('反引号与 IPA 同一行混排：前者 badge，后者灰色 chip', (tester) async {
      await pumpAnalysisCard(tester, '弱读', '`have` 常听起来像 /əv/ 这样');
      expect(hasBadgeSpan('have'), isTrue);
      expect(findIpaChip('/əv/'), findsOneWidget);
    });

    testWidgets('标签中的反引号被剥离后再渲染', (tester) async {
      await pumpAnalysisCard(tester, '`helped to` 的弱读', '弱读为 /tə/');
      final rendered = _renderedRichText();
      // 渲染后的标签应不含反引号字面字符
      expect(rendered.contains('`helped to`'), isFalse);
      // 清洗后的标签文本应当出现在渲染结果中
      expect(rendered.contains('helped to 的弱读'), isTrue);
      // 详解中的 IPA chip 不受影响
      expect(findIpaChip('/tə/'), findsOneWidget);
    });

    testWidgets('详解中的反引号保留（渲染为 badge）', (tester) async {
      await pumpAnalysisCard(tester, '词义', '`run` 表示经营');
      // 详解中的 `run` 应渲染为带背景色的内联 badge
      expect(hasBadgeSpan('run'), isTrue);
    });
  });
}
