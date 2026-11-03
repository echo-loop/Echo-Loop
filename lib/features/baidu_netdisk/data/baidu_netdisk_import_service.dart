/// 百度网盘音频导入服务。
library;

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import '../../../models/audio_item.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../services/app_logger.dart';
import '../../../utils/app_data_dir.dart';
import '../../../utils/transcript_picker.dart';
import '../../audio_import/audio_import_cancel.dart';
import '../../audio_import/audio_finalization_service.dart';
import '../../audio_import/audio_import_models.dart';
import '../../audio_import/audio_registration_service.dart';
import '../../audio_import/subtitle_pairing.dart';
import '../models/cloud_drive_models.dart';
import 'baidu_credential_repository.dart';
import 'baidu_netdisk_api.dart';

/// 百度网盘导入进度回调。
typedef BaiduNetdiskImportProgressCallback =
    void Function(CloudDriveEntry entry, int receivedBytes, int? totalBytes);

/// 百度网盘批量导入中单条音频的最终结果回调。
typedef BaiduNetdiskImportItemResultCallback =
    void Function(CloudDriveImportItemResult result);

/// 百度网盘导入后给音频挂载字幕的回调。
typedef BaiduNetdiskSubtitleImporter =
    Future<void> Function(
      AudioItem item, {
      required String text,
      required String ext,
    });

/// 百度网盘音频导入服务抽象。
abstract interface class BaiduNetdiskImportService {
  /// 导入单个百度网盘音频文件。
  Future<AudioItem> importAudio({
    required CloudDriveEntry entry,
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
  });

  /// 批量导入百度网盘音频文件。
  Future<CloudDriveImportOutcome> importAudios({
    required List<CloudDriveEntry> entries,
    List<CloudDriveEntry> subtitleEntries = const <CloudDriveEntry>[],
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  });
}

/// 默认百度网盘导入服务。
class DefaultBaiduNetdiskImportService implements BaiduNetdiskImportService {
  /// 构造默认实现。
  DefaultBaiduNetdiskImportService({
    required BaiduCredentialRepository credentialRepository,
    required BaiduNetdiskApi api,
    Future<Directory> Function()? resolveDataDir,
    AudioFinalizationService? finalizationService,
    AudioRegistrationService? registrationService,
    BaiduNetdiskSubtitleImporter? subtitleImporter,
  }) : _credentialRepository = credentialRepository,
       _api = api,
       _resolveDataDir = resolveDataDir ?? getAppDataDirectory,
       _finalizationService = finalizationService ?? AudioFinalizationService(),
       _registrationService = registrationService ?? AudioRegistrationService(),
       _subtitleImporter = subtitleImporter;

  final BaiduCredentialRepository _credentialRepository;
  final BaiduNetdiskApi _api;
  final Future<Directory> Function() _resolveDataDir;
  final AudioFinalizationService _finalizationService;
  final AudioRegistrationService _registrationService;
  final BaiduNetdiskSubtitleImporter? _subtitleImporter;

