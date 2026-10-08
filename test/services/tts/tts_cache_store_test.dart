import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/services/tts/tts_cache_store.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:echo_loop/utils/text_normalize.dart';

AppDatabase _createTestDb() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late TtsCacheStore store;

  setUp(() async {
    db = _createTestDb();
    tempDir = await Directory.systemTemp.createTemp('tts_cache_test');
    store = TtsCacheStore(
      resolveDao: () => db.ttsCacheDao,
      resolveCacheDir: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// 在缓存目录写一个假音频文件，返回合成结果。
  Future<TtsSynthesisResult> writeFile(String name, {int bytes = 10}) async {
    final dir = await store.reserveDir();
    final path = '$dir/$name.wav';
    await File(path).writeAsBytes(List.filled(bytes, 0));
    return TtsSynthesisResult(filePath: path, format: 'wav');
  }

  group('TtsCacheStore.deriveKey', () {
    test('相同参数派生相同 key', () {
      final k1 = store.deriveKey(
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        speed: 0.45,
      );
      final k2 = store.deriveKey(
        text: 'hello', // 归一化后相同
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        speed: 0.45,
      );
      expect(k1, k2);
    });

    test('口音不同 → key 不同', () {
      final us = store.deriveKey(
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        speed: 0.45,
      );
      final uk = store.deriveKey(
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-GB',
        speed: 0.45,
      );
      expect(us, isNot(uk));
    });

    test('引擎不同 → key 不同', () {
      final p = store.deriveKey(
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        speed: 0.45,
      );
      final k = store.deriveKey(
        text: 'Hello',
        engine: TtsEngineKind.kokoro,
        voiceId: 'en-US',
        speed: 0.45,
      );
      expect(p, isNot(k));
    });

    test('缓存命名空间升级 → v2 CAF key 不会继续命中', () {
      final current = store.deriveKey(
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        speed: 0.45,
      );
      final previous = sha256
          .convert(
            utf8.encode(
              [
                'tts-cache-v2',
                hashText('Hello'),
                TtsEngineKind.platform.name,
                'en-US',
                0.45.toStringAsFixed(2),
              ].join('|'),
            ),
          )
          .toString();
      expect(current, isNot(previous));
    });
  });

  group('TtsCacheStore lookup/store', () {
    test('store 后 lookup 命中返回文件', () async {
      final result = await writeFile('k1');
      await store.store(
        cacheKey: 'k1',
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        languageCode: 'en-US',
        speed: 0.45,
        result: result,
      );
      final file = await store.lookup('k1');
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
    });

    test('未 store 时 lookup 返回 null', () async {
      expect(await store.lookup('nope'), isNull);
    });

    test('文件被外部删除 → lookup 返回 null 并清理悬空索引', () async {
      final result = await writeFile('k1');
      await store.store(
        cacheKey: 'k1',
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        languageCode: 'en-US',
        speed: 0.45,
        result: result,
      );
      await File(result.filePath).delete();
      expect(await store.lookup('k1'), isNull);
      // 索引行已被清理
      expect(await db.ttsCacheDao.getByKey('k1'), isNull);
    });

    test('store 空文件被跳过', () async {
      final result = await writeFile('empty', bytes: 0);
      await store.store(
        cacheKey: 'empty',
        text: 'Hi',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        languageCode: 'en-US',
        speed: 0.45,
        result: result,
      );
      expect(await db.ttsCacheDao.getByKey('empty'), isNull);
    });
  });

  group('TtsCacheStore cleanup', () {
    test('删除过期条目的文件与索引', () async {
      final result = await writeFile('exp');
      await store.store(
        cacheKey: 'exp',
        text: 'Hello',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        languageCode: 'en-US',
        speed: 0.45,
        result: result,
        ttl: const Duration(days: 10),
      );
      // 手动把 expiresAt 改到过去
      final pastEpoch =
          DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch ~/
          1000;
      await db.customStatement(
        "UPDATE tts_cache SET expires_at = $pastEpoch WHERE cache_key = 'exp'",
      );

      await store.cleanup();
      expect(await db.ttsCacheDao.getByKey('exp'), isNull);
      expect(await File(result.filePath).exists(), isFalse);
    });

    test('clearAll 删全部缓存（入库 + 孤儿）并返回释放字节', () async {
      // 两条正常入库 + 一个孤儿文件（只写盘、不 store）。
      final r1 = await writeFile('a', bytes: 30);
      final r2 = await writeFile('b', bytes: 70);
      for (final e in [('a', r1), ('b', r2)]) {
        await store.store(
          cacheKey: e.$1,
          text: e.$1,
          engine: TtsEngineKind.platform,
          voiceId: 'en-US',
          languageCode: 'en-US',
          speed: 0.45,
          result: e.$2,
        );
      }
      final orphan = await writeFile('orphan', bytes: 50);

      final freed = await store.clearAll();
      // 入库 30+70 + 孤儿 50 全部释放
      expect(freed, 150);
      expect(await db.ttsCacheDao.getByKey('a'), isNull);
      expect(await db.ttsCacheDao.getByKey('b'), isNull);
      expect(await File(r1.filePath).exists(), isFalse);
      expect(await File(r2.filePath).exists(), isFalse);
      expect(await File(orphan.filePath).exists(), isFalse);
    });

    test('cleanup 清扫孤儿文件但保留被引用的有效文件', () async {
      // 有效缓存（被 DB 行引用、未过期）+ 孤儿文件。
      final valid = await writeFile('valid', bytes: 30);
      await store.store(
        cacheKey: 'valid',
        text: 'valid',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        languageCode: 'en-US',
        speed: 0.45,
        result: valid,
      );
      final orphan = await writeFile('orphan', bytes: 50);

      await store.cleanup();
      // 孤儿删除，有效缓存保留（cleanup 不能误删正常缓存）
      expect(await File(orphan.filePath).exists(), isFalse);
      expect(await File(valid.filePath).exists(), isTrue);
      expect(await db.ttsCacheDao.getByKey('valid'), isNotNull);
    });

    test('容量超限时按 LRU 淘汰最久未访问', () async {
      // 两条各 100 字节，上限设 150 → 应淘汰最久未访问的一条。
      final r1 = await writeFile('old', bytes: 100);
      final r2 = await writeFile('new', bytes: 100);
      await store.store(
        cacheKey: 'old',
        text: 'old',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        languageCode: 'en-US',
        speed: 0.45,
        result: r1,
      );
      await store.store(
        cacheKey: 'new',
        text: 'new',
        engine: TtsEngineKind.platform,
        voiceId: 'en-US',
        languageCode: 'en-US',
        speed: 0.45,
        result: r2,
      );
      final oldEpoch =
          DateTime.now()
              .subtract(const Duration(days: 5))
              .millisecondsSinceEpoch ~/
          1000;
      await db.customStatement(
        "UPDATE tts_cache SET last_accessed_at = $oldEpoch WHERE cache_key = 'old'",
      );

      await store.cleanup(maxBytes: 150);
      expect(await db.ttsCacheDao.getByKey('old'), isNull);
      expect(await db.ttsCacheDao.getByKey('new'), isNotNull);
    });
  });
}
