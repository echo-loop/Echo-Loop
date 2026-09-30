/// Echo Loop TTS 引擎（本地 Kokoro 82M，sherpa-onnx 推理）。
///
/// 实现 [TtsEngine] 契约，接入统一 TTS 管线（合成→文件→缓存→播放），上层
/// 协调器/缓存/播放器零改动。Kokoro **始终产文件**（无实时朗读）：
/// - [synthesize] 跑本地神经网络推理产出 wav；
/// - [speakLive] 返回 false（不抛异常，让共享协调器在合成失败时优雅静默）。
///
/// 原生推理委托给可注入的 [KokoroNativeSynthesizer]（默认 isolate worker），
/// 故本类逻辑（sid 解析、文件命名、降级）可纯单测，不依赖 FFI/平台。
library;

import 'dart:io' show Platform;

import 'package:path/path.dart' as p;

import '../app_logger.dart';
import 'kokoro_model_manager.dart' show KokoroModelPaths;
import 'kokoro_synthesizer.dart';
import 'kokoro_voices.dart';
import 'tts_engine.dart';

/// Kokoro 推理线程数（纯 CPU）。
///
/// 瓶颈在 `OfflineTts.generate` 的 CPU 推理（实测 RTF≈3），线程数直接影响延迟。
/// 按设备 CPU 核心数分档（与离线 ASR 同策略，见 `AsrModelConfig.recommendedThreads`）：
/// cores ≥ 8 → 6 线程，cores ≥ 6 → 4 线程，其他 → 2 线程。
/// 不占满 CPU，留余量给 UI 和其他任务。
int _defaultKokoroNumThreads() {
  final cores = Platform.numberOfProcessors;
  if (cores >= 8) return 6;
  if (cores >= 6) return 4;
  return 2;
}

class KokoroTtsEngine implements TtsEngine {
  /// 解析模型文件路径（通常读 `KokoroModelManager.kokoroConfigPaths`）。
  final Future<KokoroModelPaths> Function() _resolvePaths;

  /// 原生合成器工厂（默认 isolate worker；测试注入 fake）。
  final KokoroNativeSynthesizer Function() _synthesizerFactory;

  final int _numThreads;

  KokoroNativeSynthesizer? _synth;
  TtsSpeechConfig? _config;
  bool _initialized = false;

  KokoroTtsEngine({
    required Future<KokoroModelPaths> Function() resolvePaths,
    KokoroNativeSynthesizer Function()? synthesizerFactory,
    int? numThreads,
  }) : _resolvePaths = resolvePaths,
       _synthesizerFactory =
           synthesizerFactory ?? (() => IsolateKokoroSynthesizer()),
       _numThreads = numThreads ?? _defaultKokoroNumThreads();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    final paths = await _resolvePaths();
    final synth = _synthesizerFactory();
    await synth.init(paths, numThreads: _numThreads);
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

      // 优先用本次显式配置解析音色 sid（同步、入口处即定），不依赖跨 await 的
      // 引擎环境态 [_config]——使并发的不同音色合成（试听/预热）互不串扰。
      final effective = config ?? _config;
      // v1.1-zh 的英文/中文发音人在同一模型内；当文本含 CJK 且调用方给的是
      // 英文音色时，自动切到中文默认音色，避免中文被英文音素器读成乱码。
      final configuredVoiceId = effective?.voiceName;
      final hasCjk = RegExp(r'[\u3400-\u9fff]').hasMatch(text);
      final configuredVoice = configuredVoiceId == null
          ? null
          : voiceById(configuredVoiceId);
      final voiceId = hasCjk && configuredVoice?.language != TtsLanguage.chinese
          ? kokoroDefaultVoiceZh
          : configuredVoiceId;
      final sid = sidForVoiceId(
        voiceId,
        fallbackAccent: _accentFromLanguageTag(effective?.languageTag),
      );
      final outputPath = p.join(outputDir, '$baseName.wav');
      final sampleRate = await synth.synthesize(
        text: text,
        sid: sid,
        // sherpa 的 speed 是倍率，1.0 = 正常；用户设置范围为 0.5..2.0。
        speed: (effective?.speed ?? 1.0).clamp(0.5, 2.0).toDouble(),
        outputPath: outputPath,
      );
      if (sampleRate == null) {
        AppLogger.log(
          'KokoroTts',
          '✗ synthesize 返回 null（worker 失败）text="$text"',
        );
        return null;
      }
      AppLogger.log(
        'KokoroTts',
        '✓ synthesize ok sid=$sid sr=$sampleRate path=$outputPath',
      );
      return TtsSynthesisResult(
        filePath: outputPath,
        format: 'wav',
        sampleRate: sampleRate,
      );
    } catch (e, st) {
      // 合成失败不抛，交协调器处理（Kokoro 无实时兜底）；但必须落日志便于定位。
      AppLogger.log('KokoroTts', '✗ synthesize 异常: $e\n$st');
      return null;
    }
  }

  @override
  Future<bool> speakLive(String text) async {
    // Kokoro 始终产文件；合成失败时静默（返回 false），不抛异常打断共享管线。
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

  /// 由语言标签推导口音（`en-GB`→英音，其余→美音），决定缺省音色。
  TtsAccent _accentFromLanguageTag(String? tag) =>
      tag == 'en-GB' ? TtsAccent.uk : TtsAccent.us;
}
