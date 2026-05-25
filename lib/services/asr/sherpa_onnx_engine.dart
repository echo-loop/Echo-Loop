/// sherpa-onnx 离线 ASR 引擎实现。
///
/// 通过 sherpa-onnx FFI 绑定加载 Moonshine 或 Whisper ONNX 模型。
/// Recognizer 在常驻 Worker Isolate 内创建并保持，
/// [transcribe] 通过消息传递将推理委托给后台 Isolate，不阻塞 UI 线程。
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'audio_file_reader.dart';
import '../app_logger.dart';
import 'offline_asr_engine.dart';

/// sherpa-onnx 离线 ASR 引擎。
///
/// [initialize] 时在后台 Isolate 内加载模型（耗时数秒），
/// 之后 [transcribe] 通过消息传递在后台执行推理，不阻塞主线程。
/// 切换模型需先 [dispose] 再重新 [initialize]。
class SherpaOnnxEngine implements OfflineAsrEngine {
  AsrModelConfig? _config;
  _AsrWorker? _worker;

  @override
  String get name => 'sherpa-onnx';

  @override
  bool get isReady => _worker != null;

  @override
  AsrModelInfo? get currentModel => _config?.model;

  @override
  Future<void> initialize(AsrModelConfig config) async {
    // 如果已加载相同模型且 provider 相同，跳过。
    if (_config?.model.id == config.model.id &&
        _config?.provider == config.provider &&
        _worker != null) {
      AppLogger.log(
        'ASREngine',
        '⏭ initialize skipped model=${config.model.id} provider=${config.provider ?? 'auto'}',
      );
      return;
    }

    // 先释放旧 Worker Isolate。
    AppLogger.log(
      'ASREngine',
      '┌ initialize model=${config.model.id} '
          'dir=${config.modelDir} provider=${config.provider ?? 'auto'} '
          'threads=${config.numThreads}',
    );
    await dispose();

    final stopwatch = Stopwatch()..start();
    _worker = await _AsrWorker.spawn(config);
    stopwatch.stop();
    _config = config;
    AppLogger.log(
      'ASREngine',
      '└ initialize done model=${config.model.id} '
          'provider=${_config?.provider ?? 'auto'} '
          'elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
  }

  @override
  Future<AsrResult> transcribe(String wavPath) async {
    final worker = _worker;
    if (worker == null) {
      throw StateError('Engine not initialized. Call initialize() first.');
    }

    AppLogger.log(
      'ASREngine',
      '┌ transcribe wavPath=$wavPath model=${_config?.model.id ?? '(null)'}',
    );
    final result = await worker.transcribe(wavPath);
    AppLogger.log(
      'ASREngine',
      '└ transcribe done textLen=${result.text.trim().length} '
          'elapsed=${result.inferenceTime.inMilliseconds}ms',
    );
    return result;
  }

  @override
  Future<void> dispose() async {
    if (_worker != null) {
      AppLogger.log(
        'ASREngine',
        '● dispose model=${_config?.model.id ?? '(null)'} provider=${_config?.provider ?? 'auto'}',
      );
    }
    await _worker?.dispose();
    _worker = null;
    _config = null;
  }
}

// ---------------------------------------------------------------------------
// Worker Isolate — 在后台持有 Recognizer 并处理转录请求
// ---------------------------------------------------------------------------

/// 常驻后台 Isolate，持有 sherpa-onnx Recognizer。
///
/// 主线程通过 [SendPort] 发送转录请求，
/// Worker 在后台执行文件读取 + FFI 推理并返回结果。
class _AsrWorker {
  final Isolate _isolate;
  final SendPort _commandPort;

  _AsrWorker._(this._isolate, this._commandPort);

  /// 创建 Worker Isolate 并在其中初始化 Recognizer。
  ///
  /// 初始化失败时抛出 [StateError]。
  static Future<_AsrWorker> spawn(AsrModelConfig config) async {
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _InitPayload(sendPort: initPort.sendPort, config: config),
    );

    final response = await initPort.first;
    initPort.close();

    if (response is SendPort) {
      return _AsrWorker._(isolate, response);
    }

    // 初始化失败，清理 Isolate。
    isolate.kill(priority: Isolate.immediate);
    throw StateError('ASR Worker init failed: $response');
  }

  /// 发送转录请求到 Worker，等待结果返回。
  Future<AsrResult> transcribe(String wavPath) async {
    final replyPort = ReceivePort();
    _commandPort.send(
      _TranscribeRequest(wavPath: wavPath, replyPort: replyPort.sendPort),
    );

    final response = await replyPort.first;
    replyPort.close();

    if (response is _TranscribeResponse) {
      return AsrResult(
        text: response.text,
        inferenceTime: Duration(milliseconds: response.inferenceTimeMs),
      );
    }
    throw StateError('Transcription failed: $response');
  }

