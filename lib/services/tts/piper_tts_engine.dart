/// Piper VITS TTS 引擎（Echo Loop TTS 平衡档，本地 sherpa-onnx 推理）。
///
/// 实现 [TtsEngine] 契约，接入统一 TTS 管线（合成→文件→缓存→播放），上层
/// 协调器/缓存/播放器零改动。Piper **始终产文件**（无实时朗读）：
/// - [synthesize] 跑本地 VITS 推理产出 wav；
/// - [speakLive] 返回 false（不抛异常，让共享协调器在合成失败时优雅静默）。
///
/// 与 Kokoro 引擎的关键差异：每个音色是独立模型，故 [synthesize] 入口同步解析
/// 本次音色 id，向 worker 传入该音色的模型路径（worker 据 voiceId 决定是否重建
/// OfflineTts）。音色经 [TtsSpeechConfig.voiceName] 显式传入，不依赖跨 await 的
/// 环境态 [_config]——使并发的不同音色合成（试听）互不串扰（§7.18）。
library;

import 'dart:io' show Platform;

import 'package:path/path.dart' as p;

import '../app_logger.dart';
import 'piper_model_manager.dart' show PiperModelPaths;
import 'piper_synthesizer.dart';
import 'piper_model_catalog.dart';
import 'tts_engine.dart';

/// Piper 推理线程数（纯 CPU）。按设备 CPU 核心数分档（与离线 ASR 同策略，
/// 见 `AsrModelConfig.recommendedThreads`）：
/// cores ≥ 8 → 6 线程，cores ≥ 6 → 4 线程，其他 → 2 线程。不占满 CPU。
int _defaultPiperNumThreads() {
  final cores = Platform.numberOfProcessors;
  if (cores >= 8) return 6;
  if (cores >= 6) return 4;
  return 2;
}

class PiperTtsEngine implements TtsEngine {
  /// 按音色 id 解析模型路径（通常读 `PiperModelManager.piperConfigPaths`）。
  final Future<PiperModelPaths> Function(String voiceId) _resolvePaths;

  /// 原生合成器工厂（默认 isolate worker；测试注入 fake）。
  final PiperNativeSynthesizer Function() _synthesizerFactory;

  final int _numThreads;

  PiperNativeSynthesizer? _synth;
  TtsSpeechConfig? _config;
  bool _initialized = false;

  PiperTtsEngine({
    required Future<PiperModelPaths> Function(String voiceId) resolvePaths,
    PiperNativeSynthesizer Function()? synthesizerFactory,
    int? numThreads,
  }) : _resolvePaths = resolvePaths,
       _synthesizerFactory =
           synthesizerFactory ?? (() => IsolatePiperSynthesizer()),
       _numThreads = numThreads ?? _defaultPiperNumThreads();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    // worker 不预加载模型（模型按音色懒加载），故 init 只起 isolate。
    final synth = _synthesizerFactory();
    await synth.init(numThreads: _numThreads);
    _synth = synth;
    _initialized = true;
  }

  @override
  Future<void> applyConfig(TtsSpeechConfig config) async {
    _config = config;
  }

  @override
  Future<TtsSynthesisResult?> synthesize(
    String text, {
    required String outputDir,
    required String baseName,
    TtsSpeechConfig? config,
  }) async {
    try {
      await initialize();
      final synth = _synth;
      if (synth == null) return null;

      // 入口同步解析音色 id（显式 config 优先），不依赖跨 await 的环境态 [_config]。
      final effective = config ?? _config;
      final voiceId = _voiceIdFor(effective);
      final paths = await _resolvePaths(voiceId);

      final outputPath = p.join(outputDir, '$baseName.wav');
      final sampleRate = await synth.synthesize(
        paths: paths,
        voiceId: voiceId,
        text: text,
        speed: (effective?.speed ?? 1.0).clamp(0.5, 2.0).toDouble(),
        outputPath: outputPath,
      );
      if (sampleRate == null) {
        AppLogger.log(
          'PiperTts',
          '✗ synthesize 返回 null（worker 失败）voice=$voiceId',
        );
        return null;
      }
      AppLogger.log(
        'PiperTts',
        '✓ synthesize ok voice=$voiceId sr=$sampleRate path=$outputPath',
      );
      return TtsSynthesisResult(
        filePath: outputPath,
        format: 'wav',
        sampleRate: sampleRate,
      );
    } catch (e, st) {
      // 合成失败不抛，交协调器处理（Piper 无实时兜底）；但必须落日志便于定位。
      AppLogger.log('PiperTts', '✗ synthesize 异常: $e\n$st');
      return null;
    }
  }

  @override
  Future<bool> speakLive(String text) async {
    // Piper 始终产文件；合成失败时静默（返回 false），不抛异常打断共享管线。
    return false;
  }

  @override
  Future<void> stop() async {
    // 合成为一次性请求，无持续朗读可停；播放停止由协调器/播放器负责。
  }

  @override
  Future<void> dispose() async {
    await _synth?.dispose();
    _synth = null;
    _initialized = false;
    _config = null;
  }

  /// 解析本次合成的音色 id：显式 voiceName 合法则用之，否则按语言标签回退该口音默认。
  String _voiceIdFor(TtsSpeechConfig? config) {
    final name = config?.voiceName;
    if (name != null && piperVoiceById(name) != null) return name;
    final accent = config?.languageTag == 'en-GB' ? TtsAccent.uk : TtsAccent.us;
    return piperDefaultVoice(accent).id;
  }
}
