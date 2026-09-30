import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/tts/wav_audio_assembler.dart';

Uint8List _pcm16Wav({
  required int sampleRate,
  required int samples,
  int value = 1000,
}) {
  final pcm = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    pcm.setInt16(i * 2, value, Endian.little);
  }
  final bytes = pcm.buffer.asUint8List();
  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + bytes.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, bytes.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...bytes]);
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wav-assembler-test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('合并多段 WAV 并生成句子时间边界', () async {
    final one = File('${dir.path}/one.wav');
    final two = File('${dir.path}/two.wav');
    await one.writeAsBytes(
      _pcm16Wav(sampleRate: 1000, samples: 1000, value: 100),
    );
    await two.writeAsBytes(
      _pcm16Wav(sampleRate: 1000, samples: 500, value: 200),
    );
    final out = '${dir.path}/lesson.wav';
    final assembler = WavAudioAssembler(
      outputPath: out,
      gap: const Duration(milliseconds: 100),
    );
    await assembler.addWav(one.path, 'one');
    await assembler.addWav(two.path, 'two');
    final result = await assembler.finish();

    expect(await File(out).exists(), isTrue);
    expect(result.sentences.length, 2);
    expect(result.sentences[0].start, Duration.zero);
    expect(result.sentences[0].end, const Duration(seconds: 1));
    expect(result.sentences[1].start, const Duration(milliseconds: 1100));
    expect(result.sentences[1].end, const Duration(milliseconds: 1600));
    expect(result.duration, const Duration(milliseconds: 1700));
    final bytes = await File(out).readAsBytes();
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    expect(bytes.length, greaterThan(44));
  });

  test('格式不一致时拒绝合并', () async {
    final one = File('${dir.path}/one.wav');
    final two = File('${dir.path}/two.wav');
    await one.writeAsBytes(_pcm16Wav(sampleRate: 1000, samples: 10));
    await two.writeAsBytes(_pcm16Wav(sampleRate: 2000, samples: 10));
    final assembler = WavAudioAssembler(outputPath: '${dir.path}/out.wav');
    await assembler.addWav(one.path, 'one');
    expect(() => assembler.addWav(two.path, 'two'), throwsA(isA<StateError>()));
    await assembler.abort();
  });

  test('没有音频段时 finish 失败并清理 part', () async {
    final assembler = WavAudioAssembler(outputPath: '${dir.path}/out.wav');
    await assembler.start();
    await expectLater(assembler.finish(), throwsA(isA<StateError>()));
    expect(await File('${dir.path}/out.wav.part').exists(), isFalse);
  });
}
