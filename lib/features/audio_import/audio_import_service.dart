import 'dart:async';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:universal_io/io.dart';

import '../../models/audio_item.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import '../../services/app_logger.dart';
import '../../services/background_file_download_service.dart';
import '../../utils/app_data_dir.dart';
import '../../utils/media_duration.dart';
import 'audio_finalization_service.dart';
import 'audio_import_cancel.dart';
import 'audio_import_models.dart';
import 'audio_registration_service.dart';
import 'audio_transcode_service.dart';

typedef AudioImportProgressCallback =
    void Function(int receivedBytes, int? totalBytes);

/// 链接音频导入服务。
///
/// 负责把外部音频直链下载到应用沙盒并创建普通 [AudioItem]。未来 RSS 解析只需
/// 把单集 enclosure 规整成直链来源，即可复用本服务。
class AudioImportService {
  static const _logTag = 'AudioImport';

  AudioImportService({
    Dio? dio,
    Uuid? uuid,
    Future<Directory> Function()? resolveDataDir,
    Future<String> Function(String absolutePath)? computeSha256,
    Future<int> Function(String relativePath)? readDurationSeconds,
    AudioRegistrationService? registrationService,
    AudioTranscodeService? transcodeService,
    BackgroundFileDownloadService? backgroundDownloader,
  }) : _dio = dio ?? Dio(),
       _uuid = uuid ?? const Uuid(),
       _resolveDataDir = resolveDataDir ?? getAppDataDirectory,
       _readDurationSeconds = readDurationSeconds ?? getMediaDurationSeconds,
       _registrationService =
           registrationService ?? AudioRegistrationService(uuid: uuid),
       _finalizationService = AudioFinalizationService(
         transcodeService: transcodeService ?? AudioTranscodeService(),
         computeSha256: computeSha256,
         uuid: uuid,
       ),
       _backgroundDownloader =
           backgroundDownloader ?? BackgroundFileDownloadService();

  final Dio _dio;

  final BackgroundFileDownloadService _backgroundDownloader;
  final Uuid _uuid;
  final Future<Directory> Function() _resolveDataDir;
  final Future<int> Function(String relativePath) _readDurationSeconds;
  final AudioRegistrationService _registrationService;
  final AudioFinalizationService _finalizationService;

  static const supportedExtensions = {'mp3', 'wav', 'm4a', 'aac', 'flac'};

