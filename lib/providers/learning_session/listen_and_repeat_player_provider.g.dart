// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listen_and_repeat_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listenAndRepeatPlayerHash() =>
    r'8f84912af38ede86d726a04236bf051014edcb59';

/// 跟读专用播放器 Provider
///
/// 组合 SentencePlaybackEngine 实现逐句跟读播放循环。
/// 句子列表来自精听阶段标记的难句。
///
/// Copied from [ListenAndRepeatPlayer].
@ProviderFor(ListenAndRepeatPlayer)
final listenAndRepeatPlayerProvider =
    NotifierProvider<
      ListenAndRepeatPlayer,
      ListenAndRepeatPlayerState
    >.internal(
      ListenAndRepeatPlayer.new,
      name: r'listenAndRepeatPlayerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$listenAndRepeatPlayerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ListenAndRepeatPlayer = Notifier<ListenAndRepeatPlayerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
