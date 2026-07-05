/// 本地转录（离线字幕生成）的 Whisper 档位偏好 Provider。
///
/// 与评分侧 [offlineAsrSettingsProvider] 的 `selectedModel` **相互独立**：
/// 转录可选更高精度档位（如 small）而不影响评分模型，二者互不回写。
/// 独立持久化到 SharedPreferences。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart';
import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import 'offline_asr_settings_provider.dart';

/// 转录档位偏好持久化 key。
const localTranscriptionModelKey = 'local_transcription_model_id';

/// 本地转录选用的 Whisper 档位。
class LocalTranscriptionModelNotifier extends Notifier<AsrModelInfo> {
  @override
  AsrModelInfo build() {
    // 用 read 而非 watch：不随评分侧 selectedModel 变化而重建，保持独立。
    final fallback = ref.read(offlineAsrSettingsProvider).selectedModel;
    final prefs = ref.read(sharedPreferencesProvider);
    final persistedId = prefs.getString(localTranscriptionModelKey);
    if (persistedId == null) return fallback;
    // 无持久化 → 取评分侧当前档位（其本身默认 = 设备推荐档位）作为一次性合理初值。
    return availableModels.firstWhere(
      (m) => m.id == persistedId,
      orElse: () => fallback,
    );
  }

  /// 选择转录档位并持久化。不修改评分设置。
  Future<void> select(AsrModelInfo model) async {
    if (state.id == model.id) return;
    state = model;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(localTranscriptionModelKey, model.id);
  }
}

/// 本地转录档位偏好 Provider（keepAlive 全局单例）。
final localTranscriptionModelProvider =
    NotifierProvider<LocalTranscriptionModelNotifier, AsrModelInfo>(
      LocalTranscriptionModelNotifier.new,
    );
