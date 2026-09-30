import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/features/text_to_lesson/data/text_lesson_generator.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

class _MockAudioItemDao extends Mock implements AudioItemDao {}

class _FakeSynthesizer implements TextLessonSynthesizer {
  final calls = <String>[];

  @override
  Future<String?> renderToCache(
    String text, {
    required TtsEngineKind kind,
    required TtsSpeechConfig config,
  }) async {
    calls.add(text);
    final file = File(
      '${Directory.systemTemp.path}/text_lesson_chunk_${calls.length}.wav',
    );
    await file.writeAsBytes(_pcm16Wav(samples: 1000));
    return file.path;
  }
}

Uint8List _pcm16Wav({required int samples, int sampleRate = 1000}) {
  final payload = ByteData(samples * 2);
  final header = ByteData(44);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  final bytes = payload.buffer.asUint8List();
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
  late _MockAudioItemDao dao;
  late List<AudioItem> addedItems;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('text-lesson-test');
    dao = _MockAudioItemDao();
    addedItems = [];
    when(
      () => dao.saveTranscriptContent(
        any(),
        srt: any(named: 'srt'),
        wordTimestampsJson: any(named: 'wordTimestampsJson'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  TextLessonGenerator build(_FakeSynthesizer synth) => TextLessonGenerator(
    synthesizer: synth,
    audioItemDao: dao,
    addAudioItem: (item) async => addedItems.add(item),
    dataDirectoryResolver: () async => dir,
  );

  test('生成完整 WAV、SRT 与 AudioItem', () async {
    final synth = _FakeSynthesizer();
    final result = await build(synth).generate(
      title: 'My Lesson',
      text: 'Hello world. How are you?',
      voiceId: 'af_sol',
      speed: 1.2,
      modelVariant: KokoroModelVariant.int8,
    );

    expect(synth.calls, ['Hello world.', 'How are you?']);
    expect(addedItems, hasLength(1));
    expect(addedItems.single.name, 'My Lesson');
    expect(addedItems.single.transcriptSource, TranscriptSource.local);
    expect(addedItems.single.sentenceCount, 2);
    expect(await File(result.audioFile.filePath).exists(), isTrue);
    verify(
      () => dao.saveTranscriptContent(
        result.audioItem.id,
        srt: any(named: 'srt'),
        wordTimestampsJson: null,
      ),
    ).called(1);
  });

  test('取消后不写入 AudioItem 并清理 part', () async {
    final synth = _FakeSynthesizer();
    final token = TextLessonCancellationToken();
    final generator = build(synth);
    await expectLater(
      generator.generate(
        title: 'Cancel',
        text: 'One sentence. Two sentence.',
        voiceId: 'af_sol',
        speed: 1.0,
        modelVariant: KokoroModelVariant.int8,
        cancellationToken: token,
        onProgress: (progress) {
          if (progress.completedSegments == 1) token.cancel();
        },
      ),
      throwsA(isA<TextLessonCancelledException>()),
    );

    expect(synth.calls, ['One sentence.']);
    expect(addedItems, isEmpty);
    final parts = await dir
        .list(recursive: true)
        .where((entity) => entity.path.endsWith('.part'))
        .toList();
    expect(parts, isEmpty);
  });
}
