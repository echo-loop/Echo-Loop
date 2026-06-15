import 'dart:io';

import 'package:echo_loop/features/audio_import/audio_transcode_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AudioTranscodeService', () {
    testWidgets(
      'transcodes short silent common audio formats to readable m4a',
      (_) async {
        final fixtures = [
          'silence.wav',
          'silence.mp3',
          'silence_cover.mp3',
          'silence.m4a',
          'silence.aac',
          'silence.flac',
        ];
        final tempDir = await Directory.systemTemp.createTemp(
          'audio-transcode-fixtures-',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final service = AudioTranscodeService();
        for (final fixtureName in fixtures) {
          final ext = p.extension(fixtureName).replaceFirst('.', '');
          final relativePath = p.join('input', fixtureName);
          final inputFile = File(p.join(tempDir.path, relativePath));
          await inputFile.parent.create(recursive: true);
          final fixtureData = await rootBundle.load(
            'test/fixtures/audio_transcode/$fixtureName',
          );
          await inputFile.writeAsBytes(
            fixtureData.buffer.asUint8List(
              fixtureData.offsetInBytes,
              fixtureData.lengthInBytes,
            ),
          );

          final result = await service
              .transcodeToM4a(dataDir: tempDir, relativePath: relativePath)
              .timeout(const Duration(seconds: 10));

          expect(result.transcoded, isTrue, reason: 'format .$ext');
          expect(result.relativePath, endsWith('.m4a'), reason: 'format .$ext');

          final outputFile = File(p.join(tempDir.path, result.relativePath));
          expect(await outputFile.exists(), isTrue, reason: 'format .$ext');
          if (ext != 'm4a') {
            expect(
              await inputFile.exists(),
              isFalse,
              reason: 'format .$ext should remove original after transcode',
            );
          }
          expect(
            await outputFile.length(),
            greaterThan(0),
            reason: 'format .$ext',
          );

          final duration = await _readDuration(outputFile.path);
          expect(duration, isNotNull, reason: 'format .$ext');
          expect(
            duration!.inMilliseconds,
            greaterThan(400),
            reason: 'format .$ext',
          );
        }
      },
    );
  });
}

Future<Duration?> _readDuration(String path) async {
  final player = AudioPlayer();
  try {
    return await player.setFilePath(path);
  } finally {
    await player.dispose();
  }
}
