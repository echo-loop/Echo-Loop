import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../models/pronunciation/pronunciation_clip.dart';

/// 独立离线发音库查询仓库。
class PronunciationRepository {
  Database? _database;
  String? _audioDirectory;

  bool get isAvailable => _database != null;

  /// 打开发音索引；切换资源版本时先关闭旧连接。
  void open(String databasePath, String audioDirectory) {
    close();
    _database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
    _audioDirectory = audioDirectory;
  }

  /// 仅查询单个词；短语没有本地音频，直接返回空列表。
  List<PronunciationClip> lookupSingleWord(String normalizedWord) {
    final database = _database;
    final audioDirectory = _audioDirectory;
    final word = normalizedWord.trim();
    if (database == null ||
        audioDirectory == null ||
        word.isEmpty ||
        RegExp(r'\s').hasMatch(word)) {
      return const [];
    }
    // 发音包维护的 order 是多发音的权威顺序；文件名用途只用于展示 badge。
    final rows = database.select(
      'SELECT word, locale, audio_filename FROM pronunciation_audio '
      "WHERE word = ? COLLATE NOCASE AND locale = 'us' "
      'ORDER BY "order" ASC, audio_filename ASC',
      [word],
    );
    final clips = <PronunciationClip>[];
    for (final row in rows) {
      final filename = row['audio_filename'] as String;
      if (!_isSafeFilename(filename)) continue;
      clips.add(
        PronunciationClip(
          word: row['word'] as String,
          locale: row['locale'] as String,
          audioFilename: filename,
          absolutePath: p.join(audioDirectory, filename),
          reason: pronunciationReasonFromFilename(filename),
        ),
      );
    }
    return clips;
  }

  bool _isSafeFilename(String filename) =>
      filename == p.basename(filename) && filename.endsWith('.opus');

  void close() {
    _database?.close();
    _database = null;
    _audioDirectory = null;
  }
}

/// 测试与安装校验共用的 schema 检查。
void validatePronunciationDatabase(String databasePath) {
  final database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
  try {
    final columns = database.select('PRAGMA table_info(pronunciation_audio)');
    final names = columns.map((row) => row['name'] as String).toSet();
    if (!names.containsAll({'word', 'locale', 'audio_filename', 'order'})) {
      throw StateError('Pronunciation database schema is invalid');
    }
    final count =
        database
                .select('SELECT COUNT(*) AS count FROM pronunciation_audio')
                .first['count']
            as int;
    if (count <= 0) throw StateError('Pronunciation database has no records');
  } finally {
    database.close();
  }
}
