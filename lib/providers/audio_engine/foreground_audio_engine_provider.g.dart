// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foreground_audio_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$foregroundAudioEngineHash() =>
    r'c1a656d395c484562d440631ea38ea63a254d8fb';

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
///
/// Copied from [ForegroundAudioEngine].
@ProviderFor(ForegroundAudioEngine)
final foregroundAudioEngineProvider =
    NotifierProvider<ForegroundAudioEngine, AudioEngineState>.internal(
      ForegroundAudioEngine.new,
      name: r'foregroundAudioEngineProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$foregroundAudioEngineHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ForegroundAudioEngine = Notifier<AudioEngineState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
