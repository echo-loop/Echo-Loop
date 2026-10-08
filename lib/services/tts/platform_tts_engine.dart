/// 平台 TTS 引擎（flutter_tts）
///
/// 统一管线下的本期主引擎实现：
/// - [synthesize] 产文件供缓存复用：iOS/Android 走 flutter_tts `synthesizeToFile`
///   （Android `wav` / iOS `caf`，两端均正确设 voice）；**macOS** 走自家原生通道
///   `top.echo-loop/tts_synth`（flutter_tts 4.2.5 的 macOS `synthesizeToFile` 漏设
///   voice、口音失效，见 §7.15/§7.20），由 `MacosTtsSynthHandler` 用
///   `AVSpeechSynthesizer.write` 正确设 voice 后产 `wav`。
/// - [speakLive] 实时朗读兜底，沿用旧 `TtsService` 的 §7.2 防竞态方案
///   （自管理 Completer + `_started` 过滤 stale cancel），用于 synthesize 失败时降级。
///
/// 不依赖 flutter_tts 的 `awaitSpeakCompletion`（快速 stop→speak 场景会失效，
/// 见 CLAUDE.md §7.2）。method channel FIFO 保证：旧 stop 的 cancel → 新
/// speak 的 start → 新 speak 的 completion。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../app_logger.dart';
import 'tts_engine.dart';

/// 注入工厂签名（测试可替换 FlutterTts）。
typedef FlutterTtsFactory = FlutterTts Function();

/// 判断当前平台合成文件的扩展名。可被测试覆盖。
typedef SynthFormatResolver = String Function();

/// 是否走 macOS 自家原生合成通道（绕过 flutter_tts 在 macOS 漏设 voice）。可被测试覆盖。
typedef NativeMacosSynthResolver = bool Function();

/// macOS 原生合成：把文本按口音合成 wav 到给定**绝对路径**，返回是否成功产出。
/// 默认走 `top.echo-loop/tts_synth` 方法通道；测试可注入 fake 不碰平台。
typedef NativeMacosSynthesize =
    Future<bool> Function({
      required String text,
      required String filePath,
      required String languageTag,
      required double rate,
      required double pitch,
      required double volume,
    });

class PlatformTtsEngine implements TtsEngine {
  PlatformTtsEngine({
    FlutterTtsFactory? ttsFactory,
    SynthFormatResolver? formatResolver,
    NativeMacosSynthResolver? useNativeMacosSynth,
    NativeMacosSynthesize? nativeMacosSynth,
  }) : _tts = (ttsFactory ?? FlutterTts.new)(),
       _formatResolver = formatResolver ?? _defaultFormat,
       _useNativeMacosSynth =
           useNativeMacosSynth ?? _defaultUseNativeMacosSynth,
       _nativeMacosSynth = nativeMacosSynth ?? _defaultNativeMacosSynth;

  final FlutterTts _tts;
  final SynthFormatResolver _formatResolver;

  /// macOS：是否用自家原生合成通道替代 flutter_tts 的 `synthesizeToFile`。
  /// flutter_tts 4.2.5 的 macOS `synthesizeToFile` 不设 voice（`FlutterTtsPlugin.swift`
  /// 仅 `speak` 设 `AVSpeechSynthesisVoice(language:)`），产物永远默认音色、分不出
  /// 英/美音。改走 `MacosTtsSynthHandler`（正确设 voice）→ macOS 也能缓存且口音正确。
  /// 见 §7.15/§7.20。iOS/Android 的 synthesizeToFile 正确设 voice，照常用 flutter_tts。
  final NativeMacosSynthResolver _useNativeMacosSynth;
  final NativeMacosSynthesize _nativeMacosSynth;

  /// 最近一次 [applyConfig] 的配置，供 [synthesize] 在 config 为 null 时取口音等参数。
  TtsSpeechConfig? _lastConfig;

  bool _initialized = false;

  /// 当前 live speak 的完成信号。
  Completer<bool>? _speakCompleter;

  /// 标记当前 live speak 是否已被平台确认开始（过滤 stop 的 stale cancel）。
  bool _started = false;

  /// macOS 原生合成方法通道（与 `MacosTtsSynthHandler` 对接）。
  static const MethodChannel _macosSynthChannel = MethodChannel(
    'top.echo-loop/tts_synth',
  );

  /// 所有平台的文件合成都使用 WAV，供统一播放链路读取。
  static String _defaultFormat() {
    return 'wav';
  }

