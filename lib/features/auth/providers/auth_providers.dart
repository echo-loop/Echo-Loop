library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../providers/startup_bootstrap_provider.dart';
import '../../../services/app_logger.dart';
import '../../../services/supabase_token_coordinator.dart';
import '../../../services/user_id_service.dart';
import '../apple_sign_in_credentials.dart';
import '../google_sign_in_credentials.dart';
import '../supabase_startup_gate.dart';

/// 认证仓库接口。
///
/// 所有认证动作最终都应通过这层进入 Supabase，避免页面分散直连 SDK，
/// 从而保证登录方式再多，状态来源仍只有一份。
abstract class AuthRepository {
  Future<void> sendEmailOtp(String email);

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  });

  Future<AuthResponse> signInWithApple();

  Future<AuthResponse> signInWithGoogle();

  /// 邮箱+密码登录。
  ///
  /// 仅用于审核员预建账号的隐藏入口，账号在 Supabase 后台手动创建。
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._auth, {
    AppleSignInCredentialsProvider appleCredentialsProvider =
        const NativeAppleSignInCredentialsProvider(),
    GoogleSignInCredentialsProvider? googleCredentialsProvider,
  }) : _appleCredentialsProvider = appleCredentialsProvider,
       _googleCredentialsProvider =
           googleCredentialsProvider ?? NativeGoogleSignInCredentialsProvider();

  final GoTrueClient _auth;
  final AppleSignInCredentialsProvider _appleCredentialsProvider;
  final GoogleSignInCredentialsProvider _googleCredentialsProvider;

  @override
  Future<void> sendEmailOtp(String email) {
    return _auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  @override
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  @override
  Future<AuthResponse> signInWithApple() async {
    final rawNonce = _generateRawNonce();
    final credential = await _appleCredentialsProvider.getCredential(
      nonce: _sha256Hex(rawNonce),
    );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Apple identity token is missing.');
    }

    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    if (response.user?.email == null) {
      AppLogger.log(
        'Auth',
        'Apple sign-in without email claim: userId=${response.user?.id} '
            'credentialHasEmail=${credential.email?.isNotEmpty ?? false}',
      );
    }

    final userMetadata = _appleUserMetadata(credential);
    if (userMetadata.isNotEmpty) {
      try {
        await _auth.updateUser(UserAttributes(data: userMetadata));
      } catch (error, stackTrace) {
        AppLogger.log(
          'Auth',
          'Apple user metadata update failed: $error\n$stackTrace',
        );
      }
    }

    return response;
  }

  @override
  Future<AuthResponse> signInWithGoogle() async {
    final credential = await _googleCredentialsProvider.getCredentials();
    try {
      AppLogger.log('AuthGoogle', 'Supabase signInWithIdToken start');
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: credential.idToken,
        accessToken: credential.accessToken,
      );
      AppLogger.log(
        'AuthGoogle',
        'Supabase signInWithIdToken success userId=${response.user?.id}',
      );
      return response;
    } on AuthException catch (error) {
      AppLogger.log(
        'AuthGoogle',
        'Supabase signInWithIdToken failed message=${error.message} '
            'status=${error.statusCode} code=${error.code}',
      );
      rethrow;
    }
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.log('AuthPassword', 'Supabase signInWithPassword start');
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      AppLogger.log(
        'AuthPassword',
        'Supabase signInWithPassword success userId=${response.user?.id}',
      );
      return response;
    } on AuthException catch (error) {
      AppLogger.log(
        'AuthPassword',
        'Supabase signInWithPassword failed message=${error.message} '
            'status=${error.statusCode} code=${error.code}',
      );
      rethrow;
    }
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}

const _nonceCharacters =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';

String _generateRawNonce({int length = 32, Random? random}) {
  final generator = random ?? Random.secure();
  return List.generate(
    length,
    (_) => _nonceCharacters[generator.nextInt(_nonceCharacters.length)],
  ).join();
}

String _sha256Hex(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

/// 从 Apple 凭证提取需要回写到 `auth.users.raw_user_meta_data` 的字段。
///
Map<String, String> _appleUserMetadata(
  AuthorizationCredentialAppleID credential,
) {
  final givenName = credential.givenName?.trim();
  final familyName = credential.familyName?.trim();
  final parts = [
    if (givenName != null && givenName.isNotEmpty) givenName,
    if (familyName != null && familyName.isNotEmpty) familyName,
  ];
  final fullName = parts.join(' ').trim();
  final email = credential.email?.trim();

  return {
    if (fullName.isNotEmpty) 'full_name': fullName,
    if (givenName != null && givenName.isNotEmpty) 'given_name': givenName,
    if (familyName != null && familyName.isNotEmpty) 'family_name': familyName,
    if (email != null && email.isNotEmpty) 'apple_email': email,
  };
}

/// 默认认证仓库。
///
/// 未配置 Supabase 时调用动作会立刻抛错，避免页面误以为认证成功。
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!ref.watch(supabaseSdkReadyProvider)) {
    throw AuthException('Supabase auth is not configured.');
  }
  return SupabaseAuthRepository(Supabase.instance.client.auth);
});

/// 统一认证控制器。
///
/// 页面只调用这里暴露的方法，不直接操作 `Supabase.instance.client.auth`。
/// 真正的登录态仍以 `supabaseSessionProvider` 为唯一事实来源。
class AuthAnalyticsSync {
  AuthAnalyticsSync(this._ref);

