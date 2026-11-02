/// 百度网盘导入 UI Controller。
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateNotifier / StateProvider 已移入 legacy 库（Riverpod 3），此处保留旧写法
import 'package:flutter_riverpod/legacy.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/analytics_service.dart';
import '../../../analytics/models/event_names.dart';
import '../../../models/audio_item.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../services/app_logger.dart';
import '../../audio_import/audio_import_models.dart';
import '../../audio_import/subtitle_pairing.dart';
import '../data/baidu_credential_repository.dart';
import '../data/baidu_netdisk_api.dart';
import '../data/baidu_netdisk_import_service.dart';
import '../models/baidu_oauth_session.dart';
import '../models/baidu_oauth_session_status.dart';
import '../models/baidu_account_profile.dart';
import '../models/cloud_drive_models.dart';
import '../services/baidu_oauth_launcher.dart';
import 'baidu_netdisk_providers.dart';

/// 百度网盘导入流程阶段。
enum BaiduNetdiskImportPhase {
  /// 初始状态。
  idle,

  /// 需要授权。
  authorizationRequired,

  /// 正在打开授权页/轮询授权结果。
  authorizing,

  /// 正在加载目录。
  loading,

  /// 目录可浏览。
  ready,

  /// 正在导入选中文件。
  importing,

  /// 导入完成。
  completed,

  /// 失败。
  failed,
}

/// 百度网盘导入 UI 状态。
@immutable
class BaiduNetdiskImportState {
  /// 构造状态。
  const BaiduNetdiskImportState({
    required this.phase,
    this.currentPath = '/',
    this.entries = const <CloudDriveEntry>[],
    this.selectedFsIds = const <int>{},
    this.importItemStatuses = const <int, AudioImportSelectionStatus>{},
    this.importDuplicateExistingNames = const <int, String>{},
    this.importFailureMessages = const <int, String>{},
    this.importedItemsByFsId = const <int, AudioItem>{},
    this.errorMessage,
    this.importOutcome,
    this.importingEntry,
    this.importProgress = -1,
    this.importReceivedBytes,
    this.importTotalBytes,
    this.importSpeedBytesPerSecond,
    this.importingIndex = 0,
    this.importTotal = 0,
    this.accountProfile,
    this.accountProfileLoading = false,
    this.accountProfileFailed = false,
  });

  /// 初始状态。
  const BaiduNetdiskImportState.idle()
    : this(phase: BaiduNetdiskImportPhase.idle);

  /// 当前阶段。
  final BaiduNetdiskImportPhase phase;

  /// 当前目录。
  final String currentPath;

  /// 当前目录条目。
  final List<CloudDriveEntry> entries;

  /// 已选择的可导入文件 fs_id（音频 + 字幕）。
  final Set<int> selectedFsIds;

  /// 本次导入中每个音频 fs_id 对应的行状态。
  final Map<int, AudioImportSelectionStatus> importItemStatuses;

  /// 重复跳过音频 fs_id 对应的库中已有音频名。
  final Map<int, String> importDuplicateExistingNames;

  /// 导入失败音频 fs_id 对应的可展示错误原因。
  final Map<int, String> importFailureMessages;

  /// 成功导入音频 fs_id 对应的最终音频项。
  final Map<int, AudioItem> importedItemsByFsId;

  /// 错误消息。
  final String? errorMessage;

  /// 导入结果。
  final CloudDriveImportOutcome? importOutcome;

  /// 当前正在导入的条目。
  final CloudDriveEntry? importingEntry;

  /// 当前文件下载进度；-1 表示不定进度。
  final double importProgress;

  /// 当前文件已下载字节数。
  final int? importReceivedBytes;

  /// 当前文件总字节数；未知时为 null。
  final int? importTotalBytes;

  /// 当前文件下载速度，单位 bytes/s；采样不足时为 null。
  final double? importSpeedBytesPerSecond;

  /// 当前正在导入的音频序号，1-based；0 表示未知。
  final int importingIndex;

  /// 本批次音频总数。
  final int importTotal;

  /// 当前授权账户资料。
  final BaiduAccountProfile? accountProfile;

