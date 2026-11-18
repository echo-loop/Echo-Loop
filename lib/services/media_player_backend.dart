import 'dart:async';

import 'package:flutter/widgets.dart';

/// 媒体播放后端抽象。真实实现是 media_kit；测试注入 fake。
///
/// 位置与时长均为绝对时间，media_kit 链路不使用 just_audio 的 clip 语义。
abstract class MediaPlayerBackend {
  Future<void> open(
    String filePath, {
    Duration initialPosition = Duration.zero,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);

  /// 设置原生硬终点：播放器解码到 [end] 即停止，终点后的音频不会进入输出缓冲。
  ///
  /// 传 `null` 撤销终点。终点跨 [open] 不保留。区间播放必须靠它裁切句尾：
  /// 位置事件 + pause 的软停止会受事件间隔与音频输出缓冲影响而越过终点。
  Future<void> setPlaybackEnd(Duration? end);

  /// 设置音频输出缓冲时长，下次 [open] 起生效。
  ///
  /// 播到 [setPlaybackEnd] 的原生终点时播放器立即暂停，输出缓冲里尚未播出的
  /// 声音随之丢弃，句尾被截掉约一个缓冲长度。缓冲越小截得越少，但解码跟不上
  /// 时越容易断音；只在需要精确听到句尾的场景（字幕编辑）调小。
  Future<void> setAudioOutputBuffer(Duration buffer);
  Future<void> setVideoTrackEnabled(bool enabled);

  /// 关闭音轨后播放器不输出声音，也不占用音频输出；用于只借用画面、声音另由
  /// 其它播放链路负责的场景（字幕编辑的视频画面）。
  Future<void> setAudioTrackEnabled(bool enabled);
  Future<void> setSubtitleTrackData(String? srt);
  Future<void> startKeepAlive();
  Future<void> stopKeepAlive();
  Future<void> dispose();

  Duration get position;
  Duration? get duration;
  bool get playing;
  double get rate;

  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<void> get completedStream;

  /// 已解码视频按旋转元数据校正后的显示方向。
  ///
  /// `null` 表示媒体尚未提供视频参数；全屏时应保持当前设备方向。
  bool? get isLandscapeVideo;
  Stream<bool?> get isLandscapeVideoStream;

  /// 已解码视频按旋转元数据校正后的宽高比；参数尚不可用时为 `null`。
  double? get videoAspectRatio;
  Stream<double?> get videoAspectRatioStream;

  Widget buildVideoView({required Size viewportSize});
}
