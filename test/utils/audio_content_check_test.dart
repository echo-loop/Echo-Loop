import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/utils/audio_content_check.dart';

void main() {
  group('evaluateAudioContent', () {
    test('FFmpeg 短解码失败时返回 damaged', () async {
      final status = await evaluateAudioContent(
        'audios/broken.mp3',
        decodeProbe: (_) async => false,
        silenceProbe: (_) async => false,
      );

      expect(status, AudioContentStatus.damaged);
    });

    test('短解码成功且波形静音时返回 silent', () async {
      final status = await evaluateAudioContent(
        'audios/silent.mp3',
        decodeProbe: (_) async => true,
        silenceProbe: (_) async => true,
      );

      expect(status, AudioContentStatus.silent);
    });

    test('短解码成功且波形非静音时返回 ok', () async {
      final status = await evaluateAudioContent(
        'audios/normal.mp3',
        decodeProbe: (_) async => true,
        silenceProbe: (_) async => false,
      );

      expect(status, AudioContentStatus.ok);
    });

    test('短解码成功但波形探测失败时返回 ok', () async {
      final status = await evaluateAudioContent(
        'audios/waveform-error.mp3',
        decodeProbe: (_) async => true,
        silenceProbe: (_) async => throw StateError('waveform failed'),
      );

      expect(status, AudioContentStatus.ok);
    });
  });

  group('isWaveformSilent', () {
    test('全零样本判为静音', () {
      final samples = List<int>.filled(1000, 0);
      expect(isWaveformSilent(samples), isTrue);
    });

    test('大量接近满量程的样本判为非静音', () {
      final samples = List<int>.filled(1000, 20000); // 远超响亮门限
      expect(isWaveformSilent(samples), isFalse);
    });

    test('整段低幅（< -40dBFS）判为静音', () {
      // 16bit 满量程 32768，响亮门限 1% ≈ 328；全部 ≈ 4（约 -78dBFS）
      final samples = List<int>.filled(1000, 4);
      expect(isWaveformSilent(samples), isTrue);
    });

    test('极少数离群响亮样本（爆音、点击声）不影响静音判定', () {
      final samples = List<int>.filled(72000, 4);
      samples[0] = 2205;
      samples[1] = 1;
      samples[3] = 17500;
      samples[4] = 0;
      expect(isWaveformSilent(samples), isTrue);
    });

    test('响亮样本占比超过 0.5% 判为非静音', () {
      // 1000 个样本中 10 个（1%）超过门限 → 非静音
      final samples = List<int>.filled(1000, 0);
      for (var i = 0; i < 10; i++) {
        samples[i] = 20000;
      }
      expect(isWaveformSilent(samples), isFalse);
    });

    test('负向大振幅取绝对值同样计入响亮样本', () {
      final samples = List<int>.filled(1000, -20000);
      expect(isWaveformSilent(samples), isFalse);
    });

    test('空样本无法判定返回 false（不过度标记）', () {
      expect(isWaveformSilent(const []), isFalse);
    });

    test('自定义占比门限生效', () {
      // 1000 中 8 个响亮（0.8%）
      final samples = List<int>.filled(1000, 0);
      for (var i = 0; i < 8; i++) {
        samples[i] = 20000;
      }
      // 默认 0.5% → 0.8% > 0.5% → 非静音
      expect(isWaveformSilent(samples), isFalse);
      // 门限提到 1% → 0.8% < 1% → 静音
      expect(isWaveformSilent(samples, minLoudFraction: 0.01), isTrue);
    });
  });
}
