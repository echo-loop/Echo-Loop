import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sense_group_result.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';
import 'package:echo_loop/utils/sense_group_timing.dart';
import 'package:echo_loop/widgets/practice/sense_group_text.dart';
import 'package:echo_loop/widgets/practice/sentence_annotation_card.dart';

import '../helpers/test_app.dart';

void main() {
  /// 字段分隔符简写
  const sep = SentenceAnalysis.fieldSeparator;

  group('SentenceAnnotationCard — 基本渲染', () {
    testWidgets('显示句子文本', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello world',
          ),
        ),
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
            onRequestTranslation: () async => '翻译',
            onRequestAnalysis: () async => '语法${sep}词汇${sep}用法',
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
            onRequestTranslation: () async => '翻译',
            onRequestAnalysis: () async => '语法${sep}词汇${sep}用法',
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
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
          ),
        ),
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
            onRequestTranslation: () {
              requested = true;
              return completer.future;
            },
            onRequestAnalysis: () async => '语法${sep}词汇${sep}用法',
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

    testWidgets('cachedTranslation 初始折叠，点击后立即显示且不触发请求',
        (tester) async {
      var requested = false;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            cachedTranslation: '已缓存的翻译',
            onRequestTranslation: () {
              requested = true;
              return Future.value('新翻译');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // 初始应折叠，不自动展开
      expect(find.text('已缓存的翻译'), findsNothing);

      // 点击翻译按钮后立即显示缓存内容
      await tester.tap(find.text('Translate'));
      await tester.pumpAndSettle();
      expect(find.text('已缓存的翻译'), findsOneWidget);
      expect(requested, isFalse);
    });

    testWidgets('翻译请求失败显示 SnackBar', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: () {
              callCount++;
              return Future.error('network error');
            },
            onRequestAnalysis: () async => '语法${sep}词汇${sep}用法',
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

    testWidgets('展开后再次点击可折叠', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: () async => '翻译内容',
            onRequestAnalysis: () async => '语法${sep}词汇${sep}用法',
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

  group('SentenceAnnotationCard — 解析交互', () {
    testWidgets('点击解析按钮触发请求并展示结果', (tester) async {
      var requested = false;
      final completer = Completer<String>();

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence',
            onRequestTranslation: () async => '翻译',
            onRequestAnalysis: () {
              requested = true;
              return completer.future;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      expect(requested, isTrue);

      completer.complete('语法结果${sep}词汇结果${sep}用法结果');
      await tester.pumpAndSettle();

      expect(find.text('语法结果'), findsOneWidget);
      expect(find.text('词汇结果'), findsOneWidget);
      expect(find.text('用法结果'), findsOneWidget);
    });

    testWidgets('cachedAnalysis 初始折叠，点击后立即显示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            cachedAnalysis: '语法分析${sep}词汇分析${sep}用法分析',
            onRequestAnalysis: () async => '语法分析${sep}词汇分析${sep}用法分析',
          ),
        ),
      );

      await tester.pumpAndSettle();
      // 初始应折叠
      expect(find.text('语法分析'), findsNothing);

      // 点击解析按钮后立即显示缓存内容
      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();
      expect(find.text('语法分析'), findsOneWidget);
      expect(find.text('词汇分析'), findsOneWidget);
      expect(find.text('用法分析'), findsOneWidget);
    });
  });

  group('SentenceAnnotationCard — 多内容同时展示', () {
    testWidgets('翻译和解析可同时展开', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            onRequestTranslation: () async => '翻译OK',
            onRequestAnalysis: () async => '语法OK${sep}词汇OK${sep}用法OK',
          ),
        ),
      );

      // 展开翻译
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      expect(find.text('翻译OK'), findsOneWidget);
      expect(find.text('语法OK'), findsNothing);

      // 展开解析
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      expect(find.text('翻译OK'), findsOneWidget);
      expect(find.text('语法OK'), findsOneWidget);
      expect(find.text('词汇OK'), findsOneWidget);
      expect(find.text('用法OK'), findsOneWidget);
    });

    testWidgets('翻译和解析缓存初始折叠，分别点击后展开', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            cachedTranslation: '缓存翻译',
            onRequestTranslation: () async => '缓存翻译',
            cachedAnalysis: '缓存语法${sep}缓存词汇${sep}缓存用法',
            onRequestAnalysis: () async =>
                '缓存语法${sep}缓存词汇${sep}缓存用法',
          ),
        ),
      );

      await tester.pumpAndSettle();
      // 初始均折叠
      expect(find.text('缓存翻译'), findsNothing);
      expect(find.text('缓存语法'), findsNothing);

      // 点击翻译按钮
      await tester.tap(find.text('Translate'));
      await tester.pumpAndSettle();
      expect(find.text('缓存翻译'), findsOneWidget);

      // 点击解析按钮
      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();
      expect(find.text('缓存语法'), findsOneWidget);
      expect(find.text('缓存词汇'), findsOneWidget);
      expect(find.text('缓存用法'), findsOneWidget);
    });
  });

  group('SentenceAnnotationCard — 拆意群交互', () {
    testWidgets('点击拆意群按钮触发 onRequestSenseGroups', (tester) async {
      var requested = false;
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test sentence here',
            onRequestTranslation: () async => '翻译',
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
            onRequestTranslation: () async => '翻译',
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
            onRequestTranslation: () async => '翻译',
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
    /// 找到 fontFamily 为 monospace 的 Text widget（即反引号或 IPA chip 内的 Text）
    Finder findChipText(String content) => find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.fontFamily == 'monospace' &&
              w.data == content,
        );

    /// 找到任意 monospace Text，用于断言"没有任何 chip"
    final anyChipFinder = find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontFamily == 'monospace',
    );

    /// 用给定的 grammar 段构造一个已缓存的解析卡，并展开解析面板
    Future<void> pumpAnalysisCard(WidgetTester tester, String grammar) async {
      final analysis = '$grammar${sep}vocab${sep}listen';
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            cachedAnalysis: analysis,
            onRequestAnalysis: () async => analysis,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();
    }

    testWidgets('IPA 识别 — 含音节分界点', (tester) async {
      await pumpAnalysisCard(tester, '音标：/ˈɪŋ.ɡlɪʃ/ 是英语的发音');
      expect(findChipText('/ˈɪŋ.ɡlɪʃ/'), findsOneWidget);
    });

    testWidgets('IPA 识别 — 含连字符', (tester) async {
      await pumpAnalysisCard(tester, '音标：/pre-ˈfɪks/ 是前缀');
      expect(findChipText('/pre-ˈfɪks/'), findsOneWidget);
    });

    testWidgets('IPA 识别 — 单音节弱读', (tester) async {
      await pumpAnalysisCard(tester, '音标：/tə/ 是弱读形式');
      expect(findChipText('/tə/'), findsOneWidget);
    });

    testWidgets('IPA 否决 — 表示或者的斜杠两侧带空格', (tester) async {
      await pumpAnalysisCard(tester, '或者：and / or 表示选择');
      expect(anyChipFinder, findsNothing);
    });

    testWidgets('IPA 否决 — 含中文与斜杠', (tester) async {
      await pumpAnalysisCard(tester, '搭配：English / 英语 互译');
      expect(anyChipFinder, findsNothing);
    });

    testWidgets('IPA 否决 — 路径不被误判', (tester) async {
      await pumpAnalysisCard(tester, '路径：/path/to/file 是文件路径');
      expect(anyChipFinder, findsNothing);
    });

    testWidgets('IPA 否决 — 冠词 a/an', (tester) async {
      await pumpAnalysisCard(tester, '冠词：a/an 视下一词首音决定');
      expect(anyChipFinder, findsNothing);
    });

    testWidgets('反引号 chip 渲染单个词', (tester) async {
      await pumpAnalysisCard(tester, '词义：`run` 表示经营');
      expect(findChipText('run'), findsOneWidget);
    });

    testWidgets('反引号与 IPA 同一行混排，各自正确分段', (tester) async {
      await pumpAnalysisCard(tester, '弱读：`have` 常听起来像 /əv/ 这样');
      expect(findChipText('have'), findsOneWidget);
      expect(findChipText('/əv/'), findsOneWidget);
    });

    /// 把所有渲染的 RichText 的可见文本拼起来，用于检验"反引号是否还在屏上"
    String allRenderedText() {
      final buf = StringBuffer();
      for (final el in find.byType(RichText).evaluate()) {
        final rt = el.widget as RichText;
        rt.text.visitChildren((span) {
          if (span is TextSpan && span.text != null) {
            buf.write(span.text);
          }
          return true;
        });
      }
      return buf.toString();
    }

    testWidgets('客户端清洗 — key 中的反引号被剥离后再渲染', (tester) async {
      await pumpAnalysisCard(tester, '`helped to` 的弱读：弱读为 /tə/');
      final rendered = allRenderedText();
      // 渲染后的 key 应不含反引号字面字符
      expect(rendered.contains('`helped to`'), isFalse);
      // 清洗后的 key 文本应当出现在渲染结果中
      expect(rendered.contains('helped to 的弱读'), isTrue);
      // value 中的 IPA chip 不受影响
      expect(findChipText('/tə/'), findsOneWidget);
    });

    testWidgets('客户端清洗 — value 中的反引号保留（仍渲染为 chip）',
        (tester) async {
      await pumpAnalysisCard(tester, '词义：`run` 表示经营');
      // value 中的 `run` 应渲染为 chip
      expect(findChipText('run'), findsOneWidget);
    });
  });
}
