import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/services/dictionary/ai_dictionary_source.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCacheDao extends Mock implements SentenceAiCacheDao {}

class MockApiClient extends Mock implements SentenceAiApiClient {}

DictionaryEntry _entry(String headword) => DictionaryEntry(
  headword: headword,
  pronunciation: const Pronunciation(uk: 'rʌn', us: 'rʌn'),
  meanings: const [],
  commonExpressions: const [],
  wordFamily: const [],
  forms: const [],
  etymology: '',
  learnerTips: const [],
);

MultiWordDictionaryEntry _multiEntry(String headword) =>
    MultiWordDictionaryEntry(
      originalExpression: headword,
      naturalness: '',
      category: '术语',
      pronunciationTips: const [],
      keyPoints: const [],
      meanings: const [
        MultiWordMeaning(
          translation: ['机器学习'],
          examples: [],
        ),
      ],
      similarExpressions: const [],
      background: '',
    );

void main() {
  late MockCacheDao dao;
  late MockApiClient api;
  late AiDictionarySource source;

  setUp(() {
    dao = MockCacheDao();
    api = MockApiClient();
    source = AiDictionarySource(cacheDao: () => dao, apiClient: () => api);
  });

  const word = 'run';
  const tokenReq = DictionaryLookupRequest(
    word: word,
    accessToken: 'tok',
    targetLanguage: 'zh-CN',
  );

  test('元数据', () {
    expect(source.id, 'ai');
    expect(source.canBeDisabled, isFalse);
    expect(source.requiresNetwork, isTrue);
  });

  test('无 accessToken → 抛 DictionaryAuthRequiredException', () {
    expect(
      () => source.lookup(const DictionaryLookupRequest(word: word)),
      throwsA(isA<DictionaryAuthRequiredException>()),
    );
  });

  test('L3 API 命中 → 返回结果并写 L1+L2', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    final result = await source.lookup(tokenReq);

    expect(result, isA<AiDictResult>());
    expect((result! as AiDictResult).entry.headword, word);
    verify(() => dao.upsert(any(), 'ai_dictionary_v2', any())).called(1);
  });

  test('request.word（已归一化）原样发往后端', () async {
    // 归一化由 controller 统一完成；源拿到的已是清洗结果，原样透传
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        any(),
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _entry('run'));
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    await source.lookup(tokenReq);

    verify(
      () => api.lookupDictionary(
        'run',
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('L1 内存命中 → 第二次不再调 API', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    await source.lookup(tokenReq);
    await source.lookup(tokenReq);

    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('clearMemoryCache 后重查不再命中 L1（回到 L2/L3）', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    await source.lookup(tokenReq); // 写入 L1
    source.clearMemoryCache(); // 清空 L1
    await source.lookup(tokenReq); // L1 落空 → 再次走 L2/L3

    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).called(2);
  });

  test('L2 SQLite 命中 → 不调 API', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => jsonEncode(_entry(word).toJson()));

    final result = await source.lookup(tokenReq);

    expect((result! as AiDictResult).entry.headword, word);
    verifyNever(
      () => api.lookupDictionary(
        any(),
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('L2 SQLite 命中多词表达 → 解析为 MultiWordDictionaryEntry', () async {
    when(() => dao.getByHash(any(), 'ai_dictionary_v2')).thenAnswer(
      (_) async => jsonEncode(_multiEntry('machine learning').toJson()),
    );

    final result = await source.lookup(
      const DictionaryLookupRequest(
        word: 'machine learning',
        accessToken: 'tok',
        targetLanguage: 'zh-CN',
      ),
    );

    final entry = (result! as AiDictResult).entry;
    expect(entry, isA<MultiWordDictionaryEntry>());
    expect(entry.headword, 'machine learning');
    verifyNever(
      () => api.lookupDictionary(
        any(),
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('后台单请求：忽略调用方 cancelToken（不转发给 API）', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    // 即便传入一个已取消的 token，请求仍正常完成（AI 忽略它）
    final token = CancelToken()..cancel('popup closed');
    final result = await source.lookup(tokenReq, cancelToken: token);

    expect((result! as AiDictResult).entry.headword, word);
    // 关键：API 不带 cancelToken 调用，无法被调用方中断
    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).called(1);
  });

  test('并发同词复用在途请求 → 只调一次 API', () async {
    final completer = Completer<DictionaryEntry?>();
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) => completer.future);
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    final f1 = source.lookup(tokenReq);
    final f2 = source.lookup(tokenReq);
    completer.complete(_entry(word));
    final r1 = await f1;
    final r2 = await f2;

    expect((r1! as AiDictResult).entry.headword, word);
    expect((r2! as AiDictResult).entry.headword, word);
    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).called(1);
  });

  test(
    '后端 400 + code=phrase_too_long → 抛 DictionaryPhraseTooLongException 且不落缓存',
    () async {
      when(
        () => dao.getByHash(any(), 'ai_dictionary_v2'),
      ).thenAnswer((_) async => null);
      when(
        () => api.lookupDictionary(
          any(),
          accessToken: any(named: 'accessToken'),
          targetLanguage: any(named: 'targetLanguage'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
            statusCode: 400,
            data: {'error': 'too long', 'code': 'phrase_too_long'},
          ),
        ),
      );

      await expectLater(
        source.lookup(
          const DictionaryLookupRequest(
            word: 'a b c d e f g h i',
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
        throwsA(isA<DictionaryPhraseTooLongException>()),
      );
      // 异常在 upsert 之前抛出，不写缓存
      verifyNever(() => dao.upsert(any(), 'ai_dictionary_v2', any()));
    },
  );

  test('其它 DioException（如 400 无 code）原样冒泡，不转词组过长', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        any(),
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
          statusCode: 400,
          data: {'error': 'Missing word'},
        ),
      ),
    );

    await expectLater(source.lookup(tokenReq), throwsA(isA<DioException>()));
  });

  test('API 返回 null → 空条目（isEmpty），仍为 AiDictResult', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    final result = await source.lookup(tokenReq);

    expect(result, isA<AiDictResult>());
    expect((result! as AiDictResult).entry.isEmpty, isTrue);
  });

  test('L3 API 返回多词表达 → 返回并写缓存', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary_v2'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        'machine learning',
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _multiEntry('machine learning'));
    when(
      () => dao.upsert(any(), 'ai_dictionary_v2', any()),
    ).thenAnswer((_) async {});

    final result = await source.lookup(
      const DictionaryLookupRequest(
        word: 'machine learning',
        accessToken: 'tok',
        targetLanguage: 'zh-CN',
      ),
    );

    final entry = (result! as AiDictResult).entry;
    expect(entry, isA<MultiWordDictionaryEntry>());
    expect(entry.headword, 'machine learning');
    verify(() => dao.upsert(any(), 'ai_dictionary_v2', any())).called(1);
  });
}
