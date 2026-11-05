/// 单词发音的 CDN 音频仓库：本地缓存 → CDN 下载 → 缓存落盘。
///
/// 只负责「给出可播放的本地文件或 null」。null 表示该词应回退 TTS，包括
/// 词不合规、CDN 404、网络失败，调用方不需要区分原因。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_logger.dart';
import '../reliable_http_downloader.dart';
import '../runtime_endpoint_router.dart';
import 'word_audio_identity.dart';

const _logTag = 'WordAudio';

/// CDN 上单词音频所在的路径前缀（locale 目录与生成端一致）。
const _cdnDirectory = 'words/en-US';

class WordAudioRepository {
  WordAudioRepository({
    required ReliableHttpDownloader downloader,
    required Future<Directory> Function() resolveCacheDir,
    required RuntimeEndpointRouter endpointRouter,
  }) : _downloader = downloader,
       _resolveCacheDir = resolveCacheDir,
       _endpointRouter = endpointRouter;

  final ReliableHttpDownloader _downloader;
  final Future<Directory> Function() _resolveCacheDir;
  final RuntimeEndpointRouter _endpointRouter;

  /// 同一文件的并发解析共享一次下载，点击与后台预热不会重复请求。
  final _inFlight = <String, Future<String?>>{};

  /// 本进程内已确认 CDN 不存在的文件。404 是确定性结果，无需每次点击都请求。
  final _missingFileNames = <String>{};

  /// 返回 [text] 的本地音频路径；无法提供音频时返回 null。
  Future<String?> resolve(String text) async {
    final fileName = wordAudioFileName(text);
    if (fileName == null || _missingFileNames.contains(fileName)) return null;
    final running = _inFlight[fileName];
    if (running != null) return running;
    final future = _fetch(fileName);
    _inFlight[fileName] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(fileName);
    }
  }

  Future<String?> _fetch(String fileName) async {
    final file = File(p.join(await _localDirectory(), fileName));
    if (await file.exists()) {
      if (await file.length() > 0) return file.path;
      // 空文件通常来自中断或磁盘异常，留着只会永久命中一个无法播放的文件。
      await file.delete();
    }
    final uri = _endpointRouter.modelCdnUri('/$_cdnDirectory/$fileName');
    try {
      await _downloader.download(
        uri: uri,
        savePath: file.path,
        allowResume: false,
      );
      return file.path;
    } on ReliableDownloadException catch (error) {
      if (error.kind == ReliableDownloadFailure.httpStatus &&
          error.statusCode == 404) {
        _missingFileNames.add(fileName);
        AppLogger.log(_logTag, 'CDN 不存在，回退 TTS：$fileName');
      } else {
        AppLogger.log(_logTag, 'CDN 下载失败，回退 TTS：$fileName error=$error');
      }
      return null;
    } on FileSystemException catch (error) {
      AppLogger.log(_logTag, '缓存写入失败，回退 TTS：$fileName error=$error');
      return null;
    }
  }

  Future<String> _localDirectory() async {
    final base = await _resolveCacheDir();
    final directory = Directory(p.join(base.path, 'word_audio', 'en-US'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }
}

/// 生产环境仓库：短超时 + 不重试，CDN 慢时尽快回退到 TTS。
WordAudioRepository createWordAudioRepository(
  RuntimeEndpointRouter endpointRouter,
) {
  return WordAudioRepository(
    downloader: DioReliableHttpDownloader(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 5),
        ),
      ),
      maxRetries: 0,
    ),
    resolveCacheDir: getApplicationCacheDirectory,
    endpointRouter: endpointRouter,
  );
}
