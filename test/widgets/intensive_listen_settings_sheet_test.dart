// 精听设置面板测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/widgets/intensive_listen/intensive_listen_settings_sheet.dart';
import 'package:echo_loop/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

void main() {
  Widget createTestWidget({
    Locale locale = const Locale('zh'),
    IntensiveListenState? playerState,
  }) {
    return ProviderScope(
      overrides: dedupeOverrides([
        intensiveListenPlayerProvider.overrideWith(
          () => TestIntensiveListenPlayer(
            playerState ?? const IntensiveListenState(),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
      ]),
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showIntensiveListenSettingsSheet(context: context);
                },
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 打开设置面板
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
  }

  group('IntensiveListenSettingsSheet', () {
    testWidgets('显示标题和临时提示', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('精听设置'), findsOneWidget);
      expect(find.text('设置会被记住，下次自动沿用'), findsOneWidget);
      // 不再有"完成"按钮
      expect(find.widgetWithText(FilledButton, '完成'), findsNothing);
    });

    testWidgets('显示循环次数标签', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('每句循环次数'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.text('无限 ∞'), findsWidgets);
      for (final count in [20, 30, 40, 50]) {
        expect(find.text('$count 次'), findsOneWidget);
      }
    });

    testWidgets('循环次数为 1 时不显示讲解页循环开关', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const IntensiveListenState(
            settings: IntensiveListenSettings(repeatCount: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('讲解页按循环次数播放'), findsNothing);
    });

    testWidgets('循环次数超过 1 时显示讲解页循环开关并可切换', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const IntensiveListenState(
            settings: IntensiveListenSettings(repeatCount: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('讲解页按循环次数播放'), findsOneWidget);
      final switchTile = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text('讲解页按循环次数播放'),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(switchTile.value, false);

      await tester.tap(find.text('讲解页按循环次数播放'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SwitchListTile)),
      );
      expect(
        container
            .read(intensiveListenPlayerProvider)
            .settings
            .annotationReplayUsesRepeatCount,
        true,
      );
    });

    testWidgets('无限循环时显示讲解页循环开关', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const IntensiveListenState(
            settings: IntensiveListenSettings(repeatCount: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('讲解页按循环次数播放'), findsOneWidget);
    });

    testWidgets('手动模式显示循环和停顿设置', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const IntensiveListenState(
            settings: IntensiveListenSettings(
              controlMode: ShadowingControlMode.manual,
              repeatCount: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('每句循环次数'), findsOneWidget);
      expect(find.text('句间停顿'), findsOneWidget);
      expect(find.text('固定间隔'), findsOneWidget);
      expect(find.text('讲解页按循环次数播放'), findsOneWidget);
    });

    testWidgets('手动模式默认一次循环并可修改循环和停顿设置', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const IntensiveListenState(
            settings: IntensiveListenSettings(
              controlMode: ShadowingControlMode.manual,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('每句循环次数'), findsOneWidget);
      expect(find.text('1 次'), findsOneWidget);
      expect(find.text('句间停顿'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 次').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('固定间隔'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.text('每句循环次数')),
      );
      final settings = container.read(intensiveListenPlayerProvider).settings;
      expect(settings.repeatCount, 3);
      expect(settings.pauseMode, PauseMode.fixed);
      expect(settings.fixedPauseSeconds, 3);
    });

    testWidgets('显示句间停顿标签', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('句间停顿'), findsOneWidget);
    });

    testWidgets('显示三种停顿模式', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      // "自动" appears in both control mode and pause mode sections
      expect(find.text('自动'), findsNWidgets(2));
      expect(find.text('固定间隔'), findsOneWidget);
      expect(find.text('句长倍数'), findsOneWidget);
    });

    testWidgets('默认模式显示智能间隔说明', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      // 默认 smart 模式显示说明
      expect(find.text('根据难度、句子长度和学习阶段自动调整'), findsOneWidget);
    });

    testWidgets('切换到固定间隔模式显示 Slider', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      // 点击固定间隔
      await tester.tap(find.text('固定间隔'));
      await tester.pumpAndSettle();

      // 固定间隔模式有停顿 Slider + 播放速度 Slider，右侧显示当前秒数（默认 3s）
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.text('3s'), findsOneWidget);
    });

    testWidgets('切换到倍数模式显示倍数选择', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      // 点击句长倍数
      await tester.tap(find.text('句长倍数'));
      await tester.pumpAndSettle();

      // 应该显示倍数标签
      expect(find.text('倍数'), findsOneWidget);
    });

    testWidgets('英文本地化正确显示', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(
        find.text('Settings are remembered for next time'),
        findsOneWidget,
      );
      expect(find.text('Repeat per sentence'), findsOneWidget);
      expect(find.text('Pause between sentences'), findsOneWidget);
      // "Auto" appears in both control mode and pause mode sections
      expect(find.text('Auto'), findsNWidgets(2));
      expect(find.text('Fixed'), findsOneWidget);
      expect(find.text('Multiplier'), findsWidgets);
    });

    testWidgets('下拉手势关闭面板', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      // 确认面板打开
      expect(find.text('精听设置'), findsOneWidget);

      // 下拉关闭（模拟拖拽手势）
      await tester.drag(find.text('精听设置'), const Offset(0, 500));
      await tester.pumpAndSettle();

      // 面板关闭
      expect(find.text('精听设置'), findsNothing);
    });

    testWidgets('使用自定义设置初始化面板', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const IntensiveListenState(
            settings: IntensiveListenSettings(
              repeatCount: 3,
              pauseMode: PauseMode.fixed,
              fixedPauseSeconds: 10,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      // 固定间隔模式下 Slider 右侧显示当前秒数（硬编码后缀 s）
      expect(find.text('10s'), findsOneWidget);
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
  });
}
