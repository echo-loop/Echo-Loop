/// DictionaryService.readCachedAll 只读查询测试：命中返回、未命中与不合法词不发请求
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/services/dictionary_service.dart';

const _dictId = 'en_zh-CN';

/// 记录所有请求的假 HTTP 适配器：只读查询不应触发任何请求
class _RecordingAdapter implements HttpClientAdapter {
  final requestedWords = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedWords.add(options.queryParameters['word'] as String);
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late _RecordingAdapter adapter;
  late DictionaryService service;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    service = DictionaryService(
      cacheDao: db.dictionaryCacheDao,
      dio: dio,
      dictId: _dictId,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('命中本地缓存的词返回词条（大小写不敏感），且不发起请求', () async {
    await db.dictionaryCacheDao.upsert(
      _dictId,
      'run',
      jsonEncode({
        'headword': 'run',
        'phonetic': 'rʌn',
        'definitions': [
          {
            'pos': 'vi',
            'translations': ['跑'],
            'examples': <Object>[],
          },
        ],
        'collins': 0,
        'tags': <String>[],
      }),
    );

    final result = await service.readCachedAll(['run', 'Run']);

    expect(result.keys, unorderedEquals(['run', 'Run']));
    expect(result['Run']?.word, 'run');
    expect(adapter.requestedWords, isEmpty);
  });

  test('未缓存的词与不合法的多词输入都不返回也不发起请求', () async {
    final result = await service.readCachedAll(['missing', 'two words']);

    expect(result, isEmpty);
    expect(adapter.requestedWords, isEmpty);
  });
}