  /// 释放 Recognizer 并关闭 Worker Isolate。
  Future<void> dispose() async {
    final replyPort = ReceivePort();
    _commandPort.send(_DisposeRequest(replyPort: replyPort.sendPort));
    await replyPort.first;
    replyPort.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

// ---------------------------------------------------------------------------
// Isolate 消息类型
// ---------------------------------------------------------------------------

/// Worker 启动参数。
class _InitPayload {
  final SendPort sendPort;
  final AsrModelConfig config;
  const _InitPayload({required this.sendPort, required this.config});
}

/// 转录请求（主线程 → Worker）。
class _TranscribeRequest {
  final String wavPath;
  final SendPort replyPort;
  const _TranscribeRequest({required this.wavPath, required this.replyPort});
}

/// 转录结果（Worker → 主线程）。
class _TranscribeResponse {
  final String text;
  final int inferenceTimeMs;
  const _TranscribeResponse({
    required this.text,
    required this.inferenceTimeMs,
  });
}

/// 释放请求（主线程 → Worker）。
class _DisposeRequest {
  final SendPort replyPort;
  const _DisposeRequest({required this.replyPort});
}

// ---------------------------------------------------------------------------
// Isolate 入口点
// ---------------------------------------------------------------------------

/// Worker Isolate 入口函数。
///
/// 在 Isolate 内初始化 sherpa-onnx FFI 绑定、创建 Recognizer，
/// 可选创建 VAD（用于转录前裁剪静音段），
/// 然后循环处理转录请求直到收到释放指令。
void _isolateEntryPoint(_InitPayload init) {
  try {
    sherpa.initBindings();
    final recognizer = _createRecognizer(init.config);
    final vad = _createVad(init.config.vadModelPath);

    final commandPort = ReceivePort();
    // 握手：把 commandPort 发回主线程。
    init.sendPort.send(commandPort.sendPort);

    commandPort.listen((message) {
      if (message is _TranscribeRequest) {
        _handleTranscribe(recognizer, vad, message);
      } else if (message is _DisposeRequest) {
        vad?.free();
        recognizer.free();
        message.replyPort.send(null);
        commandPort.close();
      }
    });
  } catch (e) {
    // 初始化失败，把错误信息发回主线程。
    init.sendPort.send('Init failed: $e');
  }
}

/// 创建 Silero VAD 实例（可选）。
///
/// [vadModelPath] 为 null 时返回 null，转录流程跳过静音裁剪。
sherpa.VoiceActivityDetector? _createVad(String? vadModelPath) {
  if (vadModelPath == null) return null;
  final config = sherpa.VadModelConfig(
    sileroVad: sherpa.SileroVadModelConfig(
      model: vadModelPath,
      minSilenceDuration: 0.25,
      minSpeechDuration: 0.5,
      maxSpeechDuration: 30.0,
    ),
    sampleRate: 16000,
    numThreads: 1,
    provider: 'cpu',
    debug: false,
  );
  return sherpa.VoiceActivityDetector(config: config, bufferSizeInSeconds: 600);
}

/// 用 VAD 提取语音段列表。
///
/// 按 windowSize（默认 512）分块喂入 VAD，与官方示例一致。
/// 每个 segment ≤ maxSpeechDuration（30s），可直接送入 whisper。
/// 返回 null 表示无语音段（全静音）。
List<Float32List>? _extractSpeechWithVad(
  sherpa.VoiceActivityDetector vad,
  Float32List samples16k,
) {
  final windowSize = vad.config.sileroVad.windowSize;
  final numIter = samples16k.length ~/ windowSize;

  final segments = <Float32List>[];

  // 按 windowSize 分块喂入，每次检查是否检测到语音段。
  for (var i = 0; i < numIter; i++) {
    final start = i * windowSize;
    vad.acceptWaveform(
      Float32List.sublistView(samples16k, start, start + windowSize),
    );
    while (!vad.isEmpty()) {
      segments.add(vad.front().samples);
      vad.pop();
    }
  }

  // 处理尾部不足一个 window 的残余。
  vad.flush();
  while (!vad.isEmpty()) {
    segments.add(vad.front().samples);
    vad.pop();
  }
  vad.reset();

  return segments.isEmpty ? null : segments;
}

/// VAD 目标采样率。
const _vadSampleRate = 16000;

/// 将 VAD 语音段合并为 ≤ maxSamples 的 chunk。
///
/// 相邻小段累积合并，当加入下一段会超过上限时切出新 chunk。
List<Float32List> _mergeSegments(List<Float32List> segments, int maxSamples) {
  final chunks = <Float32List>[];
  var pending = <Float32List>[];
  var pendingLen = 0;

  for (final seg in segments) {
    if (pendingLen + seg.length > maxSamples && pending.isNotEmpty) {
      chunks.add(_concat(pending, pendingLen));
      pending = [];
      pendingLen = 0;
    }
    pending.add(seg);
    pendingLen += seg.length;
  }
  if (pending.isNotEmpty) {
    chunks.add(_concat(pending, pendingLen));
  }
  return chunks;
}

/// 拼接多个 Float32List 为一个。
Float32List _concat(List<Float32List> parts, int totalLen) {
  if (parts.length == 1) return parts.first;
  final merged = Float32List(totalLen);
  var offset = 0;
  for (final p in parts) {
    merged.setAll(offset, p);
    offset += p.length;
  }
  return merged;
}

/// 在 Worker 内执行转录：读取音频文件 → VAD 裁静音 → FFI 推理 → 返回结果。
void _handleTranscribe(
  sherpa.OfflineRecognizer recognizer,
  sherpa.VoiceActivityDetector? vad,
  _TranscribeRequest request,
) {
  try {
    final audioData = readAudioFile(request.wavPath);
    if (audioData.samples.isEmpty) {
      request.replyPort.send(
        const _TranscribeResponse(text: '', inferenceTimeMs: 0),
      );
      return;
    }

    // VAD 裁剪静音段（需要 16kHz 输入）。
    if (vad != null && audioData.sampleRate >= _vadSampleRate) {
      final samples16k = audioData.sampleRate == _vadSampleRate
          ? audioData.samples
          : downsample(audioData.samples, audioData.sampleRate, _vadSampleRate);
      final beforeSec = samples16k.length / _vadSampleRate;
      // 诊断：计算 RMS 确认输入音频有效。
      var sumSq = 0.0;
      for (final s in samples16k) {
        sumSq += s * s;
      }
      final rms = (sumSq / samples16k.length);
      // rms 未开根号，直接用平方均值即可判断量级。
      AppLogger.log(
        'ASREngine',
        'VAD input: ${beforeSec.toStringAsFixed(1)}s, '
            'rms²=${rms.toStringAsExponential(2)}, '
            'max=${samples16k.reduce((a, b) => a.abs() > b.abs() ? a : b).toStringAsFixed(4)}',
      );
      final segments = _extractSpeechWithVad(vad, samples16k);
      if (segments == null) {
        AppLogger.log(
          'ASREngine',
          'VAD: ${beforeSec.toStringAsFixed(1)}s → 0.0s (全静音)',
        );
        request.replyPort.send(
          const _TranscribeResponse(text: '', inferenceTimeMs: 0),
        );
        return;
      }
      final totalSpeechSamples = segments.fold<int>(
        0,
        (s, seg) => s + seg.length,
      );
      final afterSec = totalSpeechSamples / _vadSampleRate;
      AppLogger.log(
        'ASREngine',
        'VAD: ${beforeSec.toStringAsFixed(1)}s → ${afterSec.toStringAsFixed(1)}s (${segments.length} segments)',
      );

      // 合并小段为 ≤30s 的 chunk，减少 whisper 调用次数。
      final chunks = _mergeSegments(segments, 30 * _vadSampleRate);
      AppLogger.log(
        'ASREngine',
        '│ ${segments.length} segments → ${chunks.length} chunks',
      );

      final stopwatch = Stopwatch()..start();
      final texts = <String>[];
      for (final chunk in chunks) {
        final stream = recognizer.createStream();
        stream.acceptWaveform(samples: chunk, sampleRate: _vadSampleRate);
        recognizer.decode(stream);
        final t = recognizer.getResult(stream).text.trim();
        if (t.isNotEmpty) texts.add(t);
        stream.free();
      }
      stopwatch.stop();

      request.replyPort.send(
        _TranscribeResponse(
          text: texts.join(' '),
          inferenceTimeMs: stopwatch.elapsedMilliseconds,
        ),
      );
    } else {
      // 无 VAD，直接转录（可能被 whisper 截断到 30s）。
      final stopwatch = Stopwatch()..start();
      final stream = recognizer.createStream();
      stream.acceptWaveform(
        samples: audioData.samples,
        sampleRate: audioData.sampleRate,
      );
      recognizer.decode(stream);
      final text = recognizer.getResult(stream).text.trim();
      stopwatch.stop();
      stream.free();

      request.replyPort.send(
        _TranscribeResponse(
          text: text,
          inferenceTimeMs: stopwatch.elapsedMilliseconds,
        ),
      );
    }
  } catch (e) {
    request.replyPort.send('Transcribe failed: $e');
  }
}

// ---------------------------------------------------------------------------
// sherpa-onnx 配置构建
// ---------------------------------------------------------------------------

/// 创建 Recognizer，使用指定 provider，失败时回退到 CPU。
sherpa.OfflineRecognizer _createRecognizer(AsrModelConfig config) {
  final requestedProvider = config.provider ?? _platformProvider();
  final primaryConfig = _buildConfig(
    modelDir: config.modelDir,
    modelType: config.model.type,
    modelId: config.model.id,
    numThreads: config.numThreads,
    provider: requestedProvider,
  );

  try {
    return sherpa.OfflineRecognizer(primaryConfig);
  } catch (e) {
    if (requestedProvider == 'cpu') rethrow;
    // 硬件加速失败，回退到 CPU。
    final cpuConfig = _buildConfig(
      modelDir: config.modelDir,
      modelType: config.model.type,
      modelId: config.model.id,
      numThreads: config.numThreads,
      provider: 'cpu',
    );
    return sherpa.OfflineRecognizer(cpuConfig);
  }
}

/// 获取当前平台的推理加速 provider。
///
/// iOS/macOS：CoreML 对 int8 量化模型反而更慢，使用 CPU。
/// Android：尝试 NNAPI（GPU/DSP/NPU 加速），失败时 fallback 到 CPU。
String _platformProvider() {
  if (Platform.isAndroid) return 'nnapi';
  return 'cpu';
}

/// 根据模型类型和目录构建 sherpa-onnx 配置。
sherpa.OfflineRecognizerConfig _buildConfig({
  required String modelDir,
  required AsrModelType modelType,
  required String modelId,
  required int numThreads,
  String? provider,
}) {
  final p = provider ?? _platformProvider();
  switch (modelType) {
    case AsrModelType.moonshine:
      return _buildMoonshineConfig(
        modelDir: modelDir,
        numThreads: numThreads,
        provider: p,
      );
    case AsrModelType.whisper:
      return _buildWhisperConfig(
        modelDir: modelDir,
        modelId: modelId,
        numThreads: numThreads,
        provider: p,
      );
  }
}

/// 构建 Moonshine 模型配置。
sherpa.OfflineRecognizerConfig _buildMoonshineConfig({
  required String modelDir,
  required int numThreads,
  required String provider,
}) {
  final moonshine = sherpa.OfflineMoonshineModelConfig(
    preprocessor: p.join(modelDir, 'preprocess.onnx'),
    encoder: p.join(modelDir, 'encode.int8.onnx'),
    uncachedDecoder: p.join(modelDir, 'uncached_decode.int8.onnx'),
    cachedDecoder: p.join(modelDir, 'cached_decode.int8.onnx'),
  );

  final model = sherpa.OfflineModelConfig(
    moonshine: moonshine,
    tokens: p.join(modelDir, 'tokens.txt'),
    numThreads: numThreads,
    debug: false,
    provider: provider,
  );

  return sherpa.OfflineRecognizerConfig(model: model);
}

/// 构建 Whisper 模型配置。
sherpa.OfflineRecognizerConfig _buildWhisperConfig({
  required String modelDir,
  required String modelId,
  required int numThreads,
  required String provider,
}) {
  final prefix = _whisperFilePrefix(modelId);

  final whisper = sherpa.OfflineWhisperModelConfig(
    encoder: p.join(modelDir, '$prefix-encoder.int8.onnx'),
    decoder: p.join(modelDir, '$prefix-decoder.int8.onnx'),
    language: 'en',
    task: 'transcribe',
  );

  final model = sherpa.OfflineModelConfig(
    whisper: whisper,
    tokens: p.join(modelDir, '$prefix-tokens.txt'),
    modelType: 'whisper',
    numThreads: numThreads,
    debug: false,
    provider: provider,
  );

  return sherpa.OfflineRecognizerConfig(model: model);
}

/// 从 modelId 提取 Whisper 文件名前缀。
String _whisperFilePrefix(String modelId) {
  if (modelId.contains('tiny')) return 'tiny.en';
  if (modelId.contains('base')) return 'base.en';
  if (modelId.contains('small')) return 'small.en';
  throw ArgumentError('Unknown Whisper model: $modelId');
}
