import 'dart:async';
import 'dart:io';

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

  /// 解码阶段在总进度中的占比；剩余部分是峰值计算（耗时远小于解码）。
  static const double _decodeProgressShare = 0.95;

  /// 读缓存或生成波形。
  ///
  /// 音频与视频统一用 FFmpeg 把第一条音轨解码为 PCM，再在后台 isolate 计算峰值：
  /// 不依赖系统解码器，mkv/avi 等容器与普通音频同样可用。[mediaDuration] 用于把
  /// 解码进度换算为比例；未知时解码期间进度保持 0。
  Future<WaveformPeaks> load({
    required AudioItem source,
    required String mediaPath,
    required Duration? mediaDuration,
    required MediaTrimCancellation cancellation,
    required void Function(double progress) onProgress,
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
      final totalMs = mediaDuration?.inMilliseconds ?? 0;
      await _processor.decodeWaveformPcm(
        source: mediaPath,
        output: pcm.path,
        cancellation: cancellation,
        onTimeMs: totalMs <= 0
            ? null
            : (milliseconds) => onProgress(
                (milliseconds / totalMs).clamp(0.0, 1.0) * _decodeProgressShare,
              ),
      );
      final decodeMs = stopwatch.elapsedMilliseconds;
      cancellation.throwIfCancelled();
      final peaks = await computeWaveformPeaksInBackground(pcm.path);
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
        'decode=${decodeMs}ms total=${stopwatch.elapsedMilliseconds}ms',
      );
      return peaks;
    } finally {
      unawaited(_deleteQuietly(temporary));
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
