import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/widgets/common/countdown_chip.dart';

void main() {
  Widget buildChip({
    Duration remaining = const Duration(seconds: 3),
    Duration total = const Duration(seconds: 5),
    bool isPaused = false,
    VoidCallback? onPause,
    VoidCallback? onResume,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CountdownChip(
            remaining: remaining,
            total: total,
            isPaused: isPaused,
            onPause: onPause ?? () {},
            onResume: onResume ?? () {},
          ),
        ),
      ),
    );
  }

  group('CountdownChip', () {
    testWidgets('倒计时中显示秒数和暂停徽章', (tester) async {
      await tester.pumpWidget(buildChip(
        remaining: const Duration(seconds: 3),
        total: const Duration(seconds: 5),
      ));

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('暂停时显示播放徽章', (tester) async {
      await tester.pumpWidget(buildChip(isPaused: true));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('倒计时中点击调用 onPause', (tester) async {
      var pauseCalled = false;
      var resumeCalled = false;

      await tester.pumpWidget(buildChip(
        isPaused: false,
        onPause: () => pauseCalled = true,
        onResume: () => resumeCalled = true,
      ));

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(pauseCalled, isTrue);
      expect(resumeCalled, isFalse);
    });

    testWidgets('暂停中点击调用 onResume', (tester) async {
      var pauseCalled = false;
      var resumeCalled = false;

      await tester.pumpWidget(buildChip(
        isPaused: true,
        onPause: () => pauseCalled = true,
        onResume: () => resumeCalled = true,
      ));

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(pauseCalled, isFalse);
      expect(resumeCalled, isTrue);
    });

    testWidgets('进度环正确显示（3/5 = 40%）', (tester) async {
      await tester.pumpWidget(buildChip(
        remaining: const Duration(seconds: 3),
        total: const Duration(seconds: 5),
      ));

      final progressFinder = find.byType(CircularProgressIndicator);
      expect(progressFinder, findsOneWidget);

      final progress =
          tester.widget<CircularProgressIndicator>(progressFinder);
      expect(progress.value, closeTo(0.4, 0.01));
    });
  });
}
