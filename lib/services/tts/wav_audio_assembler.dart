/// 将多段 PCM WAV 流式合并为单个学习音频。
///
/// Kokoro 每段都输出 16-bit PCM WAV。本模块不引入 FFmpeg：只解析 RIFF/WAVE
/// 头、校验格式，并把各段 data 顺序追加到目标文件；写入 .part 后原子改名。
library;

import 'dart:io';
import 'dart:typed_data';

/// 合并后的句子边界元数据。
class AssembledSentence {
  const AssembledSentence({
    required this.index,
    required this.text,
    required this.start,
    required this.end,
  });

  final int index;
  final String text;
  final Duration start;
  final Duration end;
}

/// 合并结果。
class AssembledWav {
  const AssembledWav({
    required this.filePath,
    required this.duration,
    required this.sentences,
    required this.byteLength,
  });

  final String filePath;
  final Duration duration;
  final List<AssembledSentence> sentences;
  final int byteLength;
}

/// 流式 WAV 合并器。
class WavAudioAssembler {
  WavAudioAssembler({
    required String outputPath,
    this.gap = const Duration(milliseconds: 120),
  }) : _outputPath = outputPath;

  final String _outputPath;
  final Duration gap;

  RandomAccessFile? _file;
  int? _sampleRate;
  int? _channels;
  int? _bitsPerSample;
  int _dataBytes = 0;
  bool _finished = false;
  final List<AssembledSentence> _sentences = [];

  bool get isStarted => _file != null;

  /// 开始写入；目标父目录会自动创建。
  Future<void> start() async {
    if (_file != null) return;
    final file = File(_outputPath);
    await file.parent.create(recursive: true);
    final part = File('$_outputPath.part');
    if (await part.exists()) await part.delete();
    _file = await part.open(mode: FileMode.write);
    await _file!.writeFrom(Uint8List(44));
  }

  /// 追加一段 WAV（PCM 16-bit）。
  Future<void> addWav(String filePath, String text) async {
    if (_finished) throw StateError('WavAudioAssembler already finished.');
    await start();
    final bytes = await File(filePath).readAsBytes();
    final pcm = _parsePcmWav(bytes);

    if (_sampleRate == null) {
      _sampleRate = pcm.sampleRate;
      _channels = pcm.channels;
      _bitsPerSample = pcm.bitsPerSample;
    } else if (_sampleRate != pcm.sampleRate ||
        _channels != pcm.channels ||
        _bitsPerSample != pcm.bitsPerSample) {
      throw StateError(
        'WAV format mismatch: expected '
        '${_sampleRate}Hz/${_channels}ch/${_bitsPerSample}bit, got '
        '${pcm.sampleRate}Hz/${pcm.channels}ch/${pcm.bitsPerSample}bit',
      );
    }

    final startTime = _durationFromBytes(_dataBytes);
    await _file!.writeFrom(pcm.pcm);
    _dataBytes += pcm.pcm.length;
    final end = _durationFromBytes(_dataBytes);
    _sentences.add(
      AssembledSentence(
        index: _sentences.length,
        text: text,
        start: startTime,
        end: end,
      ),
    );

    if (gap > Duration.zero) {
      final gapBytes = _bytesForDuration(gap);
      if (gapBytes > 0) {
        await _file!.writeFrom(Uint8List(gapBytes));
        _dataBytes += gapBytes;
      }
    }
  }

  /// 写入最后一段并原子提交。
  Future<AssembledWav> finish() async {
    if (_finished) {
      throw StateError('WavAudioAssembler already finished.');
    }
    final file = _file ?? await _openEmpty();
    try {
      final sampleRate = _sampleRate;
      final channels = _channels;
      final bitsPerSample = _bitsPerSample;
      if (sampleRate == null || channels == null || bitsPerSample == null) {
        throw StateError('No WAV chunks were added.');
      }
      await file.setPosition(0);
      await file.writeFrom(
        _buildHeader(
          dataBytes: _dataBytes,
          sampleRate: sampleRate,
          channels: channels,
          bitsPerSample: bitsPerSample,
        ),
      );
      await file.close();
      _file = null;
      final part = File('$_outputPath.part');
      final target = File(_outputPath);
      if (await target.exists()) await target.delete();
      await part.rename(_outputPath);
      _finished = true;
      return AssembledWav(
        filePath: _outputPath,
        duration: _durationFromBytes(_dataBytes),
        sentences: List.unmodifiable(_sentences),
        byteLength: _dataBytes,
      );
    } catch (_) {
      await abort();
      rethrow;
    }
  }

  /// 失败时清理半成品。
  Future<void> abort() async {
    try {
      await _file?.close();
    } catch (_) {}
    _file = null;
    final part = File('$_outputPath.part');
    if (await part.exists()) await part.delete();
  }

  Future<RandomAccessFile> _openEmpty() async {
    await start();
    return _file!;
  }

  Duration _durationFromBytes(int bytes) {
    final byteRate = _byteRate;
    if (byteRate <= 0) return Duration.zero;
    return Duration(
      microseconds: (bytes * Duration.microsecondsPerSecond / byteRate).round(),
    );
  }

  int _bytesForDuration(Duration duration) {
    final byteRate = _byteRate;
    if (byteRate <= 0) return 0;
    return (byteRate * duration.inMicroseconds / Duration.microsecondsPerSecond)
        .round();
  }

  int get _byteRate =>
      (_sampleRate ?? 0) * (_channels ?? 0) * ((_bitsPerSample ?? 0) ~/ 8);

  _PcmWav _parsePcmWav(Uint8List bytes) {
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('Invalid WAV header.');
    }
    final data = ByteData.sublistView(bytes);
    var offset = 12;
    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;
    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, 4);
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      if (chunkId == 'fmt ') {
        if (chunkSize < 16 || chunkStart + 16 > bytes.length) {
          throw const FormatException('Invalid fmt chunk.');
        }
        audioFormat = data.getUint16(chunkStart, Endian.little);
        channels = data.getUint16(chunkStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkStart + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkStart;
        dataLength = chunkSize;
        break;
      }
      offset = chunkStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    if (audioFormat != 1 ||
        channels == null ||
        channels < 1 ||
        sampleRate == null ||
        sampleRate < 1 ||
        bitsPerSample != 16 ||
        dataOffset == null ||
        dataLength == null) {
      throw const FormatException('Only 16-bit PCM WAV is supported.');
    }
    final end = dataOffset + dataLength;
    if (end > bytes.length) {
      throw const FormatException('WAV data chunk is truncated.');
    }
    return _PcmWav(
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample!,
      pcm: Uint8List.sublistView(bytes, dataOffset, end),
    );
  }

  String _ascii(Uint8List bytes, int offset, int length) {
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }

  Uint8List _buildHeader({
    required int dataBytes,
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final header = ByteData(44);
    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(header, 36, 'data');
    header.setUint32(40, dataBytes, Endian.little);
    return header.buffer.asUint8List();
  }

  void _writeAscii(ByteData target, int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      target.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
}

class _PcmWav {
  const _PcmWav({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.pcm,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Uint8List pcm;
}
