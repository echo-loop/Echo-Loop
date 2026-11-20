import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/common/countdown_ring.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';

import '../helpers/test_app.dart';

void main() {
  Widget buildRing({
    Duration total = const Duration(seconds: 5),
    bool isPaused = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CountdownRing(
            total: total,
            isPaused: isPaused,
            diameter: 64,
            overlayBuilder: (context, seconds) =>
                Text('$seconds', key: const ValueKey('seconds')),
          ),
        ),
      ),
    );
  }

  String secondsText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('seconds'))).data!;

  testWidgets('按剩余时间向上取整显示秒数并随时间递减', (tester) async {
    await tester.pumpWidget(buildRing());
    expect(secondsText(tester), '5');

    await tester.pump(const Duration(milliseconds: 1100));
    expect(secondsText(tester), '4');
  });

  testWidgets('暂停时圆环与秒数不再推进', (tester) async {
    await tester.pumpWidget(buildRing(isPaused: true));
    await tester.pump(const Duration(seconds: 2));

    expect(secondsText(tester), '5');
  });

  testWidgets('总时长变化视为新的倒计时，从新总时长重新开始', (tester) async {
    await tester.pumpWidget(buildRing());
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(buildRing(total: const Duration(seconds: 8)));
    expect(secondsText(tester), '8');
  });

  testWidgets('主播放按钮环形倒计时与按钮同尺寸，窄屏带速度按钮时不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      createTestApp(
        Center(
          child: SizedBox(
            width: 320,
            child: PlaybackControls(
              canGoPrev: true,
              isLast: false,
              centerIcon: PlaybackToggleIcon.pause,
              onPrevious: () {},
              onNext: () {},
              onCenter: () {},
              playbackSpeed: 1.0,
              onPlaybackSpeedChanged: (_) {},
              centerRing: CountdownRing(
                total: const Duration(seconds: 5),
                isPaused: false,
                diameter: PlaybackControls.controlButtonSize,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(CountdownRing)),
      const Size.square(PlaybackControls.controlButtonSize),
    );
  });

  testWidgets('PlaybackCountdownRing 与主按钮同尺寸并显示剩余秒数', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        const Center(
          child: PlaybackCountdownRing(
            total: Duration(seconds: 5),
            isPaused: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('5'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CountdownRing)),
      const Size.square(PlaybackControls.controlButtonSize),
    );
  });
}
