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
///
/// 解码过程中可能只有前半段像素就绪（流式显示）：[length] 恒为整段音频的像素数，
/// 只有 [readyLength] 之前的像素有效，绘制与采样都应以 [readyLength] 为界。
class WaveformPeaks {
  WaveformPeaks({
    required this.pixelsPerSecond,
    required this.duration,
    required Int16List minMax,
    int? readyLength,
    int? peak,
  }) : _minMax = minMax,
       readyLength = readyLength ?? minMax.length ~/ 2,
       peak = peak ?? _peakOf(minMax, readyLength ?? minMax.length ~/ 2) {
    if (pixelsPerSecond <= 0 || minMax.length.isOdd) {
      throw ArgumentError(
        '波形数据无效 pps=$pixelsPerSecond values=${minMax.length}',
      );
    }
    if (this.readyLength < 0 || this.readyLength > length) {
      throw ArgumentError('就绪像素越界 ready=${this.readyLength} length=$length');
    }
  }

  /// 每秒像素数，决定时间与像素下标的换算。
  final int pixelsPerSecond;

  /// 解码出的音频时长（按 PCM 采样数计算）。
  final Duration duration;

  final Int16List _minMax;

  /// 全部就绪采样的最大绝对值，用于把低音量录音也放大到可见高度；至少为 1。
  final int peak;

  /// 已计算完成的像素数，即 [minAt] / [maxAt] 有效的下标范围为 `[0, readyLength)`。
  final int readyLength;

  /// 整段音频的像素（min/max 对）数量。
  int get length => _minMax.length ~/ 2;

  bool get isComplete => readyLength == length;

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
    // 缓存只保存完整波形，半成品写入会让下次打开时显示缺失的一截。
    if (!isComplete) throw StateError('未完成的波形不能写入缓存');
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

  static int _peakOf(Int16List values, int pixelCount) {
    // 越界的 pixelCount 交给构造函数的参数校验报错，这里只保证不越界读取。
    final sampleCount = math.min(pixelCount * 2, values.length);
    var peak = 1;
    for (var i = 0; i < sampleCount; i++) {
      final magnitude = values[i].abs();
      if (magnitude > peak) peak = magnitude;
    }
    return peak;
  }
}

/// 增量计算波形峰值：PCM 采样可以分段喂入（FFmpeg 仍在解码时即可边读边算），
/// 任意时刻都能取到已完整像素的 [WaveformPeaks] 快照。
///
/// 不足一个像素的尾部采样只在 [finish] 时才成为像素，快照不包含它。
class WaveformPeaksBuilder {
  WaveformPeaksBuilder({
    required int expectedSamples,
    this.pixelsPerSecond = waveformPixelsPerSecond,
  }) : _expectedPixels = _pixelCountOf(expectedSamples, pixelsPerSecond),
       _samplesPerPixel = _samplesPerPixelOf(pixelsPerSecond),
       _buffer = Int16List(_pixelCountOf(expectedSamples, pixelsPerSecond) * 2);

  /// 每秒像素数，与 [WaveformPeaks.pixelsPerSecond] 一致。
  final int pixelsPerSecond;

  /// 预期整段音频的像素数。快照的 [WaveformPeaks.length] 以它为准，让绘制时按
  /// 时间换算的像素下标在解码过程中保持稳定；实际采样更多时再向后扩展。
  final int _expectedPixels;
  final int _samplesPerPixel;

  /// 像素 min/max 缓冲，只追加不修改已完成的像素，因此旧快照共享前缀仍然有效。
  Int16List _buffer;
  int _readyPixels = 0;
  int _totalSamples = 0;
  int _peak = 1;

  /// 当前未满一像素的 min/max 与采样数。
  int _low = 32767;
  int _high = -32768;
  int _countInPixel = 0;

  /// 已完成的像素数。
  int get readyPixels => _readyPixels;

