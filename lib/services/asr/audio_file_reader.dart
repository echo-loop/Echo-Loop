/// 音频文件读取工具，支持 WAV（RIFF）和 CAF（Core Audio Format）。
///
/// 用于将录音文件解析为 sherpa-onnx 可接受的 Float32 PCM 数据。
/// Android 录音输出 WAV（16kHz/mono/PCM16），
/// macOS/iOS 录音输出 CAF（48kHz/mono/Float32 或 PCM16）。
library;

import 'dart:io';
import 'dart:typed_data';

/// 解析后的音频数据。
class AudioData {
  /// 归一化到 [-1, 1] 的单声道 PCM 样本。
  final Float32List samples;

  /// 采样率（Hz）。
  final int sampleRate;

  const AudioData({required this.samples, required this.sampleRate});

  /// 空音频数据。
  static final empty = AudioData(samples: Float32List(0), sampleRate: 0);
}

/// 读取音频文件，支持 WAV（RIFF）和 CAF（caff）格式。
///
/// 返回归一化到 [-1, 1] 的 Float32List 单声道 PCM 样本。
/// 不支持的格式抛出 [FormatException]。
AudioData readAudioFile(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 12) return AudioData.empty;

  final data = ByteData.sublistView(bytes);

  // 检查文件头判断格式。
  final magic = String.fromCharCodes(bytes.sublist(0, 4));
  if (magic == 'RIFF') return readWav(data);
  if (magic == 'caff') return readCaf(data);

  throw FormatException('Unsupported audio format: $magic');
}

/// 解析 WAV 文件（RIFF/WAVE，PCM 16-bit Little-Endian）。
AudioData readWav(ByteData data) {
  // 跳过 RIFF header (12 bytes)。
  var offset = 12;
  int sampleRate = 16000;
  int numChannels = 1;

  // 遍历 chunks。
  while (offset + 8 <= data.lengthInBytes) {
    final chunkId = String.fromCharCodes(
      data.buffer.asUint8List(data.offsetInBytes + offset, 4),
    );
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    offset += 8;

    if (chunkId == 'fmt ') {
      numChannels = data.getUint16(offset + 2, Endian.little);
      sampleRate = data.getUint32(offset + 4, Endian.little);
    } else if (chunkId == 'data') {
      final pcmBytes = data.buffer.asUint8List(
        data.offsetInBytes + offset,
        chunkSize,
      );
      return AudioData(
        samples: pcm16ToFloat32(pcmBytes, Endian.little, numChannels),
        sampleRate: sampleRate,
      );
    }

    offset += chunkSize;
    // Chunks are word-aligned。
    if (chunkSize.isOdd) offset++;
  }

  return AudioData.empty;
}

/// 解析 CAF 文件（Core Audio Format）。
///
/// macOS/iOS 的 AVAudioEngine 录音默认输出 CAF + Linear PCM。
/// 支持 Float32 和 Int16 两种 PCM 格式。
AudioData readCaf(ByteData data) {
  // CAF header: "caff" (4) + version (2) + flags (2) = 8 bytes。
  var offset = 8;
  int sampleRate = 16000;
  int numChannels = 1;
  int bitsPerChannel = 16;
  var isFloat = false;
  var isLittleEndian = false;

  while (offset + 12 <= data.lengthInBytes) {
    final chunkType = String.fromCharCodes(
      data.buffer.asUint8List(data.offsetInBytes + offset, 4),
    );
    // CAF chunk size 是 Int64 Big-Endian。
    // data chunk 可能使用 -1 哨兵表示"到文件末尾"。
    final chunkSize = data.getInt64(offset + 4, Endian.big);
    offset += 12;

    if (chunkType == 'desc') {
      // Audio Description chunk (CAF spec):
      // Float64 sampleRate, 4 bytes formatID, UInt32 formatFlags,
      // UInt32 bytesPerPacket, UInt32 framesPerPacket,
      // UInt32 channelsPerFrame, UInt32 bitsPerChannel
      final srBits = data.getUint64(offset, Endian.big);
      sampleRate = float64FromBits(srBits).round();

      final formatFlags = data.getUint32(offset + 12, Endian.big);
      numChannels = data.getUint32(offset + 24, Endian.big);
      bitsPerChannel = data.getUint32(offset + 28, Endian.big);

      // kCAFLinearPCMFormatFlagIsFloat = 0x1
      isFloat = (formatFlags & 0x1) != 0;
      // kCAFLinearPCMFormatFlagIsLittleEndian = 0x2
      isLittleEndian = (formatFlags & 0x2) != 0;
    } else if (chunkType == 'data') {
      // data chunk 的前 4 字节是 editCount（跳过）。
      final pcmOffset = offset + 4;
      final pcmSize = chunkSize == -1
          ? data.lengthInBytes - pcmOffset
          : chunkSize - 4;

      if (pcmSize <= 0) return AudioData.empty;

      final pcmBytes = data.buffer.asUint8List(
        data.offsetInBytes + pcmOffset,
        pcmSize,
      );
      final endian = isLittleEndian ? Endian.little : Endian.big;

      final Float32List samples;
      if (isFloat && bitsPerChannel == 32) {
        samples = float32PcmToMono(pcmBytes, endian, numChannels);
      } else {
        samples = pcm16ToFloat32(pcmBytes, endian, numChannels);
      }

      return AudioData(samples: samples, sampleRate: sampleRate);
    }

    if (chunkSize > 0) {
      offset += chunkSize;
    } else {
      // chunkSize == -1 表示到文件末尾（data chunk 专用）。
      break;
    }
  }

  return AudioData.empty;
}

