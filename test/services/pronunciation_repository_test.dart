import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:echo_loop/models/pronunciation/pronunciation_clip.dart';
import 'package:echo_loop/services/pronunciation/pronunciation_repository.dart';

void main() {
  test('reason 解析覆盖受控后缀和 interj', () {
    expect(
      pronunciationReasonFromFilename('read_us_v_past.opus'),
      PronunciationReason.pastTense,
    );
    expect(
      pronunciationReasonFromFilename('yeah_us_interj.opus'),
      PronunciationReason.interjection,
    );
    expect(pronunciationReasonFromFilename('run_us.opus'), isNull);
  });

  test('单词查询按数据库 order 返回本地音频，短语跳过查询', () {
    final temp = Directory.systemTemp.createTempSync(
      'pronunciation_repository_',
    );
    final repository = PronunciationRepository();
    final path = p.join(temp.path, 'pronunciation.sqlite');
    final fileDb = sqlite3.open(path);
    fileDb.execute(
      'CREATE TABLE pronunciation_audio (id INTEGER PRIMARY KEY, word TEXT NOT NULL COLLATE NOCASE, locale TEXT NOT NULL, audio_filename TEXT NOT NULL, "order" INTEGER NOT NULL)',
    );
    fileDb.execute(
      "INSERT INTO pronunciation_audio (word, locale, audio_filename, \"order\") VALUES ('read', 'us', 'read_us_v_present.opus', 1)",
    );
    fileDb.execute(
      "INSERT INTO pronunciation_audio (word, locale, audio_filename, \"order\") VALUES ('read', 'us', 'read_us_v_past.opus', 2)",
    );
    fileDb.close();
    repository.open(path, '/audio');
    final clips = repository.lookupSingleWord('READ');
    expect(clips.map((clip) => clip.reason), [
      PronunciationReason.presentTense,
      PronunciationReason.pastTense,
    ]);
    expect(repository.lookupSingleWord('read aloud'), isEmpty);
    repository.close();
    temp.deleteSync(recursive: true);
  });
}
