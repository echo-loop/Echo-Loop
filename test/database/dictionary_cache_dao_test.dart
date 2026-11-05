import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('DictionaryCacheDao', () {
    test('同一词在不同词典下互不覆盖', () async {
      final dao = db.dictionaryCacheDao;
      await dao.upsert('en_zh-CN', 'run', '{"v":"cn"}');
      await dao.upsert('en_zh-TW', 'run', '{"v":"tw"}');

      expect(await dao.get('en_zh-CN', 'run'), '{"v":"cn"}');
      expect(await dao.get('en_zh-TW', 'run'), '{"v":"tw"}');
    });

    test('upsert 覆盖已有词条', () async {
      final dao = db.dictionaryCacheDao;
      await dao.upsert('en_zh-CN', 'run', '{"v":1}');
      await dao.upsert('en_zh-CN', 'run', '{"v":2}');

      expect(await dao.get('en_zh-CN', 'run'), '{"v":2}');
    });

    test('getMany 只返回命中的词，超过单批上限也能完整返回', () async {
      final dao = db.dictionaryCacheDao;
      await dao.upsert('en_zh-CN', 'alpha', 'a');
      await dao.upsert('en_zh-CN', 'beta', 'b');
      final words = [
        for (var i = 0; i < 1200; i++) 'filler$i',
        'alpha',
        'beta',
      ];

      final result = await dao.getMany('en_zh-CN', words);

      expect(result, {'alpha': 'a', 'beta': 'b'});
    });

    test('deleteOne 只删除指定词典的指定词', () async {
      final dao = db.dictionaryCacheDao;
      await dao.upsert('en_zh-CN', 'run', 'cn');
      await dao.upsert('en_zh-TW', 'run', 'tw');

      await dao.deleteOne('en_zh-CN', 'run');

      expect(await dao.get('en_zh-CN', 'run'), isNull);
      expect(await dao.get('en_zh-TW', 'run'), 'tw');
    });

    test('deleteAll 清空全部词典缓存', () async {
      final dao = db.dictionaryCacheDao;
      await dao.upsert('en_zh-CN', 'run', 'cn');
      await dao.upsert('en_zh-TW', 'go', 'tw');

      await dao.deleteAll();

      expect(await dao.getMany('en_zh-CN', ['run']), isEmpty);
      expect(await dao.getMany('en_zh-TW', ['go']), isEmpty);
    });
  });
}
