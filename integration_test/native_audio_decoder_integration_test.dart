import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:echo_loop/services/native_audio_decoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformNativeAudioDecoder', () {
    testWidgets('decodes demo m4a without hanging', (_) async {
      final audioFile = await _materializeDemoAudio();

      final decoder = const PlatformNativeAudioDecoder();
      expect(
        decoder.isSupported,
        isTrue,
        reason: 'test requires Apple platform',
      );

      final decoded = await decoder
          .decode(audioFile.path)
          .timeout(const Duration(seconds: 5));

      expect(decoded, isNotNull);
      expect(decoded!.sampleRate, 1000);
      expect(decoded.samples, isNotEmpty);

      final durationSec = decoded.samples.length / decoded.sampleRate;
      expect(durationSec, greaterThan(25));
      expect(durationSec, lessThan(45));
    });
  });
}

Future<File> _materializeDemoAudio() async {
  const assetPath = 'assets/demo/CEFR A1 - Book a table.m4a';
  final data = await rootBundle.load(assetPath);
  final tempDir = await Directory.systemTemp.createTemp('native-audio-decoder');
  final file = File('${tempDir.path}/cefr_a1_book_a_table.m4a');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  return file;
}