  /// 仅 macOS 走自家原生合成（iOS/Android 的 flutter_tts synthesizeToFile 正常）。
  static bool _defaultUseNativeMacosSynth() {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  /// 默认 macOS 原生合成：调 `top.echo-loop/tts_synth` 的 `synthesizeToFile`。
  static Future<bool> _defaultNativeMacosSynth({
    required String text,
    required String filePath,
    required String languageTag,
    required double rate,
    required double pitch,
    required double volume,
  }) async {
    final ok = await _macosSynthChannel.invokeMethod<bool>('synthesizeToFile', {
      'text': text,
      'filePath': filePath,
      'languageTag': languageTag,
      'rate': rate,
      'pitch': pitch,
      'volume': volume,
    });
    return ok ?? false;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // live speak 不依赖 awaitSpeakCompletion——快速 stop→speak 场景会失效。
    await _tts.awaitSpeakCompletion(false);
    _tts.setStartHandler(() => _started = true);
    _tts.setCompletionHandler(() => _onLiveDone(true));
    _tts.setCancelHandler(() => _onLiveDone(false));
    _tts.setErrorHandler((_) => _onLiveDone(false));
  }

  @override
  Future<void> applyConfig(TtsSpeechConfig config) async {
    await initialize();
    _lastConfig = config;
    await _tts.setLanguage(config.languageTag);
    await _tts.setSpeechRate(config.rate);
    await _tts.setPitch(config.pitch);
    await _tts.setVolume(config.volume);
    if (config.voiceName != null) {
      // 精确 voice 预留：跨设备 voice name 不稳，失败忽略、退回 language。
      try {
        await _tts.setVoice({
          'name': config.voiceName!,
          'locale': config.languageTag,
        });
      } catch (e) {
        AppLogger.log('PlatformTtsEngine', 'setVoice 失败，退回 language: $e');
      }
    }
  }

  @override
  Future<TtsSynthesisResult?> synthesize(
    String text, {
    required String outputDir,
    required String baseName,
    TtsSpeechConfig? config,
  }) async {
    await initialize();
    // 显式配置优先：按本次 config 设定口音，使产物与缓存键一致——支持「试听非当前
    // 口音」「并发预热不同口音」（见 TtsCoordinator）。为 null 时沿用上次配置。
    if (config != null) await applyConfig(config);
    final format = _formatResolver();
    final fileName = '$baseName.$format';
    final fullPath = '$outputDir/$fileName';

    // macOS：走自家原生合成（flutter_tts 漏设 voice，见字段注释）。
    if (_useNativeMacosSynth()) {
      return _synthesizeViaNativeMacos(text, fullPath, config ?? _lastConfig);
    }

    // iOS/Android：flutter_tts synthesizeToFile（isFullPath=true 直写绝对路径）。
    try {
      // 阻塞直到合成写盘完成（区别于 speak 的实时播放）。
      await _tts.awaitSynthCompletion(true);
      await _tts.synthesizeToFile(text, fullPath, true);
      final file = File(fullPath);
      if (!await file.exists() || await file.length() <= 0) {
        AppLogger.log('PlatformTtsEngine', 'synthesize 产出为空: $fullPath');
        return null;
      }
      return TtsSynthesisResult(filePath: fullPath, format: format);
    } catch (e) {
      // synthesizeToFile 历史上不稳：失败返回 null，由协调器降级 speakLive。
      AppLogger.log('PlatformTtsEngine', 'synthesize 失败: $e');
      return null;
    }
  }

  /// macOS 原生合成到 [fullPath]（wav）。失败/产出为空返回 null，由协调器降级
  /// speakLive（speak 在 macOS 仍能按 setLanguage 选英/美音，口音不丢）。
  Future<TtsSynthesisResult?> _synthesizeViaNativeMacos(
    String text,
    String fullPath,
    TtsSpeechConfig? cfg,
  ) async {
    final c = cfg ?? const TtsSpeechConfig(languageTag: 'en-US');
    try {
      final ok = await _nativeMacosSynth(
        text: text,
        filePath: fullPath,
        languageTag: c.languageTag,
        rate: c.rate,
        pitch: c.pitch,
        volume: c.volume,
      );
      if (!ok) {
        AppLogger.log('PlatformTtsEngine', 'macOS 原生合成失败(返回 false)');
        return null;
      }
      final file = File(fullPath);
      if (!await file.exists() || await file.length() <= 0) {
        AppLogger.log('PlatformTtsEngine', 'macOS 原生合成产出为空: $fullPath');
        return null;
      }
      // macOS 合成扩展名固定 wav（见 _defaultFormat）。
      return TtsSynthesisResult(filePath: fullPath, format: 'wav');
    } catch (e) {
      AppLogger.log('PlatformTtsEngine', 'macOS 原生合成异常: $e');
      return null;
    }
  }

  @override
  Future<bool> speakLive(String text) async {
    await initialize();
    await stop();
    _started = false;
    final completer = Completer<bool>();
    _speakCompleter = completer;
    try {
      await _tts.speak(text);
    } catch (e) {
      AppLogger.log('PlatformTtsEngine', 'speakLive 失败: $e');
      if (!completer.isCompleted) completer.complete(false);
      _speakCompleter = null;
      return false;
    }
    // 兜底超时：flutter_tts 的完成回调在部分设备可能不到达（同 synth 路径的
    // §7.25 缺陷），completer 永挂会拖住上层 speaking 状态。超时按「已播完」解除，
    // 音频本身不受影响。按文本长度粗估、下限 10s。
    final timeoutMs = text.length * 90;
    return completer.future.timeout(
      Duration(milliseconds: timeoutMs < 10000 ? 10000 : timeoutMs),
      onTimeout: () {
        if (_speakCompleter == completer) {
          _started = false;
          _speakCompleter = null;
        }
        return true;
      },
    );
  }

  /// live 完成/取消/出错统一回调。
  void _onLiveDone(bool success) {
    if (!_started) return; // stale callback（来自旧 stop），忽略。
    _started = false;
    final c = _speakCompleter;
    _speakCompleter = null;
    if (c != null && !c.isCompleted) c.complete(success);
  }

  @override
  Future<void> stop() async {
    _started = false;
    final c = _speakCompleter;
    _speakCompleter = null;
    // 立即解除等待的 speak（被抢占），不悬挂调用方。
    if (c != null && !c.isCompleted) c.complete(false);
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    _started = false;
    final c = _speakCompleter;
    _speakCompleter = null;
    if (c != null && !c.isCompleted) c.complete(false);
    await _tts.stop();
  }
}
