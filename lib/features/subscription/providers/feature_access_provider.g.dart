// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_access_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 某 [feature] 当前是否对用户可用。

@ProviderFor(featureAccess)
final featureAccessProvider = FeatureAccessFamily._();

/// 某 [feature] 当前是否对用户可用。

final class FeatureAccessProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 某 [feature] 当前是否对用户可用。
  FeatureAccessProvider._({
    required FeatureAccessFamily super.from,
    required PremiumFeature super.argument,
  }) : super(
         retry: null,
         name: r'featureAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$featureAccessHash();

  @override
  String toString() {
    return r'featureAccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as PremiumFeature;
    return featureAccess(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeatureAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$featureAccessHash() => r'a7c133c1b930b5a3b11bd5ae16beae40f93e64ac';

/// 某 [feature] 当前是否对用户可用。

final class FeatureAccessFamily extends $Family
    with $FunctionalFamilyOverride<bool, PremiumFeature> {
  FeatureAccessFamily._()
    : super(
        retry: null,
        name: r'featureAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 某 [feature] 当前是否对用户可用。

  FeatureAccessProvider call(PremiumFeature feature) =>
      FeatureAccessProvider._(argument: feature, from: this);

  @override
  String toString() => r'featureAccessProvider';
}
