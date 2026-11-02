// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listening_practice_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ListeningPractice)
final listeningPracticeProvider = ListeningPracticeProvider._();

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
final class ListeningPracticeProvider
    extends $NotifierProvider<ListeningPractice, ListeningPracticeState> {
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
  ListeningPracticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listeningPracticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listeningPracticeHash();

  @$internal
  @override
  ListeningPractice create() => ListeningPractice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ListeningPracticeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ListeningPracticeState>(value),
    );
  }
}

String _$listeningPracticeHash() => r'8914b15ad3bb076bb3add5236ee7deeb8fe48bf8';

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

abstract class _$ListeningPractice extends $Notifier<ListeningPracticeState> {
  ListeningPracticeState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ListeningPracticeState, ListeningPracticeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ListeningPracticeState, ListeningPracticeState>,
              ListeningPracticeState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