  Future<AudioItem> importFromUrl({
    required String url,
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    AudioImportProgressCallback? onProgress,
  }) async {
    final resolved = await resolveUrl(url, cancelToken: cancelToken);
    final dataDir = await _resolveDataDir();
    final audioId = _uuid.v4();
    final downloadedPath = await _downloadToTemp(
      resolved: resolved,
      audioId: audioId,
      dataDir: dataDir,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    FinalizedAudio? finalizedAudio;
    try {
      finalizedAudio = await _finalizeDownloadedAudio(
        dataDir: dataDir,
        tempRelativePath: downloadedPath,
        cancelToken: cancelToken,
      );
      cancelToken?.throwIfCanceled();

      final result = await _registrationService.registerSandboxedAudio(
        input: SandboxedAudioRegistrationInput(
          name: resolved.displayName,
          relativePath: finalizedAudio.relativePath,
          importSourceType: AudioImportSourceType.directUrl,
          importSourceUrl: resolved.uri.toString(),
          audioSha256: finalizedAudio.sha256,
          originalAudioSha256: finalizedAudio.originalSha256,
        ),
        audioLibrary: audioLibrary,
        audioLibraryState: audioLibraryState,
        collectionList: collectionList,
        collectionState: collectionState,
        collectionId: collectionId,
        cancelToken: cancelToken,
      );

      switch (result) {
        case AudioRegistrationAdded(:final item):
          if (finalizedAudio.created &&
              item.audioPath != finalizedAudio.relativePath) {
            await _deleteIfExists(
              File(p.join(dataDir.path, finalizedAudio.relativePath)),
            );
          }
          return item;
        case AudioRegistrationDuplicate(:final name):
          throw AudioImportException(
            AudioImportFailureCode.duplicate,
            'Audio already exists: $name',
          );
      }
    } catch (error) {
      final savedAudio = finalizedAudio;
      if (savedAudio != null && savedAudio.created) {
        await _deleteIfExists(
          File(p.join(dataDir.path, savedAudio.relativePath)),
        );
      }
      if (error is DioException && CancelToken.isCancel(error)) {
        throw const AudioImportException(
          AudioImportFailureCode.canceled,
          'Audio import canceled',
        );
      }
      rethrow;
    }
  }

  /// 下载 podcast 单集 enclosure 到沙盒，仅落盘并返回文件信息，**不创建 [AudioItem]**。
  ///
  /// 与 [importFromUrl] 的区别：跳过严格的直链 MIME/音频校验（podcast enclosure
  /// 常返回 `application/octet-stream` 或经重定向域名分发），扩展名按
  /// URL 后缀 → enclosureType → `mp3` 兜底确定。调用方拿到结果后自行更新已存在的
  /// 占位条目（保留 podcast 元字段），避免在资源库产生重复孤儿条目。
  /// [displayName] 使用播客列表中的名称，并用于后台下载通知。
  Future<DownloadedAudio> downloadEpisodeToSandbox({
    required String url,
    required String displayName,
    String? enclosureType,
    CancelToken? cancelToken,
    AudioImportProgressCallback? onProgress,
  }) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AudioImportException(
        AudioImportFailureCode.invalidUrl,
        'Invalid audio URL',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const AudioImportException(
        AudioImportFailureCode.unsupportedScheme,
        'Only http and https URLs are supported',
      );
    }

    final normalizedUri = _normalizePodcastAudioUri(uri);
    final extension =
        _extensionFromUri(normalizedUri) ??
        _extensionFromMimeType(enclosureType) ??
        'mp3';
    final safeBaseName = _safeFileBaseName(
      _baseNameFromUri(normalizedUri, extension),
    );

    final dataDir = await _resolveDataDir();
    final audioId = _uuid.v4();
    final downloadedPath = await _downloadToTemp(
      resolved: ResolvedAudioImport(
        uri: normalizedUri,
        displayName: displayName,
        fileName: '$safeBaseName.$extension',
        extension: extension,
      ),
      audioId: audioId,
      dataDir: dataDir,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    final finalizedAudio = await _finalizeDownloadedAudio(
      dataDir: dataDir,
      tempRelativePath: downloadedPath,
      cancelToken: cancelToken,
    );

    final duration = await _tryReadDuration(finalizedAudio.relativePath);
    return DownloadedAudio(
      relativePath: finalizedAudio.relativePath,
      durationSeconds: duration,
      created: finalizedAudio.created,
      audioSha256: finalizedAudio.sha256,
      originalAudioSha256: finalizedAudio.originalSha256,
    );
  }

  /// 丢弃尚未写入 AudioItem 的下载结果，只删除本次新建的文件。
  Future<void> discardDownloadedAudio(DownloadedAudio downloaded) async {
    if (!downloaded.created) return;
    final dataDir = await _resolveDataDir();
    await _deleteIfExists(File(p.join(dataDir.path, downloaded.relativePath)));
  }

  Future<ResolvedAudioImport> resolveUrl(
    String input, {
    CancelToken? cancelToken,
  }) async {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AudioImportException(
        AudioImportFailureCode.invalidUrl,
        'Invalid audio URL',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const AudioImportException(
        AudioImportFailureCode.unsupportedScheme,
        'Only http and https URLs are supported',
      );
    }

    String? mimeType;
    try {
      final response = await _dio.head<Object>(
        trimmed,
        options: Options(followRedirects: true, validateStatus: (_) => true),
        cancelToken: cancelToken,
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 400) {
        mimeType = response.headers.value(Headers.contentTypeHeader);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const AudioImportException(
          AudioImportFailureCode.canceled,
          'Audio import canceled',
        );
      }
      // 部分服务器禁用 HEAD；后续 GET 下载时再失败。
    }

    final extFromUrl = _extensionFromUri(uri);
    final extFromMime = _extensionFromMimeType(mimeType);
    final extension = extFromUrl ?? extFromMime;
    final isAudioMime = mimeType == null || mimeType.startsWith('audio/');

    if (extension == null) {
      if (!isAudioMime) {
        throw AudioImportException(
          AudioImportFailureCode.notAudio,
          'URL does not point to an audio file',
        );
      }
      throw const AudioImportException(
        AudioImportFailureCode.unsupportedFormat,
        'Unsupported audio format',
      );
    }
    if (!supportedExtensions.contains(extension)) {
      throw AudioImportException(
        AudioImportFailureCode.unsupportedFormat,
        'Unsupported audio format: .$extension',
      );
    }
    if (!isAudioMime) {
      throw AudioImportException(
        AudioImportFailureCode.notAudio,
        'URL does not point to an audio file',
      );
    }

    final baseName = _baseNameFromUri(uri, extension);
    final safeBaseName = _safeFileBaseName(baseName);
    return ResolvedAudioImport(
      uri: uri,
      displayName: safeBaseName,
      fileName: '$safeBaseName.$extension',
      extension: extension,
      mimeType: mimeType,
    );
  }

  Future<String> _downloadToTemp({
    required ResolvedAudioImport resolved,
    required String audioId,
    required Directory dataDir,
    required CancelToken? cancelToken,
    required AudioImportProgressCallback? onProgress,
  }) async {
    final tmpDir = Directory(p.join(dataDir.path, 'tmp', 'audio_import'));
    await tmpDir.create(recursive: true);

    final downloadedFile = File(
      p.join(tmpDir.path, '$audioId.${resolved.extension}'),
    );
    try {
      try {
        await _backgroundDownloader.download(
          uri: resolved.uri,
          savePath: downloadedFile.path,
          displayName: resolved.displayName,
          cancelToken: cancelToken,
          onProgress: (received, total) => onProgress?.call(received, total),
        );
      } catch (error) {
        // 用户主动取消立即释放已落盘的部分文件；自然失败则保留，供下次继续。
        if (error is BackgroundFileDownloadException && error.isCanceled) {
          await _deleteIfExists(downloadedFile);
        }
        rethrow;
      }
      return p.join('tmp', 'audio_import', p.basename(downloadedFile.path));
    } on BackgroundFileDownloadException catch (e) {
      if (e.isCanceled) {
        throw const AudioImportException(
          AudioImportFailureCode.canceled,
          'Audio import canceled',
        );
      }
      _logDownloadFailure(resolved.uri, e);
      if (e.isStorageFailure) {
        throw AudioImportException(
          AudioImportFailureCode.storage,
          'Failed to save audio',
          e,
        );
      }
      throw AudioImportException(
        AudioImportFailureCode.network,
        'Failed to download audio',
        e,
      );
    } on FileSystemException catch (e) {
      throw AudioImportException(
        AudioImportFailureCode.storage,
        'Failed to save audio',
        e,
      );
    }
  }

  Future<FinalizedAudio> _finalizeDownloadedAudio({
    required Directory dataDir,
    required String tempRelativePath,
    CancelToken? cancelToken,
  }) {
    return _finalizationService.finalize(
      dataDir: dataDir,
      tempRelativePath: tempRelativePath,
      targetSubdir: p.join('audios', 'imported'),
      cancelToken: cancelToken,
    );
  }

  Future<int> _tryReadDuration(String relativePath) async {
    try {
      return await _readDurationSeconds(relativePath);
    } catch (_) {
      return 0;
    }
  }

  String? _extensionFromUri(Uri uri) {
    final ext = p.extension(uri.path).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) return null;
    return ext;
  }

