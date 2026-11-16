import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;

import '../../models/audio_item.dart';
import '../../services/app_logger.dart';
import '../../utils/app_data_dir.dart';
import 'media_trim_exporter.dart';
import 'media_trim_processor.dart';

final mediaTrimWaveformLoaderProvider = Provider<MediaTrimWaveformLoader>(
  (ref) => MediaTrimWaveformLoader(ref.watch(mediaTrimProcessorProvider)),
);

/// 剪辑页波形加载。与字幕编辑共用 `waveforms/{id}.wave` 缓存（同一采样密度），
/// 删除材料时缓存随之清理。
class MediaTrimWaveformLoader {
  const MediaTrimWaveformLoader(this._processor);

  final MediaTrimProcessor _processor;

  /// 与字幕编辑器保持一致，缓存文件可互相复用。
  static const WaveformZoom _zoom = WaveformZoom.pixelsPerSecond(80);

  /// 原生提取连续无进度的最长等待；卡死时判失败而不是一直转圈。
  static const Duration _inactivityTimeout = Duration(seconds: 60);

  Future<Waveform> load({
    required AudioItem source,
    required String mediaPath,
    required MediaTrimCancellation cancellation,
    required void Function(double progress) onProgress,
  }) async {
    final dataDirectory = await getAppDataDirectory();
    final cacheDirectory = Directory(p.join(dataDirectory.path, 'waveforms'));
    final cache = File(p.join(cacheDirectory.path, '${source.id}.wave'));
    if (await cache.exists()) {
      AppLogger.log('MediaTrim', '波形命中缓存 source=${source.id}');
      return JustWaveform.parse(cache);
    }
    await cacheDirectory.create(recursive: true);
    final stopwatch = Stopwatch()..start();
    final temporary = await Directory.systemTemp.createTemp('echo-trim-wave-');
    try {
      var audio = File(mediaPath);
      if (source.isVideo) {
        // 视频容器（如 mkv/webm）不一定能被系统解码器直接读取，先抽出代理音轨。
        final proxy = File(p.join(temporary.path, 'proxy.m4a'));
        await _processor.extractAudio(
          source: mediaPath,
          output: proxy.path,
          cancellation: cancellation,
        );
        audio = proxy;
      }
      cancellation.throwIfCancelled();
      // 先写临时文件，完成后再改名，避免中断留下半截缓存被字幕编辑器读到。
      final partial = File(p.join(temporary.path, 'waveform.wave'));
      Waveform? waveform;
      await for (final event in JustWaveform.extract(
        audioInFile: audio,
        waveOutFile: partial,
        zoom: _zoom,
      ).timeout(_inactivityTimeout)) {
        cancellation.throwIfCancelled();
        onProgress(event.progress);
        waveform = event.waveform ?? waveform;
      }
      if (waveform == null) {
        throw const FormatException('波形提取未返回结果');
      }
      final staged = await partial.copy('${cache.path}.partial');
      await staged.rename(cache.path);
      AppLogger.log(
        'MediaTrim',
        '波形提取完成 source=${source.id} pixels=${waveform.length} '
            'cost=${stopwatch.elapsedMilliseconds}ms',
      );
      return waveform;
    } finally {
      unawaited(_deleteQuietly(temporary));
    }
  }

  Future<void> _deleteQuietly(Directory directory) async {
    try {
      await directory.delete(recursive: true);
    } on FileSystemException catch (error) {
      // 原生提取可能仍持有文件；系统会回收临时目录，这里只记录。
      AppLogger.log('MediaTrim', '波形临时目录删除失败：$error');
    }
  }
}
