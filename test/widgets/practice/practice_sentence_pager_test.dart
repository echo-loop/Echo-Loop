import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/widgets/practice/practice_sentence_pager.dart';

void main() {
  testWidgets('非索引状态重建不会中断正在进行的用户滑动', (tester) async {
    late StateSetter rebuildPager;
    final pagerController = PracticeSentencePagerController();
    var revision = 0;
    final settledIndexes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildPager = setState;
            return SizedBox(
              width: 320,
              height: 240,
              child: PracticeSentencePager(
                pageViewKey: const ValueKey('pager'),
                controller: pagerController,
                currentIndex: 0,
                itemCount: 3,
                onSentenceSettled: (index) async => settledIndexes.add(index),
                itemBuilder: (context, index) =>
                    Text('Sentence $index $revision'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final pager = find.byKey(const ValueKey('pager'));
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(Offset(-tester.getSize(pager).width * 0.8, 0));
    await tester.pump();

    expect(tester.widget<PageView>(pager).controller?.page, greaterThan(0.5));

    rebuildPager(() => revision++);
    await tester.pumpAndSettle();

    expect(tester.widget<PageView>(pager).controller?.page, greaterThan(0.5));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(settledIndexes, [1]);
    expect(tester.widget<PageView>(pager).controller?.page?.round(), 1);
  });

  testWidgets('拖动期间外部索引变化会在停稳后覆盖旧手势', (tester) async {
    late StateSetter rebuildPager;
    final pagerController = PracticeSentencePagerController();
    var currentIndex = 0;
    final settledIndexes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildPager = setState;
            return SizedBox(
              width: 320,
              height: 240,
              child: PracticeSentencePager(
                pageViewKey: const ValueKey('pager'),
                controller: pagerController,
                currentIndex: currentIndex,
                itemCount: 3,
                onSentenceSettled: (index) async => settledIndexes.add(index),
                itemBuilder: (context, index) => Text('Sentence $index'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final pager = find.byKey(const ValueKey('pager'));
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(Offset(-tester.getSize(pager).width * 0.8, 0));
    await tester.pump();

    rebuildPager(() => currentIndex = 2);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(settledIndexes, isEmpty);
    expect(tester.widget<PageView>(pager).controller?.page?.round(), 2);
  });

  testWidgets('分页锁解除后会应用延迟的外部索引同步', (tester) async {
    late StateSetter rebuildPager;
    final pagerController = PracticeSentencePagerController();
    var currentIndex = 0;
    var isLocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildPager = setState;
            return SizedBox(
              width: 320,
              height: 240,
              child: PracticeSentencePager(
                pageViewKey: const ValueKey('pager'),
                controller: pagerController,
                currentIndex: currentIndex,
                itemCount: 3,
                isTransitionLocked: isLocked,
                onSentenceSettled: (_) async {},
                itemBuilder: (context, index) => Text('Sentence $index'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    rebuildPager(() {
      currentIndex = 2;
      isLocked = true;
    });
    await tester.pump();

    expect(
      tester
          .widget<PageView>(find.byKey(const ValueKey('pager')))
          .controller
          ?.page
          ?.round(),
      0,
    );

    rebuildPager(() => isLocked = false);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<PageView>(find.byKey(const ValueKey('pager')))
          .controller
          ?.page
          ?.round(),
      2,
    );
  });

  testWidgets('业务切句未完成时仍接受第二次程序化导航', (tester) async {
    final pagerController = PracticeSentencePagerController();
    final commitGate = Completer<void>();
    var commitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: PracticeSentencePager(
            pageViewKey: const ValueKey('pager'),
            controller: pagerController,
            currentIndex: 0,
            itemCount: 3,
            onSentenceSettled: (_) async {},
            itemBuilder: (context, index) => Text('Sentence $index'),
          ),
        ),
      ),
    );
    await tester.pump();

    final firstNavigation = pagerController.animateAndCommit(
      1,
      commit: () async {
        commitCalls += 1;
        await commitGate.future;
      },
    );
    await tester.pumpAndSettle();

    expect(commitCalls, 1);

    final secondNavigation = pagerController.animateAndCommit(
      2,
      commit: () async => commitCalls += 1,
    );
    await tester.pumpAndSettle();
    await secondNavigation;
    expect(commitCalls, 2);

    commitGate.complete();
    await firstNavigation;
    expect(commitCalls, 2);
  });

  testWidgets('手势触发的播放未结束时仍接受后续程序化切句', (tester) async {
    final pagerController = PracticeSentencePagerController();
    final commitGate = Completer<void>();
    var commitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: PracticeSentencePager(
            pageViewKey: const ValueKey('pager'),
            controller: pagerController,
            currentIndex: 0,
            itemCount: 3,
            onSentenceSettled: (_) async {
              commitCalls += 1;
              await commitGate.future;
            },
            itemBuilder: (context, index) => Text('Sentence $index'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.fling(
      find.byKey(const ValueKey('pager')),
      const Offset(-1000, 0),
      0.1,
    );
    await tester.pumpAndSettle();
    expect(commitCalls, 1);

    final secondNavigation = pagerController.animateAndCommit(
      2,
      commit: () async => commitCalls += 1,
    );
    await tester.pumpAndSettle();
    await secondNavigation;

    expect(commitCalls, 2);

    commitGate.complete();
    await tester.pump();
    await tester.pumpAndSettle();
  });

  testWidgets('句子列表首次到位时直接对齐到当前句而不做滑动', (tester) async {
    await tester.pumpWidget(_pagerHost(itemCount: 0, currentIndex: 0));
    await tester.pump();

    await tester.pumpWidget(_pagerHost(itemCount: 4, currentIndex: 1));
    await tester.pump();

    expect(_pageOf(tester), 1.0);
  });

  testWidgets('已对齐后的相邻句切换仍使用滑动动画', (tester) async {
    await tester.pumpWidget(_pagerHost(itemCount: 4, currentIndex: 0));
    await tester.pump();

    await tester.pumpWidget(_pagerHost(itemCount: 4, currentIndex: 1));
    await tester.pump();
    expect(_pageOf(tester), 0.0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(_pageOf(tester), allOf(greaterThan(0.0), lessThan(1.0)));

    await tester.pumpAndSettle();
    expect(_pageOf(tester), 1.0);
  });

  testWidgets('空列表到位时停在第一句后，之后的相邻切句仍使用滑动动画', (tester) async {
    await tester.pumpWidget(_pagerHost(itemCount: 0, currentIndex: 0));
    await tester.pump();

    // 索引未变化，到位时只依赖首次对齐来标记页面已同步。
    await tester.pumpWidget(_pagerHost(itemCount: 4, currentIndex: 0));
    await tester.pump();

    await tester.pumpWidget(_pagerHost(itemCount: 4, currentIndex: 1));
    await tester.pump();
    expect(_pageOf(tester), 0.0);

    await tester.pumpAndSettle();
    expect(_pageOf(tester), 1.0);
  });
}

Widget _pagerHost({required int itemCount, required int currentIndex}) {
  return MaterialApp(
    home: SizedBox(
      width: 320,
      height: 240,
      child: PracticeSentencePager(
        pageViewKey: const ValueKey('pager'),
        controller: PracticeSentencePagerController(),
        currentIndex: currentIndex,
        itemCount: itemCount,
        onSentenceSettled: (_) async {},
        itemBuilder: (context, index) => Text('Sentence $index'),
      ),
    ),
  );
}

double? _pageOf(WidgetTester tester) {
  return tester
      .widget<PageView>(find.byKey(const ValueKey('pager')))
      .controller
      ?.page;
}
