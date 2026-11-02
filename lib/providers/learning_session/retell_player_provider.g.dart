// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retell_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 复述专用播放器 Provider

@ProviderFor(RetellPlayer)
final retellPlayerProvider = RetellPlayerProvider._();

/// 复述专用播放器 Provider
final class RetellPlayerProvider
    extends $NotifierProvider<RetellPlayer, RetellPlayerState> {
  /// 复述专用播放器 Provider
  RetellPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retellPlayerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retellPlayerHash();

  @$internal
  @override
  RetellPlayer create() => RetellPlayer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetellPlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetellPlayerState>(value),
    );
  }
}

String _$retellPlayerHash() => r'e76ec2be5b3a0cbcf94f87c7b166e089b0c51a13';

/// 复述专用播放器 Provider

abstract class _$RetellPlayer extends $Notifier<RetellPlayerState> {
  RetellPlayerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RetellPlayerState, RetellPlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RetellPlayerState, RetellPlayerState>,
              RetellPlayerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
