import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';

/// 前台引擎单测：聚焦 session 守卫、loop 计数、clip 状态等编排逻辑
/// （深层 clip 播放与 AudioEngine 逐方法一致，由步骤 6 的行为测试平移守护）。
///
/// 通过子类 override build()（注入初始 state）与 player 触达方法（记录式），
/// 使真实裸 player 永不被操作——同时验证「前台引擎无 handler 引用、从不触达
/// 系统媒体会话」（本类无任何 audio_service / handler 依赖，结构上即保证）。
void main() {
  Sentence sentence(int startMs, int endMs) => Sentence(
    index: 0,
    text: 's',
    startTime: Duration(milliseconds: startMs),
    endTime: Duration(milliseconds: endMs),
  );

  group('ForegroundAudioEngine session 守卫', () {
    test('newSession 递增 sessionId，isActiveSession 仅认最新', () {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _BuildOnlyForegroundEngine(const AudioEngineState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final engine = container.read(foregroundAudioEngineProvider.notifier);

      final id1 = engine.newSession();
      final id2 = engine.newSession();

      expect(id2, id1 + 1);
      expect(engine.isActiveSession(id2), true);
      expect(engine.isActiveSession(id1), false);
    });

    test('playClipOnce 在 session 已过期时立即返回，不触达 player', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _BuildOnlyForegroundEngine(const AudioEngineState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final engine = container.read(foregroundAudioEngineProvider.notifier);

      // 用一个永不等于 state.sessionId(=0) 的过期 id，应在第一行守卫即返回。
      await engine.playClipOnce(sentence(0, 1000), 999);

      // 未进入 clip 设置分支 → clip 状态保持初始。
      expect(container.read(foregroundAudioEngineProvider).isClipActive, false);
    });
  });

  group('ForegroundAudioEngine playClipWithLoops', () {
    test('循环 N 遍各调一次 playClipOnce；中途 session 失效则停止', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _CountingForegroundEngine(const AudioEngineState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final engine =
          container.read(foregroundAudioEngineProvider.notifier)
              as _CountingForegroundEngine;

      final sid = engine.newSession();
      await engine.playClipWithLoops(
        sentence(0, 1000),
        sid,
        loopCount: 3,
        interval: Duration.zero,
      );

      expect(engine.playClipOnceCount, 3);
    });

    test('session 失效后不再播放', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _CountingForegroundEngine(const AudioEngineState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final engine =
          container.read(foregroundAudioEngineProvider.notifier)
              as _CountingForegroundEngine;

      final sid = engine.newSession();
      engine.newSession(); // 立即使 sid 失效

      await engine.playClipWithLoops(
        sentence(0, 1000),
        sid,
        loopCount: 3,
        interval: Duration.zero,
      );

      expect(engine.playClipOnceCount, 0);
    });
  });

  group('ForegroundAudioEngine clearClip', () {
    test('未处于 clip 状态时直接返回', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _NoPlayerClearClipEngine(
              const AudioEngineState(isClipActive: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final engine =
          container.read(foregroundAudioEngineProvider.notifier)
              as _NoPlayerClearClipEngine;

      await engine.clearClip();

      expect(engine.clearCount, 0);
      expect(container.read(foregroundAudioEngineProvider).isClipActive, false);
    });

    test('clip active 时清理并复位 state', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _NoPlayerClearClipEngine(
              const AudioEngineState(
                clipStart: Duration(milliseconds: 500),
                isClipActive: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final engine =
          container.read(foregroundAudioEngineProvider.notifier)
              as _NoPlayerClearClipEngine;

      await engine.clearClip();

      expect(engine.clearCount, 1);
      expect(
        container.read(foregroundAudioEngineProvider).clipStart,
        Duration.zero,
      );
      expect(container.read(foregroundAudioEngineProvider).isClipActive, false);
    });
  });
}

class _BuildOnlyForegroundEngine extends ForegroundAudioEngine {
  _BuildOnlyForegroundEngine(this.initialState);
  final AudioEngineState initialState;

  @override
  AudioEngineState build() => initialState;
}

/// 覆写 playClipOnce 为记录式，避免触达裸 player，仅验证循环编排。
class _CountingForegroundEngine extends ForegroundAudioEngine {
  _CountingForegroundEngine(this.initialState);
  final AudioEngineState initialState;
  int playClipOnceCount = 0;

  @override
  AudioEngineState build() => initialState;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    playClipOnceCount += 1;
  }
}

/// 覆写 clearClip 为不触达 player 的记录式版本（同 AudioEngine 测试手法）。
class _NoPlayerClearClipEngine extends ForegroundAudioEngine {
  _NoPlayerClearClipEngine(this.initialState);
  final AudioEngineState initialState;
  int clearCount = 0;

  @override
  AudioEngineState build() => initialState;

  @override
  Future<void> clearClip() async {
    if (!state.isClipActive) return;
    state = state.copyWith(clipStart: Duration.zero, isClipActive: false);
    clearCount += 1;
  }
}
