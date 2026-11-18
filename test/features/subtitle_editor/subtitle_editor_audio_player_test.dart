import 'dart:async';

import 'package:echo_loop/features/subtitle_editor/subtitle_editor_audio_player.dart';
import 'package:flutter_test/flutter_test.dart';

import 'subtitle_editor_test_support.dart';

void main() {
  late RangeRecordingBackend backend;
  late SubtitleEditorAudioPlayer player;

  setUp(() {
    backend = RangeRecordingBackend(const Duration(seconds: 12));
    player = SubtitleEditorAudioPlayer(backend);
  });

  tearDown(() => player.dispose());

  test('打开媒体：调小输出缓冲、关闭视频轨（画面由独立预览播放器负责），返回时长', () async {
    final duration = await player.open('/media/movie.mkv');

    expect(duration, const Duration(seconds: 12));
    expect(backend.openCalls, ['/media/movie.mkv']);
    expect(backend.videoTrackCalls, [false]);
    expect(backend.audioOutputBufferCalls, [
      const Duration(milliseconds: 50),
    ], reason: '默认输出缓冲会在原生终点处截掉句尾约 200ms');
  });

  test('打开失败时抛出，不吞掉错误', () async {
    backend.openError = Exception('无法解码');

    await expectLater(player.open('/media/broken.mkv'), throwsException);
  });

  test('区间播放：先撤销旧终点再定位，设置新终点后起播，播到终点返回', () async {
    final session = player.newSession();
    final playback = player.playRange(
      const Duration(seconds: 2),
      const Duration(seconds: 3),
      session,
    );
    await pumpEventQueue();

    expect(backend.playbackEndCalls, [null, const Duration(seconds: 3)]);
    expect(backend.ranges, [
      (const Duration(seconds: 2), const Duration(seconds: 3)),
    ]);

    var isDone = false;
    unawaited(playback.then((_) => isDone = true));
    await pumpEventQueue();
    expect(isDone, isFalse, reason: '未到终点不应返回');

    backend.completePlayback();
    await playback;
  });

  test('起播前晚到的暂停 / 结束事件不会让区间提前结束', () async {
    backend.playGate = Completer<void>();
    backend.playStarted = Completer<void>();
    final session = player.newSession();
    final playback = player.playRange(
      const Duration(seconds: 2),
      const Duration(seconds: 3),
      session,
    );
    var isDone = false;
    unawaited(playback.then((_) => isDone = true));
    await backend.playStarted!.future;

    // 上一段播放的暂停与自然结束事件在新区间起播前才到达。
    backend.emitCompleted();
    backend.emitPlaying(false);
    backend.playGate!.complete();
    await pumpEventQueue();
    expect(backend.playing, isTrue);
    expect(isDone, isFalse);

    backend.completePlayback();
    await playback;
    expect(isDone, isTrue);
  });

  test('新会话立即结束进行中的区间播放，旧会话的后续步骤不再执行', () async {
    final first = player.newSession();
    final firstPlayback = player.playRange(
      Duration.zero,
      const Duration(seconds: 4),
      first,
    );
    await pumpEventQueue();

    final second = player.newSession();
    await firstPlayback;
    expect(player.isActiveSession(first), isFalse);
    expect(player.isActiveSession(second), isTrue);

    // 失效会话直接返回，不再操作播放器。
    await player.playRange(Duration.zero, const Duration(seconds: 1), first);
    expect(backend.ranges, hasLength(1));
  });

  test('停止：暂停并撤销区间终点，播放位置保持不动', () async {
    final session = player.newSession();
    final playback = player.playRange(
      const Duration(seconds: 2),
      const Duration(seconds: 3),
      session,
    );
    await pumpEventQueue();
    backend.emitPosition(const Duration(milliseconds: 2500));

    await player.stop();
    await playback;

    expect(backend.playing, isFalse);
    expect(backend.playbackEnd, isNull);
    expect(backend.position, const Duration(milliseconds: 2500));
  });
}