/// 将 Float32 PCM 字节数组提取为单声道 Float32List。
Float32List float32PcmToMono(Uint8List bytes, Endian endian, int numChannels) {
  final byteData = ByteData.sublistView(bytes);
  final totalSamples = bytes.length ~/ 4;
  final frameSamples = totalSamples ~/ numChannels;
  final result = Float32List(frameSamples);
  final step = numChannels * 4;

  for (var i = 0; i < frameSamples; i++) {
    result[i] = byteData.getFloat32(i * step, endian);
  }

  return result;
}

/// 将 PCM 16-bit 字节数组转为归一化 [-1, 1] 的 Float32List。
Float32List pcm16ToFloat32(Uint8List bytes, Endian endian, int numChannels) {
  final byteData = ByteData.sublistView(bytes);
  final totalSamples = bytes.length ~/ 2;
  final frameSamples = totalSamples ~/ numChannels;
  final result = Float32List(frameSamples);
  final step = numChannels * 2;

  for (var i = 0; i < frameSamples; i++) {
    final sample = byteData.getInt16(i * step, endian);
    result[i] = sample / 32768.0;
  }

  return result;
}

/// 16kHz/单声道/PCM16 WAV 的流式读取器。
///
/// 定位 `data` chunk 后按块顺序读取 PCM16 样本并归一化为 Float32，
/// 避免像 [readAudioFile] 那样一次性把整段音频读入内存
/// （长音频可达数百 MB，直接 OOM）。仅支持单声道 PCM16；
/// 其它声道数/位深/格式一律返回 null，交由调用方回退到 [readAudioFile]。
class Pcm16WavStreamReader {
  final RandomAccessFile _raf;

  /// 采样率（Hz）。
  final int sampleRate;

  /// data chunk 起始字节偏移（绝对）。
  final int _dataStartByte;

  /// data chunk 结束字节偏移（绝对，已按文件长度截断）。
  final int _dataEndByte;

  /// 当前读取位置（绝对字节偏移）。
  int _posByte;

  Pcm16WavStreamReader._(
    this._raf,
    this.sampleRate,
    this._dataStartByte,
    this._dataEndByte,
  ) : _posByte = _dataStartByte;

  /// data chunk 内的总样本数（单声道 → 每样本 2 字节），用于进度估算。
  int get totalSamples => (_dataEndByte - _dataStartByte) ~/ 2;

