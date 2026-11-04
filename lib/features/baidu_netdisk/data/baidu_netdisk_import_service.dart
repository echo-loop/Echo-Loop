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
typedef BaiduNetdiskImportProgressCallback = void Function(
  CloudDriveEntry entry,
  int receivedBytes,
  int? totalBytes,
);

/// 百度网盘导入后给音频挂载字幕的回调。
typedef BaiduNetdiskSubtitleImporter = Future<void> Function(
  AudioItem item, {
  required String text,
  required String ext,
});

/// 百度网盘音频导入服务抽象。
abstract interface class BaiduNetdiskImportService {
  /// 一次性获取一批文件的下载 dlink。dlink 有效期约 8 小时，入队时取好即可，
  /// 不必等到真正下载时再取，这样 App 进入后台后原生队列仍能自行推进。
  ///
  /// 返回的 map 不含百度未给出链接的文件；由 [importAudio] 处理缺失。
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required List<CloudDriveEntry> entries,
  });

  /// 导入单个百度网盘音频文件；提供 [subtitleEntry] 时同批下载并挂载字幕。
  ///
  /// [downloadLinks] 由 [fetchDownloadLinks] 预先取得。重复、失败、取消均以异常表达
  /// （[AudioImportException]）。字幕失败只记日志，不影响已入库的音频。
  ///
  /// 库状态通过 reader 在注册时读取，而不是在任务开始时快照：同批任务并发下载，
  /// 快照会漏掉先完成的兄弟任务，导致重复检测失效。
  Future<AudioItem> importAudio({
    required CloudDriveEntry entry,
    CloudDriveEntry? subtitleEntry,
    required AudioLibrary audioLibrary,
    required AudioLibraryState Function() readAudioLibraryState,
    CollectionList? collectionList,
    CollectionState? Function()? readCollectionState,
    String? collectionId,
    required Map<int, BaiduDownloadLink> downloadLinks,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
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
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required List<CloudDriveEntry> entries,
  }) async {
    final accessToken = await _requireAccessToken();
    return _api.fetchDownloadLinks(
      accessToken: accessToken,
      fsIds: [for (final entry in entries) entry.fsId],
    );
  }

  @override
  Future<AudioItem> importAudio({
    required CloudDriveEntry entry,
    CloudDriveEntry? subtitleEntry,
    required AudioLibrary audioLibrary,
    required AudioLibraryState Function() readAudioLibraryState,
    CollectionList? collectionList,
    CollectionState? Function()? readCollectionState,
    String? collectionId,
    required Map<int, BaiduDownloadLink> downloadLinks,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
  }) async {
    _validateImportEntry(entry);

    // 同一百度文件已在资源库中：不重复下载音频，只做合集关联与字幕挂载。
    final existingItem = findBaiduLibraryItem(
      readAudioLibraryState().audioItems,
      entry.fsId,
    );
    if (existingItem != null) {
      return _attachToExistingItem(
        existingItem: existingItem,
        subtitleEntry: subtitleEntry,
        audioLibrary: audioLibrary,
        collectionList: collectionList,
        readCollectionState: readCollectionState,
        collectionId: collectionId,
        downloadLinks: downloadLinks,
        cancelToken: cancelToken,
      );
    }

    final accessToken = await _requireAccessToken();

    final dataDir = await _resolveDataDir();
    final tempRelativePath = await _downloadToTemp(
      accessToken: accessToken,
      entry: entry,
      dataDir: dataDir,
      downloadLinks: downloadLinks,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    final item = await _finalizeAndRegisterAudio(
      entry: entry,
      dataDir: dataDir,
      tempRelativePath: tempRelativePath,
      audioLibrary: audioLibrary,
      readAudioLibraryState: readAudioLibraryState,
      collectionList: collectionList,
      readCollectionState: readCollectionState,
      collectionId: collectionId,
      cancelToken: cancelToken,
    );
    final importer = _subtitleImporter;
    if (subtitleEntry == null || importer == null) return item;
    return _attachSubtitleEntry(
      item: item,
      subtitleEntry: subtitleEntry,
      dataDir: dataDir,
      accessToken: accessToken,
      downloadLinks: downloadLinks,
      cancelToken: cancelToken,
    );
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _credentialRepository.getValidAccessToken();
    if (accessToken == null) {
      throw const BaiduReauthorizationRequiredException();
    }
    return accessToken;
  }

  /// 已导入的素材再次导入：加入目标合集（若尚未在其中），并在没有字幕时补挂字幕。
  Future<AudioItem> _attachToExistingItem({
    required AudioItem existingItem,
    required CloudDriveEntry? subtitleEntry,
    required AudioLibrary audioLibrary,
    required CollectionList? collectionList,
    required CollectionState? Function()? readCollectionState,
    required String? collectionId,
    required Map<int, BaiduDownloadLink> downloadLinks,
    required CancelToken? cancelToken,
  }) async {
    AppLogger.log(
      'BaiduNetdiskImport',
      '素材已在资源库中，跳过音频下载 item=${existingItem.id}',
    );
    if (collectionId != null) {
      final audioIds =
          readCollectionState?.call()?.getAudioIds(collectionId) ??
          const <String>[];
      if (!audioIds.contains(existingItem.id)) {
        await collectionList?.addAudioToCollection(
          collectionId,
          existingItem.id,
        );
      }
    }
    final importer = _subtitleImporter;
    if (subtitleEntry == null ||
        importer == null ||
        existingItem.hasTranscript) {
      return existingItem;
    }
    return _attachSubtitleEntry(
      item: existingItem,
      subtitleEntry: subtitleEntry,
      dataDir: await _resolveDataDir(),
      accessToken: await _requireAccessToken(),
      downloadLinks: downloadLinks,
      cancelToken: cancelToken,
    );
  }

  /// 下载同名字幕并挂载到已入库的音频。字幕任何失败只记日志，音频保持入库。
  Future<AudioItem> _attachSubtitleEntry({
    required AudioItem item,
    required CloudDriveEntry subtitleEntry,
    required Directory dataDir,
    required String accessToken,
    required Map<int, BaiduDownloadLink> downloadLinks,
    required CancelToken? cancelToken,
  }) async {
    final savePath = _temporaryPath(dataDir, subtitleEntry);
    try {
      // 已导入素材不会经过音频下载，临时目录需要在这里确保存在。
      await File(savePath).parent.create(recursive: true);
      await _downloadWithLink(
        accessToken: accessToken,
        entry: subtitleEntry,
        link: _linkFor(downloadLinks, subtitleEntry),
        savePath: savePath,
        cancelToken: cancelToken,
        onProgress: null,
      );
      final attached = await _attachDownloadedSubtitle(
        item: item,
        subtitleEntry: subtitleEntry,
        savePath: savePath,
        cancelToken: cancelToken,
      );
      return attached
          ? item.copyWith(transcriptSource: TranscriptSource.local)
          : item;
    } on Object catch (error) {
      AppLogger.log(
        'BaiduNetdiskImport',
        'subtitle download failed for "${item.name}": $error',
      );
      return item;
    } finally {
      await _deleteIfExists(File(savePath));
    }
  }

  Future<AudioItem> _finalizeAndRegisterAudio({
    required CloudDriveEntry entry,
    required Directory dataDir,
    required String tempRelativePath,
    required AudioLibrary audioLibrary,
    required AudioLibraryState Function() readAudioLibraryState,
    required CollectionList? collectionList,
    required CollectionState? Function()? readCollectionState,
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
        audioLibraryState: readAudioLibraryState(),
        collectionList: collectionList,
        collectionState: readCollectionState?.call(),
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
    required Map<int, BaiduDownloadLink> downloadLinks,
    required CancelToken? cancelToken,
    required BaiduNetdiskImportProgressCallback? onProgress,
  }) async {
    final tmpDir = Directory(p.join(dataDir.path, 'tmp', 'baidu_netdisk'));
    await tmpDir.create(recursive: true);
    final tempFile = File(
      p.join(tmpDir.path, '${entry.fsId}.${entry.extension}'),
    );
    try {
      await _downloadWithLink(
        accessToken: accessToken,
        entry: entry,
        link: _linkFor(downloadLinks, entry),
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

  /// 取出入队时批量获取的下载链接；缺失说明百度已无该文件的下载地址。
  BaiduDownloadLink _linkFor(
    Map<int, BaiduDownloadLink> downloadLinks,
    CloudDriveEntry entry,
  ) {
    final link = downloadLinks[entry.fsId];
    if (link == null) {
      throw const BaiduNetdiskFileException(
        kind: BaiduNetdiskFileErrorKind.notFound,
        message: 'Baidu download link is unavailable.',
      );
    }
    return link;
  }

  /// 使用已取得的 dlink 下载；若因链接失效等原因失败，重新获取一次 dlink 再试。
  Future<void> _downloadWithLink({
    required String accessToken,
    required CloudDriveEntry entry,
    required BaiduDownloadLink link,
    required String savePath,
    required CancelToken? cancelToken,
    required BaiduNetdiskImportProgressCallback? onProgress,
  }) async {
    try {
      await _api.downloadToFile(
        accessToken: accessToken,
        dlink: link.dlink,
        savePath: savePath,
        displayName: entry.name,
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
      final refreshed = await _fetchFreshLink(
        accessToken: accessToken,
        fsId: entry.fsId,
      );
      await _api.downloadToFile(
        accessToken: accessToken,
        dlink: refreshed.dlink,
        savePath: savePath,
        displayName: entry.name,
        resourceKey: baiduResourceKey(entry.fsId),
        cancelToken: cancelToken,
        onProgress: (received, total) =>
            onProgress?.call(entry, received, total),
      );
    }
  }

  Future<BaiduDownloadLink> _fetchFreshLink({
    required String accessToken,
    required int fsId,
  }) async {
    final links = await _api.fetchDownloadLinks(
      accessToken: accessToken,
      fsIds: [fsId],
    );
    return links[fsId] ??
        (throw const BaiduNetdiskFileException(
          kind: BaiduNetdiskFileErrorKind.notFound,
          message: 'Baidu download link is unavailable.',
        ));
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

  String _sourceUrlForEntry(CloudDriveEntry entry) {
    return 'baidunetdisk://fs/${entry.fsId}?path=${Uri.encodeComponent(entry.path)}';
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// 从百度网盘导入来源 URL（`baidunetdisk://fs/<fsId>?path=...`）解析 fs_id。
///
/// 与 [DefaultBaiduNetdiskImportService] 写入的格式保持一致；非百度来源返回 null。
int? baiduFsIdFromImportSourceUrl(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'baidunetdisk' || uri.host != 'fs') {
    return null;
  }
  if (uri.pathSegments.isEmpty) return null;
  return int.tryParse(uri.pathSegments.first);
}

/// 在资源库中查找由同一百度文件（fs_id）导入的素材；没有时返回 null。
AudioItem? findBaiduLibraryItem(Iterable<AudioItem> items, int fsId) {
  for (final item in items) {
    if (item.importSourceType != AudioImportSourceType.cloudDrive) continue;
    if (baiduFsIdFromImportSourceUrl(item.importSourceUrl) == fsId) {
      return item;
    }
  }
  return null;
}
