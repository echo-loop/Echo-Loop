import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/widgets/retell/retell_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  Widget createTestWidget() {
    return createTestApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showRetellSettingsSheet(context),
            child: const Text('Open Settings'),
          ),
        ),
      ),
      overrides: [retellPlayerProvider.overrideWith(() => TestRetellPlayer())],
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

  testWidgets('重复次数包含新增档位和 Infinite ∞ 选项', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();
    expect(find.text('Infinite ∞'), findsWidgets);
    for (final count in [20, 30, 40, 50]) {
      expect(find.text('$count'), findsOneWidget);
    }
  });

  testWidgets('滑块更新复述速度设置', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    tester.widget<Slider>(find.byType(Slider).last).onChanged!(8);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Playback Speed')),
    );
    expect(container.read(retellPlayerProvider).settings.playbackSpeed, 1.2);
    expect(find.text('1.2x'), findsOneWidget);
  });

  testWidgets('小视口滚动内容后仍可通过固定关闭按钮关闭', (tester) async {
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