  /// BBC RSS 历史数据常落库为 HTTP enclosure，而同一 feed 同时提供 HTTPS 版本。
  /// Anchor 的 podcast/play enclosure 会把真实媒体 URL 编码在路径最后一段；
  /// 直接请求该地址，避免下载器依赖 Anchor 重定向服务。
  /// BBC RSS 历史数据则升级到 HTTPS，避免 Android cleartext 策略拦截 HTTP。
  Uri _normalizePodcastAudioUri(Uri uri) {
    if (uri.host == 'anchor.fm' || uri.host == 'www.anchor.fm') {
      final segments = uri.pathSegments;
      if (segments.length >= 5 &&
          segments[2] == 'podcast' &&
          segments[3] == 'play') {
        try {
          final mediaUri = Uri.tryParse(Uri.decodeComponent(segments.last));
          if (mediaUri != null &&
              (mediaUri.scheme == 'http' || mediaUri.scheme == 'https') &&
              mediaUri.host.isNotEmpty) {
            AppLogger.log(
              _logTag,
              'resolved Anchor media URL host=${mediaUri.host}',
            );
            return mediaUri;
          }
        } on FormatException {
          // URL 编码损坏时保留原始 enclosure，让下载器返回实际错误。
        }
      }
    }
    if (uri.scheme != 'http' || uri.host != 'open.live.bbc.co.uk') {
      return uri;
    }
    final segments = uri.pathSegments;
    final protoIndex = segments.indexOf('proto');
    if (protoIndex == -1 || protoIndex + 1 >= segments.length) {
      return uri.replace(scheme: 'https');
    }
    final nextSegments = List<String>.from(segments);
    if (nextSegments[protoIndex + 1] == 'http') {
      nextSegments[protoIndex + 1] = 'https';
    }
    return uri.replace(scheme: 'https', pathSegments: nextSegments);
  }

  void _logDownloadFailure(Uri uri, BackgroundFileDownloadException error) {
    AppLogger.log(
      _logTag,
      'download failed host=${uri.host} '
      'status=${error.statusCode ?? "(null)"} '
      'storage=${error.isStorageFailure}',
    );
  }

  String? _extensionFromMimeType(String? mimeType) {
    if (mimeType == null) return null;
    final normalized = mimeType.split(';').first.trim().toLowerCase();
    return switch (normalized) {
      'audio/mpeg' || 'audio/mp3' => 'mp3',
      'audio/wav' || 'audio/x-wav' => 'wav',
      'audio/mp4' || 'audio/x-m4a' => 'm4a',
      'audio/aac' => 'aac',
      'audio/flac' || 'audio/x-flac' => 'flac',
      _ => null,
    };
  }

  String _baseNameFromUri(Uri uri, String extension) {
    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final decoded = Uri.decodeComponent(lastSegment);
    final withoutExt = p.basenameWithoutExtension(decoded);
    if (withoutExt.trim().isNotEmpty) return withoutExt.trim();
    return 'audio-$extension';
  }

  String _safeFileBaseName(String input) {
    final replaced = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (replaced.isEmpty) return 'audio';
    return replaced.length > 80 ? replaced.substring(0, 80).trim() : replaced;
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}