  /// 是否正在获取账户资料。
  final bool accountProfileLoading;

  /// 最近一次账户资料获取是否失败。
  final bool accountProfileFailed;

  /// 是否忙碌。
  bool get isBusy =>
      phase == BaiduNetdiskImportPhase.authorizing ||
      phase == BaiduNetdiskImportPhase.loading ||
      phase == BaiduNetdiskImportPhase.importing;

  /// 可导入的音频条目。
  List<CloudDriveEntry> get selectedAudioEntries {
    return entries
        .where((entry) => selectedFsIds.contains(entry.fsId))
        .where(_isImportableAudio)
        .toList(growable: false);
  }

  /// 已选择的字幕条目。
  List<CloudDriveEntry> get selectedSubtitleEntries {
    return entries
        .where((entry) => selectedFsIds.contains(entry.fsId))
        .where(_isImportableSubtitle)
        .toList(growable: false);
  }

  /// 当前目录内可选择的导入条目。
  List<CloudDriveEntry> get selectableEntries {
    return entries.where(_isSelectableImportEntry).toList(growable: false);
  }

  /// 当前目录内是否已全选可导入条目。
  bool get isAllSelectableSelected {
    final selectable = selectableEntries;
    return selectable.isNotEmpty &&
        selectable.every((entry) => selectedFsIds.contains(entry.fsId));
  }

  /// 复制状态。
  BaiduNetdiskImportState copyWith({
    BaiduNetdiskImportPhase? phase,
    String? currentPath,
    List<CloudDriveEntry>? entries,
    Set<int>? selectedFsIds,
    Map<int, AudioImportSelectionStatus>? importItemStatuses,
    Map<int, String>? importDuplicateExistingNames,
    Map<int, String>? importFailureMessages,
    Map<int, AudioItem>? importedItemsByFsId,
    Object? errorMessage = _sentinel,
    Object? importOutcome = _sentinel,
    Object? importingEntry = _sentinel,
    double? importProgress,
    Object? importReceivedBytes = _sentinel,
    Object? importTotalBytes = _sentinel,
    Object? importSpeedBytesPerSecond = _sentinel,
    int? importingIndex,
    int? importTotal,
    Object? accountProfile = _sentinel,
    bool? accountProfileLoading,
    bool? accountProfileFailed,
  }) {
    return BaiduNetdiskImportState(
      phase: phase ?? this.phase,
      currentPath: currentPath ?? this.currentPath,
      entries: entries ?? this.entries,
      selectedFsIds: selectedFsIds ?? this.selectedFsIds,
      importItemStatuses: importItemStatuses ?? this.importItemStatuses,
      importDuplicateExistingNames:
          importDuplicateExistingNames ?? this.importDuplicateExistingNames,
      importFailureMessages:
          importFailureMessages ?? this.importFailureMessages,
      importedItemsByFsId: importedItemsByFsId ?? this.importedItemsByFsId,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      importOutcome: identical(importOutcome, _sentinel)
          ? this.importOutcome
          : importOutcome as CloudDriveImportOutcome?,
      importingEntry: identical(importingEntry, _sentinel)
          ? this.importingEntry
          : importingEntry as CloudDriveEntry?,
      importProgress: importProgress ?? this.importProgress,
      importReceivedBytes: identical(importReceivedBytes, _sentinel)
          ? this.importReceivedBytes
          : importReceivedBytes as int?,
      importTotalBytes: identical(importTotalBytes, _sentinel)
          ? this.importTotalBytes
          : importTotalBytes as int?,
      importSpeedBytesPerSecond: identical(importSpeedBytesPerSecond, _sentinel)
          ? this.importSpeedBytesPerSecond
          : importSpeedBytesPerSecond as double?,
      importingIndex: importingIndex ?? this.importingIndex,
      importTotal: importTotal ?? this.importTotal,
      accountProfile: identical(accountProfile, _sentinel)
          ? this.accountProfile
          : accountProfile as BaiduAccountProfile?,
      accountProfileLoading:
          accountProfileLoading ?? this.accountProfileLoading,
      accountProfileFailed: accountProfileFailed ?? this.accountProfileFailed,
    );
  }
}