  /// 喂入 [samples] 的前 [count] 个采样（16 位单声道）。
  void addSamples(Int16List samples, int count) {
    for (var i = 0; i < count; i++) {
      final value = samples[i];
      if (value < _low) _low = value;
      if (value > _high) _high = value;
      _totalSamples++;
      if (++_countInPixel == _samplesPerPixel) _commitPixel();
    }
  }

  /// 当前已完成像素的快照。之后的 [addSamples] 不影响已返回的快照。
  WaveformPeaks snapshot() {
    final pixelCount = math.max(_expectedPixels, _readyPixels);
    _ensureCapacity(pixelCount);
    return WaveformPeaks(
      pixelsPerSecond: pixelsPerSecond,
      duration: _durationOfPixels(pixelCount),
      minMax: Int16List.view(_buffer.buffer, 0, pixelCount * 2),
      readyLength: _readyPixels,
      peak: _peak,
    );
  }

  /// 结束计算，把尾部采样并入最后一个像素，返回完整波形。
  WaveformPeaks finish() {
    if (_countInPixel > 0) _commitPixel();
    return WaveformPeaks(
      pixelsPerSecond: pixelsPerSecond,
      duration: Duration(
        microseconds:
            _totalSamples *
            Duration.microsecondsPerSecond ~/
            waveformPcmSampleRate,
      ),
      minMax: Int16List.view(_buffer.buffer, 0, _readyPixels * 2),
      peak: _peak,
    );
  }

  void _commitPixel() {
    _ensureCapacity(_readyPixels + 1);
    _buffer[_readyPixels * 2] = _low;
    _buffer[_readyPixels * 2 + 1] = _high;
    _readyPixels++;
    _peak = math.max(_peak, math.max(_low.abs(), _high.abs()));
    _low = 32767;
    _high = -32768;
    _countInPixel = 0;
  }

  void _ensureCapacity(int pixelCount) {
    if (pixelCount * 2 <= _buffer.length) return;
    // 容量翻倍，避免每个像素都重新分配；_buffer.length 以采样计，即 2 倍像素数。
    final grown = Int16List(math.max(pixelCount, _buffer.length) * 2);
    grown.setRange(0, _readyPixels * 2, _buffer);
    _buffer = grown;
  }

  Duration _durationOfPixels(int pixelCount) => Duration(
    microseconds:
        pixelCount *
        _samplesPerPixel *
        Duration.microsecondsPerSecond ~/
        waveformPcmSampleRate,
  );

  static int _samplesPerPixelOf(int pixelsPerSecond) {
    if (pixelsPerSecond <= 0 || waveformPcmSampleRate % pixelsPerSecond != 0) {
      throw ArgumentError('采样率须为像素密度的整数倍：$pixelsPerSecond');
    }
    return waveformPcmSampleRate ~/ pixelsPerSecond;
  }

  static int _pixelCountOf(int samples, int pixelsPerSecond) {
    final samplesPerPixel = _samplesPerPixelOf(pixelsPerSecond);
    return (samples + samplesPerPixel - 1) ~/ samplesPerPixel;
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
  final file = File(pcmPath).openSync();
  try {
    final totalSamples = file.lengthSync() ~/ 2;
    final builder = WaveformPeaksBuilder(
      expectedSamples: totalSamples,
      pixelsPerSecond: pixelsPerSecond,
    );
    // 1MB 一块：读写次数少，又不会一次占用整段 PCM 的内存。
    final buffer = Uint8List(1 << 20);
    final samples = Int16List.view(buffer.buffer);
    var remaining = totalSamples;
    while (remaining > 0) {
      final want = math.min(remaining, samples.length);
      final read = file.readIntoSync(buffer, 0, want * 2);
      if (read != want * 2) {
        throw FileSystemException('PCM 读取不完整', pcmPath);
      }
      remaining -= want;
      builder.addSamples(samples, want);
    }
    return builder.finish();
  } finally {
    file.closeSync();
  }
}
