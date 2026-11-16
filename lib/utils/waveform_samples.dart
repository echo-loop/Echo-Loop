import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_waveform/just_waveform.dart';

/// 按 audiowaveform 格式正确读取 [Waveform] 的 min/max 采样。
///
/// just_waveform 0.0.7 解析 16 位数据时把数据视图偏移写成 10 字节（规范为 20 字节头），
/// 导致 `getPixelMin/Max` 整体错位 5 个采样、开头还混入头部字段（如采样率 44100），
/// 波形被异常峰值压扁。这里从第 20 字节重新建立视图；8 位数据的偏移本身正确，直接使用。
class WaveformSamples {
  WaveformSamples._(this._samples, this.length) : peak = _peakOf(_samples);

  factory WaveformSamples(Waveform waveform) {
    const headerBytes = 20;
    final data = waveform.data;
    if (data is Int16List) {
      final available = (data.buffer.lengthInBytes - headerBytes) ~/ 2;
      final count = math.min(waveform.length * 2, available);
      return WaveformSamples._(
        Int16List.view(data.buffer, headerBytes, math.max(0, count)),
        math.max(0, count) ~/ 2,
      );
    }
    return WaveformSamples._(data, math.min(waveform.length, data.length ~/ 2));
  }

  final List<int> _samples;

  /// 像素（min/max 对）数量。
  final int length;

  /// 全部采样的最大绝对值，用于把低音量录音也放大到可见高度；至少为 1。
  final int peak;

  int minAt(int pixel) => _samples[pixel * 2];
  int maxAt(int pixel) => _samples[pixel * 2 + 1];

  static int _peakOf(List<int> samples) {
    var peak = 1;
    for (final value in samples) {
      final magnitude = value.abs();
      if (magnitude > peak) peak = magnitude;
    }
    return peak;
  }
}
