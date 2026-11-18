import 'dart:io';
import 'dart:typed_data';

import 'package:echo_loop/utils/waveform_peaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waveform_peaks_test');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  /// 写 16 位小端 PCM 裸数据，模拟 FFmpeg `-f s16le` 输出。
  String writePcm(List<int> samples) {
    final data = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(i * 2, samples[i], Endian.little);
    }
    final file = File('${directory.path}/audio.pcm')
      ..writeAsBytesSync(data.buffer.asUint8List());
    return file.path;
  }

  group('computeWaveformPeaksFromPcmFile', () {
    test('每像素取对应采样的 min/max，末尾不足一像素的采样单独成像素', () {
      // 24000Hz / 80px/s = 每像素 300 个采样；750 个采样 = 2 个整像素 + 150 个尾部采样。
      final samples = List<int>.filled(750, 0);
      samples[10] = -1200;
      samples[299] = 3000;
      samples[300] = -32768;
      samples[599] = 32767;
      samples[700] = -5;
      samples[749] = 7;

      final peaks = computeWaveformPeaksFromPcmFile(writePcm(samples));

      expect(peaks.pixelsPerSecond, waveformPixelsPerSecond);
      expect(peaks.length, 3);
      expect([peaks.minAt(0), peaks.maxAt(0)], [-1200, 3000]);
      expect([peaks.minAt(1), peaks.maxAt(1)], [-32768, 32767]);
      expect([peaks.minAt(2), peaks.maxAt(2)], [-5, 7]);
      // 750 / 24000 秒
      expect(peaks.duration, const Duration(microseconds: 31250));
      expect(peaks.peak, 32768);
    });

    test('跨读取分块的像素仍合并为同一对 min/max', () {
      // 读取按 1MB（524288 个采样）分块；像素 1747 覆盖 [524100, 524400)，跨分块边界。
      final samples = List<int>.filled(600000, 1);
      samples[524287] = -20000; // 第一块最后一个采样
      samples[524290] = 25000; // 第二块开头
      samples[599999] = -3; // 最后一个尾部像素

      final peaks = computeWaveformPeaksFromPcmFile(writePcm(samples));

      expect(peaks.length, 2000);
      expect([peaks.minAt(1747), peaks.maxAt(1747)], [-20000, 25000]);
      expect([peaks.minAt(1746), peaks.maxAt(1746)], [1, 1]);
      expect([peaks.minAt(1748), peaks.maxAt(1748)], [1, 1]);
      expect([peaks.minAt(1999), peaks.maxAt(1999)], [-3, 1]);
      expect(peaks.duration, const Duration(milliseconds: 25000));
    });

    test('空 PCM（无音频采样）得到空波形', () {
      final peaks = computeWaveformPeaksFromPcmFile(writePcm(const []));

      expect(peaks.length, 0);
      expect(peaks.duration, Duration.zero);
      expect(peaks.peak, 1);
    });

    test('自定义像素密度（静音检测用的粗密度）', () {
      final samples = List<int>.generate(2400, (i) => i < 1200 ? -100 : 200);

      final peaks = computeWaveformPeaksFromPcmFile(
        writePcm(samples),
        pixelsPerSecond: 20,
      );

      expect(peaks.length, 2);
      expect(peaks.minMax, [-100, -100, 200, 200]);
    });
  });

  group('WaveformPeaks 缓存格式', () {
    WaveformPeaks samplePeaks() => WaveformPeaks(
      pixelsPerSecond: 80,
      duration: const Duration(microseconds: 1234567),
      minMax: Int16List.fromList([-32768, 32767, -1, 1, 0, 0]),
    );

    test('编码后解码保持数据、像素密度与时长', () {
      final decoded = WaveformPeaks.decode(samplePeaks().encode());

      expect(decoded.pixelsPerSecond, 80);
      expect(decoded.duration, const Duration(microseconds: 1234567));
      expect(decoded.minMax, [-32768, 32767, -1, 1, 0, 0]);
      expect(decoded.peak, 32768);
    });

    test('非本格式的文件（如旧版 just_waveform 缓存）判为无效', () {
      final legacy = ByteData(40)..setInt32(0, 2, Endian.little);

      expect(
        () => WaveformPeaks.decode(legacy.buffer.asUint8List()),
        throwsFormatException,
      );
    });

    test('被截断的缓存判为长度不符', () {
      final bytes = samplePeaks().encode();

      expect(
        () => WaveformPeaks.decode(Uint8List.sublistView(bytes, 0, 30)),
        throwsFormatException,
      );
      expect(
        () => WaveformPeaks.decode(Uint8List.sublistView(bytes, 0, 10)),
        throwsFormatException,
      );
    });
  });

  test('positionToPixel 按像素密度换算时间', () {
    final peaks = WaveformPeaks(
      pixelsPerSecond: 80,
      duration: const Duration(seconds: 1),
      minMax: Int16List(160),
    );

    expect(peaks.positionToPixel(const Duration(milliseconds: 500)), 40);
    expect(peaks.positionToPixel(const Duration(microseconds: 12500)), 1);
  });

  group('WaveformPeaksBuilder 增量计算', () {
    test('分段喂入（边界不对齐像素）的结果与整文件计算一致', () {
      final samples = [for (var i = 0; i < 1000; i++) (i * 37) % 2001 - 1000];
      final builder = WaveformPeaksBuilder(expectedSamples: samples.length);
      final chunks = [7, 293, 300, 400];
      var offset = 0;
      for (final size in chunks) {
        builder.addSamples(
          Int16List.fromList(samples.sublist(offset, offset + size)),
          size,
        );
        offset += size;
      }

      final incremental = builder.finish();
      final batch = computeWaveformPeaksFromPcmFile(writePcm(samples));

      expect(incremental.minMax, batch.minMax);
      expect(incremental.duration, batch.duration);
      expect(incremental.peak, batch.peak);
      expect(incremental.isComplete, isTrue);
    });

    test('快照只暴露已完整的像素，长度按预期采样数确定', () {
      // 1500 个预期采样 = 5 个像素（每像素 300 个采样）。
      final builder = WaveformPeaksBuilder(expectedSamples: 1500);
      builder.addSamples(Int16List.fromList(List.filled(600, 4)), 600);

      final first = builder.snapshot();
      expect(first.length, 5);
      expect(first.readyLength, 2);
      expect(first.isComplete, isFalse);
      expect([first.minAt(1), first.maxAt(1)], [4, 4]);

      // 未满一像素的尾巴不进快照。
      builder.addSamples(Int16List.fromList(List.filled(100, 9)), 100);
      expect(builder.snapshot().readyLength, 2);

      builder.addSamples(Int16List.fromList(List.filled(200, -9)), 200);
      final third = builder.snapshot();
      expect(third.readyLength, 3);
      expect([third.minAt(2), third.maxAt(2)], [-9, 9]);
      // 之前返回的快照不随后续写入变化。
      expect(first.readyLength, 2);
      expect(first.minAt(1), 4);
    });

    test('就绪像素数越界时抛出参数错误', () {
      expect(
        () => WaveformPeaks(
          pixelsPerSecond: 80,
          duration: const Duration(seconds: 1),
          minMax: Int16List(4),
          readyLength: 3,
        ),
        throwsArgumentError,
      );
    });

    test('未完成的波形不能写入缓存', () {
      final builder = WaveformPeaksBuilder(expectedSamples: 1500);
      builder.addSamples(Int16List.fromList(List.filled(600, 4)), 600);

      expect(() => builder.snapshot().encode(), throwsStateError);
    });
  });

  test('解码参数：只取第一条音轨，单声道 24kHz 16 位小端 PCM', () {
    final arguments = waveformPcmDecodeArguments(
      input: '/media/a.mkv',
      output: '/tmp/a.pcm',
    );

    expect(arguments.join(' '), contains('-i /media/a.mkv'));
    expect(
      arguments.join(' '),
      contains('-map 0:a:0 -ac 1 -ar 24000 -f s16le'),
    );
    expect(arguments.last, '/tmp/a.pcm');
  });
}
