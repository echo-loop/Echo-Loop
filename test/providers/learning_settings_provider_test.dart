/// LearningSettings Provider 单元测试
///
/// 覆盖：
/// - 默认值（autoSkipRetell=false，自动回听=false，复述评级=true，首次提示=false）
/// - SP 同步预读注入正确
/// - setAutoSkipRetell 写 SP + 状态更新
/// - cleanupLegacyLearningSettingsKeys 清理旧 SP key
/// - copyWith / == / hashCode
library;

import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer(SharedPreferences prefs) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialLearningSettingsProvider.overrideWithValue(
          LearningSettings.fromPrefsSync(prefs),
        ),
      ],
    );
  }

  group('LearningSettings.fromPrefsSync', () {
    test('SP 缺失时返回默认值', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = LearningSettings.fromPrefsSync(prefs);
      expect(settings.autoSkipRetell, isFalse);
      expect(settings.autoShowAiExplanation, isTrue);
      expect(settings.autoShowAiAnalysis, isTrue);
      expect(settings.autoShowAiTranslation, isTrue);
      expect(settings.autoShowAiSenseGroups, isFalse);
      expect(settings.autoPlayRetellRecordingAfterCompletion, isFalse);
      expect(settings.listenAndRepeatRatingEnabled, isTrue);
      expect(settings.retellRatingEnabled, isTrue);
      expect(settings.retellAutoPlaybackPromptShown, isFalse);
      expect(settings.pdfExportReminderShown, isFalse);
    });

    test('SP 已写入时同步返回保存值', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.autoSkipRetell: true,
        LearningSettingsKeys.autoShowAiExplanation: false,
        LearningSettingsKeys.autoShowAiAnalysis: false,
        LearningSettingsKeys.autoShowAiTranslation: false,
        LearningSettingsKeys.autoShowAiSenseGroups: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
        LearningSettingsKeys.listenAndRepeatRatingEnabled: false,
        LearningSettingsKeys.retellRatingEnabled: false,
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.pdfExportReminderShown: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = LearningSettings.fromPrefsSync(prefs);
      expect(settings.autoSkipRetell, isTrue);
      expect(settings.autoShowAiExplanation, isFalse);
      expect(settings.autoShowAiAnalysis, isFalse);
      expect(settings.autoShowAiTranslation, isFalse);
      expect(settings.autoShowAiSenseGroups, isTrue);
      expect(settings.autoPlayRetellRecordingAfterCompletion, isTrue);
      expect(settings.listenAndRepeatRatingEnabled, isFalse);
      expect(settings.retellRatingEnabled, isFalse);
      expect(settings.retellAutoPlaybackPromptShown, isTrue);
      expect(settings.pdfExportReminderShown, isTrue);
    });
  });

  group('LearningSettingsNotifier', () {
    test('build 返回 initialLearningSettingsProvider 注入值', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.autoSkipRetell: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final settings = container.read(learningSettingsProvider);
      expect(settings.autoSkipRetell, isTrue);
    });

    test('setAutoSkipRetell(true) 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoSkipRetell(true);

      expect(container.read(learningSettingsProvider).autoSkipRetell, isTrue);
      expect(prefs.getBool(LearningSettingsKeys.autoSkipRetell), isTrue);
    });

    test('setAutoSkipRetell(false) 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.autoSkipRetell: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoSkipRetell(false);

      expect(container.read(learningSettingsProvider).autoSkipRetell, isFalse);
      expect(prefs.getBool(LearningSettingsKeys.autoSkipRetell), isFalse);
    });

    test('setAutoSkipRetell 重复设同值不写 SP', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoSkipRetell(false); // 与默认一致
      expect(prefs.containsKey(LearningSettingsKeys.autoSkipRetell), isFalse);
    });

    test('setAutoShowAiExplanation 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoShowAiExplanation(false);

      expect(
        container.read(learningSettingsProvider).autoShowAiExplanation,
        isFalse,
      );
      expect(
        prefs.getBool(LearningSettingsKeys.autoShowAiExplanation),
        isFalse,
      );
    });

    test('setAutoShowAiAnalysis 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoShowAiAnalysis(false);

      expect(
        container.read(learningSettingsProvider).autoShowAiAnalysis,
        isFalse,
      );
      expect(prefs.getBool(LearningSettingsKeys.autoShowAiAnalysis), isFalse);
    });

    test('setAutoShowAiTranslation 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoShowAiTranslation(false);

      expect(
        container.read(learningSettingsProvider).autoShowAiTranslation,
        isFalse,
      );
      expect(
        prefs.getBool(LearningSettingsKeys.autoShowAiTranslation),
        isFalse,
      );
    });

    test('setAutoShowAiSenseGroups 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoShowAiSenseGroups(true);

      expect(
        container.read(learningSettingsProvider).autoShowAiSenseGroups,
        isTrue,
      );
      expect(prefs.getBool(LearningSettingsKeys.autoShowAiSenseGroups), isTrue);
    });

    test('setAutoPlayRetellRecordingAfterCompletion 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setAutoPlayRetellRecordingAfterCompletion(true);

      expect(
        container
            .read(learningSettingsProvider)
            .autoPlayRetellRecordingAfterCompletion,
        isTrue,
      );
      expect(
        prefs.getBool(
          LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion,
        ),
        isTrue,
      );
    });

    test('setRetellRatingEnabled 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setRetellRatingEnabled(false);

      expect(
        container.read(learningSettingsProvider).retellRatingEnabled,
        isFalse,
      );
      expect(prefs.getBool(LearningSettingsKeys.retellRatingEnabled), isFalse);
    });

    test('setShowStudyRecommendation(false) 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setShowStudyRecommendation(false);

      expect(
        container.read(learningSettingsProvider).showStudyRecommendation,
        isFalse,
      );
      expect(
        prefs.getBool(LearningSettingsKeys.showStudyRecommendation),
        isFalse,
      );
    });

    test('SP 缺失时推荐卡默认显示，已关闭时启动读取为 false', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(
        LearningSettings.fromPrefsSync(prefs).showStudyRecommendation,
        isTrue,
      );

      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.showStudyRecommendation: false,
      });
      final closedPrefs = await SharedPreferences.getInstance();
      expect(
        LearningSettings.fromPrefsSync(closedPrefs).showStudyRecommendation,
        isFalse,
      );
    });

    test('setListenAndRepeatRatingEnabled 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setListenAndRepeatRatingEnabled(false);

      expect(
        container.read(learningSettingsProvider).listenAndRepeatRatingEnabled,
        isFalse,
      );
      expect(
        prefs.getBool(LearningSettingsKeys.listenAndRepeatRatingEnabled),
        isFalse,
      );
    });

    test('markRetellAutoPlaybackPromptShown 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.markRetellAutoPlaybackPromptShown();

      expect(
        container.read(learningSettingsProvider).retellAutoPlaybackPromptShown,
        isTrue,
      );
      expect(
        prefs.getBool(LearningSettingsKeys.retellAutoPlaybackPromptShown),
        isTrue,
      );
    });
    test('markPdfExportReminderShown 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.markPdfExportReminderShown();

      expect(
        container.read(learningSettingsProvider).pdfExportReminderShown,
        isTrue,
      );
      expect(
        prefs.getBool(LearningSettingsKeys.pdfExportReminderShown),
        isTrue,
      );
    });

    test('reloadFromPrefs 回灌外部删除的 SP（首次提示标记复位）', () async {
      // 初始：已提示过 + 功能已开。
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellAutoPlaybackPromptShown: true,
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      expect(
        container.read(learningSettingsProvider).retellAutoPlaybackPromptShown,
        isTrue,
      );

      // 模拟开发者偏好设置页直接删 SP（绕过 Notifier）。
      await prefs.remove(LearningSettingsKeys.retellAutoPlaybackPromptShown);
      await prefs.remove(
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion,
      );

      // 重载前内存仍是旧值。
      expect(
        container.read(learningSettingsProvider).retellAutoPlaybackPromptShown,
        isTrue,
      );

      notifier.reloadFromPrefs();

      // 重载后回到默认关闭，首次提示可再次触发。
      final reloaded = container.read(learningSettingsProvider);
      expect(reloaded.retellAutoPlaybackPromptShown, isFalse);
      expect(reloaded.autoPlayRetellRecordingAfterCompletion, isFalse);
    });
  });

  group('migrateLegacyOfflineAsrEnabledToRatingSettings', () {
    test('旧 ASR 关闭且无新 key 时迁移为关闭两个评分', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.legacyOfflineAsrEnabled: false,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyOfflineAsrEnabledToRatingSettings(prefs);

      expect(
        prefs.getBool(LearningSettingsKeys.listenAndRepeatRatingEnabled),
        isFalse,
      );
      expect(prefs.getBool(LearningSettingsKeys.retellRatingEnabled), isFalse);
      expect(
        prefs.containsKey(LearningSettingsKeys.legacyOfflineAsrEnabled),
        isFalse,
      );
    });

    test('旧 ASR 开启或缺失时不写新评分 key，默认保持 true', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.legacyOfflineAsrEnabled: true,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyOfflineAsrEnabledToRatingSettings(prefs);
      final settings = LearningSettings.fromPrefsSync(prefs);

      expect(settings.listenAndRepeatRatingEnabled, isTrue);
      expect(settings.retellRatingEnabled, isTrue);
      expect(
        prefs.containsKey(LearningSettingsKeys.listenAndRepeatRatingEnabled),
        isFalse,
      );
      expect(
        prefs.containsKey(LearningSettingsKeys.retellRatingEnabled),
        isFalse,
      );
    });

    test('旧 ASR 关闭不覆盖已有新评分 key', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.legacyOfflineAsrEnabled: false,
        LearningSettingsKeys.retellRatingEnabled: true,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyOfflineAsrEnabledToRatingSettings(prefs);

      expect(
        prefs.getBool(LearningSettingsKeys.listenAndRepeatRatingEnabled),
        isFalse,
      );
      expect(prefs.getBool(LearningSettingsKeys.retellRatingEnabled), isTrue);
    });
  });

  group('cleanupLegacyLearningSettingsKeys', () {
    test('清除老 SP key（retell_enabled / setup_choice_at_ms）', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.legacyRetellEnabled: true,
        LearningSettingsKeys.legacySetupChoiceMadeAtMs: 1700000000000,
        LearningSettingsKeys.autoSkipRetell: true, // 新 key 不动
      });
      final prefs = await SharedPreferences.getInstance();
      await cleanupLegacyLearningSettingsKeys(prefs);
      expect(
        prefs.containsKey(LearningSettingsKeys.legacyRetellEnabled),
        isFalse,
      );
      expect(
        prefs.containsKey(LearningSettingsKeys.legacySetupChoiceMadeAtMs),
        isFalse,
      );
      expect(prefs.containsKey(LearningSettingsKeys.autoSkipRetell), isTrue);
    });

    test('老 key 不存在时幂等不报错', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await cleanupLegacyLearningSettingsKeys(prefs);
    });
  });

  group('LearningSettings model', () {
    test('copyWith 修改 autoSkipRetell', () {
      const settings = LearningSettings(autoSkipRetell: true);
      final copied = settings.copyWith(
        autoSkipRetell: false,
        autoPlayRetellRecordingAfterCompletion: true,
        listenAndRepeatRatingEnabled: false,
        retellRatingEnabled: false,
        retellAutoPlaybackPromptShown: true,
      );
      expect(copied.autoSkipRetell, isFalse);
      expect(copied.autoPlayRetellRecordingAfterCompletion, isTrue);
      expect(copied.listenAndRepeatRatingEnabled, isFalse);
      expect(copied.retellRatingEnabled, isFalse);
      expect(copied.retellAutoPlaybackPromptShown, isTrue);
    });

    test('== 和 hashCode 正确', () {
      const a = LearningSettings(
        autoSkipRetell: true,
        autoPlayRetellRecordingAfterCompletion: true,
        listenAndRepeatRatingEnabled: false,
        retellRatingEnabled: false,
      );
      const b = LearningSettings(
        autoSkipRetell: true,
        autoPlayRetellRecordingAfterCompletion: true,
        listenAndRepeatRatingEnabled: false,
        retellRatingEnabled: false,
      );
      const c = LearningSettings(autoSkipRetell: false);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