  /// 打开 [path] 并解析头部，成功返回定位到 data 起始的读取器；
  /// 非 RIFF/WAVE、非单声道、非 16-bit PCM 或格式异常时返回 null（不抛出）。
  static Pcm16WavStreamReader? open(String path) {
    RandomAccessFile? raf;
    try {
      raf = File(path).openSync();
      final fileLen = raf.lengthSync();
      final head = raf.readSync(12);
      if (head.length < 12) return _closeReturnNull(raf);
      if (String.fromCharCodes(head.sublist(0, 4)) != 'RIFF' ||
          String.fromCharCodes(head.sublist(8, 12)) != 'WAVE') {
        return _closeReturnNull(raf);
      }

      int numChannels = 0;
      int bitsPerSample = 0;
      int sampleRate = 0;
      var offset = 12;

      // 遍历 chunk 头，定位 fmt（读格式）与 data（定位样本区）。
      while (offset + 8 <= fileLen) {
        raf.setPositionSync(offset);
        final chunkHeader = raf.readSync(8);
        if (chunkHeader.length < 8) break;
        final chunkId = String.fromCharCodes(chunkHeader.sublist(0, 4));
        final chunkSize = ByteData.sublistView(
          chunkHeader,
        ).getUint32(4, Endian.little);
        final chunkDataStart = offset + 8;

        if (chunkId == 'fmt ') {
          final fmt = raf.readSync(16);
          if (fmt.length < 16) return _closeReturnNull(raf);
          final bd = ByteData.sublistView(fmt);
          numChannels = bd.getUint16(2, Endian.little);
          sampleRate = bd.getUint32(4, Endian.little);
          bitsPerSample = bd.getUint16(14, Endian.little);
        } else if (chunkId == 'data') {
          if (numChannels != 1 || bitsPerSample != 16) {
            return _closeReturnNull(raf);
          }
          final dataEnd = chunkDataStart + chunkSize;
          final end = dataEnd > fileLen ? fileLen : dataEnd;
          return Pcm16WavStreamReader._(raf, sampleRate, chunkDataStart, end);
        }

        offset = chunkDataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
      }
      return _closeReturnNull(raf);
    } catch (_) {
      if (raf != null) {
        try {
          raf.closeSync();
        } catch (_) {}
      }
      return null;
    }
  }

  static Pcm16WavStreamReader? _closeReturnNull(RandomAccessFile raf) {
    try {
      raf.closeSync();
    } catch (_) {}
    return null;
  }

  /// 从样本下标 [startSample] 起随机读取最多 [maxSamples] 个样本（不影响顺序读位置）。
  ///
  /// 供滑窗转录按 seek 位置读任意 ≤30s 窗口（PCM16 每样本 2 字节，可直接算字节偏移）。
  /// 越界自动截断，起点已到/超过末尾返回空 [Float32List]。
  Float32List readWindow(int startSample, int maxSamples) {
    final startByte = _dataStartByte + startSample * 2;
    if (startByte >= _dataEndByte) return Float32List(0);
    var wantBytes = maxSamples * 2;
    final avail = _dataEndByte - startByte;
    if (wantBytes > avail) wantBytes = avail;
    wantBytes -= wantBytes % 2; // 对齐到完整样本
    if (wantBytes <= 0) return Float32List(0);

    _raf.setPositionSync(startByte);
    final bytes = _raf.readSync(wantBytes);
    final n = bytes.length ~/ 2;
    final bd = ByteData.sublistView(bytes);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// 顺序读取下一块样本（最多 [maxSamples] 个），到末尾返回空 [Float32List]。
  Float32List readBlock(int maxSamples) {
    final remainingBytes = _dataEndByte - _posByte;
    if (remainingBytes <= 0) return Float32List(0);
    var wantBytes = maxSamples * 2;
    if (wantBytes > remainingBytes) wantBytes = remainingBytes;
    wantBytes -= wantBytes % 2; // 对齐到完整样本
    if (wantBytes <= 0) return Float32List(0);

    _raf.setPositionSync(_posByte);
    final bytes = _raf.readSync(wantBytes);
    _posByte += bytes.length;

    final n = bytes.length ~/ 2;
    final bd = ByteData.sublistView(bytes);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// 关闭底层文件句柄。
  void close() {
    try {
      _raf.closeSync();
    } catch (_) {}
  }
}

/// 将音频从 [fromRate] 降采样到 [toRate]（整数倍降采样）。
///
/// 要求 [fromRate] 是 [toRate] 的整数倍（如 48000→16000，比率 3）。
/// 对每 N 个样本取均值，兼做简易低通滤波，避免混叠。
Float32List downsample(Float32List samples, int fromRate, int toRate) {
  assert(fromRate > toRate && fromRate % toRate == 0);
  final ratio = fromRate ~/ toRate;
  final outLen = samples.length ~/ ratio;
  final result = Float32List(outLen);
  for (var i = 0; i < outLen; i++) {
    var sum = 0.0;
    final base = i * ratio;
    for (var j = 0; j < ratio; j++) {
      sum += samples[base + j];
    }
    result[i] = sum / ratio;
  }
  return result;
}

/// 从 IEEE 754 64-bit 位模式还原 double。
double float64FromBits(int bits) {
  final bd = ByteData(8)..setUint64(0, bits, Endian.big);
  return bd.getFloat64(0, Endian.big);
}
