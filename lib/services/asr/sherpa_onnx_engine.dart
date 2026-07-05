/// sherpa-onnx 离线 ASR 引擎实现。
///
/// 通过 sherpa-onnx FFI 绑定加载 Moonshine 或 Whisper ONNX 模型。
/// Recognizer 在常驻 Worker Isolate 内创建并保持，
/// [transcribe] 通过消息传递将推理委托给后台 Isolate，不阻塞 UI 线程。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' show Utf8Pointer;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
// 实现层 import：sherpa_onnx 未导出 SherpaOnnxBindings，但 whisper 的 segment
// 时间戳（segment_timestamps/…）只在原生 result JSON 里，公开 getResult() 丢弃了它们。
// 直接调 package 已解析的 getOfflineStreamResultAsJson 取 raw JSON（比自建
// DynamicLibrary 查符号更跨平台稳，复用 package 的按平台加载）。已 pin ^1.12.36。
// ignore: implementation_imports
import 'package:sherpa_onnx/src/sherpa_onnx_bindings.dart'
    show SherpaOnnxBindings;

import 'audio_file_reader.dart';
import '../app_logger.dart';
import '../../utils/app_data_dir.dart';
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
  Future<List<AsrSegment>> transcribeSegments(
    String wavPath, {
    void Function(double progress)? onProgress,
  }) async {
    final worker = _worker;
    if (worker == null) {
      throw StateError('Engine not initialized. Call initialize() first.');
    }

    AppLogger.log(
      'ASREngine',
      '┌ transcribeSegments wavPath=$wavPath model=${_config?.model.id ?? '(null)'}',
    );
    final segments = await worker.transcribeSegments(
      wavPath,
      onProgress: onProgress,
    );
    AppLogger.log(
      'ASREngine',
      '└ transcribeSegments done segments=${segments.length}',
    );
    return segments;
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
    // 主 isolate 解析路径后传入 Worker：日志落盘 + 崩溃面包屑。
    final logFilePath = await appLogFilePath();
    final crashMarkerPath = await asrCrashMarkerPath();

    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _InitPayload(
        sendPort: initPort.sendPort,
        config: config,
        logFilePath: logFilePath,
        crashMarkerPath: crashMarkerPath,
      ),
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

  /// 发送分段转录请求到 Worker，逐段解码并回传进度与结果。
  ///
  /// replyPort 上先到达若干 [_SegmentsProgress]（透传给 [onProgress]），
  /// 最后到达 [_TranscribeSegmentsResponse]（完成）或错误字符串（失败）。
  Future<List<AsrSegment>> transcribeSegments(
    String wavPath, {
    void Function(double progress)? onProgress,
  }) {
    final replyPort = ReceivePort();
    final completer = Completer<List<AsrSegment>>();

    replyPort.listen((message) {
      if (message is _SegmentsProgress) {
        onProgress?.call(
          message.total == 0 ? 1.0 : message.done / message.total,
        );
        return;
      }
      replyPort.close();
      if (message is _TranscribeSegmentsResponse) {
        completer.complete(
          message.segments
              .map(
                (s) => AsrSegment(
                  text: s.text,
                  start: Duration(milliseconds: s.startMs),
                  end: Duration(milliseconds: s.endMs),
                ),
              )
              .toList(),
        );
      } else {
        completer.completeError(StateError('Transcription failed: $message'));
      }
    });

    _commandPort.send(
      _TranscribeSegmentsRequest(
        wavPath: wavPath,
        replyPort: replyPort.sendPort,
      ),
    );
    return completer.future;
  }

  /// 释放 Recognizer 并关闭 Worker Isolate。
  ///
  /// 优先请求 worker 优雅释放 native 资源（free recognizer/vad）；worker 空闲时
  /// 立即完成。若 worker 正阻塞在推理循环中（如用户取消转录），其事件循环无法
  /// 响应 [_DisposeRequest]，则超时后强制 kill isolate（native 资源随进程回收，
  /// 取消属低频操作，可接受），避免 dispose 挂死拖住调用方的清理逻辑。
  Future<void> dispose() async {
    final replyPort = ReceivePort();
    _commandPort.send(_DisposeRequest(replyPort: replyPort.sendPort));
    try {
      await replyPort.first.timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // 超时（worker 忙于阻塞推理）→ 强制 kill。
    }
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

  /// 落盘日志文件路径（Worker isolate 内直接追加，静态字段不跨 isolate 共享）。
  final String? logFilePath;

  /// 崩溃面包屑文件路径（native 推理前同步写、成功后清除）。
  final String? crashMarkerPath;

  const _InitPayload({
    required this.sendPort,
    required this.config,
    this.logFilePath,
    this.crashMarkerPath,
  });
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

/// 分段转录请求（主线程 → Worker）。
class _TranscribeSegmentsRequest {
  final String wavPath;
  final SendPort replyPort;
  const _TranscribeSegmentsRequest({
    required this.wavPath,
    required this.replyPort,
  });
}

/// 分段转录进度（Worker → 主线程，可多次）。
class _SegmentsProgress {
  final int done;
  final int total;
  const _SegmentsProgress({required this.done, required this.total});
}

/// 单个分段载荷（跨 isolate 传递用原始类型）。
class _SegmentPayload {
  final String text;
  final int startMs;
  final int endMs;
  const _SegmentPayload({
    required this.text,
    required this.startMs,
    required this.endMs,
  });
}

/// 分段转录结果（Worker → 主线程）。
class _TranscribeSegmentsResponse {
  final List<_SegmentPayload> segments;
  const _TranscribeSegmentsResponse({required this.segments});
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
  final logFilePath = init.logFilePath;
  final crashMarkerPath = init.crashMarkerPath;
  // 诊断标识：写入崩溃面包屑，便于区分崩在哪个模型/provider。
  final diag =
      'model=${init.config.model.id} '
      'provider=${init.config.provider ?? _platformProvider()}';
  try {
    sherpa.initBindings();
    final recognizer = _createRecognizer(init.config);
    final vad = _createVad(init.config.vadModelPath);

    final commandPort = ReceivePort();
    // 握手：把 commandPort 发回主线程。
    init.sendPort.send(commandPort.sendPort);

    commandPort.listen((message) {
      if (message is _TranscribeRequest) {
        _handleTranscribe(
          recognizer,
          vad,
          message,
          logFilePath: logFilePath,
          crashMarkerPath: crashMarkerPath,
          diag: diag,
        );
      } else if (message is _TranscribeSegmentsRequest) {
        // 转录（字幕生成）不使用 VAD：whisper 自驱滑窗 + 原生 segment 时间戳。
        _handleTranscribeSegments(
          recognizer,
          message,
          logFilePath: logFilePath,
          crashMarkerPath: crashMarkerPath,
          diag: diag,
        );
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

/// Worker isolate 内的日志：print + 直接追加到落盘文件（与主 isolate 同格式）。
///
/// 静态 [AppLogger] 字段不跨 isolate 共享，故 Worker 必须自行写文件，
/// 这样 ASR 推理日志才能进入导出的日志（此前是黑洞）。
void _workerLog(String? logFilePath, String tag, String message) {
  final line = AppLogger.formatLine(DateTime.now(), tag, message);
  // ignore: avoid_print
  print(line);
  if (logFilePath == null) return;
  try {
    File(
      logFilePath,
    ).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // 忽略：落盘失败不影响推理。
  }
}

/// 在调用 native 推理前同步写崩溃面包屑并 flush。
///
/// 若进程在 native 层 abort 被杀，该文件残留，下次启动据此判定"崩在 ASR 推理"。
void _writeCrashMarker(String? path, String info) {
  if (path == null) return;
  try {
    File(path).writeAsStringSync(info, flush: true);
  } catch (_) {}
}

/// 清除崩溃面包屑（native 推理正常返回后调用）。
void _clearCrashMarker(String? path) {
  if (path == null) return;
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

/// 创建 Silero VAD 实例（可选）。
///
/// [vadModelPath] 为 null 时返回 null，转录流程跳过静音裁剪。
sherpa.VoiceActivityDetector? _createVad(String? vadModelPath) {
  if (vadModelPath == null) return null;
  final config = sherpa.VadModelConfig(
    sileroVad: sherpa.SileroVadModelConfig(
      model: vadModelPath,
      // 仅在静音 ≥0.8s 处切段：短促停顿不再切碎，每段更接近完整句/短语，
      // 供上层拼成 ≤30s chunk 后整体送 whisper（whisper 在长上下文上质量远好于碎片）。
      minSilenceDuration: 0.8,
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

/// ASR 输入采样率（16kHz）——whisper 转录与评分 VAD 均用此采样率。
const _asrSampleRate = 16000;

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
  _TranscribeRequest request, {
  String? logFilePath,
  String? crashMarkerPath,
  String diag = '',
}) {
  try {
    final audioData = readAudioFile(request.wavPath);
    if (audioData.samples.isEmpty) {
      request.replyPort.send(
        const _TranscribeResponse(text: '', inferenceTimeMs: 0),
      );
      return;
    }

    // 即将进入 native 推理（VAD + decode）。先写崩溃面包屑：
    // 若 native abort 杀进程，finally 不会执行，文件残留→下次启动可定位。
    final durationSec = audioData.samples.length / audioData.sampleRate;
    _writeCrashMarker(
      crashMarkerPath,
      AppLogger.formatLine(
        DateTime.now(),
        'ASRCrash',
        'native 推理中 $diag wav=${request.wavPath} '
            'audio=${durationSec.toStringAsFixed(1)}s',
      ),
    );

    // VAD 裁剪静音段（需要 16kHz 输入）。
    if (vad != null && audioData.sampleRate >= _asrSampleRate) {
      final samples16k = audioData.sampleRate == _asrSampleRate
          ? audioData.samples
          : downsample(audioData.samples, audioData.sampleRate, _asrSampleRate);
      final beforeSec = samples16k.length / _asrSampleRate;
      // 诊断：计算 RMS 确认输入音频有效。
      var sumSq = 0.0;
      for (final s in samples16k) {
        sumSq += s * s;
      }
      final rms = (sumSq / samples16k.length);
      // rms 未开根号，直接用平方均值即可判断量级。
      _workerLog(
        logFilePath,
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
      final afterSec = totalSpeechSamples / _asrSampleRate;
      _workerLog(
        logFilePath,
        'ASREngine',
        'VAD: ${beforeSec.toStringAsFixed(1)}s → ${afterSec.toStringAsFixed(1)}s (${segments.length} segments)',
      );

      // 合并小段为 ≤30s 的 chunk，减少 whisper 调用次数。
      final chunks = _mergeSegments(segments, 30 * _asrSampleRate);
      _workerLog(
        logFilePath,
        'ASREngine',
        '│ ${segments.length} segments → ${chunks.length} chunks',
      );

      final stopwatch = Stopwatch()..start();
      final texts = <String>[];
      for (final chunk in chunks) {
        final stream = recognizer.createStream();
        stream.acceptWaveform(samples: chunk, sampleRate: _asrSampleRate);
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
  } finally {
    // 推理正常结束（含 Dart 异常被捕获）→ 清除面包屑。
    // 仅当 native abort 杀进程、finally 未执行时，面包屑才残留。
    _clearCrashMarker(crashMarkerPath);
  }
}

/// 在 Worker 内执行分段转录（字幕生成）：把音频切成 ≤30s 连续窗口逐个送 whisper
/// 解码，用 whisper 原生 segment 时间戳生成字幕 cue（whisper 自驱滑窗，业界标准做法）。
///
/// **不使用 VAD**：cue 边界/时间来自 whisper 原生 segment 时间戳（见
/// [_slidingWindowTranscribe]）；窗口在 whisper 自己的完整 segment 边界处推进，
/// **不裁剪、不丢弃任何音频**（旧的 VAD 切段会漏掉 <0.5s 短词、削词头尾、对非人声
/// 误删）。whisper 30s 硬上限决定必须切窗，切点由 whisper 上一个完整 segment 的结束
/// 时刻决定（落在自然停顿处、不在词中间硬切）。转录路径因此也不再触及 Silero VAD
/// （规避 §7.4 的 native 崩溃面）。
///
/// **内存**：优先用可 seek 的 [Pcm16WavStreamReader]（标准 16kHz 单声道 PCM16 WAV，
/// = ffmpeg 转码产物），按 seek 位置只读当前 ≤30s 窗口，峰值内存与总时长解耦；
/// 非标准 WAV 回退 [readAudioFile] 全量读后同样滑窗。
void _handleTranscribeSegments(
  sherpa.OfflineRecognizer recognizer,
  _TranscribeSegmentsRequest request, {
  String? logFilePath,
  String? crashMarkerPath,
  String diag = '',
}) {
  try {
    // ── 首选：可 seek 流式读取（标准 16kHz 单声道 PCM16 WAV，内存与时长解耦）──
    final reader = Pcm16WavStreamReader.open(request.wavPath);
    if (reader != null && reader.sampleRate == _asrSampleRate) {
      final total = reader.totalSamples;
      _writeCrashMarker(
        crashMarkerPath,
        AppLogger.formatLine(
          DateTime.now(),
          'ASRCrash',
          'native 滑窗分段推理中 $diag wav=${request.wavPath} '
              'audio=${(total / _asrSampleRate).toStringAsFixed(1)}s',
        ),
      );
      try {
        final out = _slidingWindowTranscribe(
          recognizer,
          total,
          (start, count) => reader.readWindow(start, count),
          request.replyPort,
          logFilePath: logFilePath,
        );
        request.replyPort.send(_TranscribeSegmentsResponse(segments: out));
      } finally {
        reader.close();
      }
      return;
    }
    reader?.close();

    // ── 回退：全量读取（非标准 WAV）──
    final audioData = readAudioFile(request.wavPath);
    if (audioData.samples.isEmpty) {
      request.replyPort.send(const _TranscribeSegmentsResponse(segments: []));
      return;
    }
    // whisper 需 16kHz：等于直用；整数倍降采样；其余（<16k/非整数倍）尽力直送。
    final samples16k = audioData.sampleRate == _asrSampleRate
        ? audioData.samples
        : (audioData.sampleRate > _asrSampleRate &&
              audioData.sampleRate % _asrSampleRate == 0)
        ? downsample(audioData.samples, audioData.sampleRate, _asrSampleRate)
        : audioData.samples;
    final total = samples16k.length;
    _writeCrashMarker(
      crashMarkerPath,
      AppLogger.formatLine(
        DateTime.now(),
        'ASRCrash',
        'native 滑窗分段推理中(全量) $diag wav=${request.wavPath} '
            'audio=${(total / _asrSampleRate).toStringAsFixed(1)}s',
      ),
    );
    final out = _slidingWindowTranscribe(
      recognizer,
      total,
      (start, count) {
        final end = start + count > total ? total : start + count;
        if (start >= end) return Float32List(0);
        return Float32List.sublistView(samples16k, start, end);
      },
      request.replyPort,
      logFilePath: logFilePath,
    );
    request.replyPort.send(_TranscribeSegmentsResponse(segments: out));
  } catch (e) {
    request.replyPort.send('Transcribe segments failed: $e');
  } finally {
    _clearCrashMarker(crashMarkerPath);
  }
}

/// 窗口解码函数签名：输入 ≤30s 窗口样本，返回 (whisper 原生 segment 列表[相对窗口
/// 起点秒], 整段文本)。生产用 [_decodeWindow]（真 recognizer），测试注入 fake。
typedef WindowDecoder =
    (List<WhisperSegment>, String) Function(Float32List samples);

/// 一条字幕 cue（绝对毫秒时间；[slidingWindowCues] 的可测输出类型）。
@visibleForTesting
class TranscriptionCue {
  final String text;
  final int startMs;
  final int endMs;
  const TranscriptionCue(this.text, this.startMs, this.endMs);

  @override
  bool operator ==(Object other) =>
      other is TranscriptionCue &&
      other.text == text &&
      other.startMs == startMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(text, startMs, endMs);

  @override
  String toString() => 'Cue("$text", $startMs~$endMs)';
}

/// whisper 自驱滑窗转录核心（纯逻辑、依赖注入、可单测）：把音频切成 ≤30s **连续窗口**
/// 逐个 [decode]，用 whisper 原生 segment 时间戳生成 cue，窗口在「上一个完整 segment
/// 的结束时刻」推进（openai/whisper 长音频标准做法）——既不丢内容也不在词中间硬切；
/// 每窗前跳过足够长的静音（[_skipLeadingSilence]）。
///
/// [totalSamples] 总样本数（16kHz）；[readWindow] 按样本下标随机读一段（越界截断、
/// 超尾返回空）；[decode] 解码一窗。cue 绝对时间 = 窗口起点 + segment 相对时间
/// （连续音频，线性映射）。[onProgress] 回传已推进样本数，[log] 回传诊断行。
@visibleForTesting
List<TranscriptionCue> slidingWindowCues(
  int totalSamples,
  Float32List Function(int startSample, int count) readWindow,
  WindowDecoder decode, {
  void Function(int done)? onProgress,
  void Function(String msg)? log,
}) {
  const windowSamples = 30 * _asrSampleRate; // whisper 30s 硬上限
  const minProgress = _asrSampleRate; // 至少推进 1s，防止在段边界原地打转
  final out = <TranscriptionCue>[];
  var seek = 0;

  while (seek < totalSamples) {
    // 跳过足够长的静音（考试音频常有大段答题静音，转录无意义且 whisper 会在静音上
    // 幻觉）。只跳「持续 ≥0.8s 且能量极低」的段，保守阈值绝不跳过有声内容。
    final afterSilence = _skipLeadingSilence(readWindow, seek, totalSamples);
    if (afterSilence != seek) {
      if (afterSilence >= totalSamples) break; // 剩余全是静音
      seek = afterSilence;
      onProgress?.call(seek);
    }

    final window = readWindow(seek, windowSamples);
    if (window.isEmpty) break;
    final windowLen = window.length;
    final isLast = seek + windowLen >= totalSamples;
    final seekSec = seek / _asrSampleRate;

    final (segments, text) = decode(window);

    List<WhisperSegment> used;
    int advance;
    if (segments.isEmpty) {
      // 该窗无 segment 时间戳：有文本则按句切分 + 字符比例估时（罕见兜底），推进整窗。
      used = const [];
      advance = windowLen;
      if (text.isNotEmpty) {
        _emitCharProportional(out, text, seekSec, windowLen / _asrSampleRate);
      }
    } else if (isLast || segments.length == 1) {
      // 末窗或整窗仅一段：全用，推进整窗（末窗循环随后结束；单段无法安全丢弃、防打转）。
      used = segments;
      advance = windowLen;
    } else {
      // 丢弃末段（可能被 30s 边界截断），推进到倒数第二段结束、下一窗重解析末段。
      final candidate = (segments[segments.length - 2].endSec * _asrSampleRate)
          .round();
      if (candidate >= minProgress) {
        used = segments.sublist(0, segments.length - 1);
        advance = candidate;
      } else {
        // 丢末段推进不足（如「短段 + 超长段」）：改为全用、推进整窗，避免漏掉长段。
        used = segments;
        advance = windowLen;
      }
    }

    for (final seg in used) {
      final t = seg.text.trim();
      if (t.isEmpty) continue;
      final startMs = ((seekSec + seg.startSec) * 1000).round();
      final endMs = ((seekSec + seg.endSec) * 1000).round();
      out.add(TranscriptionCue(t, startMs, endMs));
      log?.call(
        '│ cue [${_msLabel(startMs)}~${_msLabel(endMs)}] "${_preview(t)}"',
      );
    }

    seek += advance <= 0 ? windowLen : advance;
    onProgress?.call(seek > totalSamples ? totalSamples : seek);
  }

  onProgress?.call(totalSamples);
  log?.call(
    '滑窗分段完成: ${out.length} cues, '
    'audio=${(totalSamples / _asrSampleRate).toStringAsFixed(1)}s',
  );
  return out;
}

/// [slidingWindowCues] 的生产包装：注入真 recognizer 解码、把 cue 转 [_SegmentPayload]、
/// 进度经 replyPort 回传、诊断行落盘日志。
List<_SegmentPayload> _slidingWindowTranscribe(
  sherpa.OfflineRecognizer recognizer,
  int totalSamples,
  Float32List Function(int startSample, int count) readWindow,
  SendPort replyPort, {
  String? logFilePath,
}) {
  final cues = slidingWindowCues(
    totalSamples,
    readWindow,
    (samples) => _decodeWindow(recognizer, samples),
    onProgress: (done) =>
        replyPort.send(_SegmentsProgress(done: done, total: totalSamples)),
    log: (msg) => _workerLog(logFilePath, 'ASREngine', msg),
  );
  return [
    for (final c in cues)
      _SegmentPayload(text: c.text, startMs: c.startMs, endMs: c.endMs),
  ];
}

/// 帧级静音判定阈值（归一化 PCM 均方，≈ -40 dBFS）。低于此视作静音。
/// 保守取值：宁可漏跳（把静音喂给 whisper，无害）也不误跳有声内容。
const _silenceMeanSquare = 1e-4;

/// 静音扫描帧长（20ms @16kHz）。
const _silenceFrameSamples = 320;

/// 只跳过时长 ≥1s 的静音（略大于 2×前导，保证跳过后仍留足两侧余量；短停顿保留）。
const _minSkipSilenceSamples = _asrSampleRate;

/// 跳到可听内容前保留 0.5s 前导，避免削掉词头（能量检测可能漏掉很轻的词起音）。
const _silenceLeadInSamples = _asrSampleRate ~/ 2;

/// 从 [seek] 起跳过「足够长（≥1s）的静音」，返回下一段可听内容前 ~0.5s 处的样本
/// 下标；静音不足则原样返回 [seek]；[seek] 起剩余全为静音则返回 [total]。
///
/// 「静音 = 持续多帧均方 < 阈值」，与内容无关（不检测人声），故只删真静音、
/// 保留一切有声内容（语音/音乐/音效）。按 2s 块扫描（均方，无神经网络，廉价）。
int _skipLeadingSilence(
  Float32List Function(int startSample, int count) readWindow,
  int seek,
  int total,
) {
  const scanBlock = _asrSampleRate * 2; // 2s，且是帧长整数倍（32000/320=100）
  var pos = seek;
  while (pos < total) {
    final block = readWindow(pos, scanBlock);
    if (block.isEmpty) break;
    final idx = firstAudibleFrameIndex(block);
    if (idx >= 0) {
      final audibleStart = pos + idx;
      if (audibleStart - seek < _minSkipSilenceSamples) return seek; // 静音太短
      final newSeek = audibleStart - _silenceLeadInSamples;
      return newSeek < seek ? seek : newSeek;
    }
    pos += block.length;
  }
  // 到末尾都无可听帧：[seek] 起全是静音，够长则跳到末尾（结束），否则原样保留。
  return (total - seek) >= _minSkipSilenceSamples ? total : seek;
}

/// 返回 [block] 内首个「可听帧」（均方 ≥ [_silenceMeanSquare]）的起始样本下标；
/// 全为静音返回 -1。帧长 [_silenceFrameSamples]，尾部不足一帧的残余忽略。
@visibleForTesting
int firstAudibleFrameIndex(Float32List block) {
  final frames = block.length ~/ _silenceFrameSamples;
  for (var f = 0; f < frames; f++) {
    final base = f * _silenceFrameSamples;
    var sum = 0.0;
    for (var i = 0; i < _silenceFrameSamples; i++) {
      final s = block[base + i];
      sum += s * s;
    }
    if (sum / _silenceFrameSamples >= _silenceMeanSquare) return base;
  }
  return -1;
}

/// 解码一个 ≤30s 窗口，返回 (whisper 原生 segment 列表[相对窗口起点秒], 整段文本)。
(List<WhisperSegment>, String) _decodeWindow(
  sherpa.OfflineRecognizer recognizer,
  Float32List samples,
) {
  final stream = recognizer.createStream();
  stream.acceptWaveform(samples: samples, sampleRate: _asrSampleRate);
  recognizer.decode(stream);
  // 先取原生 result JSON（含 segment 时间戳），再用公开 getResult 拿整段文本兜底。
  final rawJson = _rawStreamResultJson(stream);
  final result = recognizer.getResult(stream);
  stream.free();
  final segs = rawJson == null
      ? const <WhisperSegment>[]
      : parseWhisperSegments(rawJson);
  return (segs, result.text.trim());
}

/// 无 segment 时间戳时的兜底：把 [text] 按句切分，时间按字符长度在
/// `[startSec, startSec+spanSec]` 内比例分配（近似，与词级合成同源）。罕见路径。
void _emitCharProportional(
  List<TranscriptionCue> out,
  String text,
  double startSec,
  double spanSec,
) {
  final sentences = splitTextIntoSentences(text);
  if (sentences.isEmpty) return;
  final totalChars = sentences.fold<int>(0, (s, x) => s + x.length);
  var cumChars = 0;
  for (final sent in sentences) {
    final startFrac = totalChars == 0 ? 0.0 : cumChars / totalChars;
    cumChars += sent.length;
    final endFrac = totalChars == 0 ? 1.0 : cumChars / totalChars;
    final s = ((startSec + spanSec * startFrac) * 1000).round();
    final e = ((startSec + spanSec * endFrac) * 1000).round();
    out.add(TranscriptionCue(sent, s, e));
  }
}

/// 取解码后 stream 的原生 result JSON 字符串（含 `segment_timestamps` 等公开
/// getResult 丢弃的字段）。绑定未就绪/异常时返回 null（调用方回退）。
String? _rawStreamResultJson(sherpa.OfflineStream stream) {
  final getJson = SherpaOnnxBindings.getOfflineStreamResultAsJson;
  final destroy = SherpaOnnxBindings.destroyOfflineStreamResultJson;
  if (getJson == null || destroy == null) return null;
  final ptr = getJson(stream.ptr);
  if (ptr.address == 0) return null;
  try {
    return ptr.toDartString();
  } finally {
    destroy(ptr);
  }
}

/// whisper 原生 segment（时间为相对 chunk 起点的秒，待映射回原始音频）。
@visibleForTesting
class WhisperSegment {
  final String text;
  final double startSec;
  final double durationSec;
  const WhisperSegment(this.text, this.startSec, this.durationSec);

  /// 段结束时间（相对 chunk 起点的秒）。
  double get endSec => startSec + durationSec;
}

/// 解析 whisper 原生 result JSON 里的 segment 时间戳（纯逻辑，可测）。
///
/// 读 `segment_texts` / `segment_timestamps`（各段起始秒）/ `segment_durations`
/// （各段时长秒），三者等长时逐段配对；任一缺失/长度不齐/JSON 非法 → 返回空列表
/// （调用方回退到按句切分）。文本 trim，丢弃空段。
@visibleForTesting
List<WhisperSegment> parseWhisperSegments(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } catch (_) {
    return const [];
  }
  if (decoded is! Map) return const [];
  final texts = decoded['segment_texts'];
  final starts = decoded['segment_timestamps'];
  final durs = decoded['segment_durations'];
  if (texts is! List || starts is! List || durs is! List) return const [];
  final n = texts.length;
  if (starts.length != n || durs.length != n) return const [];

  final out = <WhisperSegment>[];
  for (var i = 0; i < n; i++) {
    final t = texts[i];
    final s = starts[i];
    final d = durs[i];
    if (t is! String || s is! num || d is! num) continue;
    final text = t.trim();
    if (text.isEmpty) continue;
    out.add(WhisperSegment(text, s.toDouble(), d.toDouble()));
  }
  return out;
}

/// 毫秒 → `mm:ss.mmm` 简标签，便于对照播放器时间轴。
String _msLabel(int ms) {
  final totalSec = ms ~/ 1000;
  final mm = (totalSec ~/ 60).toString().padLeft(2, '0');
  final ss = (totalSec % 60).toString().padLeft(2, '0');
  final rem = (ms % 1000).toString().padLeft(3, '0');
  return '$mm:$ss.$rem';
}

/// 文本预览：过长时截断，避免日志刷屏。
String _preview(String text, [int max = 80]) =>
    text.length <= max ? text : '${text.substring(0, max)}…';

/// 把整段文本按**句末标点**（`.`/`?`/`!`）切成句子列表（纯逻辑，可测）。
///
/// 每个句子保留其结尾标点；连续标点（如 `?!`、省略号 `...`）归入同一句。
/// 末尾无标点的残句也单独成句。各句归一空白 + trim，丢弃空句。
/// 供 chunk 级转录结果按句切成字幕 cue（时间另按字符长度比例分配）。
@visibleForTesting
List<String> splitTextIntoSentences(String text) {
  final out = <String>[];
  // 匹配「若干非句末字符 + 一个及以上句末标点」或「结尾无标点的残段」。
  for (final m in RegExp(r'[^.!?]*[.!?]+|[^.!?]+$').allMatches(text)) {
    final s = m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isNotEmpty) out.add(s);
  }
  return out;
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

/// 获取当前平台的推理加速 provider，统一返回 `cpu`。
///
/// iOS/macOS：CoreML 对 int8 量化模型反而更慢，使用 CPU。
/// Android：曾用 NNAPI 走厂商 GPU/DSP/NPU 加速，但部分机型（如 OnePlus
/// ColorOS / Android 16）的 NNAPI 驱动在 onnxruntime int8 推理时触发 native
/// abort（SIGABRT，Dart/Java 无法捕获，进程直接被杀）。`_createRecognizer`
/// 的 try/catch 只能兜住构造期 Dart 异常，挡不住 decode 期的 native abort，
/// 故统一改用 CPU，稳定优先；int8 模型在移动端 CPU 上性能可接受。
/// 仍可通过 [AsrModelConfig.provider] 显式覆盖（如日后做成设置项重开 NNAPI）。
String _platformProvider() {
  // if (Platform.isAndroid) return 'nnapi';
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
    // 开启 segment 级时间戳：靠 logit filter 保留 whisper 原生时间戳 token，**不需
    // 重导模型**（现有 int8 模型即可，见 sherpa-onnx PR #2945）。分段路径据此把每个
    // whisper segment 直接作一条字幕 cue（自带真实 start/duration）。
    // 注意：token 级时间戳（DTW）才需重导带 cross_attention_weights 的模型，故不开
    // enableTokenTimestamps。segment 数据不在公开 getResult()，需读原生 result JSON。
    enableSegmentTimestamps: true,
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
