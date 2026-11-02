// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foreground_audio_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 前台音频引擎——录音/复习类任务专用，**不接入 `audio_service`**。
///
/// 与媒体引擎 [AudioEngine]（接 `audio_service`，带锁屏/后台/静音保活）相对：
/// 本引擎自持一个**裸 [ja.AudioPlayer]**，物理上碰不到系统媒体会话
/// （`MPNowPlayingInfoCenter` / 前台通知），故播放原句/原段时永不弹锁屏卡片。
///
/// 服务于：难句跟读 / 段落复述 / 难句补练 / 收藏句复习 / 收藏词复习(闪卡)。
/// 这些任务只在前台播放，不需要后台续播与锁屏控制（见 PLAN.md ADR-7）。
///
/// 播放子集逐方法照抄 [AudioEngine]，仅把 `_handler.xxx` 换成裸 `_player.xxx`，
/// 保证 session 守卫、clip 语义、await-完成等行为与 commit 578f8829 一致；
/// 不实现 `setMediaSessionSuppressed` / `setLogicalPlaying` / 保活 / 锁屏回调 /
/// `playToEnd`（媒体会话/整篇循环专属）。

@ProviderFor(ForegroundAudioEngine)
final foregroundAudioEngineProvider = ForegroundAudioEngineProvider._();

/// 前台音频引擎——录音/复习类任务专用，**不接入 `audio_service`**。
///
/// 与媒体引擎 [AudioEngine]（接 `audio_service`，带锁屏/后台/静音保活）相对：
/// 本引擎自持一个**裸 [ja.AudioPlayer]**，物理上碰不到系统媒体会话
/// （`MPNowPlayingInfoCenter` / 前台通知），故播放原句/原段时永不弹锁屏卡片。
///
/// 服务于：难句跟读 / 段落复述 / 难句补练 / 收藏句复习 / 收藏词复习(闪卡)。
/// 这些任务只在前台播放，不需要后台续播与锁屏控制（见 PLAN.md ADR-7）。
///
/// 播放子集逐方法照抄 [AudioEngine]，仅把 `_handler.xxx` 换成裸 `_player.xxx`，
/// 保证 session 守卫、clip 语义、await-完成等行为与 commit 578f8829 一致；
/// 不实现 `setMediaSessionSuppressed` / `setLogicalPlaying` / 保活 / 锁屏回调 /
/// `playToEnd`（媒体会话/整篇循环专属）。
final class ForegroundAudioEngineProvider
    extends $NotifierProvider<ForegroundAudioEngine, AudioEngineState> {
  /// 前台音频引擎——录音/复习类任务专用，**不接入 `audio_service`**。
  ///
  /// 与媒体引擎 [AudioEngine]（接 `audio_service`，带锁屏/后台/静音保活）相对：
  /// 本引擎自持一个**裸 [ja.AudioPlayer]**，物理上碰不到系统媒体会话
  /// （`MPNowPlayingInfoCenter` / 前台通知），故播放原句/原段时永不弹锁屏卡片。
  ///
  /// 服务于：难句跟读 / 段落复述 / 难句补练 / 收藏句复习 / 收藏词复习(闪卡)。
  /// 这些任务只在前台播放，不需要后台续播与锁屏控制（见 PLAN.md ADR-7）。
  ///
  /// 播放子集逐方法照抄 [AudioEngine]，仅把 `_handler.xxx` 换成裸 `_player.xxx`，
  /// 保证 session 守卫、clip 语义、await-完成等行为与 commit 578f8829 一致；
  /// 不实现 `setMediaSessionSuppressed` / `setLogicalPlaying` / 保活 / 锁屏回调 /
  /// `playToEnd`（媒体会话/整篇循环专属）。
  ForegroundAudioEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundAudioEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundAudioEngineHash();

  @$internal
  @override
  ForegroundAudioEngine create() => ForegroundAudioEngine();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioEngineState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioEngineState>(value),
    );
  }
}

String _$foregroundAudioEngineHash() =>
    r'ea93ce94e83c2d6c015f9d720de98611fbc4f279';

/// 前台音频引擎——录音/复习类任务专用，**不接入 `audio_service`**。
///
/// 与媒体引擎 [AudioEngine]（接 `audio_service`，带锁屏/后台/静音保活）相对：
/// 本引擎自持一个**裸 [ja.AudioPlayer]**，物理上碰不到系统媒体会话
/// （`MPNowPlayingInfoCenter` / 前台通知），故播放原句/原段时永不弹锁屏卡片。
///
/// 服务于：难句跟读 / 段落复述 / 难句补练 / 收藏句复习 / 收藏词复习(闪卡)。
/// 这些任务只在前台播放，不需要后台续播与锁屏控制（见 PLAN.md ADR-7）。
///
/// 播放子集逐方法照抄 [AudioEngine]，仅把 `_handler.xxx` 换成裸 `_player.xxx`，
/// 保证 session 守卫、clip 语义、await-完成等行为与 commit 578f8829 一致；
/// 不实现 `setMediaSessionSuppressed` / `setLogicalPlaying` / 保活 / 锁屏回调 /
/// `playToEnd`（媒体会话/整篇循环专属）。

abstract class _$ForegroundAudioEngine extends $Notifier<AudioEngineState> {
  AudioEngineState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AudioEngineState, AudioEngineState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioEngineState, AudioEngineState>,
              AudioEngineState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
