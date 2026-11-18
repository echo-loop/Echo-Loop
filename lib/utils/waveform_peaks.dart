import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// 波形 PCM 解码采样率。
///
/// FFmpeg 解码耗时基本与输出采样率无关（实测 22 分钟 mkv：8k~48k 均约 2.2s），
/// 采样率只影响临时 PCM 大小和峰值计算量。重采样会滤掉 sampleRate/2 以上的成分，
/// 削低齿擦音等高频峰值：与原生采样率相比，16kHz 有约 9% 的竖条高度差超过 1px，
/// 24kHz 约 2%（p99 误差 3%），肉眼无法分辨，因此取 24kHz。
const int waveformPcmSampleRate = 24000;

/// 波形每秒的像素（min/max 对）数。
///
/// 剪辑页最大缩放 120px/s、3px 一根竖条，即每秒 40 根；字幕编辑页最大缩放约 5cm/s，
/// 每秒不到 70 根。80 足够覆盖两者。
const int waveformPixelsPerSecond = 80;

/// 把媒体第一条音轨解码为波形用的 16 位小端单声道 PCM 裸数据的 FFmpeg 参数。
///
/// 只映射第一条音轨，视频等其它流不解码；多声道按平均混成单声道。
List<String> waveformPcmDecodeArguments({
  required String input,
  required String output,
}) => [
  '-nostdin',
  '-y',
  '-v',
  'error',
  '-i',
  input,
  '-map',
  '0:a:0',
  '-ac',
  '1',
  '-ar',
  '$waveformPcmSampleRate',
  '-f',
  's16le',
  output,
];

/// 波形峰值：每个像素一对 min/max（16 位 PCM 采样值），按时间顺序交错存放。
class WaveformPeaks {
  WaveformPeaks({
    required this.pixelsPerSecond,
    required this.duration,
    required Int16List minMax,
  }) : _minMax = minMax,
       peak = _peakOf(minMax) {
    if (pixelsPerSecond <= 0 || minMax.length.isOdd) {
      throw ArgumentError(
        '波形数据无效 pps=$pixelsPerSecond values=${minMax.length}',
      );
    }
  }

  /// 每秒像素数，决定时间与像素下标的换算。
  final int pixelsPerSecond;

  /// 解码出的音频时长（按 PCM 采样数计算）。
  final Duration duration;

  final Int16List _minMax;

  /// 全部采样的最大绝对值，用于把低音量录音也放大到可见高度；至少为 1。
  final int peak;

  /// 像素（min/max 对）数量。
  int get length => _minMax.length ~/ 2;

  /// 交错的 min/max 采样只读视图。
  List<int> get minMax => _minMax.asUnmodifiableView();

  int minAt(int pixel) => _minMax[pixel * 2];
  int maxAt(int pixel) => _minMax[pixel * 2 + 1];

  /// 时间对应的像素下标（可带小数，可越界，由调用方钳制）。
  double positionToPixel(Duration position) =>
      position.inMicroseconds *
      pixelsPerSecond /
      Duration.microsecondsPerSecond;

  // 缓存格式（小端）：magic "ELWP" | pixelsPerSecond u32 | durationUs i64 |
  // pixelCount u32 | pixelCount 对 i16 min/max。
  static const List<int> _magic = [0x45, 0x4C, 0x57, 0x50];
  static const int _headerBytes = 20;

  Uint8List encode() {
    final bytes = Uint8List(_headerBytes + _minMax.lengthInBytes)
      ..setAll(0, _magic)
      ..setAll(_headerBytes, Uint8List.sublistView(_minMax));
    ByteData.sublistView(bytes)
      ..setUint32(4, pixelsPerSecond, Endian.little)
      ..setInt64(8, duration.inMicroseconds, Endian.little)
      ..setUint32(16, length, Endian.little);
    return bytes;
  }

