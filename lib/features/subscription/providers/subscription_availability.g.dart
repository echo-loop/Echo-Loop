// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_availability.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subscriptionAvailabilityHash() =>
    r'1d8a6329d9b6a654eb55cf7c7323fcb08ca099ee';

/// 当前平台是否支持订阅（订阅 UI 展示总闸）。
///
/// Copied from [subscriptionAvailability].
@ProviderFor(subscriptionAvailability)
final subscriptionAvailabilityProvider = AutoDisposeProvider<bool>.internal(
  subscriptionAvailability,
  name: r'subscriptionAvailabilityProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subscriptionAvailabilityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubscriptionAvailabilityRef = AutoDisposeProviderRef<bool>;
String _$webCheckoutModeHash() => r'a50e5b3874aa3f9c8b5db0c04aa000115c167bd4';

/// 当前是否走 Paddle 网页支付渠道（侧载 APK / 桌面）。
///
/// Paywall 据此切换购买动作：套餐仍由统一 UI 展示，点击后改为
/// 「服务端创建 Paddle checkout + 浏览器结账 + 回流对账」。
///
/// Copied from [webCheckoutMode].
@ProviderFor(webCheckoutMode)
final webCheckoutModeProvider = AutoDisposeProvider<bool>.internal(
  webCheckoutMode,
  name: r'webCheckoutModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$webCheckoutModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WebCheckoutModeRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
