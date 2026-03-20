/// 盲听播放器手动模式测试
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluency/models/blind_listen_settings.dart';
import 'package:fluency/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import '../helpers/mock_providers.dart';

/// 测试用 AudioEngine：支持 session 管理和模拟播放
class _TestAudioEngine extends TestAudioEngine {
  int _sessionId = 0;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId,
  ) async {
    if (!isActiveSession(sessionId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> stopPlayback() async {}

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BlindListenPlayer 手动模式', () {
    late ProviderContainer container;
    late BlindListenPlayer notifier;

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

    setUp(() {
      container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => _TestAudioEngine()),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
        ],
      );
      notifier = container.read(blindListenPlayerProvider.notifier);
      notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(
          controlMode: ShadowingControlMode.manual,
        ),
      );
    });

    tearDown(() => container.dispose());

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
        const BlindListenSettings(
          controlMode: ShadowingControlMode.auto,
        ),
      );

      await notifier.startPlaying();

      final state = container.read(blindListenPlayerProvider);
      // 自动模式下应进入倒计时
      expect(state.isPauseCountdown, true);
    });
  });
}
