// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listening_practice_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listeningPracticeHash() => r'3dbe456f48ef1076603c858a49d0898161728adc';

/// 自由练习播放器的状态与业务编排。
///
/// 播放推进采用统一的「确定性 await-完成循环」模型：无论整篇连续播放
/// （[_playWholeDriven]）还是单句循环/收藏跳播（[_playSentenceDriven]），都在
/// 协程里 `await` 引擎播放一遍（[AudioEngine.playToEnd] / [AudioEngine.playClipOnce]）
/// 后，用纯函数 [decideNext] / [shouldLoopWhole] 决定下一步（重播 / 进下一句 /
/// 回卷 / 停止）。计数与循环不依赖反应式的 `completed` 事件流，从根上避免 just_audio
/// 重复/滞后 `completed` 事件导致的多计数与提前停止。
///
/// 真相源是 [ListeningPracticeState.currentFullIndex] /
/// [ListeningPracticeState.currentBookmarkIndex]，只在以下入口被修改：
/// 用户显式选句/上下句、连播时位置流推进（仅 gapless 模式）、完成事件归约器。
///
/// Copied from [ListeningPractice].
@ProviderFor(ListeningPractice)
final listeningPracticeProvider =
    NotifierProvider<ListeningPractice, ListeningPracticeState>.internal(
      ListeningPractice.new,
      name: r'listeningPracticeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$listeningPracticeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ListeningPractice = Notifier<ListeningPracticeState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
