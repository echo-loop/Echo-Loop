library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../config/auth_config.dart' as auth_config;
import '../../../services/app_logger.dart';
import '../../../services/user_id_service.dart';
import '../apple_sign_in_credentials.dart';
import '../google_sign_in_credentials.dart';

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

  return {
    if (fullName.isNotEmpty) 'full_name': fullName,
    if (givenName != null && givenName.isNotEmpty) 'given_name': givenName,
    if (familyName != null && familyName.isNotEmpty) 'family_name': familyName,
  };
}

/// 默认认证仓库。
///
/// 未配置 Supabase 时调用动作会立刻抛错，避免页面误以为认证成功。
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!auth_config.isAuthConfigured) {
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

    final anonymousId = _ref.read(userIdProvider);
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
/// 首值：启动时 SDK 已恢复的 `currentSession`（可能为 null）。
/// 后续：`onAuthStateChange` 的每个事件（signedIn / signedOut / tokenRefreshed
/// 等都会带 `session`）。
///
/// Supabase 未配置（`isAuthConfigured == false`）时永远 emit `null`，
/// 等价于匿名态，调用方无需特殊判断。
final supabaseSessionProvider = StreamProvider<Session?>((ref) {
  if (!auth_config.isAuthConfigured) {
    return Stream<Session?>.value(null);
  }

  final auth = Supabase.instance.client.auth;
  final controller = StreamController<Session?>();
  controller.add(auth.currentSession);

  final sub = auth.onAuthStateChange.listen(
    (event) => controller.add(event.session),
    onError: controller.addError,
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// 当前是否已登录的便捷 Provider。
///
/// UI 层 `ref.watch(isAuthenticatedProvider)` 比 `watch(supabaseSessionProvider)
/// .valueOrNull != null` 更直观。
final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(supabaseSessionProvider).valueOrNull;
  return session != null;
});
