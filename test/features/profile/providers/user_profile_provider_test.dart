import 'dart:async';
import 'dart:typed_data';

import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/profile/data/user_profile_api.dart';
import 'package:echo_loop/features/profile/domain/user_profile.dart';
import 'package:echo_loop/features/profile/providers/user_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockProfileApi extends Mock implements UserProfileRemoteDataSource {}

Session _sessionFor(String userId) => Session(
  accessToken: 'token-$userId',
  tokenType: 'bearer',
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-11-03T00:00:00.000Z',
  ),
);

UserProfile _profile(String userId, {String? nickname, String? avatarUrl}) {
  return UserProfile(
    userId: userId,
    nickname: nickname,
    avatarUrl: avatarUrl,
    updatedAt: DateTime.utc(2026, 11, 7),
  );
}

void main() {
  late _MockProfileApi api;
  late StreamController<Session?> sessionEvents;
  late ProviderContainer container;

  /// 发出登录态并等待 userProfileProvider 落定。
  Future<void> signInAs(String? userId) async {
    sessionEvents.add(userId == null ? null : _sessionFor(userId));
    await container.read(supabaseSessionProvider.future);
    await container.read(userProfileProvider.future);
  }

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    api = _MockProfileApi();
    sessionEvents = StreamController<Session?>();
    container = ProviderContainer(
      overrides: [
        userProfileApiProvider.overrideWithValue(api),
        supabaseSessionProvider.overrideWith((ref) => sessionEvents.stream),
      ],
    );
    // Riverpod 3 会暂停无监听的 StreamProvider，这里保持常驻监听。
    container.listen(supabaseSessionProvider, (_, __) {});
    container.listen(userProfileProvider, (_, __) {});
  });

  tearDown(() async {
    container.dispose();
    await sessionEvents.close();
  });

  test('未登录时资料为 null，且不请求后端', () async {
    await signInAs(null);

    expect(container.read(userProfileProvider).value, isNull);
    verifyNever(() => api.getProfile());
  });

  test('登录后拉取服务端资料', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Quiet Otter'));

    await signInAs('user-1');

    expect(container.read(userProfileProvider).value?.nickname, 'Quiet Otter');
  });

  test('换号后重新拉取新账号的资料', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann'));
    await signInAs('user-1');

    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-2', nickname: 'Bob'));
    await signInAs('user-2');

    expect(container.read(userProfileProvider).value?.userId, 'user-2');
    expect(container.read(userProfileProvider).value?.nickname, 'Bob');
  });

  test('登出后资料清空为 null', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann'));
    await signInAs('user-1');

    await signInAs(null);

    expect(container.read(userProfileProvider).value, isNull);
  });

  test('修改昵称后以服务端响应整体替换资料', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann'));
    await signInAs('user-1');
    when(() => api.updateNickname('Anna'))
        .thenAnswer((_) async => _profile('user-1', nickname: 'Anna'));

    await container.read(userProfileProvider.notifier).updateNickname('Anna');

    expect(container.read(userProfileProvider).value?.nickname, 'Anna');
  });

  test('上传头像失败时抛出异常且保留旧资料', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann'));
    await signInAs('user-1');
    when(() => api.uploadAvatar(any())).thenThrow(StateError('network down'));

    await expectLater(
      container
          .read(userProfileProvider.notifier)
          .uploadAvatar(Uint8List.fromList([1])),
      throwsA(isA<StateError>()),
    );

    expect(container.read(userProfileProvider).value?.nickname, 'Ann');
  });

  test('写请求返回前切换账号时，丢弃过期响应', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann'));
    await signInAs('user-1');
    final pendingUpdate = Completer<UserProfile>();
    when(() => api.updateNickname('Anna'))
        .thenAnswer((_) => pendingUpdate.future);

    final update = container
        .read(userProfileProvider.notifier)
        .updateNickname('Anna');
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-2', nickname: 'Bob'));
    await signInAs('user-2');
    pendingUpdate.complete(_profile('user-1', nickname: 'Anna'));
    await update;

    expect(container.read(userProfileProvider).value?.userId, 'user-2');
    expect(container.read(userProfileProvider).value?.nickname, 'Bob');
  });

  test('后台刷新失败时只记录日志，保留当前资料', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann'));
    await signInAs('user-1');
    when(() => api.getProfile()).thenThrow(StateError('offline'));

    await container.read(userProfileProvider.notifier).refresh();

    expect(container.read(userProfileProvider).value?.nickname, 'Ann');
  });

  test('后台刷新成功时用服务端最新资料覆盖（如 Web 端改了昵称）', () async {
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann'));
    await signInAs('user-1');
    when(() => api.getProfile())
        .thenAnswer((_) async => _profile('user-1', nickname: 'Ann (web)'));

    await container.read(userProfileProvider.notifier).refresh();

    expect(container.read(userProfileProvider).value?.nickname, 'Ann (web)');
  });
}
