// 难句补练/收藏复习设置底部弹窗 Widget 测试
//
// 验证标题、提示文本、循环次数下拉框、停顿模式切换等 UI 行为。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/models/difficult_practice_settings.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

void main() {
  /// 创建测试 App，内含一个按钮用于打开设置底部弹窗
  Widget createTestWidget({
    ReviewDifficultPracticeState initialState =
        const ReviewDifficultPracticeState(),
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [
        reviewDifficultPracticeProvider.overrideWith(
          () => TestReviewDifficultPractice(initialState),
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
            body: ElevatedButton(
              onPressed: () =>
                  showDifficultPracticeSettingsSheet(context: context),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      ),
    );
  }

  /// 打开底部弹窗的辅助方法
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
  }

  group('DifficultPracticeSettingsSheet — 基本展示', () {
    testWidgets('显示标题和提示', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await openSheet(tester);

      expect(find.text('Practice Settings'), findsOneWidget);
      expect(find.text('Settings apply to this session only'), findsOneWidget);
    });

    testWidgets('显示盲听和跟读循环次数行', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await openSheet(tester);

      expect(find.text('Blind listen repeats'), findsOneWidget);
      expect(find.text('Shadow reading repeats'), findsOneWidget);
    });

    testWidgets('显示停顿模式标签和三个选项', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await openSheet(tester);

      expect(find.text('Pause between sentences'), findsOneWidget);
      // "Auto" appears in both control mode and pause mode sections
      expect(find.text('Auto'), findsNWidgets(2));
      expect(find.text('Fixed'), findsOneWidget);
      expect(find.text('Multiplier'), findsAtLeast(1));
    });

    testWidgets('默认显示 Smart 模式描述', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await openSheet(tester);

      // Smart 模式下有 info_outline 图标和描述文字
      // （控制模式区域也有一个 info_outline 图标，共 2 个）
      expect(find.byIcon(Icons.info_outline), findsNWidgets(2));
      expect(find.textContaining('Auto-adjusted based on'), findsOneWidget);
    });
  });

  group('DifficultPracticeSettingsSheet — 默认值', () {
    testWidgets('盲听默认 1 次', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await openSheet(tester);

      // DropdownButton 显示 "1 time(s)"
      expect(find.text('1 time(s)'), findsAtLeast(1));
    });

    testWidgets('跟读默认 3 次', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await openSheet(tester);

      expect(find.text('3 time(s)'), findsAtLeast(1));
    });
  });

  group('DifficultPracticeSettingsSheet — 停顿模式切换', () {
    testWidgets('Fixed 模式显示秒数选择器', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: const ReviewDifficultPracticeState(
            settings: DifficultPracticeSettings(pauseMode: PauseMode.fixed),
          ),
        ),
      );
      await openSheet(tester);

      // Fixed 模式使用 Slider，右侧显示当前秒数（默认 5s）
      expect(find.text('5s'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('点击 Multiplier 显示倍数下拉框', (tester) async {
      // 直接用 Multiplier 模式的初始状态
      await tester.pumpWidget(
        createTestWidget(
          initialState: const ReviewDifficultPracticeState(
            settings: DifficultPracticeSettings(
              pauseMode: PauseMode.multiplier,
            ),
          ),
        ),
      );
      await openSheet(tester);

      // Multiplier 模式显示倍数标签和下拉框
      // 默认 2.0x → "2x"
      expect(find.text('2x'), findsAtLeast(1));
    });
  });

  group('DifficultPracticeSettingsSheet — 中文本地化', () {
    testWidgets('中文标题和提示', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await openSheet(tester);

      expect(find.text('练习设置'), findsOneWidget);
      expect(find.text('设置仅对本次练习有效'), findsOneWidget);
    });

    testWidgets('中文循环次数标签', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await openSheet(tester);

      expect(find.text('盲听循环次数'), findsOneWidget);
      expect(find.text('跟读循环次数'), findsOneWidget);
    });
  });
}
