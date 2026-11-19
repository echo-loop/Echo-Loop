import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

import '../../utils/waveform_peaks.dart';
import 'media_trim_clip.dart';

/// 一次剪辑任务的取消令牌；只取消该任务登记的原生会话，不影响其它 FFmpeg 任务。
class MediaTrimCancellation {
  bool _isCancelled = false;
  int? _sessionId;

  bool get isCancelled => _isCancelled;

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const MediaTrimException(MediaTrimFailure.cancelled);
    }
  }

  Future<void> cancel() async {
    if (_isCancelled) return;
    _isCancelled = true;
    final sessionId = _sessionId;
    if (sessionId != null) await FFmpegKit.cancel(sessionId);
  }

  Future<void> _attach(int? sessionId) async {
    _sessionId = sessionId;
    if (_isCancelled && sessionId != null) await FFmpegKit.cancel(sessionId);
  }

  void _detach() => _sessionId = null;
}

/// 原媒体的探测结果。
class MediaTrimSourceInfo {
  const MediaTrimSourceInfo({required this.duration, this.videoBitrate});

  final Duration duration;

  /// 原视频流码率（bit/s）；未知时为 null。
  final int? videoBitrate;
}

/// FFmpeg 边界：探测、精确重编码与波形 PCM 解码。实例本身无状态，可复用。
class MediaTrimProcessor {
  const MediaTrimProcessor();

  /// 导出片段与原片时长允许的误差，覆盖编码器帧对齐带来的偏差。
  static const Duration durationTolerance = Duration(milliseconds: 150);

  static const int _fallbackVideoBitrate = 4000000;
  static const int _minVideoBitrate = 800000;
  static const int _maxVideoBitrate = 12000000;

