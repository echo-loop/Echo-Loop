/// [ParagraphSentenceListCard] 自动跟随滚动行为测试
///
/// 重点验证到头/尾时不再自动越界回弹（用 ClampingScrollPhysics 硬停）：
/// - 末句贴底、首句贴顶，无大片留白（非居中）；
/// - 自动滚动过程中滚动位置始终落在 [min, max] 区间内（不越界）；
/// - [autoFollowAlignment] 纯函数的锚点决策。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';
import 'package:echo_loop/widgets/common/paragraph_sentence_list_card.dart';

import '../../helpers/shared/test_fixtures.dart';

void main() {
  group('autoFollowAlignment', () {
    test('目标可见 → 0.5（居中）', () {
      expect(autoFollowAlignment(targetVisible: true), 0.5);
    });

    test('目标不可见 → 0.0（保持 anchor 0，避免留白）', () {
      expect(autoFollowAlignment(targetVisible: false), 0.0);
    });
  });

  group('isTargetWellCentered', () {
    test('leading edge 居中 → 已居中', () {
      expect(isTargetWellCentered(leadingEdge: 0.5), isTrue);
    });

    test('leading edge 在容差带内 → 已居中', () {
      expect(isTargetWellCentered(leadingEdge: 0.5 + 0.1), isTrue);
      expect(isTargetWellCentered(leadingEdge: 0.5 - 0.1), isTrue);
    });

    test('leading edge 越出容差带 → 需重新居中', () {
      // 逐句下移漂移到底部：leading edge 偏大，应触发重新居中。
      expect(isTargetWellCentered(leadingEdge: 0.9), isFalse);
      // 贴顶：leading edge 接近 0，应触发重新居中。
      expect(isTargetWellCentered(leadingEdge: 0.0), isFalse);
    });
  });

  group('ParagraphSentenceListCard 自动跟随', () {
    const sentenceCount = 24;

    // 在固定高度容器内构建列表，强制内容溢出以产生滚动空间。
    Widget buildHost({required int playingIndex}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 220,
              child: ParagraphSentenceListCard(
                sentences: createTestSentences(count: sentenceCount),
                displayMode: RetellDisplayMode.showAll,
                keywordMap: const {},
                playingSentenceIndex: playingIndex,
                autoFocusEnabled: true,
              ),
            ),
          ),
        ),
      );
    }

    // 列表视口矩形。
    Rect viewportRect(WidgetTester tester) =>
        tester.getRect(find.byType(ScrollablePositionedList));

    // 指定句子对应的 tile 矩形（须在屏内已构建）。
    Rect tileRect(WidgetTester tester, int sentenceIndex) {
      final finder = find.byWidgetPredicate(
        (w) => w is MaskedSentenceTile && w.sentence.index == sentenceIndex,
      );
      expect(finder, findsOneWidget, reason: '第 $sentenceIndex 句应已渲染在屏内');
      return tester.getRect(finder);
    }

    // 边界容差：内边距(8) + 分隔线 + 行高取整。
    const edgeTol = 24.0;

    testWidgets('末句：贴底停住，不居中留白', (tester) async {
      await tester.pumpWidget(buildHost(playingIndex: sentenceCount - 1));
      await tester.pumpAndSettle();

      final list = viewportRect(tester);
      final last = tileRect(tester, sentenceCount - 1);
      // 末句底边贴近视口底边（而非居中：居中时底边会落在视口中部）。
      expect(
        last.bottom,
        closeTo(list.bottom, edgeTol),
        reason: '最后一句应贴底，下方无大片留白',
      );
      expect(last.bottom, lessThanOrEqualTo(list.bottom + 1));
    });

    testWidgets('首句：贴顶停住', (tester) async {
      // 先定位到末句，再切回首句，制造一次向上的自动跟随。
      await tester.pumpWidget(buildHost(playingIndex: sentenceCount - 1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildHost(playingIndex: 0));
      await tester.pumpAndSettle();

      final list = viewportRect(tester);
      final first = tileRect(tester, 0);
      expect(first.top, closeTo(list.top, edgeTol), reason: '第一句应贴顶，上方无留白');
      expect(first.top, greaterThanOrEqualTo(list.top - 1));
    });

    testWidgets('首次进入恢复进度：中部句居中，不卡在顶部', (tester) async {
      // 直接以中部句进入（模拟恢复进度），目标句首帧未渲染。
      const restored = sentenceCount ~/ 2;
      await tester.pumpWidget(buildHost(playingIndex: restored));
      await tester.pumpAndSettle();

      final list = viewportRect(tester);
      final tile = tileRect(tester, restored);
      final viewportCenter = list.center.dy;
      final tileCenter = tile.center.dy;
      // 中部句应落在视口中段，而非贴顶。
      expect(tile.top, greaterThan(list.top + 24), reason: '恢复进度的中部句不应贴在顶部');
      expect(
        (tileCenter - viewportCenter).abs(),
        lessThan(list.height / 2),
        reason: '中部句中心应靠近视口中心',
      );
    });

    testWidgets('初次定位：居中完成前隐藏、完成后淡入且已居中（无可见滚动）', (tester) async {
      // 初次定位（首次进入 / 切 Tab）应在「列表不可见」时把目标句滚到中部，
      // 用户看不到从顶部到中部的滚动；完成后才淡入显示，等同「直接显示在中间」。
      const restored = sentenceCount ~/ 2;
      await tester.pumpWidget(buildHost(playingIndex: restored));

      double opacity() => tester
          .widget<AnimatedOpacity>(find.byKey(kParagraphListInitialFocusKey))
          .opacity;

      // 居中完成前列表隐藏（滚动过程不可见）。
      await tester.pump();
      expect(opacity(), 0, reason: '居中完成前列表应隐藏，滚动过程不可见');

      // 完成并淡入后：可见且目标句紧贴视口中心、不贴顶。
      await tester.pumpAndSettle();
      expect(opacity(), 1, reason: '居中完成后列表应淡入可见');
      final list = viewportRect(tester);
      final tile = tileRect(tester, restored);
      expect(tile.top, greaterThan(list.top + 24), reason: '中部句应居中而非贴顶');
      expect(
        (tile.center.dy - list.center.dy).abs(),
        lessThan(24),
        reason: '中部句中心应紧贴视口中心',
      );
    });

    testWidgets('自动跟随到末句过程中：滚动位置始终不越界（防回弹回归）', (tester) async {
      await tester.pumpWidget(buildHost(playingIndex: 0));
      await tester.pumpAndSettle();

      // 触发到末句的自动跟随，逐帧推进动画。ClampingScrollPhysics 下任一可滚动
      // 列表的位置都不应越过自身 [min, max]；越界即说明发生了回弹。
      await tester.pumpWidget(buildHost(playingIndex: sentenceCount - 1));
      const eps = 0.5;
      var checkedFrames = 0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final positions = tester
            .stateList<ScrollableState>(find.byType(Scrollable))
            .map((s) => s.position)
            .where((p) => p.hasContentDimensions);
        for (final pos in positions) {
          expect(
            pos.pixels,
            greaterThanOrEqualTo(pos.minScrollExtent - eps),
            reason: '第 $i 帧越过了顶部边界（出现回弹）',
          );
          expect(
            pos.pixels,
            lessThanOrEqualTo(pos.maxScrollExtent + eps),
            reason: '第 $i 帧越过了底部边界（出现回弹）',
          );
          checkedFrames++;
        }
      }
      expect(checkedFrames, greaterThan(0), reason: '应至少检查到若干帧的滚动位置');
      await tester.pumpAndSettle();
    });
  });
}
