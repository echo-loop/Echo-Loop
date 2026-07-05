import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/providers/local_transcription_model_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';

/// 构建带 override 的容器。
Future<ProviderContainer> buildContainer({
  Map<String, Object> prefs = const {},
  AsrModelInfo? recommended,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final rec = recommended ?? availableModels.first; // tiny
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      recommendedAsrModelProvider.overrideWithValue(rec),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalTranscriptionModelNotifier', () {
    test('无持久化时默认回退到评分侧 selectedModel（= 推荐档位）', () async {
      final container = await buildContainer(recommended: availableModels[1]);
      addTearDown(container.dispose);

      final model = container.read(localTranscriptionModelProvider);
      expect(model.id, availableModels[1].id);
    });

    test('恢复持久化的档位', () async {
      final container = await buildContainer(
        prefs: {localTranscriptionModelKey: availableModels[2].id},
      );
      addTearDown(container.dispose);

      final model = container.read(localTranscriptionModelProvider);
      expect(model.id, availableModels[2].id);
    });

    test('持久化非法 id 时回退到评分侧默认', () async {
      final container = await buildContainer(
        prefs: {localTranscriptionModelKey: 'not-a-real-model'},
        recommended: availableModels[0],
      );
      addTearDown(container.dispose);

      expect(
        container.read(localTranscriptionModelProvider).id,
        availableModels[0].id,
      );
    });

    test('select 更新状态并持久化，不回写评分设置', () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          recommendedAsrModelProvider.overrideWithValue(availableModels[0]),
        ],
      );
      addTearDown(container.dispose);

      // 初值 = 推荐档位（tiny）。
      expect(
        container.read(localTranscriptionModelProvider).id,
        availableModels[0].id,
      );

      await container
          .read(localTranscriptionModelProvider.notifier)
          .select(availableModels[2]); // small

      expect(
        container.read(localTranscriptionModelProvider).id,
        availableModels[2].id,
      );
      expect(sp.getString(localTranscriptionModelKey), availableModels[2].id);

      // 评分侧 selectedModel 未被改动。
      expect(
        container.read(offlineAsrSettingsProvider).selectedModel.id,
        availableModels[0].id,
      );
    });
  });
}
