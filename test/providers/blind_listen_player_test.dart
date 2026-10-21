// 盲听播放器手动模式测试
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/models/blind_listen_settings.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/paragraph_playback_driver.dart';
import '../helpers/mock_providers.dart';

/// 测试用段落驱动器：支持 session 管理和模拟播放。
class _TestParagraphPlaybackDriver implements ParagraphPlaybackDriver {
  int _sessionId = 0;
  final speeds = <double>[];

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> pause() async {}

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    if (!isActiveSession(sessionId)) return SentencePlaybackResult.cancelled;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return isActiveSession(sessionId)
        ? SentencePlaybackResult.completed
        : SentencePlaybackResult.cancelled;
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {}

  @override
  void setSessionActive(bool active) {}

  @override
  void setProgressFrozen(bool frozen) {}

  @override
  void unbindLockScreen() {}
}

class _DelayedParagraphPlaybackDriver extends _TestParagraphPlaybackDriver {
  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    if (!isActiveSession(sessionId)) return SentencePlaybackResult.cancelled;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return isActiveSession(sessionId)
        ? SentencePlaybackResult.completed
        : SentencePlaybackResult.cancelled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BlindListenPlayer 手动模式', () {
    late ProviderContainer container;
    late BlindListenPlayer notifier;
    late _TestParagraphPlaybackDriver playbackDriver;

    final paragraphs = [
      [
        Sentence(
          index: 0,
          text: 'First sentence.',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 3),
        ),
        Sentence(
          index: 1,
          text: 'Second sentence.',
          startTime: const Duration(seconds: 3),
          endTime: const Duration(seconds: 6),
        ),
      ],
      [
        Sentence(
          index: 2,
          text: 'Third sentence.',
          startTime: const Duration(seconds: 7),
          endTime: const Duration(seconds: 10),
        ),
      ],
    ];

    setUp(() async {
      container = ProviderContainer(
        overrides: [
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      notifier = container.read(blindListenPlayerProvider.notifier);
      playbackDriver = _TestParagraphPlaybackDriver();
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(controlMode: ShadowingControlMode.manual),
        playbackDriver: playbackDriver,
      );
    });

    tearDown(() => container.dispose());

    test('更新播放速度时同步到段落播放驱动', () async {
      notifier.updateSettings(
        container
            .read(blindListenPlayerProvider)
            .settings
            .copyWith(playbackSpeed: 1.25),
      );

      expect(playbackDriver.speeds, [1.25]);
    });

    test('手动模式下播放段落完成后停止，不启动倒计时', () async {
      await notifier.startPlaying();

      final state = container.read(blindListenPlayerProvider);
      expect(state.isPlaying, false);
      expect(state.isPauseCountdown, false);
      // 仍在第一段
      expect(state.currentParagraphIndex, 0);
    });

    test('手动模式下用户可手动跳转到下一段', () async {
      await notifier.startPlaying();

      // 播放完停止后，手动跳到下一段
      await notifier.goToNextParagraph();

      final state = container.read(blindListenPlayerProvider);
      // 应该在第二段（goToNextParagraph 内部会调用 _playCurrentParagraph）
      expect(state.currentParagraphIndex, 1);
    });

    test('手动模式下重复播放当前段落', () async {
      await notifier.startPlaying();

      // 停止后，恢复播放应重播当前段
      await notifier.resume();

      final state = container.read(blindListenPlayerProvider);
      expect(state.isPlaying, false); // 手动模式播完一遍即停
      expect(state.currentParagraphIndex, 0);
    });

    test('自动模式下播放完段落会启动倒计时', () async {
      // 切换回自动模式
      notifier.updateSettings(
        const BlindListenSettings(controlMode: ShadowingControlMode.auto),
      );

      await notifier.startPlaying();

      final state = container.read(blindListenPlayerProvider);
      // 自动模式下应进入倒计时
      expect(state.isPauseCountdown, true);
    });

    test('等待态挂起时，当前段播完后进入 waiting for user', () async {
      final delayedContainer = ProviderContainer(
        overrides: [
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(delayedContainer.dispose);

      final delayedNotifier = delayedContainer.read(
        blindListenPlayerProvider.notifier,
      );
      await delayedNotifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(controlMode: ShadowingControlMode.auto),
        playbackDriver: _DelayedParagraphPlaybackDriver(),
      );

      final pending = delayedNotifier.startPlaying();
      delayedNotifier.enterWaitingForUser(afterCurrentParagraph: true);
      delayedNotifier.updateSettings(
        const BlindListenSettings(controlMode: ShadowingControlMode.manual),
      );
      await pending;

      final state = delayedContainer.read(blindListenPlayerProvider);
      expect(state.isWaitingForUser, true);
      expect(state.isPlaying, false);
      expect(state.isPauseCountdown, false);
    });
  });
}
