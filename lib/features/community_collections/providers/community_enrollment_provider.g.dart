// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_enrollment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 社区合集加入和移除的业务入口。

@ProviderFor(CommunityEnrollment)
final communityEnrollmentProvider = CommunityEnrollmentProvider._();

/// 社区合集加入和移除的业务入口。
final class CommunityEnrollmentProvider
    extends $NotifierProvider<CommunityEnrollment, void> {
  /// 社区合集加入和移除的业务入口。
  CommunityEnrollmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityEnrollmentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityEnrollmentHash();

  @$internal
  @override
  CommunityEnrollment create() => CommunityEnrollment();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$communityEnrollmentHash() =>
    r'6284477e984701cd29cdcbb62b56d5712da39c4d';

/// 社区合集加入和移除的业务入口。

abstract class _$CommunityEnrollment extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
