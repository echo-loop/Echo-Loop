/// 波形生成（FFmpeg 解码 PCM + 自研峰值计算）的真机 / 桌面集成测试。
///
/// 用 ffmpeg 合成「前 2 秒静音、后 2 秒 0.5 满量程 440Hz 正弦」的双声道音频，封装为
/// 常见音频格式与 mkv / avi 视频，走真实 FFmpegKit 与后台 isolate，验证：
/// - 各容器 / 编码都能生成波形，时长正确；
/// - 静音段峰值接近 0、正弦段每个像素的 min/max 都接近 ±0.5 满量程（双声道正确混音）；
/// - 进度单调递增并以 1 结束；
/// - 二次加载命中缓存；
/// - 解码中取消即终止，不留下缓存；
/// - 导入时的静音检测（同一解码与峰值计算）对 mkv 也生效。
///
/// 运行：flutter test integration_test/media_waveform_loader_test.dart -d macos
library;

import 'dart:io';

import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/features/media_trim/media_trim_processor.dart';
import 'package:echo_loop/features/media_trim/media_trim_waveform_loader.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:echo_loop/utils/audio_content_check.dart';
import 'package:echo_loop/utils/waveform_peaks.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';

import '../test/helpers/shared/test_fixtures.dart';

const _tag = 'MediaWaveform';
const _loader = MediaTrimWaveformLoader(MediaTrimProcessor());