class _ImportSpeedSample {
  const _ImportSpeedSample({required this.at, required this.receivedBytes});

  final DateTime at;
  final int receivedBytes;
}

/// 百度网盘导入 Controller provider。
final baiduNetdiskImportControllerProvider =
    StateNotifierProvider.autoDispose<
      BaiduNetdiskImportController,
      BaiduNetdiskImportState
    >((ref) {
      return BaiduNetdiskImportController(
        credentialRepository: ref.watch(baiduCredentialRepositoryProvider),
        api: ref.watch(baiduNetdiskApiProvider),
        importService: ref.watch(baiduNetdiskImportServiceProvider),
        launcher: ref.watch(baiduOAuthLauncherProvider),
        audioLibrary: ref.watch(audioLibraryProvider.notifier),
        readAudioLibraryState: () => ref.read(audioLibraryProvider),
        collectionList: ref.watch(collectionListProvider.notifier),
        readCollectionState: () => ref.read(collectionListProvider),
        analytics: ref.read(analyticsServiceProvider),
      );
    });

/// 百度网盘导入 Controller。
class BaiduNetdiskImportController
    extends StateNotifier<BaiduNetdiskImportState> {
  /// 构造 Controller。
  BaiduNetdiskImportController({
    required BaiduCredentialRepository credentialRepository,
    required BaiduNetdiskApi api,
    required BaiduNetdiskImportService importService,
    required BaiduOAuthLauncher launcher,
    required AudioLibrary audioLibrary,
    required AudioLibraryState Function() readAudioLibraryState,
    required CollectionList collectionList,
    required CollectionState Function() readCollectionState,
    AnalyticsService? analytics,
    TargetPlatform? platform,
    DateTime Function()? now,
  }) : _credentialRepository = credentialRepository,
       _api = api,
       _importService = importService,
       _launcher = launcher,
       _audioLibrary = audioLibrary,
       _readAudioLibraryState = readAudioLibraryState,
       _collectionList = collectionList,
       _readCollectionState = readCollectionState,
       _analytics = analytics,
       _now = now ?? DateTime.now,
       _platform = platform,
       super(const BaiduNetdiskImportState.idle());

  final BaiduCredentialRepository _credentialRepository;
  final BaiduNetdiskApi _api;
  final BaiduNetdiskImportService _importService;
  final BaiduOAuthLauncher _launcher;
  final AudioLibrary _audioLibrary;
  final AudioLibraryState Function() _readAudioLibraryState;
  final CollectionList _collectionList;
  final CollectionState Function() _readCollectionState;
  final AnalyticsService? _analytics;
  final DateTime Function() _now;
  final TargetPlatform? _platform;

  CancelToken? _cancelToken;
  int _sessionId = 0;
  int? _speedSampleFsId;
  final List<_ImportSpeedSample> _speedSamples = [];
  double? _displayedImportSpeed;
  DateTime? _lastSpeedDisplayAt;

  @override
  void dispose() {
    _cancelToken?.cancel('disposed');
    super.dispose();
  }

  /// 初始化并加载根目录；无凭证时进入授权态。
  Future<void> loadInitial() async {
    if (state.isBusy) return;
    final accessToken = await _credentialRepository.getValidAccessToken();
    if (accessToken == null) {
      state = state.copyWith(
        phase: BaiduNetdiskImportPhase.authorizationRequired,
        currentPath: '/',
        errorMessage: null,
      );
      return;
    }
    _sessionId++;
    final sid = _sessionId;
    _loadAccountProfile(accessToken: accessToken, sid: sid);
    await _loadDirectoryWithToken(path: '/', accessToken: accessToken);
  }

  /// 加载指定目录。
  Future<void> loadDirectory(String path) async {
    if (state.isBusy) return;
    final accessToken = await _credentialRepository.getValidAccessToken();
    if (accessToken == null) {
      state = state.copyWith(
        phase: BaiduNetdiskImportPhase.authorizationRequired,
        currentPath: path,
        errorMessage: null,
      );
      return;
    }
    await _loadDirectoryWithToken(path: path, accessToken: accessToken);
  }

  /// 打开百度授权并轮询完成结果。
  Future<void> authorizeAndLoad() async {
    if (state.isBusy) return;
    _sessionId++;
    final sid = _sessionId;
    state = state.copyWith(
      phase: BaiduNetdiskImportPhase.authorizing,
      errorMessage: null,
    );
    try {
      final session = await _credentialRepository.createSession(_platformName);
      await _launcher.open(session.authorizationUri);
      while (mounted && sid == _sessionId) {
        await Future<void>.delayed(session.pollInterval);
        if (!mounted || sid != _sessionId) return;
        final status = await _credentialRepository.fetchStatus(session);
        switch (status.phase) {
          case BaiduOAuthSessionPhase.pending:
          case BaiduOAuthSessionPhase.exchanging:
            continue;
          case BaiduOAuthSessionPhase.completed:
            final credential = status.credential!;
            await _credentialRepository.persistCompletedSession(
              session: session,
              credential: credential,
            );
            await _credentialRepository.consumeForceLoginOnce();
            _loadAccountProfile(accessToken: credential.accessToken, sid: sid);
            await _loadDirectoryWithToken(
              path: state.currentPath,
              accessToken: credential.accessToken,
            );
            return;
          case BaiduOAuthSessionPhase.canceled:
            await _credentialRepository.consumeForceLoginOnce();
            state = state.copyWith(
              phase: BaiduNetdiskImportPhase.authorizationRequired,
              errorMessage:
                  status.error?.message ?? 'Baidu authorization failed.',
            );
            return;
          case BaiduOAuthSessionPhase.failed:
            state = state.copyWith(
              phase: BaiduNetdiskImportPhase.authorizationRequired,
              errorMessage:
                  status.error?.message ?? 'Baidu authorization failed.',
            );
            return;
        }
      }
    } catch (error) {
      if (sid != _sessionId) return;
      state = state.copyWith(
        phase: BaiduNetdiskImportPhase.failed,
        errorMessage: _messageForError(error),
      );
    }
  }

  /// 异步记录授权账户资料；资料失败不影响目录加载。
  void _loadAccountProfile({required String accessToken, required int sid}) {
    state = state.copyWith(
      accountProfileLoading: true,
      accountProfileFailed: false,
    );
    _api
        .fetchAccountProfile(accessToken: accessToken)
        .then((profile) {
          if (!mounted || sid != _sessionId) return;
          state = state.copyWith(
            accountProfile: profile,
            accountProfileLoading: false,
            accountProfileFailed: false,
          );
          AppLogger.log(
            'BAIDU-NETDISK',
            '授权用户: uk=${profile.uk} '
                'baidu_name=${profile.baiduName ?? "(empty)"} '
                'netdisk_name=${profile.netdiskName ?? "(empty)"} '
                'vip_type=${profile.vipType ?? "(unknown)"} '
                'membership=${profile.membershipLabel} '
                'avatar_url=${profile.avatarUrl ?? "(empty)"}',
          );
        })
        .catchError((Object error) {
          if (!mounted || sid != _sessionId) return;
          state = state.copyWith(
            accountProfileLoading: false,
            accountProfileFailed: true,
          );
          AppLogger.log(
            'BAIDU-NETDISK',
            '授权用户资料获取失败: type=${error.runtimeType}',
          );
        });
  }

  /// 切换文件选择。
  void toggleEntry(CloudDriveEntry entry) {
    if (!_isSelectableImportEntry(entry) || state.isBusy) return;
    final next = Set<int>.of(state.selectedFsIds);
    if (!next.add(entry.fsId)) {
      next.remove(entry.fsId);
    }
    state = state.copyWith(selectedFsIds: next);
  }

  /// 切换当前目录内音频和字幕的全选状态。
  void toggleSelectAll() {
    if (state.isBusy) return;
    final selectable = state.selectableEntries;
    if (selectable.isEmpty) return;
    final next = Set<int>.of(state.selectedFsIds);
    if (state.isAllSelectableSelected) {
      for (final entry in selectable) {
        next.remove(entry.fsId);
      }
    } else {
      for (final entry in selectable) {
        next.add(entry.fsId);
      }
    }
    state = state.copyWith(selectedFsIds: next);
  }

  /// 从导入结果页回到当前目录浏览态。
  ///
  /// 完成态会保留本次选择供列表展示状态；用户返回继续选文件时再清空选择和结果。
  void returnToReady() {
    if (state.isBusy) return;
    state = state.copyWith(
      phase: BaiduNetdiskImportPhase.ready,
      selectedFsIds: const <int>{},
      importItemStatuses: const <int, AudioImportSelectionStatus>{},
      importDuplicateExistingNames: const <int, String>{},
      importFailureMessages: const <int, String>{},
      importedItemsByFsId: const <int, AudioItem>{},
      errorMessage: null,
      importOutcome: null,
      importingEntry: null,
      importProgress: -1,
      importReceivedBytes: null,
      importTotalBytes: null,
      importSpeedBytesPerSecond: null,
      importingIndex: 0,
      importTotal: 0,
    );
  }

  /// 导入选中文件。
  Future<void> importSelected({String? collectionId}) async {
    if (state.isBusy) return;
    final selected = state.selectedAudioEntries;
    final subtitles = state.selectedSubtitleEntries;
    if (selected.isEmpty) return;

    await _importEntries(
      entries: selected,
      subtitleEntries: subtitles,
      collectionId: collectionId,
      resetPreviousOutcome: true,
    );
  }

  /// 重新导入单个失败的网盘素材。
  Future<void> retryFailedEntry(
    CloudDriveEntry entry, {
    String? collectionId,
  }) async {
    if (state.isBusy) return;
    if (state.importItemStatuses[entry.fsId] !=
        AudioImportSelectionStatus.failed) {
      return;
    }
    await _importEntries(
      entries: [entry],
      subtitleEntries: state.selectedSubtitleEntries,
      collectionId: collectionId,
      resetPreviousOutcome: false,
    );
  }

  Future<void> _importEntries({
    required List<CloudDriveEntry> entries,
    required List<CloudDriveEntry> subtitleEntries,
    required String? collectionId,
    required bool resetPreviousOutcome,
  }) async {
    if (entries.isEmpty) return;

    _sessionId++;
    final sid = _sessionId;
    _resetImportProgressSample();
    _cancelToken = CancelToken();
    final statuses = resetPreviousOutcome
        ? <int, AudioImportSelectionStatus>{
            for (final entry in entries)
              entry.fsId: AudioImportSelectionStatus.pending,
          }
        : Map<int, AudioImportSelectionStatus>.from(state.importItemStatuses);
    final duplicateNames = resetPreviousOutcome
        ? <int, String>{}
        : Map<int, String>.from(state.importDuplicateExistingNames);
    final failureMessages = resetPreviousOutcome
        ? <int, String>{}
        : Map<int, String>.from(state.importFailureMessages);
    final importedItems = resetPreviousOutcome
        ? <int, AudioItem>{}
        : Map<int, AudioItem>.from(state.importedItemsByFsId);
    for (final entry in entries) {
      statuses[entry.fsId] = AudioImportSelectionStatus.pending;
      duplicateNames.remove(entry.fsId);
      failureMessages.remove(entry.fsId);
      importedItems.remove(entry.fsId);
    }
    state = state.copyWith(
      phase: BaiduNetdiskImportPhase.importing,
      errorMessage: null,
      importingEntry: entries.first,
      importProgress: -1,
      importItemStatuses: statuses,
      importDuplicateExistingNames: duplicateNames,
      importFailureMessages: failureMessages,
      importedItemsByFsId: importedItems,
      importOutcome: resetPreviousOutcome ? null : state.importOutcome,
      importingIndex: 1,
      importTotal: entries.length,
      importReceivedBytes: null,
      importTotalBytes: null,
      importSpeedBytesPerSecond: null,
    );
    try {
      final outcome = await _importService.importAudios(
        entries: entries,
        subtitleEntries: subtitleEntries,
        audioLibrary: _audioLibrary,
        audioLibraryState: _readAudioLibraryState(),
        collectionList: collectionId == null ? null : _collectionList,
        collectionState: collectionId == null ? null : _readCollectionState(),
        collectionId: collectionId,
        cancelToken: _cancelToken,
        onProgress: (entry, received, total) {
          if (sid != _sessionId) return;
          final index = entries.indexWhere((audio) => audio.fsId == entry.fsId);
          final speed = _speedForProgress(entry: entry, received: received);
          final statuses = Map<int, AudioImportSelectionStatus>.from(
            state.importItemStatuses,
          );
          statuses[entry.fsId] = AudioImportSelectionStatus.importing;
          state = state.copyWith(
            importingEntry: entry,
            importProgress: total == null || total <= 0 ? -1 : received / total,
            importReceivedBytes: received,
            importTotalBytes: total,
            importSpeedBytesPerSecond: speed,
            importItemStatuses: statuses,
            importingIndex: index < 0 ? state.importingIndex : index + 1,
            importTotal: entries.length,
          );
        },
        onItemResult: (result) {
          if (sid != _sessionId) return;
          _applyItemResult(result);
        },
      );
      if (sid != _sessionId) return;
      final nextOutcome = resetPreviousOutcome
          ? outcome
          : _mergeRetryOutcome(
              previous: state.importOutcome,
              retryOutcome: outcome,
              retriedEntries: entries,
            );
      final itemStatuses = Map<int, AudioImportSelectionStatus>.from(
        state.importItemStatuses,
      );
      var resetImportingItems = 0;
      if (outcome.wasCanceled) {
        for (final entry in entries) {
          if (itemStatuses[entry.fsId] ==
              AudioImportSelectionStatus.importing) {
            itemStatuses[entry.fsId] = AudioImportSelectionStatus.pending;
            resetImportingItems++;
          }
        }
        AppLogger.log(
          'BaiduNetdiskImport',
          'cancel settled session=$sid reset_importing=$resetImportingItems '
              'added=${outcome.added.length}',
        );
      }
      state = state.copyWith(
        phase: BaiduNetdiskImportPhase.completed,
        importOutcome: nextOutcome,
        importItemStatuses: itemStatuses,
        importingEntry: null,
        importProgress: -1,
        importReceivedBytes: null,
        importTotalBytes: null,
        importSpeedBytesPerSecond: null,
        importingIndex: 0,
      );
      _analytics?.track(Events.cloudImportResult, {
        EventParams.result: outcome.wasCanceled
            ? 'cancelled'
            : outcome.failures.isEmpty
            ? 'completed'
            : 'partial_failure',
        EventParams.source: 'baidu_netdisk',
        EventParams.selectedCount: entries.length,
        EventParams.addedCount: outcome.added.length,
        EventParams.duplicateCount: outcome.duplicateDetails.length,
        EventParams.failedCount: outcome.failures.length,
      });
    } catch (error) {
      if (sid != _sessionId) return;
      state = state.copyWith(
        phase: BaiduNetdiskImportPhase.failed,
        errorMessage: _messageForError(error),
        importingEntry: null,
        importReceivedBytes: null,
        importTotalBytes: null,
        importSpeedBytesPerSecond: null,
      );
      _analytics?.track(Events.cloudImportResult, {
        EventParams.result: 'failed',
        EventParams.source: 'baidu_netdisk',
        EventParams.selectedCount: entries.length,
      });
    } finally {
      if (sid == _sessionId) _cancelToken = null;
    }
  }

  void _applyItemResult(CloudDriveImportItemResult result) {
    final statuses = Map<int, AudioImportSelectionStatus>.from(
      state.importItemStatuses,
    );
    final duplicateNames = Map<int, String>.from(
      state.importDuplicateExistingNames,
    );
    final failureMessages = Map<int, String>.from(state.importFailureMessages);
    final importedItems = Map<int, AudioItem>.from(state.importedItemsByFsId);
    switch (result.status) {
      case CloudDriveImportItemStatus.added:
        statuses[result.entry.fsId] = AudioImportSelectionStatus.added;
        duplicateNames.remove(result.entry.fsId);
        failureMessages.remove(result.entry.fsId);
        final item = result.item;
        if (item != null) importedItems[result.entry.fsId] = item;
      case CloudDriveImportItemStatus.duplicate:
        statuses[result.entry.fsId] = AudioImportSelectionStatus.skipped;
        failureMessages.remove(result.entry.fsId);
        final existingName = result.duplicateExistingName;
        if (existingName != null) {
          duplicateNames[result.entry.fsId] = existingName;
        }
      case CloudDriveImportItemStatus.failed:
        statuses[result.entry.fsId] = AudioImportSelectionStatus.failed;
        duplicateNames.remove(result.entry.fsId);
        final message = result.failure?.message;
        if (message != null && message.isNotEmpty) {
          failureMessages[result.entry.fsId] = message;
        }
    }
    state = state.copyWith(
      importItemStatuses: statuses,
      importDuplicateExistingNames: duplicateNames,
      importFailureMessages: failureMessages,
      importedItemsByFsId: importedItems,
    );
  }

  /// 用最近 5 秒下载量估算速度，并限制显示刷新频率。
  ///
  /// 底层下载回调按网络分块触发，相邻两次回调的瞬时值会跳动明显。
  /// 这里保留当前文件最近 5 秒采样，用窗口内字节差 / 时间差计算速度。
  double? _speedForProgress({
    required CloudDriveEntry entry,
    required int received,
  }) {
    final now = _now();
    if (_speedSampleFsId != entry.fsId) {
      _speedSampleFsId = entry.fsId;
      _speedSamples.clear();
      _displayedImportSpeed = null;
      _lastSpeedDisplayAt = null;
    }
    _speedSamples.add(_ImportSpeedSample(at: now, receivedBytes: received));
    final cutoff = now.subtract(const Duration(seconds: 5));
    _speedSamples.removeWhere((sample) => sample.at.isBefore(cutoff));
    final speed = _speedFromSamples();
    if (speed == null) return _displayedImportSpeed;

    final lastDisplayAt = _lastSpeedDisplayAt;
    if (_displayedImportSpeed == null ||
        lastDisplayAt == null ||
        now.difference(lastDisplayAt).inMilliseconds >= 700) {
      _displayedImportSpeed = speed;
      _lastSpeedDisplayAt = now;
    }
    return _displayedImportSpeed;
  }

  void _resetImportProgressSample() {
    _speedSampleFsId = null;
    _speedSamples.clear();
    _displayedImportSpeed = null;
    _lastSpeedDisplayAt = null;
  }

  double? _speedFromSamples() {
    if (_speedSamples.length < 2) return null;
    final first = _speedSamples.first;
    final latest = _speedSamples.last;
    final elapsedMs = latest.at.difference(first.at).inMilliseconds;
    final deltaBytes = latest.receivedBytes - first.receivedBytes;
    if (elapsedMs <= 0 || deltaBytes < 0) return null;
    return deltaBytes / (elapsedMs / 1000);
  }

  CloudDriveImportOutcome _mergeRetryOutcome({
    required CloudDriveImportOutcome? previous,
    required CloudDriveImportOutcome retryOutcome,
    required List<CloudDriveEntry> retriedEntries,
  }) {
    if (previous == null) return retryOutcome;
    final retriedFsIds = retriedEntries.map((entry) => entry.fsId).toSet();
    final retriedNames = retriedEntries
        .map(_displayNameWithoutExtension)
        .toSet();
    final keptAdded = <CloudDriveEntry>[];
    final keptAddedItems = <AudioItem>[];
    for (var i = 0; i < previous.added.length; i++) {
      final entry = previous.added[i];
      if (retriedFsIds.contains(entry.fsId)) continue;
      keptAdded.add(entry);
      if (i < previous.addedItems.length) {
        keptAddedItems.add(previous.addedItems[i]);
      }
    }
    return CloudDriveImportOutcome(
      added: [...keptAdded, ...retryOutcome.added],
      addedItems: [...keptAddedItems, ...retryOutcome.addedItems],
      duplicateDetails: [
        for (final duplicate in previous.duplicateDetails)
          if (!retriedNames.contains(duplicate.attempted)) duplicate,
        ...retryOutcome.duplicateDetails,
      ],
      duplicateEntries: [
        for (final entry in previous.duplicateEntries)
          if (!retriedFsIds.contains(entry.fsId)) entry,
        ...retryOutcome.duplicateEntries,
      ],
      failures: [
        for (final failure in previous.failures)
          if (!retriedFsIds.contains(failure.entry.fsId)) failure,
        ...retryOutcome.failures,
      ],
      wasCanceled: retryOutcome.wasCanceled,
    );
  }

  /// 取消当前操作。
  void cancel() {
    final cancelToken = _cancelToken;
    if (cancelToken == null) return;
    AppLogger.log(
      'BaiduNetdiskImport',
      'cancel requested session=$_sessionId '
          'entry=${state.importingEntry?.fsId ?? 'none'}',
    );
    cancelToken.cancel('user-cancelled');
  }

  /// 重置。
  void reset() {
    if (state.isBusy) return;
    state = const BaiduNetdiskImportState.idle();
  }

  Future<void> _loadDirectoryWithToken({
    required String path,
    required String accessToken,
  }) async {
    _resetImportProgressSample();
    final previous = state;
    state = state.copyWith(
      phase: BaiduNetdiskImportPhase.loading,
      currentPath: path,
      errorMessage: null,
      selectedFsIds: const <int>{},
      importItemStatuses: const <int, AudioImportSelectionStatus>{},
      importDuplicateExistingNames: const <int, String>{},
      importFailureMessages: const <int, String>{},
      importedItemsByFsId: const <int, AudioItem>{},
      importReceivedBytes: null,
      importTotalBytes: null,
      importSpeedBytesPerSecond: null,
      importingIndex: 0,
      importTotal: 0,
    );
    try {
      final page = await _api.listDirectory(
        accessToken: accessToken,
        dir: path,
      );
      state = state.copyWith(
        phase: BaiduNetdiskImportPhase.ready,
        entries: _visibleEntries(page.entries),
      );
    } on BaiduNetdiskFileException catch (error) {
      if (error.kind == BaiduNetdiskFileErrorKind.unauthorized) {
        await _credentialRepository.clearCredential();
        state = previous.copyWith(
          phase: BaiduNetdiskImportPhase.authorizationRequired,
          errorMessage: 'Baidu authorization expired.',
        );
        return;
      }
      state = previous.copyWith(
        phase: BaiduNetdiskImportPhase.failed,
        errorMessage: error.message,
      );
    } catch (error) {
      state = previous.copyWith(
        phase: BaiduNetdiskImportPhase.failed,
        errorMessage: _messageForError(error),
      );
    }
  }

  List<CloudDriveEntry> _visibleEntries(List<CloudDriveEntry> entries) {
    return entries.toList(growable: false);
  }

  BaiduNetdiskPlatform get _platformName {
    final platform = _platform ?? defaultTargetPlatform;
    return switch (platform) {
      TargetPlatform.iOS => BaiduNetdiskPlatform.ios,
      TargetPlatform.android => BaiduNetdiskPlatform.android,
      TargetPlatform.macOS => BaiduNetdiskPlatform.macos,
      TargetPlatform.windows => BaiduNetdiskPlatform.windows,
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => BaiduNetdiskPlatform.linux,
    };
  }

  String _messageForError(Object error) {
    if (error is BaiduReauthorizationRequiredException) {
      return 'Please connect Baidu Netdisk again.';
    }
    if (error is AudioImportException) return error.message;
    if (error is BaiduNetdiskFileException) return error.message;
    return 'Baidu Netdisk import failed.';
  }
}

bool _isImportableAudio(CloudDriveEntry entry) {
  return !entry.isDirectory &&
      isImportablePrimaryMediaExtension(entry.extension);
}

bool _isImportableSubtitle(CloudDriveEntry entry) {
  return !entry.isDirectory &&
      subtitleImportExtensions.contains(entry.extension);
}

bool _isSelectableImportEntry(CloudDriveEntry entry) {
  return _isImportableAudio(entry) || _isImportableSubtitle(entry);
}

String _displayNameWithoutExtension(CloudDriveEntry entry) {
  final name = entry.name;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}

const _sentinel = Object();
