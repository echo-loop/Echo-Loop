/// LearningSettingsScreen Widget 测试
///
/// 覆盖：
/// - 开关初始值显示
/// - 切换开关写入 SP + 翻转 state
/// - 说明文字渲染
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/screens/learning_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

/// 将测试视口加高，确保位于列表底部的新手引导区域可被点击。
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> buildApp({
    bool autoSkipRetell = false,
    bool autoShowAiExplanation = true,
    bool autoShowAiAnalysis = true,
    bool autoShowAiTranslation = true,
    bool autoShowAiSenseGroups = false,
    bool autoPlayRetellRecording = false,
    bool listenAndRepeatRatingEnabled = true,
    bool retellRatingEnabled = true,
    bool? guideEnabled,
    bool seedGuideSeen = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (autoSkipRetell) LearningSettingsKeys.autoSkipRetell: true,
      if (!autoShowAiExplanation)
        LearningSettingsKeys.autoShowAiExplanation: false,
      if (!autoShowAiAnalysis) LearningSettingsKeys.autoShowAiAnalysis: false,
      if (!autoShowAiTranslation)
        LearningSettingsKeys.autoShowAiTranslation: false,
      if (autoShowAiSenseGroups)
        LearningSettingsKeys.autoShowAiSenseGroups: true,
      if (autoPlayRetellRecording)
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      if (!listenAndRepeatRatingEnabled)
        LearningSettingsKeys.listenAndRepeatRatingEnabled: false,
      if (!retellRatingEnabled) LearningSettingsKeys.retellRatingEnabled: false,
      if (guideEnabled != null) GuideRegistry.enabledKey: guideEnabled,
      if (seedGuideSeen) 'guide_v1_${GuideFlowIds.active.first}_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialLearningSettingsProvider.overrideWithValue(
          LearningSettings.fromPrefsSync(prefs),
        ),
        analyticsOverride(),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('zh')],
        home: LearningSettingsScreen(),
      ),
    );
  }

  testWidgets('默认显示 AI 讲解总开关 ON，解析/翻译 ON，意群 OFF', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final autoShowFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-show AI explanation',
    );
    final autoShowTile = tester.widget<SwitchListTile>(autoShowFinder);
    expect(autoShowTile.value, isTrue);

    expect(find.text('AI Analysis'), findsOneWidget);
    expect(find.text('AI Translation'), findsOneWidget);
    expect(find.text('AI Sense Groups'), findsOneWidget);
    expect(find.byIcon(Icons.psychology_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.translate), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);

    // 找到 "Auto-skip" label 所在的 SwitchListTile
    final autoSkipFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-skip retelling practice',
    );
    final switchTile = tester.widget<SwitchListTile>(autoSkipFinder);
    expect(switchTile.value, isFalse);
    expect(find.textContaining('Auto-skip'), findsWidgets);
    final autoPlayFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-play retelling recording',
    );
    final autoPlayTile = tester.widget<SwitchListTile>(autoPlayFinder);
    expect(autoPlayTile.value, isFalse);
    final ratingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each repeat',
    );
    final listenRatingTile = tester.widget<SwitchListTile>(ratingFinder);
    expect(listenRatingTile.value, isTrue);
    final retellRatingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each retelling',
    );
    final ratingTile = tester.widget<SwitchListTile>(retellRatingFinder);
    expect(ratingTile.value, isTrue);
  });

  testWidgets('关闭 AI 讲解总开关后隐藏三个子开关', (tester) async {
    await tester.pumpWidget(await buildApp(autoShowAiExplanation: false));
    await tester.pumpAndSettle();

    final autoShowFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-show AI explanation',
    );
    expect(tester.widget<SwitchListTile>(autoShowFinder).value, isFalse);
    expect(find.text('AI Analysis'), findsNothing);
    expect(find.text('AI Translation'), findsNothing);
    expect(find.text('AI Sense Groups'), findsNothing);
  });

  testWidgets('点击 AI 讲解子开关 → 翻转 state + 写 SP', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI Sense Groups'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LearningSettingsKeys.autoShowAiSenseGroups), isTrue);

    await tester.tap(find.text('AI Analysis'));
    await tester.pumpAndSettle();
    expect(prefs.getBool(LearningSettingsKeys.autoShowAiAnalysis), isFalse);

    await tester.tap(find.text('AI Translation'));
    await tester.pumpAndSettle();
    expect(prefs.getBool(LearningSettingsKeys.autoShowAiTranslation), isFalse);
  });

  testWidgets('点击开关 → 翻转 state + 写 SP', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // 找到 "Auto-skip Retell" 的 SwitchListTile 并点击
    final autoSkipFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-skip retelling practice',
    );
    await tester.tap(autoSkipFinder);
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(autoSkipFinder);
    expect(switchTile.value, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LearningSettingsKeys.autoSkipRetell), isTrue);
  });

  testWidgets('点击自动回听开关 → 翻转 state + 写 SP', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final autoPlayFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-play retelling recording',
    );
    await tester.tap(autoPlayFinder);
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(autoPlayFinder);
    expect(switchTile.value, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion,
      ),
      isTrue,
    );
    // Bug 1：设置页显式配置过即标记首次提示已展示，避免复述完成后再弹窗。
    expect(
      prefs.getBool(LearningSettingsKeys.retellAutoPlaybackPromptShown),
      isTrue,
    );
  });

  testWidgets('点击复述评级开关 → 翻转 state + 写 SP', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final ratingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each retelling',
    );
    await tester.tap(ratingFinder);
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(ratingFinder);
    expect(switchTile.value, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LearningSettingsKeys.retellRatingEnabled), isFalse);
  });

  testWidgets('点击跟读评级开关 → 翻转 state + 写 SP', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final ratingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each repeat',
    );
    await tester.tap(ratingFinder);
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(ratingFinder);
    expect(switchTile.value, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(LearningSettingsKeys.listenAndRepeatRatingEnabled),
      isFalse,
    );
  });

  testWidgets('初始 ON 时开关显示 ON', (tester) async {
    await tester.pumpWidget(
      await buildApp(autoSkipRetell: true, autoPlayRetellRecording: true),
    );
    await tester.pumpAndSettle();

    // 找到 "Auto-skip Retell" 的 SwitchListTile
    final autoSkipFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-skip retelling practice',
    );
    final switchTile = tester.widget<SwitchListTile>(autoSkipFinder);
    expect(switchTile.value, isTrue);

    final autoPlayFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Auto-play retelling recording',
    );
    final autoPlayTile = tester.widget<SwitchListTile>(autoPlayFinder);
    expect(autoPlayTile.value, isTrue);

    final ratingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each repeat',
    );
    final listenRatingTile = tester.widget<SwitchListTile>(ratingFinder);
    expect(listenRatingTile.value, isTrue);

    final retellRatingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each retelling',
    );
    final ratingTile = tester.widget<SwitchListTile>(retellRatingFinder);
    expect(ratingTile.value, isTrue);
  });

  testWidgets('复述评级初始 OFF 时开关显示 OFF', (tester) async {
    await tester.pumpWidget(await buildApp(retellRatingEnabled: false));
    await tester.pumpAndSettle();

    final ratingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each retelling',
    );
    final ratingTile = tester.widget<SwitchListTile>(ratingFinder);
    expect(ratingTile.value, isFalse);
  });

  testWidgets('跟读评级初始 OFF 时开关显示 OFF', (tester) async {
    await tester.pumpWidget(
      await buildApp(listenAndRepeatRatingEnabled: false),
    );
    await tester.pumpAndSettle();

    final ratingFinder = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Show rating after each repeat',
    );
    final ratingTile = tester.widget<SwitchListTile>(ratingFinder);
    expect(ratingTile.value, isFalse);
  });

  // 新手引导项为自定义 Row（非 SwitchListTile），按所在 Card 内的 Switch 定位。
  Finder guideSwitchFinder() => find.descendant(
    of: find.widgetWithText(Card, 'New User Guide'),
    matching: find.byType(Switch),
  );

  testWidgets('新手引导默认开启，且显示「重置」按钮', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final guideSwitch = tester.widget<Switch>(guideSwitchFinder());
    expect(guideSwitch.value, isTrue);
    // 开启时「重置」按钮可见。
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
  });

  testWidgets('关闭新手引导后「重置」按钮消失', (tester) async {
    await tester.pumpWidget(await buildApp(guideEnabled: false));
    await tester.pumpAndSettle();

    final guideSwitch = tester.widget<Switch>(guideSwitchFinder());
    expect(guideSwitch.value, isFalse);
    expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);
  });

  testWidgets('切换新手引导开关 → 翻转 state + 写 SP', (tester) async {
    // 设置页已加入更多卡片，引导开关位于默认视口之外，这里加高视口以便点击。
    _useTallViewport(tester);
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(guideSwitchFinder());
    await tester.pumpAndSettle();

    final guideSwitch = tester.widget<Switch>(guideSwitchFinder());
    expect(guideSwitch.value, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(GuideRegistry.enabledKey), isFalse);
  });

  testWidgets('点击「重置」→ 清空 seen 状态并弹 snackbar', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await buildApp(seedGuideSeen: true));
    await tester.pumpAndSettle();

    final seenKey = 'guide_v1_${GuideFlowIds.active.first}_seen';
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(seenKey), isTrue);

    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(prefs.getBool(seenKey), isNull);
    expect(find.text('New user guide has been reset'), findsOneWidget);
  });
}
