/// 微软 Edge 在线 TTS 引擎（flutter_edge_tts）。
///
/// 经 Edge「大声朗读」WebSocket 端点合成 MP3 并落盘，由统一管线入缓存后播放；
/// 同一文本二次播放直接命中缓存，无需联网。
///
/// 该端点非微软公开 API（逆向协议），可能随时变更或失效：失败时 [synthesize]
/// 返回 null（不抛出），并经 [EdgeTtsFailureRecorder] 记录失败原因，由上层决定是否
/// 提示用户切换引擎。第三方包只在本文件引用，便于将来替换实现。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:path/path.dart' as p;

import '../app_logger.dart';
import 'edge_voices.dart';
import 'tts_engine.dart';

/// Edge 合成失败原因（决定提示文案）。
enum EdgeTtsFailureKind {
  /// 网络不可达（断网、DNS/TLS 失败、连接超时）。
  network,

  /// 服务端异常（鉴权被拒、协议变更、返回空音频等）。
  service,
}

/// 记录最近一次 Edge 合成结果，供控制器在发音失败后选择提示文案。
///
/// 由引擎写、控制器读；与引擎实例解耦，切换音色重建引擎后仍保留。
class EdgeTtsFailureRecorder {
  EdgeTtsFailureKind? _lastFailure;

  /// 最近一次合成失败原因；最近一次合成成功则为 null。
  EdgeTtsFailureKind? get lastFailure => _lastFailure;

  void recordFailure(EdgeTtsFailureKind kind) => _lastFailure = kind;

  void recordSuccess() => _lastFailure = null;
}

/// 合成一段文本为 MP3 字节。测试可注入 fake，不碰网络。
typedef EdgeSynthesize = Future<Uint8List> Function({
  required String text,
  required String voice,
  required String languageTag,
});

class EdgeTtsEngine implements TtsEngine {
  EdgeTtsEngine({
    EdgeTtsFailureRecorder? failureRecorder,
    EdgeSynthesize? synthesizer,
  }) : _failureRecorder = failureRecorder,
       _synthesizer = synthesizer;

  /// 建连超时。库默认 20s；协调器总超时有限，这里收紧以便失败后还有余量重试一次。
  static const Duration _connectionTimeout = Duration(seconds: 8);

  final EdgeTtsFailureRecorder? _failureRecorder;
  EdgeSynthesize? _synthesizer;

  /// 默认实现持有的客户端（[dispose] 时关闭其 HTTP 客户端与在途 WebSocket）。
  FlutterEdgeTts? _client;

  TtsSpeechConfig? _lastConfig;

  @override
  Future<void> initialize() async {
    // 在线引擎无模型可加载；客户端在首次合成时惰性创建。
  }

  @override
  Future<void> applyConfig(TtsSpeechConfig config) async {
    _lastConfig = config;
  }

  @override
  Future<TtsSynthesisResult?> synthesize(
    String text, {
    required String outputDir,
    required String baseName,
    TtsSpeechConfig? config,
  }) async {
    final effective = config ?? _lastConfig;
    if (effective == null) {
      AppLogger.log('EdgeTts', '✗ 合成跳过：未配置音色');
      return null;
    }
    final voice =
        effective.voiceName ??
        edgeDefaultVoice(
          effective.languageTag == 'en-GB' ? TtsAccent.uk : TtsAccent.us,
        ).id;

    final bytes = await _synthesizeWithRetry(
      text: text,
      voice: voice,
      languageTag: effective.languageTag,
    );
    if (bytes == null) return null;

    final filePath = p.join(outputDir, '$baseName.mp3');
    try {
      await File(filePath).writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (e) {
      AppLogger.log('EdgeTts', '✗ 写入合成文件失败：$e');
      return null;
    }
    _failureRecorder?.recordSuccess();
    return TtsSynthesisResult(filePath: filePath, format: 'mp3');
  }

  /// 合成并在服务端偶发失败时重试一次。
  ///
  /// 实测 Edge 端点约 1/10 的请求会返回空音频，立即重试即成功；网络不可达时重试无益，
  /// 直接失败。
  Future<Uint8List?> _synthesizeWithRetry({
    required String text,
    required String voice,
    required String languageTag,
  }) async {
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final stopwatch = Stopwatch()..start();
      try {
        final bytes = await _synthesize(
          text: text,
          voice: voice,
          languageTag: languageTag,
        );
        AppLogger.log(
          'EdgeTts',
          '合成成功：音色=$voice 文本长度=${text.length} 字节=${bytes.length} '
              '第$attempt次 耗时=${stopwatch.elapsedMilliseconds}ms',
        );
        return bytes;
      } on Exception catch (e) {
        // 第三方包边界：除 EdgeTtsException 外，消息解析异常（如 FormatException）
        // 会经 stream 原样抛出；引擎契约要求失败返回 null 而非抛出。
        final kind = classifyEdgeTtsFailure(e);
        AppLogger.log(
          'EdgeTts',
          '✗ 合成失败：类型=${kind.name} 音色=$voice 第$attempt次 '
              '耗时=${stopwatch.elapsedMilliseconds}ms 错误=$e',
        );
        if (kind == EdgeTtsFailureKind.network || attempt == maxAttempts) {
          _failureRecorder?.recordFailure(kind);
          return null;
        }
      }
    }
    return null;
  }

  Future<Uint8List> _synthesize({
    required String text,
    required String voice,
    required String languageTag,
  }) {
    final synthesizer = _synthesizer ??= _defaultSynthesizer;
    return synthesizer(text: text, voice: voice, languageTag: languageTag);
  }

  Future<Uint8List> _defaultSynthesizer({
    required String text,
    required String voice,
    required String languageTag,
  }) async {
    final client = _client ??= FlutterEdgeTts(
      voice: voice,
      connectionTimeout: _connectionTimeout,
    );
    final result = await client.synthesize(
      text,
      config: EdgeTtsConfig(voice: voice, voiceLocale: languageTag),
    );
    return result.audioBytes;
  }

  /// Edge 无实时朗读通道；合成失败即发音失败，由上层提示用户。
  @override
  Future<bool> speakLive(String text) async => false;

  /// 协调器仅在无在途合成时调用；在途网络请求随 [dispose] 一并关闭。
  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    final client = _client;
    _client = null;
    await client?.close();
  }
}

/// 按异常链判断失败原因：底层是 Socket/TLS/超时/HTTP 连接错误视为网络问题，
/// 其余（升级被拒、空音频、协议解析失败）视为服务端问题。
EdgeTtsFailureKind classifyEdgeTtsFailure(Exception error) {
  Object? cause = error is EdgeTtsException ? error.cause : error;
  while (cause != null) {
    if (cause is SocketException ||
        cause is HandshakeException ||
        cause is TimeoutException ||
        cause is HttpException) {
      return EdgeTtsFailureKind.network;
    }
    cause = cause is EdgeTtsException ? cause.cause : null;
  }
  return EdgeTtsFailureKind.service;
}
