import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/services/background_audio_handler.dart';

/// just_audio 播放器的最小 mock：仅满足 [EchoLoopAudioHandler] 构造与
/// `_broadcastState` 读取的接口，不做真实播放。
class _MockAudioPlayer extends Mock implements ja.AudioPlayer {}

void main() {
  late _MockAudioPlayer player;
  late EchoLoopAudioHandler handler;

  setUp(() {
    player = _MockAudioPlayer();
    // 构造函数订阅这两个流，给空流即可。
    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<ja.PlaybackEvent>.empty());
    when(
      () => player.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    // _broadcastState 读取的瞬时状态。
    when(() => player.playing).thenReturn(false);
    when(() => player.processingState).thenReturn(ja.ProcessingState.idle);
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.bufferedPosition).thenReturn(Duration.zero);
    when(() => player.speed).thenReturn(1.0);
    when(() => player.play()).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    handler = EchoLoopAudioHandler(player: player);
  });

  group('skip 回调', () {
    test('未注册时 skipToNext/skipToPrevious 为 no-op，且控制列表不含切句', () async {
      await handler.skipToNext();
      await handler.skipToPrevious();

      // 触发一次广播后读取 controls（未注册回调 → 仅播放/停止）。
      handler.setSkipHandlers(onPrevious: null, onNext: null);
      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls.contains(MediaControl.skipToPrevious), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });

    test('注册后 skipToNext/skipToPrevious 触发对应回调', () async {
      var nextCalls = 0;
      var prevCalls = 0;
      handler.setSkipHandlers(
        onPrevious: () async => prevCalls++,
        onNext: () async => nextCalls++,
      );

      await handler.skipToNext();
      await handler.skipToPrevious();

      expect(nextCalls, 1);
      expect(prevCalls, 1);
    });

    test('注册后控制列表与 systemActions 包含切句', () {
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToPrevious), isTrue);
      expect(state.controls.contains(MediaControl.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToPrevious), isTrue);
    });

    test('清空回调后控制列表恢复为播放/停止', () {
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});
      handler.setSkipHandlers(onPrevious: null, onNext: null);

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });
  });

  group('seek 回调（后退/前进 10 秒）', () {
    test('注册后 rewind/fastForward 触发对应回调', () async {
      var rewindCalls = 0;
      var forwardCalls = 0;
      handler.setSeekHandlers(
        onRewind: () async => rewindCalls++,
        onFastForward: () async => forwardCalls++,
      );

      await handler.rewind();
      await handler.fastForward();

      expect(rewindCalls, 1);
      expect(forwardCalls, 1);
    });

    test('注册后控制列表与 systemActions 含 rewind/fastForward', () {
      handler.setSeekHandlers(
        onRewind: () async {},
        onFastForward: () async {},
      );

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.rewind), isTrue);
      expect(state.controls.contains(MediaControl.fastForward), isTrue);
      expect(state.systemActions.contains(MediaAction.rewind), isTrue);
      expect(state.systemActions.contains(MediaAction.fastForward), isTrue);
      // seek 模式不出现切句按钮。
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls.contains(MediaControl.skipToPrevious), isFalse);
    });

    test('切句回调优先于 seek 回调（互斥）', () {
      handler.setSeekHandlers(
        onRewind: () async {},
        onFastForward: () async {},
      );
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToPrevious), isTrue);
      expect(state.controls.contains(MediaControl.skipToNext), isTrue);
      expect(state.controls.contains(MediaControl.rewind), isFalse);
      expect(state.controls.contains(MediaControl.fastForward), isFalse);
    });

    test('清空 seek 回调后恢复为播放/停止', () {
      handler.setSeekHandlers(
        onRewind: () async {},
        onFastForward: () async {},
      );
      handler.setSeekHandlers(onRewind: null, onFastForward: null);

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.rewind), isFalse);
      expect(state.controls.contains(MediaControl.fastForward), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });

    test('未注册时 rewind/fastForward 为 no-op', () async {
      await handler.rewind();
      await handler.fastForward();
      // 不抛异常即通过。
    });
  });

  group('processingState 映射（锁屏状态）', () {
    test('completed 上报为 ready，避免锁屏进度条卡在结尾', () {
      // just_audio 自然播完后处于 completed、playing 仍为 true（§7.6）。
      when(
        () => player.processingState,
      ).thenReturn(ja.ProcessingState.completed);
      when(() => player.playing).thenReturn(true);

      // 触发一次广播（setSkipHandlers 内部调用 _broadcastState）。
      handler.setSkipHandlers(onPrevious: null, onNext: null);

      final state = handler.playbackState.value;
      // 关键断言：系统永远收不到 completed，否则整篇循环回卷后进度条会被钉在结尾。
      expect(state.processingState, AudioProcessingState.ready);
    });

    test('其余状态按原样映射', () {
      const cases = {
        ja.ProcessingState.idle: AudioProcessingState.idle,
        ja.ProcessingState.loading: AudioProcessingState.loading,
        ja.ProcessingState.buffering: AudioProcessingState.buffering,
        ja.ProcessingState.ready: AudioProcessingState.ready,
      };
      for (final entry in cases.entries) {
        when(() => player.processingState).thenReturn(entry.key);
        handler.setSkipHandlers(onPrevious: null, onNext: null);
        expect(handler.playbackState.value.processingState, entry.value);
      }
    });
  });

  group('逻辑播放态覆盖（锁屏图标真相源）', () {
    test('setLogicalPlaying(true) 使广播 playing=true 且图标为暂停（即便裸 player 未播放）', () {
      when(() => player.playing).thenReturn(false);

      handler.setLogicalPlaying(true);

      final state = handler.playbackState.value;
      // 停顿倒计时期间裸 player 已暂停，但锁屏必须显示「播放中」。
      expect(state.playing, isTrue);
      expect(state.controls.contains(MediaControl.pause), isTrue);
      expect(state.controls.contains(MediaControl.play), isFalse);
    });

    test('setLogicalPlaying(false) 覆盖裸 playing=true（修复图标卡暂停的反面）', () {
      when(() => player.playing).thenReturn(true);

      handler.setLogicalPlaying(false);

      final state = handler.playbackState.value;
      expect(state.playing, isFalse);
      expect(state.controls.contains(MediaControl.play), isTrue);
    });

    test('setLogicalPlaying(null) 恢复读裸 player.playing（Free Player 行为不变）', () {
      when(() => player.playing).thenReturn(true);
      handler.setLogicalPlaying(true);

      handler.setLogicalPlaying(null);
      // 覆盖清除后读裸值：当前裸 playing=true。
      expect(handler.playbackState.value.playing, isTrue);

      // 裸值变 false 后，下一次广播应反映 false。
      when(() => player.playing).thenReturn(false);
      handler.setSkipHandlers(onPrevious: null, onNext: null); // 触发广播
      expect(handler.playbackState.value.playing, isFalse);
    });
  });

  group('静音保活（非 iOS 测试环境为 no-op，不抛异常）', () {
    test('startKeepAlive/stopKeepAlive 在测试环境安全调用', () async {
      // 测试运行于 host（非 iOS），startKeepAlive 直接 return，不创建播放器、不抛异常。
      await handler.startKeepAlive();
      await handler.stopKeepAlive();
    });
  });

  group('play/pause 命令路由', () {
    test('未注册时 play/pause 直接驱动底层播放器', () async {
      await handler.play();
      await handler.pause();

      verify(() => player.play()).called(1);
      verify(() => player.pause()).called(1);
    });

    test('注册后 play/pause 转交业务回调，不直接碰播放器', () async {
      var playCalls = 0;
      var pauseCalls = 0;
      handler.setTransportHandlers(
        onPlay: () async => playCalls++,
        onPause: () async => pauseCalls++,
      );

      await handler.play();
      await handler.pause();

      expect(playCalls, 1);
      expect(pauseCalls, 1);
      verifyNever(() => player.play());
      verifyNever(() => player.pause());
    });

    test('playPlayer/pausePlayer 始终直接驱动播放器（不经回调）', () async {
      handler.setTransportHandlers(onPlay: () async {}, onPause: () async {});

      await handler.playPlayer();
      await handler.pausePlayer();

      verify(() => player.play()).called(1);
      verify(() => player.pause()).called(1);
    });
  });

  group('stop 广播（退出播放页面清锁屏控制）', () {
    test('stop() 显式广播 idle，使 audio_service 调 stopService 清锁屏控制', () async {
      when(() => player.stop()).thenAnswer((_) async {});
      // stop 后 just_audio 进入 idle。
      when(() => player.processingState).thenReturn(ja.ProcessingState.idle);
      when(() => player.playing).thenReturn(false);

      await handler.stop();

      final state = handler.playbackState.value;
      // 关键：必须广播 idle，否则 audio_service 不触发 stopService、锁屏控制残留。
      expect(state.processingState, AudioProcessingState.idle);
      expect(state.playing, isFalse);
    });
  });

  group('锁屏进度：clip 偏移上报绝对位置（盲听切句不归零）', () {
    setUp(() {
      when(
        () => player.setClip(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer((_) async => const Duration(seconds: 20));
    });

    test('setClip 后广播绝对位置 = clip 起点 + clip 内相对位置', () async {
      // 段落 clip = [30s, 50s]，clip 内已播 5s。
      await handler.setClip(
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 50),
      );
      when(() => player.position).thenReturn(const Duration(seconds: 5));
      when(
        () => player.bufferedPosition,
      ).thenReturn(const Duration(seconds: 6));

      handler.setLogicalPlaying(true); // 触发广播

      final state = handler.playbackState.value;
      // 绝对位置 = 30s + 5s = 35s（而非 clip 相对的 5s，更非归零）。
      expect(state.updatePosition, const Duration(seconds: 35));
      expect(state.bufferedPosition, const Duration(seconds: 36));
    });

    test('切到另一段（重设 clip）后绝对位置随新 clip 起点更新，不归零', () async {
      await handler.setClip(
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 50),
      );
      // 切到下一段 clip = [50s, 70s]，新 clip 内相对位置回到 0。
      await handler.setClip(
        start: const Duration(seconds: 50),
        end: const Duration(seconds: 70),
      );
      when(() => player.position).thenReturn(Duration.zero);

      handler.setLogicalPlaying(true);

      // 绝对位置 = 50s（新段起点），而非 0。
      expect(
        handler.playbackState.value.updatePosition,
        const Duration(seconds: 50),
      );
    });

    test('无 clip（clearClip）后绝对位置回退为裸 player.position', () async {
      await handler.setClip(
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 50),
      );
      // clearClip：start/end 均为 null。
      await handler.setClip(start: null, end: null);
      when(() => player.position).thenReturn(const Duration(seconds: 8));

      handler.setLogicalPlaying(true);

      // _clipStart 归零 → 绝对位置 = 裸 position（Free Player 整曲行为不变）。
      expect(
        handler.playbackState.value.updatePosition,
        const Duration(seconds: 8),
      );
    });
  });

  group('进度冻结（停顿倒计时锁屏进度条不外推前进）', () {
    test('冻结时广播 speed=0，但 playing 仍由逻辑播放态决定（图标不变）', () {
      when(() => player.speed).thenReturn(1.5);
      handler.setLogicalPlaying(true);

      handler.setProgressFrozen(true);

      final state = handler.playbackState.value;
      // speed=0 → iOS 不按 playbackRate 外推 elapsed，进度条停住。
      expect(state.speed, 0.0);
      // playing 仍为 true → 锁屏图标保持「播放中」（暂停图标）。
      expect(state.playing, isTrue);
    });

    test('解除冻结后广播恢复真实 speed', () {
      when(() => player.speed).thenReturn(1.5);
      handler.setLogicalPlaying(true);
      handler.setProgressFrozen(true);

      handler.setProgressFrozen(false);

      expect(handler.playbackState.value.speed, 1.5);
    });

    test('冻结期间仍上报当前绝对位置（停在段尾），不归零', () async {
      when(
        () => player.setClip(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer((_) async => const Duration(seconds: 20));
      // 段落 clip = [30s, 50s]，已播到段尾（clip 内相对 20s）。
      await handler.setClip(
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 50),
      );
      when(() => player.position).thenReturn(const Duration(seconds: 20));
      handler.setLogicalPlaying(true);

      handler.setProgressFrozen(true);

      final state = handler.playbackState.value;
      expect(state.speed, 0.0);
      // 进度停在段尾绝对位置 50s（= 30s + 20s），而非归零或继续前进。
      expect(state.updatePosition, const Duration(seconds: 50));
    });
  });
}
