import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/sense_group_result.dart';
import 'package:fluency/models/sentence_ai_result.dart';
import 'package:fluency/utils/sense_group_timing.dart';
import 'package:fluency/widgets/intensive_listen/sense_group_text.dart';
import 'package:fluency/widgets/intensive_listen/sentence_annotation_card.dart';

import '../helpers/test_app.dart';

void main() {
  /// 字段分隔符简写
  const sep = SentenceAnalysis.fieldSeparator;

  group('SentenceAnnotationCard — 基本渲染', () {
    testWidgets('显示句子文本和难句标记', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello world',
            isDifficult: false,
            onToggle: () {},
          ),
        ),
      );

      // 句子文本通过 RichText 渲染
      expect(find.byType(RichText), findsWidgets);
      // 非难句状态
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('难句标记状态正确显示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Difficult sentence',
            isDifficult: true,
            onToggle: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('自动标记分支显示自动文案', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Auto difficult',
            isDifficult: true,
            showAutoMarkedLabel: true,
            onToggle: () {},
          ),
        ),
      );

      expect(find.text('Auto-marked difficult, tap to undo'), findsOneWidget);
    });

    testWidgets('已标记分支显示普通难句文案', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Marked difficult',
            isDifficult: true,
            showAutoMarkedLabel: false,
            onToggle: () {},
          ),
        ),
      );

      expect(find.text('Marked difficult, tap to undo'), findsOneWidget);
    });

    testWidgets('点击难句标记触发 onToggle', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () => toggled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.bookmark_border));
      expect(toggled, isTrue);
    });
  });

  group('SentenceAnnotationCard — 三按钮工具栏', () {
    testWidgets('有 AI 回调时显示三个工具栏按钮', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
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
            isDifficult: false,
            onToggle: () {},
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
            isDifficult: false,
            onToggle: () {},
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
            isDifficult: false,
            onToggle: () {},
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

    testWidgets('cachedTranslation 自动展开且不触发请求', (tester) async {
      var requested = false;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            cachedTranslation: '已缓存的翻译',
            onRequestTranslation: () {
              requested = true;
              return Future.value('新翻译');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('已缓存的翻译'), findsOneWidget);
      expect(requested, isFalse);
    });

    testWidgets('翻译请求失败显示错误和重试按钮', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
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

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(callCount, 1);

      // 点击重试
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets('展开后再次点击可折叠', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
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
            isDifficult: false,
            onToggle: () {},
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

    testWidgets('cachedAnalysis 自动展开', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            isDifficult: false,
            onToggle: () {},
            cachedAnalysis: '语法分析${sep}词汇分析${sep}用法分析',
          ),
        ),
      );

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
            isDifficult: false,
            onToggle: () {},
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

    testWidgets('翻译和解析缓存同时自动展开', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
            cachedTranslation: '缓存翻译',
            cachedAnalysis: '缓存语法${sep}缓存词汇${sep}缓存用法',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('缓存翻译'), findsOneWidget);
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
            isDifficult: false,
            onToggle: () {},
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
      final groups = [
        SenseGroup(text: 'Hello', isCore: true),
        SenseGroup(text: 'world'),
      ];
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
            isDifficult: false,
            onToggle: () {},
            onRequestTranslation: () async => '翻译',
            senseGroups: groups,
            senseGroupTimings: timings,
            hasWordTimestamps: true,
            onRequestSenseGroups: () async {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 意群色块组件已渲染
      expect(find.byType(SenseGroupText), findsOneWidget);

      // 点击拆意群按钮 toggle 回纯文本
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      // 意群色块不再显示（已切回纯文本模式）
      expect(find.byType(SenseGroupText), findsNothing);

      // 再次点击恢复色块
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.byType(SenseGroupText), findsOneWidget);
    });

    testWidgets('加载意群时按钮显示 spinner', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
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
}
