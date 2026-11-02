// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_availability.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 当前平台是否支持订阅（订阅 UI 展示总闸）。

@ProviderFor(subscriptionAvailability)
final subscriptionAvailabilityProvider = SubscriptionAvailabilityProvider._();

/// 当前平台是否支持订阅（订阅 UI 展示总闸）。

final class SubscriptionAvailabilityProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 当前平台是否支持订阅（订阅 UI 展示总闸）。
  SubscriptionAvailabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionAvailabilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionAvailabilityHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return subscriptionAvailability(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$subscriptionAvailabilityHash() =>
    r'1d8a6329d9b6a654eb55cf7c7323fcb08ca099ee';

/// 当前是否走 Paddle 网页支付渠道（侧载 APK / 桌面）。
///
/// Paywall 据此切换购买动作：套餐仍由统一 UI 展示，点击后改为
/// 「服务端创建 Paddle checkout + 浏览器结账 + 回流对账」。

@ProviderFor(webCheckoutMode)
final webCheckoutModeProvider = WebCheckoutModeProvider._();

/// 当前是否走 Paddle 网页支付渠道（侧载 APK / 桌面）。
///
/// Paywall 据此切换购买动作：套餐仍由统一 UI 展示，点击后改为
/// 「服务端创建 Paddle checkout + 浏览器结账 + 回流对账」。

final class WebCheckoutModeProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 当前是否走 Paddle 网页支付渠道（侧载 APK / 桌面）。
  ///
  /// Paywall 据此切换购买动作：套餐仍由统一 UI 展示，点击后改为
  /// 「服务端创建 Paddle checkout + 浏览器结账 + 回流对账」。
  WebCheckoutModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webCheckoutModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webCheckoutModeHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return webCheckoutMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$webCheckoutModeHash() => r'a50e5b3874aa3f9c8b5db0c04aa000115c167bd4';
