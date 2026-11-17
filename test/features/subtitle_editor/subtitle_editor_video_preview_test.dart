import 'package:echo_loop/features/subtitle_editor/subtitle_editor_video_preview.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shared/fake_media_player_backend.dart';

void main() {
  late FakeMediaPlayerBackend backend;
  late SubtitleEditorVideoPreview preview;

  setUp(() {
    backend = FakeMediaPlayerBackend();
    preview = SubtitleEditorVideoPreview(backend);
  });

  tearDown(() async {
    await preview.dispose();
  });

  /// 让同步循环里串行的 await 全部跑完。
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('打开后关闭音轨，画面停在初始位置', () async {
    await preview.open('/media/lesson.mp4', initialPosition: seconds(3));

    expect(backend.openCalls, ['/media/lesson.mp4']);
    expect(backend.openInitialPositions, [seconds(3)]);
    expect(backend.audioTrackCalls, [false]);
    expect(preview.status.value, SubtitleEditorVideoStatus.ready);
  });

  test('跟随播放：开始时定位并同速播放，结束时暂停在停止位置', () async {
    await preview.open('/media/lesson.mp4', initialPosition: Duration.zero);

    preview.follow(isPlaying: true, position: seconds(5), speed: 1.5);
    await flush();
    expect(backend.playing, isTrue);
    expect(backend.rate, 1.5);
    expect(backend.seekCalls.last, seconds(5));

    // 播放中的小幅偏差不重新定位，避免频繁 seek 卡顿。
    final seeksWhilePlaying = backend.seekCalls.length;
    preview.follow(
      isPlaying: true,
      position: seconds(5) + const Duration(milliseconds: 100),
      speed: 1.5,
    );
    await flush();
    expect(backend.seekCalls.length, seeksWhilePlaying);

    preview.follow(isPlaying: false, position: seconds(8), speed: 1.5);
    await flush();
    expect(backend.playing, isFalse);
    expect(backend.seekCalls.last, seconds(8));
  });

  test('播放转暂停时即使偏差很小也定位到停止位置（暂停前画面还会再走一点）', () async {
    await preview.open('/media/lesson.mp4', initialPosition: Duration.zero);
    preview.follow(isPlaying: true, position: seconds(5), speed: 1);
    await flush();
    final seeksBefore = backend.seekCalls.length;

    // 停止位置与画面只差 20ms（小于暂停时的 40ms 容差）。
    preview.follow(
      isPlaying: false,
      position: seconds(5) + const Duration(milliseconds: 20),
      speed: 1,
    );
    await flush();

    expect(backend.playing, isFalse);
    expect(backend.seekCalls.length, seeksBefore + 1);
    expect(
      backend.seekCalls.last,
      seconds(5) + const Duration(milliseconds: 20),
    );
  });

  test('暂停时拖动播放头，画面停到对应帧；收起画面时暂停', () async {
    await preview.open('/media/lesson.mp4', initialPosition: Duration.zero);

    preview.follow(isPlaying: false, position: seconds(12), speed: 1);
    await flush();
    expect(backend.seekCalls.last, seconds(12));
    expect(backend.playing, isFalse);

    preview.follow(isPlaying: true, position: seconds(12), speed: 1);
    await flush();
    expect(backend.playing, isTrue);
    preview.suspend();
    await flush();
    expect(backend.playing, isFalse);
  });

  test('文件缺失或打开失败时进入失败态，不再同步', () async {
    await preview.open(null, initialPosition: Duration.zero);
    expect(preview.status.value, SubtitleEditorVideoStatus.failed);
    expect(backend.openCalls, isEmpty);

    final failing = FakeMediaPlayerBackend()..openError = Exception('坏文件');
    final failingPreview = SubtitleEditorVideoPreview(failing);
    await failingPreview.open('/media/bad.mp4', initialPosition: Duration.zero);
    failingPreview.follow(isPlaying: true, position: seconds(1), speed: 1);
    await flush();
    expect(failingPreview.status.value, SubtitleEditorVideoStatus.failed);
    expect(failing.playCalls, 0);
    await failingPreview.dispose();
  });
}

Duration seconds(int value) => Duration(seconds: value);
