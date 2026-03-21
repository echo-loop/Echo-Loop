// 精听设置面板测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/widgets/intensive_listen/intensive_listen_settings_sheet.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

void main() {
  Widget createTestWidget({
    Locale locale = const Locale('zh'),
    IntensiveListenState? playerState,
  }) {
    return ProviderScope(
      overrides: [
        intensiveListenPlayerProvider.overrideWith(
          () => TestIntensiveListenPlayer(
            playerState ?? const IntensiveListenState(),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
      ],
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
      expect(find.text('设置仅对本次精听有效'), findsOneWidget);
      // 不再有"完成"按钮
      expect(find.widgetWithText(FilledButton, '完成'), findsNothing);
    });

    testWidgets('显示循环次数标签', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('每句循环次数'), findsOneWidget);
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

      // 固定间隔模式使用 Slider，右侧显示当前秒数（默认 5s）
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('5s'), findsOneWidget);
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
      expect(find.text('Settings apply to this session only'), findsOneWidget);
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
      await tester.drag(find.text('精听设置'), const Offset(0, 300));
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
  });
}