  /// 解析 [encode] 写出的缓存；不是该格式或长度不符时抛 [FormatException]。
  static WaveformPeaks decode(Uint8List bytes) {
    final header = ByteData.sublistView(bytes);
    final isValid =
        bytes.length >= _headerBytes &&
        _magic.indexed.every((entry) => bytes[entry.$1] == entry.$2) &&
        bytes.length == _headerBytes + header.getUint32(16, Endian.little) * 4;
    if (!isValid) throw const FormatException('波形缓存格式无效');
    return WaveformPeaks(
      pixelsPerSecond: header.getUint32(4, Endian.little),
      duration: Duration(microseconds: header.getInt64(8, Endian.little)),
      // sublist 复制到从 0 开始的新 buffer，保证 16 位视图对齐。
      minMax: Int16List.sublistView(bytes.sublist(_headerBytes)),
    );
  }

  static int _peakOf(Int16List values) {
    var peak = 1;
    for (final value in values) {
      final magnitude = value.abs();
      if (magnitude > peak) peak = magnitude;
    }
    return peak;
  }
}

/// 在后台 isolate 计算 [computeWaveformPeaksFromPcmFile]，不阻塞 UI。
///
/// 放在顶层函数里，闭包只捕获参数本身；在调用方方法内直接写 `Isolate.run`
/// 会连带捕获外层上下文（如 Notifier 的回调、Stream），发送到 isolate 时报
/// `object is unsendable`。
Future<WaveformPeaks> computeWaveformPeaksInBackground(
  String pcmPath, {
  int pixelsPerSecond = waveformPixelsPerSecond,
}) => Isolate.run(
  () => computeWaveformPeaksFromPcmFile(
    pcmPath,
    pixelsPerSecond: pixelsPerSecond,
  ),
);

/// 从 [waveformPcmDecodeArguments] 输出的 PCM 文件计算峰值。整文件同步分块读取，
/// UI 中应经 [computeWaveformPeaksInBackground] 调用。
///
/// 每个像素取 `waveformPcmSampleRate / pixelsPerSecond` 个连续采样的 min/max；末尾
/// 不足一个像素的采样单独成一个像素，保证尾部声音不丢。PCM 与缓存都按宿主字节序
/// 直接映射，本应用支持的平台均为小端。
WaveformPeaks computeWaveformPeaksFromPcmFile(
  String pcmPath, {
  int pixelsPerSecond = waveformPixelsPerSecond,
}) {
  if (waveformPcmSampleRate % pixelsPerSecond != 0) {
    throw ArgumentError('采样率须为像素密度的整数倍：$pixelsPerSecond');
  }
  final samplesPerPixel = waveformPcmSampleRate ~/ pixelsPerSecond;
  final file = File(pcmPath).openSync();
  try {
    final totalSamples = file.lengthSync() ~/ 2;
    final pixelCount = (totalSamples + samplesPerPixel - 1) ~/ samplesPerPixel;
    final minMax = Int16List(pixelCount * 2);
    // 1MB 一块：读写次数少，又不会一次占用整段 PCM 的内存。
    final buffer = Uint8List(1 << 20);
    final samples = Int16List.view(buffer.buffer);
    var remaining = totalSamples;
    var out = 0;
    var count = 0;
    var low = 32767;
    var high = -32768;
    while (remaining > 0) {
      final want = math.min(remaining, samples.length);
      final read = file.readIntoSync(buffer, 0, want * 2);
      if (read != want * 2) {
        throw FileSystemException('PCM 读取不完整', pcmPath);
      }
      remaining -= want;
      for (var i = 0; i < want; i++) {
        final value = samples[i];
        if (value < low) low = value;
        if (value > high) high = value;
        if (++count == samplesPerPixel) {
          minMax[out++] = low;
          minMax[out++] = high;
          count = 0;
          low = 32767;
          high = -32768;
        }
      }
    }
    if (count > 0) {
      minMax[out++] = low;
      minMax[out++] = high;
    }
    return WaveformPeaks(
      pixelsPerSecond: pixelsPerSecond,
      duration: Duration(
        microseconds:
            totalSamples *
            Duration.microsecondsPerSecond ~/
            waveformPcmSampleRate,
      ),
      minMax: minMax,
    );
  } finally {
    file.closeSync();
  }
}
