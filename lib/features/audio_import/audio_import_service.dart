import 'dart:async';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:universal_io/io.dart';

import '../../models/audio_item.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import '../../utils/app_data_dir.dart';
import '../../utils/audio_duration.dart';
import '../../utils/audio_fingerprint.dart';
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
  AudioImportService({
    Dio? dio,
    Uuid? uuid,
    Future<Directory> Function()? resolveDataDir,
    Future<String> Function(String absolutePath)? computeSha256,
    Future<int> Function(String relativePath)? readDurationSeconds,
    AudioRegistrationService? registrationService,
    AudioTranscodeService? transcodeService,
  }) : _dio = dio ?? Dio(),
       _uuid = uuid ?? const Uuid(),
       _resolveDataDir = resolveDataDir ?? getAppDataDirectory,
       _computeSha256 = computeSha256 ?? computeAudioSha256,
       _readDurationSeconds = readDurationSeconds ?? getAudioDurationSeconds,
       _registrationService =
           registrationService ?? AudioRegistrationService(uuid: uuid),
       _transcodeService =
           transcodeService ?? AudioTranscodeService(uuid: uuid);

  final Dio _dio;
  final Uuid _uuid;
  final Future<Directory> Function() _resolveDataDir;
  final Future<String> Function(String absolutePath) _computeSha256;
  final Future<int> Function(String relativePath) _readDurationSeconds;
  final AudioRegistrationService _registrationService;
  final AudioTranscodeService _transcodeService;

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
    final existingResult = await _registrationService
        .registerExistingAudioByName(
          name: resolved.displayName,
          audioLibraryState: audioLibraryState,
          collectionList: collectionList,
          collectionState: collectionState,
          collectionId: collectionId,
        );
    switch (existingResult) {
      case AudioRegistrationAdded(:final item):
        return item;
      case AudioRegistrationDuplicate(:final name):
        throw AudioImportException(
          AudioImportFailureCode.duplicate,
          'Audio already exists: $name',
        );
      case null:
        break;
    }

    final dataDir = await _resolveDataDir();
    final audioId = _uuid.v4();
    final downloadedPath = await _downloadToTemp(
      resolved: resolved,
      audioId: audioId,
      dataDir: dataDir,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    final relativeAudioPath = await _finalizeDownloadedAudio(
      dataDir: dataDir,
      tempRelativePath: downloadedPath,
      requestedFileName: resolved.fileName,
    );

    final absoluteAudioPath = p.join(dataDir.path, relativeAudioPath);
    final sha256 = await _tryComputeSha256(absoluteAudioPath);
    final result = await _registrationService.registerSandboxedAudio(
      input: SandboxedAudioRegistrationInput(
        name: resolved.displayName,
        relativePath: relativeAudioPath,
        importSourceType: AudioImportSourceType.directUrl,
        importSourceUrl: resolved.uri.toString(),
        audioSha256: sha256,
      ),
      audioLibrary: audioLibrary,
      audioLibraryState: audioLibraryState,
      collectionList: collectionList,
      collectionState: collectionState,
      collectionId: collectionId,
    );

    switch (result) {
      case AudioRegistrationAdded(:final item):
        return item;
      case AudioRegistrationDuplicate(:final name):
        throw AudioImportException(
          AudioImportFailureCode.duplicate,
          'Audio already exists: $name',
        );
    }
  }

  /// 下载 podcast 单集 enclosure 到沙盒，仅落盘并返回文件信息，**不创建 [AudioItem]**。
  ///
  /// 与 [importFromUrl] 的区别：跳过严格的直链 MIME/音频校验（podcast enclosure
  /// 常返回 `application/octet-stream` 或经重定向域名分发），扩展名按
  /// URL 后缀 → enclosureType → `mp3` 兜底确定。调用方拿到结果后自行更新已存在的
  /// 占位条目（保留 podcast 元字段），避免在资源库产生重复孤儿条目。
  Future<DownloadedAudio> downloadEpisodeToSandbox({
    required String url,
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

    final extension =
        _extensionFromUri(uri) ??
        _extensionFromMimeType(enclosureType) ??
        'mp3';
    final safeBaseName = _safeFileBaseName(_baseNameFromUri(uri, extension));

    final dataDir = await _resolveDataDir();
    final audioId = _uuid.v4();
    final downloadedPath = await _downloadToTemp(
      resolved: ResolvedAudioImport(
        uri: uri,
        displayName: safeBaseName,
        fileName: '$safeBaseName.$extension',
        extension: extension,
      ),
      audioId: audioId,
      dataDir: dataDir,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    final relativeAudioPath = await _finalizeDownloadedAudio(
      dataDir: dataDir,
      tempRelativePath: downloadedPath,
      requestedFileName: '$safeBaseName.$extension',
    );

    final absoluteAudioPath = p.join(dataDir.path, relativeAudioPath);
    final sha256 = await _tryComputeSha256(absoluteAudioPath);
    final duration = await _tryReadDuration(relativeAudioPath);
    return DownloadedAudio(
      relativePath: relativeAudioPath,
      durationSeconds: duration,
      audioSha256: sha256,
    );
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
    int? contentLength;
    try {
      final response = await _dio.head<Object>(
        trimmed,
        options: Options(followRedirects: true, validateStatus: (_) => true),
        cancelToken: cancelToken,
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 400) {
        mimeType = response.headers.value(Headers.contentTypeHeader);
        contentLength = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        );
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
      contentLength: contentLength,
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

    final tmpFile = File(p.join(tmpDir.path, '$audioId.part'));
    final downloadedFile = File(
      p.join(tmpDir.path, '$audioId.${resolved.extension}'),
    );
    try {
      await _dio.download(
        resolved.uri.toString(),
        tmpFile.path,
        cancelToken: cancelToken,
        options: Options(followRedirects: true),
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total <= 0 ? null : total);
        },
      );
      await tmpFile.rename(downloadedFile.path);
      return p.join('tmp', 'audio_import', p.basename(downloadedFile.path));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const AudioImportException(
          AudioImportFailureCode.canceled,
          'Audio import canceled',
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
    } finally {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<String> _finalizeDownloadedAudio({
    required Directory dataDir,
    required String tempRelativePath,
    required String requestedFileName,
  }) async {
    final audioDir = Directory(p.join(dataDir.path, 'audios', 'imported'));
    await audioDir.create(recursive: true);

    final transcodeResult = await _transcodeService.transcodeToM4a(
      dataDir: dataDir,
      relativePath: tempRelativePath,
    );
    final sourceRelativePath = transcodeResult.relativePath;
    final sourceFile = File(p.join(dataDir.path, sourceRelativePath));
    final requestedBaseName = p.basenameWithoutExtension(requestedFileName);
    final targetName = transcodeResult.transcoded
        ? '$requestedBaseName.m4a'
        : requestedFileName;
    final finalName = await _uniqueFileName(audioDir, targetName);
    final finalFile = File(p.join(audioDir.path, finalName));

    await _moveAudioToFinal(sourceFile: sourceFile, finalFile: finalFile);
    await _deleteTempAudioSibling(dataDir, tempRelativePath);
    return p.join('audios', 'imported', finalName);
  }

  /// 将临时音频移动到正式目录；跨卷 rename 失败时回退 copy，并清理半成品。
  Future<void> _moveAudioToFinal({
    required File sourceFile,
    required File finalFile,
  }) async {
    try {
      await sourceFile.rename(finalFile.path);
      return;
    } on FileSystemException {
      try {
        await sourceFile.copy(finalFile.path);
        await _deleteIfExists(sourceFile);
        return;
      } on FileSystemException catch (e) {
        await _deleteIfExists(finalFile);
        throw AudioImportException(
          AudioImportFailureCode.storage,
          'Failed to save audio',
          e,
        );
      }
    }
  }

  Future<String> _uniqueFileName(Directory dir, String requested) async {
    final base = p.basenameWithoutExtension(requested);
    final ext = p.extension(requested);
    var candidate = requested;
    var index = 1;
    while (await File(p.join(dir.path, candidate)).exists()) {
      final suffix = _uuid.v4().substring(0, 8);
      candidate = '$base-$suffix$ext';
      index++;
      if (index > 20) {
        candidate = '${_uuid.v4()}$ext';
        break;
      }
    }
    return candidate;
  }

  Future<String?> _tryComputeSha256(String absolutePath) async {
    try {
      return await _computeSha256(absolutePath);
    } catch (_) {
      return null;
    }
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

  Future<void> _deleteTempAudioSibling(
    Directory dataDir,
    String tempRelativePath,
  ) async {
    final tempFile = File(p.join(dataDir.path, tempRelativePath));
    await _deleteIfExists(tempFile);
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}
