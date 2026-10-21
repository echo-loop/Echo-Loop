import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/widgets/blind_listen_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  Widget createTestWidget({
    BlindListenPlayerState initialState = const BlindListenPlayerState(),
  }) {
    return createTestApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showBlindListenSettingsSheet(context),
            child: const Text('Open Settings'),
          ),
        ),
      ),
      overrides: [
        blindListenPlayerProvider.overrideWith(
          () => TestBlindListenPlayer(initialState),
        ),
      ],
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('默认显示 1.0x 播放速度滑块', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    expect(find.text('Playback Speed'), findsOneWidget);
    expect(find.text('1.0x'), findsAtLeast(1));
    final slider = tester.widget<Slider>(find.byType(Slider).last);
    expect(slider.value, 6.0);
    expect(slider.min, 0);
    expect(slider.max, 12.0);
    expect(slider.divisions, 12);
  });

  testWidgets('播放速度设置显示在重复次数和段间停顿之后', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    final repeatTop = tester.getTopLeft(find.text('Repeat per segment')).dy;
    final pauseTop = tester.getTopLeft(find.text('Pause between segments')).dy;
    final speedTop = tester.getTopLeft(find.text('Playback Speed')).dy;

    expect(speedTop, greaterThan(pauseTop));
    expect(speedTop, greaterThan(repeatTop));
  });

  testWidgets('重复次数包含 Infinite ∞ 选项', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();
    expect(find.text('Infinite ∞'), findsWidgets);
  });

  testWidgets('滑块更新盲听速度设置', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    tester.widget<Slider>(find.byType(Slider).last).onChanged!(8);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Playback Speed')),
    );
    expect(
      container.read(blindListenPlayerProvider).settings.playbackSpeed,
      1.2,
    );
    expect(find.text('1.2x'), findsOneWidget);
  });

  testWidgets('小视口下内容可滚动且关闭按钮保持可见', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();

    final closeButton = find.byKey(const Key('settings-sheet-close'));
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(closeButton, findsNothing);
  });
}
