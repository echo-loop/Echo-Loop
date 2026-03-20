// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intensive_listen_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$intensiveListenPlayerHash() =>
    r'f7aa0d27a739b96c951bd8942580413d2ae409d2';

/// 精听专用播放器 Provider
///
/// 直接操作 AudioEngine 的 playClipOnce 基元，实现逐句播放循环。
/// 使用 engine 的 sessionId 防止异步竞态。
///
/// Copied from [IntensiveListenPlayer].
@ProviderFor(IntensiveListenPlayer)
final intensiveListenPlayerProvider =
    NotifierProvider<IntensiveListenPlayer, IntensiveListenState>.internal(
      IntensiveListenPlayer.new,
      name: r'intensiveListenPlayerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$intensiveListenPlayerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IntensiveListenPlayer = Notifier<IntensiveListenState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
