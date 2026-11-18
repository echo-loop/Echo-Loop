import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../models/audio_item.dart';
import '../../services/app_logger.dart';
import '../../utils/app_data_dir.dart';
import '../../utils/waveform_peaks.dart';
import 'media_trim_exporter.dart';
import 'media_trim_processor.dart';

final mediaTrimWaveformLoaderProvider = Provider<MediaTrimWaveformLoader>(
  (ref) => MediaTrimWaveformLoader(ref.watch(mediaTrimProcessorProvider)),
);

/// 剪辑页与字幕编辑页的波形加载，共用 `waveforms/{id}.wave` 缓存（同一采样密度），
/// 删除材料时缓存随之清理。
class MediaTrimWaveformLoader {
  const MediaTrimWaveformLoader(this._processor);

  final MediaTrimProcessor _processor;

  /// 剪辑页与字幕编辑页共用，日志不归属某一页面。
  static const String _logTag = 'MediaWaveform';

  /// 解码阶段在总进度中的占比；剩余部分是解码结束后读取尾部并收尾的耗时（远小于解码）。
  static const double _decodeProgressShare = 0.95;

  /// 解码进行中每隔此时长把 PCM 新增部分折算进峰值，并通知一次快照。
  static const Duration _partialInterval = Duration(milliseconds: 300);

  /// 读缓存或生成波形。
  ///
  /// 音频与视频统一用 FFmpeg 把第一条音轨解码为 PCM，解码过程中边读边计算峰值：
  /// 不依赖系统解码器，mkv/avi 等容器与普通音频同样可用。[mediaDuration] 用于把
  /// 解码进度换算为比例；未知时解码期间进度保持 0。
  ///
  /// [onPartial] 在解码期间收到已完成部分的波形快照，页面可边生成边显示。只有完整
  /// 波形才写入缓存；快照需要 [mediaDuration] 确定整段像素数，因此时长未知时不发送。
  Future<WaveformPeaks> load({
    required AudioItem source,
    required String mediaPath,
    required Duration? mediaDuration,
    required MediaTrimCancellation cancellation,
    required void Function(double progress) onProgress,
    void Function(WaveformPeaks partial)? onPartial,
  }) async {
    final dataDirectory = await getAppDataDirectory();
    final cacheDirectory = Directory(p.join(dataDirectory.path, 'waveforms'));
    final cache = File(p.join(cacheDirectory.path, '${source.id}.wave'));
    final cached = await _readCache(cache, source);
    if (cached != null) return cached;
    await cacheDirectory.create(recursive: true);
    final stopwatch = Stopwatch()..start();
    final temporary = await Directory.systemTemp.createTemp('echo-wave-');
    try {
      final pcm = File(p.join(temporary.path, 'audio.pcm'));
      final peaks = await _decodePeaks(
        mediaPath: mediaPath,
        pcm: pcm,
        mediaDuration: mediaDuration,
        cancellation: cancellation,
        onProgress: onProgress,
        onPartial: onPartial,
      );
      cancellation.throwIfCancelled();
      // 先写临时文件再改名，避免中断留下半截缓存被另一页读到。
      final staged = File('${cache.path}.partial');
      await staged.writeAsBytes(peaks.encode(), flush: true);
      await staged.rename(cache.path);
      onProgress(1);
      AppLogger.log(
        _logTag,
        '波形生成完成 source=${source.id} video=${source.isVideo} '
        'pixels=${peaks.length} duration=${peaks.duration.inMilliseconds}ms '
        'total=${stopwatch.elapsedMilliseconds}ms',
      );
      return peaks;
    } finally {
      unawaited(_deleteQuietly(temporary));
    }
  }

