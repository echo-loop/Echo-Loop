import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/user_profile_api.dart';
import '../domain/user_profile.dart';

final userProfileApiProvider = Provider<UserProfileRemoteDataSource>((ref) {
  final dio = createAuthenticatedBackendDio(
    tokenCoordinator: ref.read(supabaseTokenCoordinatorProvider),
    endpointRouter: runtimeEndpointRouter,
    apiLogTag: 'USER_PROFILE',
  );
  ref.onDispose(() => dio.close(force: true));
  return UserProfileApi(dio);
});

/// 当前登录用户的资料；未登录时为 `null`。
///
/// 后端 `profiles` 是唯一事实来源：登录、换号、登出时自动重建，
/// 写操作以服务端响应整体替换 state，因此所有订阅处都会同步刷新。
///
/// 关闭 Riverpod 默认的自动重试：加载失败（如接口 404、网络异常）后由用户点击入口重新加载，
/// 避免对失败接口进行退避式的反复请求。
final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
      UserProfileNotifier.new,
      retry: (_, _) => null,
    );

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    // 只监听 userId：token 刷新不会触发重新拉取资料。
    final userId = ref.watch(
      supabaseSessionProvider.select((session) => session.value?.user.id),
    );
    if (userId == null) return null;
    return ref.read(userProfileApiProvider).getProfile();
  }

  /// 回前台等场景的静默刷新。失败时保留旧资料，不影响已展示的内容。
  Future<void> refresh() async {
    final userId = _currentUserId();
    if (userId == null) return;
    try {
      final profile = await ref.read(userProfileApiProvider).getProfile();
      if (!_isStillCurrent(userId)) return;
      state = AsyncData(profile);
    } on Object catch (error, stackTrace) {
      // 后台刷新是 fire-and-forget 的边界，任何失败都只记日志，不能抛到生命周期回调里。
      AppLogger.log('UserProfile', '刷新资料失败，保留当前资料: $error\n$stackTrace');
    }
  }

  Future<void> updateNickname(String nickname) {
    return _applyServerProfile((api) => api.updateNickname(nickname));
  }

  Future<void> uploadAvatar(Uint8List jpegBytes) {
    return _applyServerProfile((api) => api.uploadAvatar(jpegBytes));
  }

  Future<void> removeAvatar() {
    return _applyServerProfile((api) => api.removeAvatar());
  }

  /// 写操作失败时异常向上抛给 UI 提示，state 保持旧值。
  Future<void> _applyServerProfile(
    Future<UserProfile> Function(UserProfileRemoteDataSource api) send,
  ) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('未登录时不能修改用户资料');
    }
    final profile = await send(ref.read(userProfileApiProvider));
    // 请求期间若切换了账号或已登出，丢弃这份过期响应，避免串号。
    if (!_isStillCurrent(userId)) return;
    state = AsyncData(profile);
  }

  String? _currentUserId() {
    return ref.read(supabaseSessionProvider).value?.user.id;
  }

  bool _isStillCurrent(String userId) {
    return ref.mounted && _currentUserId() == userId;
  }
}
