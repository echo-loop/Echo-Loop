/// DictionaryService 在线查词与本地缓存测试
///
/// 用内存数据库承载真实缓存 DAO，用假 HTTP 适配器模拟后端 `/api/v1/dictionary`。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _dictId = 'en_zh-CN';

/// 按查询词返回后端响应，并记录实际请求过的词
class _FakeDictionaryApi implements HttpClientAdapter {
  _FakeDictionaryApi(this.respond);

  final Future<ResponseBody> Function(String word) respond;
  final requestedWords = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final word = options.queryParameters['word'] as String;
    requestedWords.add(word);
    return respond(word);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _entryResponse(String headword) => ResponseBody.fromString(
  jsonEncode({
    'headword': headword,
    'phonetic': 'rʌn',
    'definitions': [
      {
        'pos': 'vi',
        'translations': ['跑'],
        'examples': [],
      },
    ],
    'collins': 0,
    'tags': <String>[],
  }),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _notFoundResponse() => ResponseBody.fromString(
  jsonEncode({'error': 'Entry not found', 'code': 'entry_not_found'}),
  404,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _serverErrorResponse() => ResponseBody.fromString('internal', 500);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DictionaryService buildService(_FakeDictionaryApi api) {
    final dio = Dio(BaseOptions(baseUrl: 'https://dict.test'))
      ..httpClientAdapter = api;
    return DictionaryService(
      cacheDao: db.dictionaryCacheDao,
      dio: dio,
      dictId: _dictId,
    );
  }

  group('dictionaryQueryKey', () {
    test('与后端口径一致：缩写保留大写，其余小写，去除首尾空白', () {
      expect(dictionaryQueryKey('  Run '), 'run');
      expect(dictionaryQueryKey('US'), 'US');
      expect(dictionaryQueryKey('Us'), 'us');
      expect(dictionaryQueryKey('NASA'), 'NASA');
    });

    test('空串与超长词返回 null', () {
      expect(dictionaryQueryKey('   '), isNull);
      expect(dictionaryQueryKey('a' * 201), isNull);
    });
  });

  group('lookup', () {
    test('缓存未命中时请求后端，命中后写入缓存且之后不再请求', () async {
      final api = _FakeDictionaryApi((word) async => _entryResponse('run'));
      final service = buildService(api);

      final first = await service.lookup('Run');
      final second = await service.lookup('run');

      expect(first, isA<DictEntry>());
      expect(first!.word, 'run');
      expect(second!.translation, 'vi. 跑');
      expect(api.requestedWords, ['run']);
      expect(await db.dictionaryCacheDao.get(_dictId, 'run'), isNotNull);
    });

    test('404 视为未收录：返回 null 且不写缓存，下次仍会请求', () async {
      final api = _FakeDictionaryApi((word) async => _notFoundResponse());
      final service = buildService(api);

      expect(await service.lookup('missing'), isNull);
      expect(await service.lookup('missing'), isNull);

      expect(api.requestedWords, ['missing', 'missing']);
      expect(await db.dictionaryCacheDao.get(_dictId, 'missing'), isNull);
    });

    test('服务端错误抛出异常，不伪装成未收录，也不写缓存', () async {
      final api = _FakeDictionaryApi((word) async => _serverErrorResponse());
      final service = buildService(api);

      await expectLater(service.lookup('run'), throwsA(isA<DioException>()));
      expect(await db.dictionaryCacheDao.get(_dictId, 'run'), isNull);
    });

    test('缓存行损坏时删除并回源重取', () async {
      await db.dictionaryCacheDao.upsert(_dictId, 'run', '{not json');
      final api = _FakeDictionaryApi((word) async => _entryResponse('run'));
      final service = buildService(api);

      final entry = await service.lookup('run');

      expect(entry!.word, 'run');
      expect(api.requestedWords, ['run']);
      final repaired = await db.dictionaryCacheDao.get(_dictId, 'run');
      expect(repaired, contains('"headword":"run"'));
    });

    test('同一查询键的并发请求只发出一次网络请求', () async {
      final api = _FakeDictionaryApi((word) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _entryResponse('run');
      });
      final service = buildService(api);

      final results = await Future.wait([
        service.lookup('run'),
        service.lookup('Run'),
        service.lookup('run'),
      ]);

      expect(results.map((e) => e?.word), everyElement('run'));
      expect(api.requestedWords, ['run']);
    });
  });

  group('lookup', () {
    test('多词短语不发请求，直接返回未收录', () async {
      final api = _FakeDictionaryApi((word) async => _entryResponse(word));
      final service = buildService(api);

      expect(await service.lookup('forty percent'), isNull);
      expect(api.requestedWords, isEmpty);
    });
  });

  group('lookupAll', () {
    test('慢请求不阻塞后续请求：前面的请求完成后立即补位', () async {
      final events = <String>[];
      final api = _FakeDictionaryApi((word) async {
        events.add('start:$word');
        await Future<void>.delayed(
          Duration(milliseconds: word == 'w1' ? 100 : 1),
        );
        events.add('end:$word');
        return _entryResponse(word);
      });
      final service = buildService(api);

      await service.lookupAll([for (var i = 1; i <= 7; i++) 'w$i']);

      // w7 不必等 w1（慢请求）结束，只需等一个空位
      expect(events.indexOf('start:w7'), lessThan(events.indexOf('end:w1')));
    });

    test('同时在途的请求数不超过并发上限', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final api = _FakeDictionaryApi((word) async {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return _entryResponse(word);
      });
      final service = buildService(api);

      await service.lookupAll([for (var i = 1; i <= 20; i++) 'w$i']);

      expect(maxInFlight, 3);
    });

    test('多词短语与整句不发请求，也不进入结果', () async {
      final api = _FakeDictionaryApi((word) async => _entryResponse(word));
      final service = buildService(api);
      const sentence = 'they are doomed to be shy forever';

      final result = await service.lookupAll([
        sentence,
        'forty percent',
        'run',
      ]);

      expect(result.keys, ['run']);
      expect(api.requestedWords, ['run']);
    });

    test('优先使用缓存，只请求缺失的词；单词失败只跳过该词', () async {
      await db.dictionaryCacheDao.upsert(
        _dictId,
        'NASA',
        jsonEncode({
          'headword': 'NASA',
          'definitions': [
            {
              'pos': 'abbr',
              'translations': ['美国国家航空航天局'],
            },
          ],
        }),
      );
      final api = _FakeDictionaryApi((word) async {
        return switch (word) {
          'run' => _entryResponse('run'),
          'missing' => _notFoundResponse(),
          _ => _serverErrorResponse(),
        };
      });
      final service = buildService(api);

      final result = await service.lookupAll([
        'Run',
        'run',
        'NASA',
        'missing',
        'boom',
      ]);

      expect(result.keys, unorderedEquals(['Run', 'run', 'NASA']));
      expect(result['NASA']!.translation, 'abbr. 美国国家航空航天局');
      expect(result['Run']!.word, 'run');
      expect(api.requestedWords, unorderedEquals(['run', 'missing', 'boom']));
    });

    test('没有有效查询词时直接返回空结果，不发请求', () async {
      final api = _FakeDictionaryApi((word) async => _entryResponse(word));
      final service = buildService(api);

      expect(await service.lookupAll(['  ', '']), isEmpty);
      expect(api.requestedWords, isEmpty);
    });
  });
}