  /// FFmpeg 解码到 [pcm]，同时跟随文件增长计算峰值；解码结束后读完剩余部分。
  Future<WaveformPeaks> _decodePeaks({
    required String mediaPath,
    required File pcm,
    required Duration? mediaDuration,
    required MediaTrimCancellation cancellation,
    required void Function(double progress) onProgress,
    required void Function(WaveformPeaks partial)? onPartial,
  }) async {
    final totalMs = mediaDuration?.inMilliseconds ?? 0;
    final builder = WaveformPeaksBuilder(
      expectedSamples: mediaDuration == null
          ? 0
          : mediaDuration.inMicroseconds *
                waveformPcmSampleRate ~/
                Duration.microsecondsPerSecond,
    );
    // 快照的像素总数由 mediaDuration 决定，时长未知或为零时不能流式通知。
    final streamsPartials =
        onPartial != null &&
        mediaDuration != null &&
        mediaDuration > Duration.zero;
    final tail = _PcmFileTail(pcm.path);
    var isDecoding = true;
    final decoding = _processor
        .decodeWaveformPcm(
          source: mediaPath,
          output: pcm.path,
          cancellation: cancellation,
          onTimeMs: totalMs <= 0
              ? null
              : (milliseconds) => onProgress(
                  (milliseconds / totalMs).clamp(0.0, 1.0) *
                      _decodeProgressShare,
                ),
        )
        .whenComplete(() => isDecoding = false);
    // 解码失败会在下面的 await 处抛出；这里先忽略，避免等待期间被当作未处理异常上报。
    decoding.ignore();
    try {
      var notifiedPixels = 0;
      while (isDecoding) {
        await Future<void>.delayed(_partialInterval);
        await tail.drainInto(builder);
        if (streamsPartials && builder.readyPixels > notifiedPixels) {
          notifiedPixels = builder.readyPixels;
          onPartial(builder.snapshot());
        }
      }
      await decoding;
      cancellation.throwIfCancelled();
      await tail.drainInto(builder);
      return builder.finish();
    } finally {
      await tail.close();
    }
  }

  /// 读取缓存；不存在返回 null。无效缓存（旧版 just_waveform 文件或写坏的文件）
  /// 直接删除后返回 null，由调用方重新生成。
  Future<WaveformPeaks?> _readCache(File cache, AudioItem source) async {
    try {
      final peaks = WaveformPeaks.decode(await cache.readAsBytes());
      AppLogger.log(_logTag, '波形命中缓存 source=${source.id}');
      return peaks;
    } on PathNotFoundException {
      return null;
    } on FormatException {
      AppLogger.log(_logTag, '删除无效波形缓存 source=${source.id}');
      await cache.delete();
      return null;
    }
  }

  Future<void> _deleteQuietly(Directory directory) async {
    try {
      await directory.delete(recursive: true);
    } on FileSystemException catch (error) {
      // 系统会回收临时目录，这里只记录。
      AppLogger.log(_logTag, '波形临时目录删除失败：$error');
    }
  }
}

/// 跟随正在被 FFmpeg 写入的 PCM 文件：每次只读取新增的完整采样，不重复读取已消费部分。
class _PcmFileTail {
  _PcmFileTail(this._path);

  /// 单次读取上限，与峰值计算分块一致；每块处理后让出事件循环，避免占满 UI 线程。
  static const int _chunkBytes = 1 << 20;

  final String _path;
  final Uint8List _buffer = Uint8List(_chunkBytes);
  RandomAccessFile? _file;
  int _consumedBytes = 0;

  /// 把文件中当前已写入的完整采样喂给 [builder]。文件尚未创建时什么也不做。
  Future<void> drainInto(WaveformPeaksBuilder builder) async {
    _file ??= await _openIfExists();
    final file = _file;
    if (file == null) return;
    while (true) {
      // 只取偶数字节，保证每次读到的都是完整的 16 位采样。
      final available = (await file.length() - _consumedBytes) ~/ 2 * 2;
      if (available <= 0) return;
      final want = math.min(available, _buffer.length);
      await file.setPosition(_consumedBytes);
      final read = await file.readInto(_buffer, 0, want);
      if (read != want) throw FileSystemException('PCM 读取不完整', _path);
      builder.addSamples(
        Int16List.view(_buffer.buffer, 0, read ~/ 2),
        read ~/ 2,
      );
      _consumedBytes += read;
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> close() async {
    await _file?.close();
    _file = null;
  }

  Future<RandomAccessFile?> _openIfExists() async {
    final pcm = File(_path);
    if (!await pcm.exists()) return null;
    return pcm.open();
  }
}
