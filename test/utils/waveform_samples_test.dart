import 'dart:io';
import 'dart:typed_data';

import 'package:echo_loop/utils/waveform_samples.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_waveform/just_waveform.dart';

void main() {
  test('16 位波形按 20 字节头读取，不混入头部字段', () async {
    final directory = await Directory.systemTemp.createTemp('waveform-');
    addTearDown(() => directory.delete(recursive: true));
    // just_waveform 的头部视图按 20 个 uint32 读取，文件至少要 80 字节。
    const pixelCount = 20;
    final bytes = ByteData(20 + pixelCount * 4)
      ..setUint32(0, 1, Endian.little)
      ..setUint32(4, 0, Endian.little)
      ..setUint32(8, 44100, Endian.little)
      ..setUint32(12, 441, Endian.little)
      ..setUint32(16, pixelCount, Endian.little);
    const pairs = [(-100, 120), (-300, 250), (-50, 40)];
    for (var i = 0; i < pairs.length; i++) {
      bytes
        ..setInt16(20 + i * 4, pairs[i].$1, Endian.little)
        ..setInt16(22 + i * 4, pairs[i].$2, Endian.little);
    }
    final file = File('${directory.path}/test.wave')
      ..writeAsBytesSync(bytes.buffer.asUint8List());

    final samples = WaveformSamples(await JustWaveform.parse(file));

    expect(samples.length, pixelCount);
    for (var i = 0; i < pairs.length; i++) {
      expect((samples.minAt(i), samples.maxAt(i)), pairs[i]);
    }
    // 头部的采样率 44100 不能被当成峰值。
    expect(samples.peak, 300);
  });
}
