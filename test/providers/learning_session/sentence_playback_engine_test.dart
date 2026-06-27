// SentencePlaybackEngine 单元测试。
// 测试纯函数 listenAndRepeatPauseCalculator / targetPlayCountForDifficulty，
// 以及 SentencePlaybackEngine 的 cleanup 和 invalidateSession 生命周期行为。
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/providers/learning_session/sentence_playback_engine.dart';

import '../../helpers/mock_providers.dart';

void main() {
  // ============================================================
  // listenAndRepeatPauseCalculator
  // ============================================================
  group('listenAndRepeatPauseCalculator', () {
    test('零时长返回最小值 2000ms', () {
      final result = listenAndRepeatPauseCalculator(Duration.zero);
      expect(result, const Duration(milliseconds: 2000));
    });

    test('500ms × 2 = 1000ms 小于 2000ms，返回 2000ms', () {
      final result = listenAndRepeatPauseCalculator(
        const Duration(milliseconds: 500),
      );
      expect(result, const Duration(milliseconds: 2000));
    });

    test('999ms × 2 = 1998ms 小于 2000ms，返回 2000ms', () {
      final result = listenAndRepeatPauseCalculator(
        const Duration(milliseconds: 999),
      );
      expect(result, const Duration(milliseconds: 2000));
    });

    test('1000ms × 2 = 2000ms 等于最小值，返回 2000ms', () {
      final result = listenAndRepeatPauseCalculator(
        const Duration(milliseconds: 1000),
      );
      expect(result, const Duration(milliseconds: 2000));
    });

    test('1001ms → 1000 + 600 = 1600ms，clamp 到 2000ms', () {
      final result = listenAndRepeatPauseCalculator(
        const Duration(milliseconds: 1001),
      );
      expect(result, const Duration(milliseconds: 2000));
    });

    test('1500ms → 1000 + 900 = 1900ms，clamp 到 2000ms', () {
      final result = listenAndRepeatPauseCalculator(
        const Duration(milliseconds: 1500),
      );
      expect(result, const Duration(milliseconds: 2000));
    });

    test('5000ms → 1000 + 3000 = 4000ms', () {
      final result = listenAndRepeatPauseCalculator(
        const Duration(milliseconds: 5000),
      );
      expect(result, const Duration(milliseconds: 4000));
    });

    test('返回值始终为 Duration 类型', () {
      final result = listenAndRepeatPauseCalculator(const Duration(seconds: 3));
      expect(result, isA<Duration>());
      // 3s → 1000 + 1800 = 2800ms
      expect(result.inMilliseconds, 2800);
    });
  });

  // ============================================================
  // targetPlayCountForDifficulty
  // ============================================================
  group('targetPlayCountForDifficulty（当前各档统一 3 遍）', () {
    test('各难度档均返回 3', () {
      for (final v in [0, 1, 2, 3, 4]) {
        expect(targetPlayCountForDifficulty(v), 3, reason: 'difficulty=$v');
      }
    });

    test('越界 / 负数同样返回 3', () {
      expect(targetPlayCountForDifficulty(-1), 3);
      expect(targetPlayCountForDifficulty(-100), 3);
      expect(targetPlayCountForDifficulty(5), 3);
      expect(targetPlayCountForDifficulty(999), 3);
    });
  });

  // ============================================================
  // SentencePlaybackEngine 生命周期
  // ============================================================
  group('SentencePlaybackEngine', () {
    late TestForegroundAudioEngine testAudioEngine;
    late SentencePlaybackEngine engine;

    setUp(() {
      testAudioEngine = TestForegroundAudioEngine();
      engine = SentencePlaybackEngine(getEngine: () => testAudioEngine);
    });

    group('初始状态', () {
      test('初始 sessionId 为 -1', () {
        expect(engine.currentSessionId, -1);
      });
    });

    group('cleanup', () {
      test('cleanup 将 sessionId 重置为 -1', () {
        // 先通过 newSession 改变 sessionId
        engine.newSession();
        expect(engine.currentSessionId, isNot(-1));

        engine.cleanup();
        expect(engine.currentSessionId, -1);
      });

      test('多次调用 cleanup 不会抛异常', () {
        engine.cleanup();
        engine.cleanup();
        engine.cleanup();
        expect(engine.currentSessionId, -1);
      });

      test('cleanup 后再调用 cleanup 仍然安全', () {
        engine.newSession();
        engine.cleanup();
        expect(engine.currentSessionId, -1);

        // 第二次 cleanup
        engine.cleanup();
        expect(engine.currentSessionId, -1);
      });
    });

    group('invalidateSession', () {
      test('invalidateSession 将 sessionId 重置为 -1', () {
        engine.newSession();
        expect(engine.currentSessionId, isNot(-1));

        engine.invalidateSession();
        expect(engine.currentSessionId, -1);
      });

      test('invalidateSession 会暂停音频引擎', () {
        engine.newSession();
        // TestAudioEngine.pause() 设置 _isPlaying = false
        engine.invalidateSession();
        expect(testAudioEngine.isPlaying, false);
      });

      test('初始状态下调用 invalidateSession 不会抛异常', () {
        // sessionId 已经是 -1，调用不应出错
        engine.invalidateSession();
        expect(engine.currentSessionId, -1);
      });
    });

    group('newSession', () {
      test('newSession 返回新的 sessionId 并更新 currentSessionId', () {
        final sessionId = engine.newSession();
        expect(engine.currentSessionId, sessionId);
      });

      test('newSession 委托给 AudioEngine', () {
        // TestAudioEngine.newSession() 固定返回 0
        final sessionId = engine.newSession();
        expect(sessionId, 0);
      });
    });

    group('isActiveSession', () {
      test('委托给 AudioEngine 判断 session 是否有效', () {
        // TestAudioEngine.isActiveSession() 固定返回 true
        expect(engine.isActiveSession(0), true);
        expect(engine.isActiveSession(42), true);
      });
    });
  });
}
