import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../services/app_logger.dart';
import '../../services/tts/piper_model_catalog.dart';
import '../../services/tts/tts_engine.dart';
import 'kokoro_model_provider.dart';
import 'piper_model_provider.dart';

/// 当前 ProviderScope 内共享的 TTS 模型安装状态加载门。
///
/// 首次使用时扫描磁盘并缓存结果；后续调用只读取 Kokoro/Piper Provider
/// 的内存状态。扫描期间失效不会清空在途 Future，旧扫描结果也不能回写。
class TtsModelInstallationGate {
  TtsModelInstallationGate(this._read, Ref ref) {
    ref.listen<KokoroModelsState>(kokoroModelProvider, (previous, next) {
      if (_loading || previous == null) return;
      final removed = KokoroModelVariant.values.any(
        (variant) => previous.of(variant).isReady && !next.of(variant).isReady,
      );
      if (removed) invalidate();
    });
    ref.listen<PiperModelsState>(piperModelProvider, (previous, next) {
      if (_loading || previous == null) return;
      final removed = piperVoices.any(
        (voice) => previous.of(voice.id).isReady && !next.of(voice.id).isReady,
      );
      if (removed) invalidate();
    });
  }

  final T Function<T>(ProviderListenable<T>) _read;
  bool _loaded = false;
  int _generation = 0;
  Future<void>? _loadFuture;
  bool _loading = false;

  /// 确保安装状态已加载；并发调用共享同一个扫描 Future。
  Future<void> ensureInstallationStatesLoaded() async {
    while (!_loaded) {
      final future = _loadFuture ??= _load(_generation);
      await future;
    }
  }

  /// 标记磁盘状态可能变化；正在进行的扫描会自然结束并被丢弃。
  void invalidate() {
    _generation++;
    _loaded = false;
  }

  /// 强制重新扫描一次磁盘状态。
  Future<void> refreshNow() {
    invalidate();
    return ensureInstallationStatesLoaded();
  }

  Future<void> _load(int generation) async {
    _loading = true;
    try {
      AppLogger.log(
        'TtsModelGate',
        '开始刷新 Kokoro/Piper 安装状态 generation=$generation',
      );
      bool isCurrent() => generation == _generation;
      await Future.wait([
        _read(
          kokoroModelProvider.notifier,
        ).refreshInstalledStates(shouldCommit: isCurrent),
        _read(
          piperModelProvider.notifier,
        ).refreshInstalledStates(shouldCommit: isCurrent),
      ]);
      if (isCurrent()) {
        _loaded = true;
        AppLogger.log(
          'TtsModelGate',
          '完成刷新 Kokoro/Piper 安装状态 generation=$generation',
        );
      } else {
        AppLogger.log('TtsModelGate', '丢弃过期 TTS 安装状态刷新 generation=$generation');
      }
    } finally {
      _loading = false;
      _loadFuture = null;
    }
  }
}

/// TTS 模型安装状态 Gate Provider；普通 Provider 在当前 ProviderScope 内保持共享实例。
final ttsModelInstallationGateProvider = Provider<TtsModelInstallationGate>(
  (ref) => TtsModelInstallationGate(ref.read, ref),
);