/// 正弦段幅度（满量程比例）。
const _toneAmplitude = 0.5;
const _signal =
    "aevalsrc=exprs='if(lt(t,2),0,$_toneAmplitude*sin(2*PI*440*t))'"
    ':s=48000:c=stereo:d=4';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory appDir;

  // 与其它 macOS 集成测试一致：结束时隐藏窗口，测试进程才会随 flutter test 退出，
  // 否则每次运行都残留一个 Echo Loop 窗口。
  setUpAll(() async {
    if (Platform.isMacOS) await windowManager.ensureInitialized();
  });

  tearDownAll(() async {
    if (Platform.isMacOS) await windowManager.hide();
  });

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('media-waveform-');
    appDataDirectoryOverride = appDir;
    AppLogger.instance.clear();
  });

  tearDown(() async {
    appDataDirectoryOverride = null;
    await appDir.delete(recursive: true);
  });

  Future<String> synthesize(String fileName, List<String> arguments) async {
    final output = '${appDir.path}/$fileName';
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      ...arguments,
      output,
    ]);
    expect(
      ReturnCode.isSuccess(await session.getReturnCode()),
      isTrue,
      reason: await session.getOutput(),
    );
    return output;
  }

  Future<WaveformPeaks> load(
    String id,
    String path, {
    List<double>? progress,
    MediaTrimCancellation? cancellation,
  }) => _loader.load(
    source: createTestAudioItem(id: id, audioPath: path),
    mediaPath: path,
    mediaDuration: const Duration(seconds: 4),
    cancellation: cancellation ?? MediaTrimCancellation(),
    onProgress: (value) => progress?.add(value),
  );

  File cacheOf(String id) => File('${appDir.path}/waveforms/$id.wave');

  bool hasLog(String fragment) => AppLogger.instance.entries.any(
    (entry) => entry.tag == _tag && entry.message.contains(fragment),
  );

  /// 跳过编码器预回声 / 过渡附近的像素，只看稳定区间。
  void expectSignalShape(WaveformPeaks peaks, String label) {
    expect(
      (peaks.duration.inMilliseconds - 4000).abs(),
      lessThan(100),
      reason: '$label 时长',
    );
    expect(peaks.pixelsPerSecond, waveformPixelsPerSecond);
    int pixelAt(double seconds) => (seconds * peaks.pixelsPerSecond).round();
    const fullScale = 32768;
    for (var i = pixelAt(0.2); i < pixelAt(1.8); i++) {
      final magnitude = [
        peaks.minAt(i).abs(),
        peaks.maxAt(i).abs(),
      ].reduce((a, b) => a > b ? a : b);
      expect(magnitude, lessThan(fullScale * 0.01), reason: '$label 静音段像素 $i');
    }
    const expected = fullScale * _toneAmplitude;
    for (var i = pixelAt(2.3); i < pixelAt(3.7); i++) {
      expect(
        peaks.maxAt(i),
        inInclusiveRange(expected * 0.9, expected * 1.1),
        reason: '$label 正弦段像素 $i max',
      );
      expect(
        -peaks.minAt(i),
        inInclusiveRange(expected * 0.9, expected * 1.1),
        reason: '$label 正弦段像素 $i min',
      );
    }
  }

  for (final (fileName, arguments) in [
    ('tone.m4a', ['-f', 'lavfi', '-i', _signal, '-c:a', 'aac', '-b:a', '128k']),
    ('tone.flac', ['-f', 'lavfi', '-i', _signal, '-c:a', 'flac']),
    ('tone.wav', ['-f', 'lavfi', '-i', _signal, '-c:a', 'pcm_s16le']),
    (
      'tone.mkv',
      [
        ...['-f', 'lavfi', '-i', 'testsrc=size=160x120:rate=25:duration=4'],
        ...['-f', 'lavfi', '-i', _signal],
        ...['-c:v', 'mpeg4', '-c:a', 'ac3', '-b:a', '192k'],
      ],
    ),
    (
      'tone.avi',
      [
        ...['-f', 'lavfi', '-i', 'testsrc=size=160x120:rate=25:duration=4'],
        ...['-f', 'lavfi', '-i', _signal],
        ...['-c:v', 'mpeg4', '-c:a', 'pcm_s16le'],
      ],
    ),
  ]) {
    testWidgets('$fileName：生成的波形与信号一致，二次加载命中缓存', (tester) async {
      await tester.runAsync(() async {
        final path = await synthesize(fileName, arguments);
        final progress = <double>[];

        final peaks = await load(fileName, path, progress: progress);

        expectSignalShape(peaks, fileName);
        expect(progress.last, 1);
        for (var i = 1; i < progress.length; i++) {
          expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
        }
        expect(hasLog('波形生成完成 source=$fileName'), isTrue);

        final cached = await load(fileName, path);
        expect(hasLog('波形命中缓存 source=$fileName'), isTrue);
        expect(cached.minMax, peaks.minMax);
        expect(cached.duration, peaks.duration);
      });
    });
  }

  testWidgets('解码中取消：抛出取消、不写缓存', (tester) async {
    await tester.runAsync(() async {
      // 30 分钟音频，解码需要明显时间，保证取消时 FFmpeg 仍在运行。
      final path = await synthesize('long.flac', [
        ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=1800'],
        ...['-c:a', 'flac'],
      ]);
      final cancellation = MediaTrimCancellation();

      final loading = load('long.flac', path, cancellation: cancellation);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await cancellation.cancel();

      await expectLater(
        loading,
        throwsA(
          isA<MediaTrimException>().having(
            (error) => error.failure,
            'failure',
            MediaTrimFailure.cancelled,
          ),
        ),
      );
      expect(await cacheOf('long.flac').exists(), isFalse);
    });
  });

  testWidgets('流式生成：解码期间收到递增的部分波形，前缀与最终结果一致', (tester) async {
    await tester.runAsync(() async {
      // 30 分钟音频，解码耗时远超一个刷新间隔，保证解码期间能收到部分快照。
      final path = await synthesize('stream.flac', [
        ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=1800'],
        ...['-c:a', 'flac'],
      ]);
      final partials = <WaveformPeaks>[];

      final peaks = await _loader.load(
        source: createTestAudioItem(id: 'stream.flac', audioPath: path),
        mediaPath: path,
        mediaDuration: const Duration(seconds: 1800),
        cancellation: MediaTrimCancellation(),
        onProgress: (_) {},
        onPartial: partials.add,
      );

      expect(partials.any((partial) => !partial.isComplete), isTrue);
      var previousReady = 0;
      for (final partial in partials) {
        expect(partial.readyLength, greaterThanOrEqualTo(previousReady));
        expect(partial.length, peaks.length);
        previousReady = partial.readyLength;
        expect(
          partial.minMax.sublist(0, partial.readyLength * 2),
          peaks.minMax.sublist(0, partial.readyLength * 2),
          reason: '就绪像素与最终结果不一致 ready=${partial.readyLength}',
        );
      }
      expect(peaks.isComplete, isTrue);
      expect(hasLog('波形生成完成 source=stream.flac'), isTrue);
    });
  });

  testWidgets('静音检测：全程静音的 mkv 判为 silent，有声音的判为 ok', (tester) async {
    await tester.runAsync(() async {
      const video = [
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=160x120:rate=25:duration=4',
      ];
      await synthesize('silent.mkv', [
        ...video,
        ...['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo:d=4'],
        ...['-c:v', 'mpeg4', '-c:a', 'ac3', '-shortest'],
      ]);
      await synthesize('voice.mkv', [
        ...video,
        ...['-f', 'lavfi', '-i', _signal],
        ...['-c:v', 'mpeg4', '-c:a', 'ac3'],
      ]);

      expect(
        await evaluateAudioContent('silent.mkv'),
        AudioContentStatus.silent,
      );
      expect(await evaluateAudioContent('voice.mkv'), AudioContentStatus.ok);
    });
  });
}
