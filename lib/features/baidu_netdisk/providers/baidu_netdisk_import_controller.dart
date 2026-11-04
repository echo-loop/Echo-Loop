/// 百度网盘浏览与选择 UI Controller。
///
/// 只负责授权、目录浏览和文件选择；下载任务由 [baiduNetdiskImportTasksProvider] 管理，
/// 因此关闭导入弹窗不会影响正在进行的下载。
library;

import 'package:flutter/foundation.dart';
// StateNotifier / StateProvider 已移入 legacy 库（Riverpod 3），此处保留旧写法
import 'package:flutter_riverpod/legacy.dart';

import '../../../services/app_logger.dart';
import '../../audio_import/subtitle_pairing.dart';
import '../data/baidu_credential_repository.dart';
import '../data/baidu_netdisk_api.dart';
import '../models/baidu_oauth_session.dart';
import '../models/baidu_oauth_session_status.dart';
import '../models/baidu_account_profile.dart';
import '../models/cloud_drive_models.dart';
import '../services/baidu_oauth_launcher.dart';
import 'baidu_netdisk_providers.dart';

/// 百度网盘浏览流程阶段。
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

  /// 失败。
  failed,
}

/// 百度网盘浏览 UI 状态。
@immutable
class BaiduNetdiskImportState {
  /// 构造状态。
  const BaiduNetdiskImportState({
    required this.phase,
    this.currentPath = '/',
    this.entries = const <CloudDriveEntry>[],
    this.selectedFsIds = const <int>{},
    this.errorMessage,
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

  /// 错误消息。
  final String? errorMessage;

  /// 当前授权账户资料。
  final BaiduAccountProfile? accountProfile;

  /// 是否正在获取账户资料。
  final bool accountProfileLoading;

  /// 最近一次账户资料获取是否失败。
  final bool accountProfileFailed;

  /// 是否忙碌（授权或加载目录中）。
  bool get isBusy =>
      phase == BaiduNetdiskImportPhase.authorizing ||
      phase == BaiduNetdiskImportPhase.loading;

  /// 已选择的音频条目。
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

  /// 当前目录内可选条目（排除 [unavailableFsIds]）是否已全部选中。
  bool isAllSelectableSelected({Set<int> unavailableFsIds = const <int>{}}) {
    final candidates = selectableEntries.where(
      (entry) => !unavailableFsIds.contains(entry.fsId),
    );
    return candidates.isNotEmpty &&
        candidates.every((entry) => selectedFsIds.contains(entry.fsId));
  }

  /// 复制状态。
  BaiduNetdiskImportState copyWith({
    BaiduNetdiskImportPhase? phase,
    String? currentPath,
    List<CloudDriveEntry>? entries,
    Set<int>? selectedFsIds,
    Object? errorMessage = _sentinel,
    Object? accountProfile = _sentinel,
    bool? accountProfileLoading,
    bool? accountProfileFailed,
  }) {
    return BaiduNetdiskImportState(
      phase: phase ?? this.phase,
      currentPath: currentPath ?? this.currentPath,
      entries: entries ?? this.entries,
      selectedFsIds: selectedFsIds ?? this.selectedFsIds,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      accountProfile: identical(accountProfile, _sentinel)
          ? this.accountProfile
          : accountProfile as BaiduAccountProfile?,
      accountProfileLoading:
          accountProfileLoading ?? this.accountProfileLoading,
      accountProfileFailed: accountProfileFailed ?? this.accountProfileFailed,
    );
  }
}

/// 百度网盘浏览 Controller provider。
final baiduNetdiskImportControllerProvider =
    StateNotifierProvider.autoDispose<
      BaiduNetdiskImportController,
      BaiduNetdiskImportState
    >((ref) {
      return BaiduNetdiskImportController(
        credentialRepository: ref.watch(baiduCredentialRepositoryProvider),
        api: ref.watch(baiduNetdiskApiProvider),
        launcher: ref.watch(baiduOAuthLauncherProvider),
      );
    });

/// 百度网盘浏览 Controller。
class BaiduNetdiskImportController
    extends StateNotifier<BaiduNetdiskImportState> {
  /// 构造 Controller。
  BaiduNetdiskImportController({
    required BaiduCredentialRepository credentialRepository,
    required BaiduNetdiskApi api,
    required BaiduOAuthLauncher launcher,
    TargetPlatform? platform,
  }) : _credentialRepository = credentialRepository,
       _api = api,
       _launcher = launcher,
       _platform = platform,
       super(const BaiduNetdiskImportState.idle());

  final BaiduCredentialRepository _credentialRepository;
  final BaiduNetdiskApi _api;
  final BaiduOAuthLauncher _launcher;
  final TargetPlatform? _platform;

  /// 会话序号，用于丢弃已过期的授权与账户资料回调。
  int _sessionId = 0;

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
  ///
  /// [unavailableFsIds] 是已在下载任务中或已导入的条目，不参与全选，
  /// 否则按钮数量会和实际入队数量对不上。
  void toggleSelectAll({Set<int> unavailableFsIds = const <int>{}}) {
    if (state.isBusy) return;
    final candidates = state.selectableEntries
        .where((entry) => !unavailableFsIds.contains(entry.fsId))
        .toList(growable: false);
    if (candidates.isEmpty) return;
    final allSelected = state.isAllSelectableSelected(
      unavailableFsIds: unavailableFsIds,
    );
    final next = Set<int>.of(state.selectedFsIds);
    for (final entry in candidates) {
      if (allSelected) {
        next.remove(entry.fsId);
      } else {
        next.add(entry.fsId);
      }
    }
    state = state.copyWith(selectedFsIds: next);
  }

  /// 清空当前选择（已交给导入任务管理器接管）。
  void clearSelection() {
    state = state.copyWith(selectedFsIds: const <int>{});
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
    final previous = state;
    state = state.copyWith(
      phase: BaiduNetdiskImportPhase.loading,
      currentPath: path,
      errorMessage: null,
      selectedFsIds: const <int>{},
    );
    try {
      final page = await _api.listDirectory(
        accessToken: accessToken,
        dir: path,
      );
      state = state.copyWith(
        phase: BaiduNetdiskImportPhase.ready,
        entries: page.entries.toList(growable: false),
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
    if (error is BaiduNetdiskFileException) return error.message;
    AppLogger.log('BaiduNetdiskImport', '浏览失败: ${error.runtimeType}');
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

const _sentinel = Object();