  final Ref _ref;

  /// 将当前登录用户同步到分析系统。
  ///
  /// 匿名阶段不应调用；调用方需先确保 [user] 非空。
  Future<void> syncSignedInUser(User user) async {
    final analytics = _ref.read(analyticsServiceProvider);
    await analytics.setUserId(user.id);
    await analytics.registerSuperProperties({'supabase_user_id': user.id});

    final resolvedEmail = user.email;
    if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
      await analytics.setUserProperty('email', resolvedEmail);
    }

    final anonymousId = await _ref.read(userIdProvider);
    await analytics.setUserProperty('app_anonymous_id', anonymousId);
  }

  /// 根据 session 变化同步分析身份。
  ///
  /// 仅在"已登录 -> 已登出"时 reset，避免匿名启动阶段反复生成新 distinct id。
  Future<void> syncSessionChange({
    required Session? previous,
    required Session? current,
  }) async {
    final previousUser = previous?.user;
    final currentUser = current?.user;

    if (currentUser != null) {
      await syncSignedInUser(currentUser);
      return;
    }

    if (previousUser != null) {
      await _ref
          .read(analyticsServiceProvider)
          .unregisterSuperProperty('supabase_user_id');
      await _ref.read(analyticsServiceProvider).setUserId(null);
    }
  }
}

final authAnalyticsSyncProvider = Provider<AuthAnalyticsSync>((ref) {
  return AuthAnalyticsSync(ref);
});

class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);

  Future<void> requestEmailOtp(String email) {
    return _repository.sendEmailOtp(email);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final response = await _repository.verifyEmailOtp(
      email: email,
      token: token,
    );
    final user = response.user;
    if (user != null) {
      await _ref.read(authAnalyticsSyncProvider).syncSignedInUser(user);
    }
  }

  Future<void> signInWithApple() async {
    final response = await _repository.signInWithApple();
    final user = response.user;
    if (user != null) {
      await _ref.read(authAnalyticsSyncProvider).syncSignedInUser(user);
    }
  }

  Future<void> signInWithGoogle() async {
    final response = await _repository.signInWithGoogle();
    final user = response.user;
    if (user != null) {
      await _ref.read(authAnalyticsSyncProvider).syncSignedInUser(user);
    }
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _repository.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user != null) {
      await _ref.read(authAnalyticsSyncProvider).syncSignedInUser(user);
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    await _ref.read(analyticsServiceProvider).setUserId(null);
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

/// 当前 Supabase Session 的响应式来源。
///
/// 首值：SDK 启动完成后 `onAuthStateChange` 发出的 `initialSession` 事件。
/// 后续：该流的每个认证事件（signedIn / signedOut / tokenRefreshed 等都会带
/// `session`）。不会把 SDK 恢复期间暂时为空的 `currentSession` 当作匿名首值。
///
/// 当前进程所选 Supabase 配置不完整时永远 emit `null`，
/// 等价于匿名态，调用方无需特殊判断。
final supabaseSessionProvider = StreamProvider<Session?>((ref) {
  if (!ref.watch(supabaseAuthConfiguredProvider)) {
    return Stream<Session?>.value(null);
  }

  // SDK 尚未完成第三方启动时，不能把「尚未解析」误当成「确认匿名」。
  // 否则订阅控制器会提前以匿名身份对账，登录用户随后会出现 free 闪烁。
  final startup = ref.watch(thirdPartyStartupProvider);
  if (!startup.hasValue) return const Stream<Session?>.empty();
  if (!(startup.value?.isSupabaseReady ?? false)) {
    return Stream<Session?>.value(null);
  }

  final auth = Supabase.instance.client.auth;
  final controller = StreamController<Session?>();
  final initialSession = auth.currentSession;
  AppLogger.log(
    'AuthSession',
    'provider_created currentSession=${initialSession == null ? "unresolved_or_anonymous" : "signedIn"} '
        'userId=${initialSession?.user.id ?? "none"}',
  );

  // currentSession 可能在 Supabase.initialize() 返回时仍为空；必须先监听
  // onAuthStateChange，等待 initialSession 事件作为首次认证结果。
  final sub = auth.onAuthStateChange.listen((event) {
    final session = event.session;
    AppLogger.log(
      'AuthSession',
      'auth_state_changed event=${event.event.name} '
          'session=${session == null ? "anonymous" : "signedIn"} '
          'userId=${session?.user.id ?? "none"}',
    );
    controller.add(session);
  }, onError: controller.addError);

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// 自建后端鉴权请求共享的 Token Gate。
///
/// 未配置 Supabase 的离线构建返回 null；生产 API client 只在非空时安装鉴权拦截器。
final supabaseTokenCoordinatorProvider = Provider<SupabaseTokenCoordinator?>((
  ref,
) {
  if (!ref.watch(supabaseSdkReadyProvider)) {
    return null;
  }
  final coordinator = SupabaseTokenCoordinator(
    SupabaseAuthSessionSource(Supabase.instance.client.auth),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// 当前是否已登录的便捷 Provider。
///
/// UI 层 `ref.watch(isAuthenticatedProvider)` 比 `watch(supabaseSessionProvider)
/// .valueOrNull != null` 更直观。
final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(supabaseSessionProvider).valueOrNull;
  return session != null;
});
