/// DictionaryService 精确查询测试
///
/// 使用内存 SQLite 数据库验证清洗后、大小写不敏感的精确匹配逻辑。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// 创建内存数据库并插入测试数据
Database _createTestDb() {
  final db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE words (
      word TEXT PRIMARY KEY,
      phonetic TEXT NOT NULL,
      translation TEXT,
      collins INTEGER DEFAULT 0,
      tag TEXT
    )
  ''');
  final insertSql =
      "INSERT INTO words (word, phonetic, translation, collins, tag) VALUES"
      " ('professor', 'prəfesər', 'n. 教授', 4, 'gk cet4 cet6 ky toefl ielts'),"
      " ('run', 'rʌn', 'vi. 跑, 奔', 5, 'zk gk cet4'),"
      " ('go', 'gəu', 'vi. 去, 走', 5, 'zk gk cet4'),"
      " ('good', 'gud', 'a. 好的', 5, 'zk gk cet4'),"
      " ('happy', 'hæpi', 'a. 快乐的', 4, 'zk gk cet4'),"
      " ('study', 'stʌdi', 'n. 学习, 研究', 4, 'zk gk cet4'),"
      " ('child', 'tʃaild', 'n. 孩子', 5, 'zk gk cet4'),"
      " ('mouse', 'maus', 'n. 鼠, 鼠标', 3, 'zk gk cet4')";
  db.execute(insertSql);
  return db;
}

void main() {
  late DictionaryService service;
  late Database db;

  setUp(() {
    db = _createTestDb();
    service = DictionaryService.withDatabase(db);
  });

  tearDown(() {
    service.close();
  });

  group('isAvailable', () {
    test('withDatabase 构造后为 true', () {
      expect(service.isAvailable, isTrue);
    });

    test('未打开数据库时为 false', () {
      final emptyService = DictionaryService.withDatabase(_createTestDb());
      emptyService.close();
      expect(emptyService.isAvailable, isFalse);
    });
  });

  group('openDatabase 补建 NOCASE 索引 + 预热', () {
    test('打开文件库时补建 idx_words_word_nocase，大小写不敏感查询命中', () async {
      final dir = await Directory.systemTemp.createTemp('dict_test');
      final path = p.join(dir.path, 'dict.sqlite');
      // 预置一个无索引的 words 表文件库（headword 含大写）
      final seed = sqlite3.open(path);
      seed.execute(
        'CREATE TABLE words (word TEXT, phonetic TEXT NOT NULL, '
        'translation TEXT, collins INTEGER DEFAULT 0, tag TEXT)',
      );
      seed.execute(
        "INSERT INTO words (word, phonetic, translation) "
        "VALUES ('Message', 'ˈmesɪdʒ', 'n. 消息')",
      );
      seed.close();

      final svc = DictionaryService.instance;
      svc.openDatabase(path);
      addTearDown(() async {
        svc.close();
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      // 索引已补建
      final checker = sqlite3.open(path, mode: OpenMode.readOnly);
      final idx = checker.select(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_words_word_nocase'",
      );
      checker.close();
      expect(idx, isNotEmpty);

      // NOCASE 查询命中（输入小写，headword 大写）
      expect(svc.lookup('message')?.word, 'Message');

      // 预热数据库页缓存不抛异常，且不影响后续查询
      svc.warmUpDatabase();
      expect(svc.lookup('message')?.word, 'Message');

      svc.close();
      await dir.delete(recursive: true);
    });

    test('warmUpDatabase 在数据库未就绪时安全 no-op', () {
      final closedService = DictionaryService.withDatabase(_createTestDb());
      closedService.close();
      expect(closedService.warmUpDatabase, returnsNormally);
    });
  });

  group('数据库未就绪', () {
    test('lookup 返回 null', () {
      final closedService = DictionaryService.withDatabase(_createTestDb());
      closedService.close();
      expect(closedService.lookup('professor'), isNull);
    });

    test('lookupAll 返回空 map', () {
      final closedService = DictionaryService.withDatabase(_createTestDb());
      closedService.close();
      expect(closedService.lookupAll(['professor']), isEmpty);
    });
  });

  group('精确匹配', () {
    test('查到已有单词', () {
      final entry = service.lookup('professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
      expect(entry.phonetic, contains('fes'));
    });

    test('大小写不敏感', () {
      final entry = service.lookup('Professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('查不到且无法还原的词返回 null', () {
      final entry = service.lookup('xyznotaword');
      expect(entry, isNull);
    });

    test('会去掉单词两侧多余符号', () {
      final entry = service.lookup(' "Professor!" ');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('只有符号时返回 null', () {
      final entry = service.lookup('..."\'!?');
      expect(entry, isNull);
    });
  });

  group('未精确收录的词形', () {
    test('不会回退到原形', () {
      for (final word in [
        'professors',
        'running',
        'goes',
        'happier',
        'studied',
        'children',
        'mice',
        'went',
        'happiest',
        'studies',
      ]) {
        expect(service.lookup(word), isNull, reason: '$word 必须精确匹配');
      }
    });
  });

  group('批量查询 lookupAll', () {
    test('大小写不敏感', () {
      final results = service.lookupAll(['Professor', 'RUN']);
      expect(results['Professor'], isNotNull);
      expect(results['Professor']!.word, 'professor');
      expect(results['RUN'], isNotNull);
      expect(results['RUN']!.word, 'run');
    });

    test('未收录的词不出现在结果中', () {
      final results = service.lookupAll(['professor', 'xyznotaword']);
      expect(results.containsKey('professor'), isTrue);
      expect(results.containsKey('xyznotaword'), isFalse);
    });

    test('未精确收录的词形不出现在结果中', () {
      final results = service.lookupAll(['professors', 'running']);
      expect(results, isEmpty);
    });

    test('未收录词组不命中', () {
      final results = service.lookupAll(['going to']);
      expect(results.containsKey('going to'), isFalse);
    });
  });

  group('词组精确匹配', () {
    test('未收录词组直接返回 null', () {
      expect(service.lookup('going to'), isNull);
    });

    test('lookup 词组精确命中仍正常返回', () {
      // 若本地库恰好收录该词组，精确匹配照常命中
      db.execute(
        "INSERT INTO words (word, phonetic, translation) "
        "VALUES ('give up', 'ɡɪv ʌp', 'v. 放弃')",
      );
      final entry = service.lookup('give up');
      expect(entry?.word, 'give up');
    });
  });
}
