import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../providers/media_engine/media_engine_provider.dart';
import '../../services/app_logger.dart';
import '../../services/media_fullscreen_service.dart';

/// 视频画面的可见性、字幕、全屏与 App 生命周期视频轨状态。
///
/// 任务页宿主与收藏视频讲解会话共用同一份实现，避免两处各自维护 CC、全屏
/// 与后台暂停视频轨的规则。控制器只持有注入的 [MediaEngine]，不负责加载或
/// 释放引擎会话，那是调用方的职责。
class MediaPresentationController extends ChangeNotifier {
  /// [readTranscriptSrt] 在用户开启字幕时才调用，宿主可借此延迟读取数据库，
  /// 避免控制器创建时就依赖尚未就绪的 Provider。
  MediaPresentationController({
    required MediaEngine engine,
    required Future<String?> Function(String audioItemId) readTranscriptSrt,
    required String audioItemId,
  }) : _engine = engine,
       _readTranscriptSrt = readTranscriptSrt,
       _audioItemId = audioItemId;

  final MediaEngine _engine;
  final Future<String?> Function(String audioItemId) _readTranscriptSrt;
  String _audioItemId;
  final MediaFullscreenService _fullscreen = MediaFullscreenService();
  StreamSubscription<bool>? _fullscreenSubscription;
  AppLifecycleListener? _lifecycle;
  bool _visualTrackVisible = true;
  bool _expanded = false;
  bool _subtitleVisible = false;
  bool _isReleased = false;

  /// 用户是否选择显示视频轨；隐藏后仍保留音频播放。
  bool get visualTrackVisible => _visualTrackVisible;

  /// 视频画面是否处于全屏展开状态。
  bool get expanded => _expanded;

  /// 当前是否已加载并显示字幕轨。
  bool get subtitleVisible => _subtitleVisible;

  /// 开始监听系统全屏与 App 生命周期，应与 [release] 成对调用。
  void start() {
    if (_lifecycle != null || _isReleased) return;
    _fullscreenSubscription = _fullscreen.changes.listen((expanded) {
      _expanded = expanded;
      notifyListeners();
    });
    _lifecycle = AppLifecycleListener(onStateChange: handleLifecycleState);
  }

  /// 进入后台时禁用视频轨以省电；回到前台且画面仍可见时恢复。
  @visibleForTesting
  void handleLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_engine.setVideoTrackEnabled(false));
      case AppLifecycleState.resumed:
        if (_visualTrackVisible) unawaited(_engine.setVideoTrackEnabled(true));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> setVisualTrackVisible(bool visible) async {
    AppLogger.log(
      'PracticeMediaLayout',
      '视频轨${visible ? '显示' : '隐藏'}: audio=$_audioItemId',
    );
    await _engine.setVideoTrackEnabled(visible);
    _visualTrackVisible = visible;
    notifyListeners();
  }

  Future<void> setSubtitleVisible(bool visible) async {
    if (visible) {
      final srt = await _readTranscriptSrt(_audioItemId);
      await _engine.setSubtitleTrackData(srt);
    } else {
      await _engine.setSubtitleTrackData(null);
    }
    _subtitleVisible = visible;
    notifyListeners();
  }

  Future<void> setFullscreen(bool expanded) async {
    if (expanded) {
      await _fullscreen.enter(
        isLandscapeVideo: _engine.isLandscapeVideo ?? false,
      );
      return;
    }
    await _fullscreen.exit();
  }

  /// 宿主更换材料时清除上一份材料的字幕开关。
  ///
  /// 不通知监听者：调用方正处于重建过程中，随后会读取新状态。
  void switchAudioItem(String audioItemId) {
    _audioItemId = audioItemId;
    _subtitleVisible = false;
  }

  /// 停止监听并退出系统全屏，只生效一次。
  Future<void> release() async {
    if (_isReleased) return;
    _isReleased = true;
    _lifecycle?.dispose();
    _lifecycle = null;
    await _fullscreenSubscription?.cancel();
    _fullscreenSubscription = null;
    await _fullscreen.exit();
    await _fullscreen.dispose();
  }
}
