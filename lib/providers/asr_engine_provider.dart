/// ASR 引擎选择和离线模型状态管理 Provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import '../services/asr/sherpa_onnx_engine.dart';

/// ASR 模型管理器 Provider（单例）。
final asrModelManagerProvider = Provider<AsrModelManager>((ref) {
  final manager = AsrModelManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// 离线 ASR 引擎 Provider（单例）。
final offlineAsrEngineProvider = Provider<OfflineAsrEngine>((ref) {
  final engine = SherpaOnnxEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});