  @override
  Future<AudioItem> importAudio({
    required CloudDriveEntry entry,
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  }) async {
    if (entry.isDirectory) {
      throw AudioImportException(
        AudioImportFailureCode.unsupportedFormat,
        'Cannot import a directory: ${entry.name}',
      );
    }
    if (!isImportablePrimaryMediaExtension(entry.extension)) {
      throw AudioImportException(
        AudioImportFailureCode.unsupportedFormat,
        'Unsupported media format: .${entry.extension}',
      );
    }

    final accessToken = await _credentialRepository.getValidAccessToken();
    if (accessToken == null) {
      throw const BaiduReauthorizationRequiredException();
    }

    final dataDir = await _resolveDataDir();
    final tempRelativePath = await _downloadToTemp(
      accessToken: accessToken,
      entry: entry,
      dataDir: dataDir,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    return _finalizeAndRegisterAudio(
      entry: entry,
      dataDir: dataDir,
      tempRelativePath: tempRelativePath,
      audioLibrary: audioLibrary,
      audioLibraryState: audioLibraryState,
      collectionList: collectionList,
      collectionState: collectionState,
      collectionId: collectionId,
      cancelToken: cancelToken,
    );
  }

  Future<AudioItem> _finalizeAndRegisterAudio({
    required CloudDriveEntry entry,
    required Directory dataDir,
    required String tempRelativePath,
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    required CollectionList? collectionList,
    required CollectionState? collectionState,
    required String? collectionId,
    required CancelToken? cancelToken,
  }) async {
    final targetSubdir = isVideoImportExtension(entry.extension)
        ? 'videos'
        : p.join('audios', 'imported');
    FinalizedAudio? finalizedAudio;
    try {
      finalizedAudio = await _finalizationService.finalize(
        dataDir: dataDir,
        tempRelativePath: tempRelativePath,
        targetSubdir: targetSubdir,
        cancelToken: cancelToken,
      );
      cancelToken?.throwIfCanceled();

      final result = await _registrationService.registerSandboxedAudio(
        input: SandboxedAudioRegistrationInput(
          name: _displayNameForEntry(entry),
          relativePath: finalizedAudio.relativePath,
          importSourceType: AudioImportSourceType.cloudDrive,
          importSourceUrl: _sourceUrlForEntry(entry),
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

  @override
  Future<CloudDriveImportOutcome> importAudios({
    required List<CloudDriveEntry> entries,
    List<CloudDriveEntry> subtitleEntries = const <CloudDriveEntry>[],
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  }) async {
    final added = <CloudDriveEntry>[];
    final addedItems = <AudioItem>[];
    final duplicateDetails = <AudioImportDuplicate>[];
    final duplicateEntries = <CloudDriveEntry>[];
    final failures = <CloudDriveImportFailure>[];
    var currentLibraryState = audioLibraryState;
    var wasCanceled = false;
    final subtitleByAudio = _matchSubtitleEntries(entries, subtitleEntries);
    final dataDir = await _resolveDataDir();
    final accessToken = await _credentialRepository.getValidAccessToken();
    if (accessToken == null) {
      throw const BaiduReauthorizationRequiredException();
    }

    final requestsById = <String, BaiduNetdiskDownloadRequest>{};
    final failuresByRequestId = <String, Object>{};
    final entryByAudioRequestId = <String, CloudDriveEntry>{};
    final requestIdByAudioId = <int, String>{};
    final requestIdBySubtitleAudioId = <int, String>{};
    final subtitleByRequestId = <String, CloudDriveEntry>{};

    // 先解析整批 dlink，再交给原生下载队列，后台挂起时队列也能启动后续文件。
    for (final entry in entries) {
      if (cancelToken?.isCancelled ?? false) {
        wasCanceled = true;
        break;
      }
      final requestId = 'audio-${entry.fsId}';
      requestIdByAudioId[entry.fsId] = requestId;
      entryByAudioRequestId[requestId] = entry;
      try {
        _validateImportEntry(entry);
        final link = await _api.fetchDownloadLink(
          accessToken: accessToken,
          fsId: entry.fsId,
        );
        requestsById[requestId] = BaiduNetdiskDownloadRequest(
          id: requestId,
          fsId: entry.fsId,
          displayName: entry.name,
          dlink: link.dlink,
          savePath: _temporaryPath(dataDir, entry),
        );
      } on Object catch (error) {
        failuresByRequestId[requestId] = error;
      }
    }

    if (!wasCanceled && _subtitleImporter != null) {
      for (final entry in entries) {
        final subtitle = subtitleByAudio[entry.fsId];
        if (subtitle == null) continue;
        if (cancelToken?.isCancelled ?? false) {
          wasCanceled = true;
          break;
        }
        final requestId = 'subtitle-${subtitle.fsId}';
        requestIdBySubtitleAudioId[entry.fsId] = requestId;
        subtitleByRequestId[requestId] = subtitle;
        try {
          final link = await _api.fetchDownloadLink(
            accessToken: accessToken,
            fsId: subtitle.fsId,
          );
          requestsById[requestId] = BaiduNetdiskDownloadRequest(
            id: requestId,
            fsId: subtitle.fsId,
            displayName: subtitle.name,
            dlink: link.dlink,
            savePath: _temporaryPath(dataDir, subtitle),
          );
        } on Object catch (error) {
          failuresByRequestId[requestId] = error;
        }
      }
    }

    final resultsById = <String, BaiduNetdiskDownloadItemResult>{};
    final requests = requestsById.values.toList(growable: false);
    if (!wasCanceled && requests.isNotEmpty) {
      final results = await _api.downloadFiles(
        accessToken: accessToken,
        requests: requests,
        cancelToken: cancelToken,
        onProgress: (requestId, received, total) {
          final entry = entryByAudioRequestId[requestId];
          if (entry != null) onProgress?.call(entry, received, total);
        },
      );
      for (final result in results) {
        resultsById[result.request.id] = result;
      }

      // dlink 过期或网络错误仍刷新一次，再把失败任务交回同一通用队列。
      final retryRequests = <BaiduNetdiskDownloadRequest>[];
      for (final result in results) {
        final failure = result.failure;
        if (failure == null || !_shouldRefreshDlink(failure)) continue;
        try {
          final refreshed = await _api.fetchDownloadLink(
            accessToken: accessToken,
            fsId: result.request.fsId,
          );
          retryRequests.add(
            BaiduNetdiskDownloadRequest(
              id: result.request.id,
              fsId: result.request.fsId,
              displayName: result.request.displayName,
              dlink: refreshed.dlink,
              savePath: result.request.savePath,
            ),
          );
        } on Object catch (error) {
          failuresByRequestId[result.request.id] = error;
        }
      }
      if (retryRequests.isNotEmpty && !(cancelToken?.isCancelled ?? false)) {
        final retryResults = await _api.downloadFiles(
          accessToken: accessToken,
          requests: retryRequests,
          cancelToken: cancelToken,
          onProgress: (requestId, received, total) {
            final entry = entryByAudioRequestId[requestId];
            if (entry != null) onProgress?.call(entry, received, total);
          },
        );
        for (final result in retryResults) {
          resultsById[result.request.id] = result;
        }
      }
    }
    if (cancelToken?.isCancelled ?? false) wasCanceled = true;

    try {
      for (final entry in entries) {
        final requestId =
            requestIdByAudioId[entry.fsId] ?? 'audio-${entry.fsId}';
        final error =
            failuresByRequestId[requestId] ?? resultsById[requestId]?.failure;
        if (error != null) {
          if (_isCanceled(error)) {
            wasCanceled = true;
            continue;
          }
          _reportFailure(entry, error, failures, onItemResult);
          continue;
        }
        final request = requestsById[requestId];
        if (request == null) {
          if (cancelToken?.isCancelled ?? false) {
            wasCanceled = true;
            continue;
          }
          _reportFailure(
            entry,
            StateError('Missing prepared download for ${entry.name}'),
            failures,
            onItemResult,
          );
          continue;
        }
        if (!resultsById.containsKey(requestId)) {
          if (cancelToken?.isCancelled ?? false) {
            wasCanceled = true;
            continue;
          }
          _reportFailure(
            entry,
            StateError('Missing completed download for ${entry.name}'),
            failures,
            onItemResult,
          );
          continue;
        }

        try {
          // 取消整批时仍完成已下载文件的入库，避免丢弃此前已完成的任务。
          final itemCancelToken = cancelToken?.isCancelled ?? false
              ? null
              : cancelToken;
          final item = await _finalizeAndRegisterAudio(
            entry: entry,
            dataDir: dataDir,
            tempRelativePath: p.relative(request.savePath, from: dataDir.path),
            audioLibrary: audioLibrary,
            audioLibraryState: currentLibraryState,
            collectionList: collectionList,
            collectionState: collectionState,
            collectionId: collectionId,
            cancelToken: itemCancelToken,
          );
          var importedItem = item;
          final subtitleRequestId = requestIdBySubtitleAudioId[entry.fsId];
          final subtitleRequest = subtitleRequestId == null
              ? null
              : requestsById[subtitleRequestId];
          final subtitleError = subtitleRequestId == null
              ? null
              : failuresByRequestId[subtitleRequestId] ??
                    resultsById[subtitleRequestId]?.failure;
          final subtitleCanceled =
              subtitleError != null && _isCanceled(subtitleError);
          if (subtitleError != null) {
            AppLogger.log(
              'BaiduNetdiskImport',
              'subtitle download failed for "${entry.name}": $subtitleError',
            );
          }
          if (subtitleCanceled) wasCanceled = true;
          if (subtitleRequest != null && subtitleError == null) {
            final subtitle = subtitleByRequestId[subtitleRequestId];
            if (subtitle != null &&
                await _attachDownloadedSubtitle(
                  item: importedItem,
                  subtitleEntry: subtitle,
                  savePath: subtitleRequest.savePath,
                  cancelToken: itemCancelToken,
                )) {
              importedItem = importedItem.copyWith(
                transcriptSource: TranscriptSource.local,
              );
            }
          }
          added.add(entry);
          addedItems.add(importedItem);
          onItemResult?.call(
            CloudDriveImportItemResult.added(entry: entry, item: importedItem),
          );
          currentLibraryState = currentLibraryState.copyWith(
            audioItems: [...currentLibraryState.audioItems, importedItem],
          );
        } on AudioImportException catch (error) {
          if (error.code == AudioImportFailureCode.canceled) {
            wasCanceled = true;
            break;
          }
          if (error.code == AudioImportFailureCode.duplicate) {
            final existingName = _existingNameFromDuplicateMessage(
              error.message,
            );
            duplicateEntries.add(entry);
            duplicateDetails.add((
              attempted: _displayNameForEntry(entry),
              existing: existingName,
            ));
            onItemResult?.call(
              CloudDriveImportItemResult.duplicate(
                entry: entry,
                existingName: existingName,
              ),
            );
            continue;
          }
          _reportFailure(entry, error, failures, onItemResult);
        } on Object catch (error, stackTrace) {
          if (_isCanceled(error)) {
            wasCanceled = true;
            break;
          }
          AppLogger.log(
            'BaiduNetdiskImport',
            'import "${entry.name}" failed unexpectedly: $error\n$stackTrace',
          );
          _reportFailure(entry, error, failures, onItemResult);
        }
      }
    } finally {
      for (final request in requestsById.values) {
        await _deleteIfExists(File(request.savePath));
      }
    }

    return CloudDriveImportOutcome(
      added: added,
      addedItems: addedItems,
      duplicateDetails: duplicateDetails,
      duplicateEntries: duplicateEntries,
      failures: failures,
      wasCanceled: wasCanceled,
    );
  }

  Map<int, CloudDriveEntry> _matchSubtitleEntries(
    List<CloudDriveEntry> audioEntries,
    List<CloudDriveEntry> subtitleEntries,
  ) {
    if (audioEntries.isEmpty || subtitleEntries.isEmpty) {
      return const <int, CloudDriveEntry>{};
    }
    final entriesByName = <String, CloudDriveEntry>{
      for (final entry in [...audioEntries, ...subtitleEntries])
        entry.name: entry,
    };
    final pairing = matchSubtitlesForAudios(entriesByName.keys);
    final result = <int, CloudDriveEntry>{};
    for (final audio in audioEntries) {
      final subtitleName = pairing[audio.name];
      final subtitle = subtitleName == null
          ? null
          : entriesByName[subtitleName];
      if (subtitle != null) result[audio.fsId] = subtitle;
    }
    return result;
  }

  /// 验证批量导入中的主媒体类型。
  void _validateImportEntry(CloudDriveEntry entry) {
    if (entry.isDirectory) {
      throw AudioImportException(
        AudioImportFailureCode.unsupportedFormat,
        'Cannot import a directory: ${entry.name}',
      );
    }
    if (!isImportablePrimaryMediaExtension(entry.extension)) {
      throw AudioImportException(
        AudioImportFailureCode.unsupportedFormat,
        'Unsupported media format: .${entry.extension}',
      );
    }
  }

  /// 生成可供平台任务和后处理共用的沙盒临时文件路径。
  String _temporaryPath(Directory dataDir, CloudDriveEntry entry) => p.join(
    dataDir.path,
    'tmp',
    'baidu_netdisk',
    '${entry.fsId}.${entry.extension}',
  );

  bool _isCanceled(Object error) => switch (error) {
    AudioImportException(code: AudioImportFailureCode.canceled) => true,
    BaiduNetdiskFileException(kind: BaiduNetdiskFileErrorKind.canceled) => true,
    DioException() when CancelToken.isCancel(error) => true,
    _ => false,
  };

  void _reportFailure(
    CloudDriveEntry entry,
    Object error,
    List<CloudDriveImportFailure> failures,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  ) {
    final failure = CloudDriveImportFailure(
      entry: entry,
      message: switch (error) {
        AudioImportException(:final message) => message,
        BaiduNetdiskFileException(:final message) => message,
        _ => _messageForUnexpectedError(error),
      },
      errorKind: switch (error) {
        AudioImportException(:final code) => code.name,
        BaiduNetdiskFileException(:final kind) => kind.name,
        _ => 'unknown',
      },
    );
    failures.add(failure);
    onItemResult?.call(
      CloudDriveImportItemResult.failed(entry: entry, failure: failure),
    );
  }

  Future<bool> _attachDownloadedSubtitle({
    required AudioItem item,
    required CloudDriveEntry subtitleEntry,
    required String savePath,
    required CancelToken? cancelToken,
  }) async {
    final importer = _subtitleImporter;
    if (importer == null || item.hasTranscript) return false;
    try {
      cancelToken?.throwIfCanceled();
      final decoded = await decodeTranscriptBytes(
        await File(savePath).readAsBytes(),
      );
      final text = decoded.text;
      await importer(item, text: text, ext: subtitleEntry.extension);
      AppLogger.log(
        'BaiduNetdiskImport',
        'attached subtitle "${subtitleEntry.name}" to "${item.name}"',
      );
      return true;
    } on BaiduNetdiskFileException catch (error) {
      if (error.kind == BaiduNetdiskFileErrorKind.canceled) rethrow;
      AppLogger.log(
        'BaiduNetdiskImport',
        'attach subtitle "${subtitleEntry.name}" to "${item.name}" failed: $error',
      );
    } on AudioImportException catch (error) {
      if (error.code == AudioImportFailureCode.canceled) rethrow;
      AppLogger.log(
        'BaiduNetdiskImport',
        'attach subtitle "${subtitleEntry.name}" to "${item.name}" failed: $error',
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const AudioImportException(
          AudioImportFailureCode.canceled,
          'Audio import canceled',
        );
      }
      AppLogger.log(
        'BaiduNetdiskImport',
        'attach subtitle "${subtitleEntry.name}" to "${item.name}" failed: $error',
      );
    } on Object catch (error) {
      AppLogger.log(
        'BaiduNetdiskImport',
        'attach subtitle "${subtitleEntry.name}" to "${item.name}" failed: $error',
      );
    }
    return false;
  }

  Future<String> _downloadToTemp({
    required String accessToken,
    required CloudDriveEntry entry,
    required Directory dataDir,
    required CancelToken? cancelToken,
    required BaiduNetdiskImportProgressCallback? onProgress,
  }) async {
    final tmpDir = Directory(p.join(dataDir.path, 'tmp', 'baidu_netdisk'));
    await tmpDir.create(recursive: true);
    final tempFile = File(
      p.join(tmpDir.path, '${entry.fsId}.${entry.extension}'),
    );
    try {
      await _downloadWithFreshLink(
        accessToken: accessToken,
        entry: entry,
        savePath: tempFile.path,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
      return p.join('tmp', 'baidu_netdisk', p.basename(tempFile.path));
    } on Object {
      await _deleteIfExists(tempFile);
      rethrow;
    }
  }

  Future<void> _downloadWithFreshLink({
    required String accessToken,
    required CloudDriveEntry entry,
    required String savePath,
    required CancelToken? cancelToken,
    required BaiduNetdiskImportProgressCallback? onProgress,
  }) async {
    final link = await _api.fetchDownloadLink(
      accessToken: accessToken,
      fsId: entry.fsId,
    );
    try {
      await _api.downloadToFile(
        accessToken: accessToken,
        dlink: link.dlink,
        savePath: savePath,
        resourceKey: baiduResourceKey(entry.fsId),
        cancelToken: cancelToken,
        onProgress: (received, total) =>
            onProgress?.call(entry, received, total),
      );
    } on BaiduNetdiskFileException catch (error) {
      if (!_shouldRefreshDlink(error)) rethrow;
      AppLogger.log(
        'BaiduNetdiskImport',
        'download "${entry.name}" failed with ${error.kind.name}; refreshing dlink once',
      );
      final refreshed = await _api.fetchDownloadLink(
        accessToken: accessToken,
        fsId: entry.fsId,
      );
      await _api.downloadToFile(
        accessToken: accessToken,
        dlink: refreshed.dlink,
        savePath: savePath,
        resourceKey: baiduResourceKey(entry.fsId),
        cancelToken: cancelToken,
        onProgress: (received, total) =>
            onProgress?.call(entry, received, total),
      );
    }
  }

  bool _shouldRefreshDlink(BaiduNetdiskFileException error) {
    return switch (error.kind) {
      BaiduNetdiskFileErrorKind.unauthorized ||
      BaiduNetdiskFileErrorKind.notFound ||
      BaiduNetdiskFileErrorKind.network => true,
      BaiduNetdiskFileErrorKind.badRequest ||
      BaiduNetdiskFileErrorKind.rateLimited ||
      BaiduNetdiskFileErrorKind.canceled ||
      BaiduNetdiskFileErrorKind.unknown => false,
    };
  }

  String _displayNameForEntry(CloudDriveEntry entry) {
    final name = p.basenameWithoutExtension(entry.name).trim();
    return name.isEmpty ? entry.name : name;
  }

  String _existingNameFromDuplicateMessage(String message) {
    const prefix = 'Audio already exists: ';
    if (!message.startsWith(prefix)) return message;
    return message.substring(prefix.length);
  }

  String _sourceUrlForEntry(CloudDriveEntry entry) {
    return 'baidunetdisk://fs/${entry.fsId}?path=${Uri.encodeComponent(entry.path)}';
  }

  String _messageForUnexpectedError(Object error) {
    final message = error.toString().trim();
    return message.isEmpty ? 'Baidu Netdisk import failed.' : message;
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}