  Future<MediaTrimSourceInfo> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final information = session.getMediaInformation();
    final seconds = double.tryParse(information?.getDuration() ?? '');
    if (seconds == null || !seconds.isFinite || seconds <= 0) {
      throw MediaTrimException(
        MediaTrimFailure.durationUnreadable,
        await session.getOutput(),
      );
    }
    int? videoBitrate;
    for (final stream in information?.getStreams() ?? const []) {
      if (stream.getType() == 'video') {
        videoBitrate = int.tryParse(stream.getBitrate() ?? '');
        break;
      }
    }
    return MediaTrimSourceInfo(
      duration: Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
      ),
      videoBitrate: videoBitrate,
    );
  }

  /// 精确裁剪并重编码：音频 AAC/M4A，视频 H.264 + AAC/MP4，不使用关键帧流复制。
  Future<void> render({
    required String source,
    required String output,
    required Duration start,
    required Duration end,
    required bool isVideo,
    int? sourceVideoBitrate,
    required MediaTrimCancellation cancellation,
    required void Function(double fraction) onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final duration = end - start;
    final videoBitrate = (sourceVideoBitrate ?? _fallbackVideoBitrate).clamp(
      _minVideoBitrate,
      _maxVideoBitrate,
    );
    final arguments = <String>[
      '-nostdin',
      '-y',
      '-loglevel',
      'error',
      '-ss',
      _seconds(start),
      '-i',
      source,
      '-t',
      _seconds(duration),
      if (isVideo) ...[
        '-map',
        '0:v:0',
        '-map',
        '0:a:0?',
        '-c:v',
        Platform.isAndroid ? 'h264_mediacodec' : 'h264_videotoolbox',
        // 硬件编码会话可能被占用或不可用，允许 VideoToolbox 退回系统软件编码。
        if (!Platform.isAndroid) ...['-allow_sw', '1'],
        // 跳过 FFmpeg 为 MP4 全局头部预送探测帧后 flush 的流程。
        // 部分 MediaCodec 编码器在该流程后会拒收后续帧或提前结束。
        if (Platform.isAndroid) ...['-flags:v', '-global_header'],
        '-b:v',
        '$videoBitrate',
        '-pix_fmt',
        'yuv420p',
      ] else ...[
        '-map',
        '0:a:0',
        '-vn',
      ],
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-map_metadata',
      '-1',
      '-map_chapters',
      '-1',
      '-sn',
      '-movflags',
      '+faststart',
      output,
    ];
    final session = await _run(
      arguments,
      cancellation,
      onTimeMs: (milliseconds) => onProgress(
        (milliseconds / duration.inMilliseconds).clamp(0.0, 1.0).toDouble(),
      ),
    );
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      throw MediaTrimException(
        MediaTrimFailure.encodeFailed,
        await session.getOutput(),
      );
    }
    await _verifyOutput(
      output,
      duration,
      cancellation,
      verifyVideoTrack: isVideo && Platform.isAndroid,
    );
  }

  /// 把第一条音轨解码为波形用 PCM（参数见 [waveformPcmDecodeArguments]）。
  ///
  /// [onTimeMs] 为已解码到的媒体时间，用于换算进度。
  Future<void> decodeWaveformPcm({
    required String source,
    required String output,
    required MediaTrimCancellation cancellation,
    void Function(int milliseconds)? onTimeMs,
  }) async {
    final session = await _run(
      waveformPcmDecodeArguments(input: source, output: output),
      cancellation,
      onTimeMs: onTimeMs,
    );
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      throw MediaTrimException(
        MediaTrimFailure.encodeFailed,
        await session.getOutput(),
      );
    }
  }

  Future<void> _verifyOutput(
    String output,
    Duration expected,
    MediaTrimCancellation cancellation, {
    required bool verifyVideoTrack,
  }) async {
    final decode = await FFmpegKit.executeWithArguments([
      '-nostdin',
      '-v',
      'error',
      '-i',
      output,
      '-t',
      '1',
      '-f',
      'null',
      '-',
    ]);
    cancellation.throwIfCancelled();
    if (!ReturnCode.isSuccess(await decode.getReturnCode())) {
      throw MediaTrimException(
        MediaTrimFailure.outputInvalid,
        await decode.getOutput(),
      );
    }
    final session = await FFprobeKit.getMediaInformation(output);
    cancellation.throwIfCancelled();
    final information = session.getMediaInformation();
    final seconds = double.tryParse(information?.getDuration() ?? '');
    final expectedSeconds =
        expected.inMicroseconds / Duration.microsecondsPerSecond;
    final toleranceSeconds =
        durationTolerance.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds == null ||
        !seconds.isFinite ||
        (seconds - expectedSeconds).abs() > toleranceSeconds) {
      throw MediaTrimException(
        MediaTrimFailure.outputInvalid,
        '时长不符 expectedSeconds=$expectedSeconds actualSeconds=$seconds',
      );
    }
    if (verifyVideoTrack) {
      double? videoSeconds;
      for (final stream in information?.getStreams() ?? const []) {
        if (stream.getType() == 'video') {
          videoSeconds = double.tryParse(
            stream.getStringProperty('duration') ?? '',
          );
          break;
        }
      }
      // 容器时长可能只来自完整的音轨，无法证明视频已写全。
      if (videoSeconds == null ||
          !videoSeconds.isFinite ||
          (videoSeconds - expectedSeconds).abs() > toleranceSeconds) {
        throw MediaTrimException(
          MediaTrimFailure.outputInvalid,
          '视频轨时长不符 expectedSeconds=$expectedSeconds actualSeconds=$videoSeconds',
        );
      }
    }
  }

  Future<FFmpegSession> _run(
    List<String> arguments,
    MediaTrimCancellation cancellation, {
    void Function(int milliseconds)? onTimeMs,
  }) async {
    cancellation.throwIfCancelled();
    final completed = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      completed.complete,
      null,
      onTimeMs == null
          ? null
          : (statistics) {
              if (!cancellation.isCancelled) onTimeMs(statistics.getTime());
            },
    );
    await cancellation._attach(session.getSessionId());
    try {
      final result = await completed.future;
      cancellation.throwIfCancelled();
      return result;
    } finally {
      cancellation._detach();
    }
  }

  static String _seconds(Duration value) =>
      (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(
        6,
      );
}
