import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/audio_sentences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 三句测试字幕
const _srt = '''
1
00:00:00,000 --> 00:00:03,000
Hello world.

2
00:00:03,500 --> 00:00:06,000
This is a test.

3
00:00:06,500 --> 00:00:09,000
Goodbye now.
''';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> insertAudio({String id = 'a1', String? srt = _srt}) {
    final now = DateTime.now();
    return db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: const Value('Test'),
        audioPath: const Value('t.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
        transcriptSrt: Value(srt),
      ),
    );
  }

  test('解析出连续句子列表，index 即数组下标，可取相邻句', () async {
    await insertAudio();
    final sentences = await container.read(audioSentencesProvider('a1').future);

    expect(sentences.length, 3);
    expect(sentences[0].text, 'Hello world.');
    expect(sentences[1].text, 'This is a test.');
    expect(sentences[2].text, 'Goodbye now.');
    // 中间句的前后句
    expect(sentences[1 - 1].text, 'Hello world.');
    expect(sentences[1 + 1].text, 'Goodbye now.');
  });

  test('无字幕的音频返回空列表', () async {
    await insertAudio(id: 'no-srt', srt: null);
    final sentences = await container.read(
      audioSentencesProvider('no-srt').future,
    );
    expect(sentences, isEmpty);
  });

  test('audioItemId 为空返回空列表', () async {
    final sentences = await container.read(audioSentencesProvider('').future);
    expect(sentences, isEmpty);
  });

  test('不存在的音频返回空列表', () async {
    final sentences = await container.read(
      audioSentencesProvider('missing').future,
    );
    expect(sentences, isEmpty);
  });
}
