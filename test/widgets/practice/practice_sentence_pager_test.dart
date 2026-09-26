import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/widgets/practice/practice_sentence_pager.dart';

void main() {
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
}
