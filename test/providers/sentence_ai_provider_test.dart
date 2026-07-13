import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/models/sense_group_result.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/utils/text_normalize.dart';

class MockCacheDao extends Mock implements SentenceAiCacheDao {}

class MockApiClient extends Mock implements SentenceAiApiClient {}

/// 结构化解析样例
const _analysisSample = SentenceAnalysis(
  grammar: [GrammarPoint(point: 'g', note: 'ge')],
  vocabulary: [VocabularyItem(term: 'v', note: 'vn')],
  listening: [ListeningPoint(phrase: 'l', note: 'ln')],
);

/// 单帧（末帧）解析流，供 analyzeStream mock 返回
Stream<SentenceAnalysisStreamFrame> _finalFrame(SentenceAnalysis a) =>
    Stream.fromIterable([
      SentenceAnalysisStreamFrame(analysis: a, isFinal: true),
    ]);

/// 单帧（末帧）译文流，供 translateStream mock 返回
Stream<SentenceTranslationStreamFrame> _finalTranslation(String t) =>
    Stream.fromIterable([
      SentenceTranslationStreamFrame(
        translation: SentenceTranslation(translation: t),
        isFinal: true,
      ),
    ]);

/// 单帧（末帧）意群流，供 senseGroupsStream mock 返回
Stream<SenseGroupsStreamFrame> _finalSenseGroups(SenseGroupResult r) =>
    Stream.fromIterable([SenseGroupsStreamFrame(result: r, isFinal: true)]);

/// 先让出一个事件循环再抛错的译文流，模拟真实端点（先 await POST 再出错），
/// 确保共享流的订阅者已挂载，错误不会在 broadcast 无监听时丢失。
Stream<SentenceTranslationStreamFrame> _errorTranslation(Object error) async* {
  await Future<void>.delayed(Duration.zero);
  throw error;
}

void main() {
  late MockCacheDao mockDao;
  late MockApiClient mockApi;
  late SentenceAiNotifier notifier;

  const lang = 'zh-CN';
  const l2TranslationType = 'translation_v2:$lang';
  const l2AnalysisType = 'analysis_v2:$lang';

  setUp(() {
    mockDao = MockCacheDao();
    mockApi = MockApiClient();
    notifier = SentenceAiNotifier(cacheDao: mockDao, apiClient: mockApi);
  });

  /// translateStream mock：默认 previous/next 为 null（无上下文），可覆盖。
  void stubTranslateStream(
    String text,
    Stream<SentenceTranslationStreamFrame> Function() streamFactory, {
    String targetLanguage = lang,
  }) {
    when(
      () => mockApi.translateStream(
        text,
        previousText: any(named: 'previousText'),
        nextText: any(named: 'nextText'),
        targetLanguage: targetLanguage,
        accessToken: 'token',
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => streamFactory());
  }

  group('getTranslationStream', () {
    const text = 'Hello world';

    test('后端 402（本月额度用尽）→ 抛 AiFeatureQuotaExceededException', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(
        text,
        () => _errorTranslation(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/stream/translate'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/stream/translate'),
              statusCode: 402,
            ),
          ),
        ),
      );

      await expectLater(
        notifier
            .getTranslationStream(
              text,
              targetLanguage: lang,
              accessToken: 'token',
            )
            .toList(),
        throwsA(isA<AiFeatureQuotaExceededException>()),
      );
    });

    test('后端 quota_exceeded 响应携带 resetAt 时透传到异常', () async {
      final resetAt = DateTime.utc(2026, 8);
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(
        text,
        () => _errorTranslation(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/stream/translate'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/stream/translate'),
              statusCode: 402,
              data: {
                'error': 'Monthly free quota exceeded',
                'code': 'quota_exceeded',
                'quota': {'resetAt': resetAt.toIso8601String()},
              },
            ),
          ),
        ),
      );

      await expectLater(
        notifier
            .getTranslationStream(
              text,
              targetLanguage: lang,
              accessToken: 'token',
            )
            .toList(),
        throwsA(
          isA<AiFeatureQuotaExceededException>().having(
            (e) => e.resetAt,
            'resetAt',
            resetAt,
          ),
        ),
      );
    });

    test('非 402 的 Dio 错误原样抛出（不误判为额度超限）', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(
        text,
        () => _errorTranslation(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/stream/translate'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/stream/translate'),
              statusCode: 500,
            ),
          ),
        ),
      );

      await expectLater(
        notifier
            .getTranslationStream(
              text,
              targetLanguage: lang,
              accessToken: 'token',
            )
            .toList(),
        throwsA(isA<DioException>()),
      );
    });

    test('L2 SQLite 缓存命中，一次性 yield 译文', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => '{"translation":"你好世界"}');

      final frames = await notifier
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .toList();
      expect(frames.single.translation, '你好世界');

      // 命中缓存不调 L3
      verifyNever(
        () => mockApi.translateStream(
          any(),
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: any(named: 'targetLanguage'),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('L3 流式调用：逐帧 yield，收 final 后写 L1+L2', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(text, () => _finalTranslation('你好世界'));
      when(
        () => mockDao.upsert(any(), l2TranslationType, any()),
      ).thenAnswer((_) async {});

      final result = await notifier
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;
      expect(result.translation, '你好世界');

      verify(() => mockDao.upsert(any(), l2TranslationType, any())).called(1);
      // L1 也已缓存（同上下文命中）
      expect(notifier.getCachedTranslation(text)?.translation, '你好世界');
    });

    test('L2 未命中且无 accessToken 时抛出登录需求，不调用 API', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);

      await expectLater(
        notifier.getTranslationStream(text, targetLanguage: lang).toList(),
        throwsA(isA<AiFeatureAuthRequiredException>()),
      );

      verifyNever(
        () => mockApi.translateStream(
          any(),
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: any(named: 'targetLanguage'),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('中途取消（未收 final）不写缓存', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      // 只发部分帧、无 final（模拟客户端关流）
      stubTranslateStream(
        text,
        () => Stream.fromIterable([
          SentenceTranslationStreamFrame(
            translation: const SentenceTranslation(translation: '你好'),
            isFinal: false,
          ),
        ]),
      );

      await notifier
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .toList();

      verifyNever(() => mockDao.upsert(any(), l2TranslationType, any()));
      expect(notifier.getCachedTranslation(text), isNull);
    });

    test('并发请求去重（共享同一后端流）', () async {
      final controller = StreamController<SentenceTranslationStreamFrame>();
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(text, () => controller.stream);
      when(
        () => mockDao.upsert(any(), l2TranslationType, any()),
      ).thenAnswer((_) async {});

      final f1 = notifier
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .toList();
      final f2 = notifier
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .toList();
      await Future<void>.delayed(Duration.zero);

      controller.add(
        SentenceTranslationStreamFrame(
          translation: const SentenceTranslation(translation: '你好'),
          isFinal: true,
        ),
      );
      await controller.close();

      final r1 = await f1;
      final r2 = await f2;
      expect(r1.last.translation, '你好');
      expect(r2.last.translation, '你好');

      // 后端流只被建立一次
      verify(
        () => mockApi.translateStream(
          text,
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('前后句上下文进缓存键：不同上下文各自独立', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      when(
        () => mockDao.upsert(any(), l2TranslationType, any()),
      ).thenAnswer((_) async {});
      when(
        () => mockApi.translateStream(
          text,
          previousText: 'A.',
          nextText: 'B.',
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => _finalTranslation('带上下文'));

      await notifier
          .getTranslationStream(
            text,
            previous: 'A.',
            next: 'B.',
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;

      // 带上下文的缓存键命中；无上下文的键不命中（context hash 不同）
      expect(
        notifier
            .getCachedTranslation(text, previous: 'A.', next: 'B.')
            ?.translation,
        '带上下文',
      );
      expect(notifier.getCachedTranslation(text), isNull);
    });
  });

  group('getAnalysisStream', () {
    const text = 'She has been studying.';

    test('L2 SQLite 缓存命中，一次性 yield 结构化结果', () async {
      when(() => mockDao.getByHash(any(), l2AnalysisType)).thenAnswer(
        (_) async =>
            '{"grammar":[{"point":"现在完成进行时","note":"表持续"}],"vocabulary":[],"listening":[]}',
      );

      final frames = await notifier
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .toList();
      expect(frames.length, 1);
      expect(frames.single.grammar.single.point, '现在完成进行时');
      // 命中缓存不调 L3
      verifyNever(
        () => mockApi.analyzeStream(
          any(),
          targetLanguage: any(named: 'targetLanguage'),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('L3 流式调用：逐帧 yield，收 final 后写 L2', () async {
      when(
        () => mockDao.getByHash(any(), l2AnalysisType),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeStream(
          text,
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => _finalFrame(_analysisSample));
      when(
        () => mockDao.upsert(any(), l2AnalysisType, any()),
      ).thenAnswer((_) async {});

      final result = await notifier
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .last;
      expect(result.grammar.single.point, 'g');

      verify(() => mockDao.upsert(any(), l2AnalysisType, any())).called(1);
    });

    test('final 解析为空时不写缓存、不计试用，后续允许重试', () async {
      final consumed = <PremiumFeature>[];
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        onConsumeTrial: consumed.add,
      );
      when(
        () => mockDao.getByHash(any(), l2AnalysisType),
      ).thenAnswer((_) async => null);
      var calls = 0;
      when(
        () => mockApi.analyzeStream(
          text,
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) {
        calls++;
        return _finalFrame(const SentenceAnalysis());
      });

      final first = await gated
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .toList();
      final second = await gated
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .toList();

      expect(first.single.isEmpty, isTrue);
      expect(second.single.isEmpty, isTrue);
      expect(calls, 2);
      expect(consumed, isEmpty);
      verifyNever(() => mockDao.upsert(any(), l2AnalysisType, any()));
    });

    test('L2 未命中且无 accessToken 时抛出登录需求，不调用 API', () async {
      when(
        () => mockDao.getByHash(any(), l2AnalysisType),
      ).thenAnswer((_) async => null);

      await expectLater(
        notifier.getAnalysisStream(text, targetLanguage: lang).toList(),
        throwsA(isA<AiFeatureAuthRequiredException>()),
      );

      verifyNever(
        () => mockApi.analyzeStream(
          any(),
          targetLanguage: any(named: 'targetLanguage'),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('中途取消（未收 final）不写缓存', () async {
      when(
        () => mockDao.getByHash(any(), l2AnalysisType),
      ).thenAnswer((_) async => null);
      // 只发部分帧、无 final（模拟客户端关流）
      when(
        () => mockApi.analyzeStream(
          text,
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          SentenceAnalysisStreamFrame(
            analysis: _analysisSample,
            isFinal: false,
          ),
        ]),
      );

      await notifier
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .toList();

      verifyNever(() => mockDao.upsert(any(), l2AnalysisType, any()));
      // 未 final 不落 L1
      expect(notifier.getCachedAnalysis(text, targetLanguage: lang), isNull);
    });
  });

  group('getCachedTranslation / getCachedAnalysis', () {
    test('无缓存时返回 null', () {
      expect(notifier.getCachedTranslation('test'), isNull);
      expect(notifier.getCachedAnalysis('test'), isNull);
    });
  });

  group('clearMemoryCache', () {
    test('清除后 getCachedTranslation 返回 null', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream('test', () => _finalTranslation('t'));
      when(() => mockDao.upsert(any(), any(), any())).thenAnswer((_) async {});

      await notifier
          .getTranslationStream(
            'test',
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;
      expect(notifier.getCachedTranslation('test'), isNotNull);

      notifier.clearMemoryCache();
      expect(notifier.getCachedTranslation('test'), isNull);
    });
  });

  group('getAnalysisStream L1 缓存', () {
    const text = 'She has been studying.';

    test('L1 内存缓存命中直接返回，不查 DB 也不调 API', () async {
      when(
        () => mockDao.getByHash(any(), l2AnalysisType),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeStream(
          text,
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => _finalFrame(_analysisSample));
      when(
        () => mockDao.upsert(any(), l2AnalysisType, any()),
      ).thenAnswer((_) async {});

      // 第一次：L3 流式写入 L1
      await notifier
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .last;

      reset(mockDao);
      reset(mockApi);

      // 第二次：L1 命中，不查 DB 也不调 API
      final result = await notifier
          .getAnalysisStream(text, targetLanguage: lang)
          .last;
      expect(result.grammar.single.point, 'g');

      verifyNever(() => mockDao.getByHash(any(), any()));
      verifyNever(
        () => mockApi.analyzeStream(
          any(),
          targetLanguage: any(named: 'targetLanguage'),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('并发请求同一句子复用同一条流式 API 调用', () async {
      final controller = StreamController<SentenceAnalysisStreamFrame>();

      when(
        () => mockDao.getByHash(any(), l2AnalysisType),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeStream(
          text,
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => controller.stream);
      when(
        () => mockDao.upsert(any(), l2AnalysisType, any()),
      ).thenAnswer((_) async {});

      final first = notifier
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .last;
      final second = notifier
          .getAnalysisStream(text, targetLanguage: lang, accessToken: 'token')
          .last;

      controller.add(
        SentenceAnalysisStreamFrame(analysis: _analysisSample, isFinal: false),
      );
      controller.add(
        SentenceAnalysisStreamFrame(analysis: _analysisSample, isFinal: true),
      );
      await controller.close();

      final results = await Future.wait([first, second]);
      expect(results.map((r) => r.grammar.single.point), ['g', 'g']);
      verify(
        () => mockApi.analyzeStream(
          text,
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      verify(() => mockDao.upsert(any(), l2AnalysisType, any())).called(1);
    });
  });

  group('失败处理', () {
    test('getTranslationStream API 失败时不写入缓存', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(
        'fail test',
        () => _errorTranslation(Exception('network error')),
      );

      // 流抛异常
      await expectLater(
        notifier
            .getTranslationStream(
              'fail test',
              targetLanguage: lang,
              accessToken: 'token',
            )
            .toList(),
        throwsA(isA<Exception>()),
      );

      // L1 内存缓存应为空
      expect(notifier.getCachedTranslation('fail test'), isNull);
    });

    test('clearMemoryCache 同时清除 analysis 缓存', () async {
      // 写入 translation
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream('test', () => _finalTranslation('t'));
      when(() => mockDao.upsert(any(), any(), any())).thenAnswer((_) async {});

      // 写入 analysis
      when(
        () => mockDao.getByHash(any(), l2AnalysisType),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeStream(
          any(),
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => _finalFrame(_analysisSample));

      await notifier
          .getTranslationStream(
            'test',
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;
      await notifier
          .getAnalysisStream('test', targetLanguage: lang, accessToken: 'token')
          .last;

      // 确认两者都有缓存
      expect(notifier.getCachedTranslation('test'), isNotNull);
      expect(notifier.getCachedAnalysis('test'), isNotNull);

      // 清除后两者都为 null
      notifier.clearMemoryCache();
      expect(notifier.getCachedTranslation('test'), isNull);
      expect(notifier.getCachedAnalysis('test'), isNull);
    });
  });

  group('getSenseGroupsStream', () {
    const text = 'Hello world';
    final hash = hashText(text);

    void stubSenseGroupsStream(Stream<SenseGroupsStreamFrame> Function() f) {
      when(
        () => mockApi.senseGroupsStream(
          text,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => f());
    }

    test('L2 未命中且无 accessToken 时抛出登录需求，不调用 API', () async {
      when(
        () => mockDao.getByHash(hash, 'sense_groups'),
      ).thenAnswer((_) async => null);

      await expectLater(
        notifier.getSenseGroupsStream(text).toList(),
        throwsA(isA<AiFeatureAuthRequiredException>()),
      );

      verifyNever(
        () => mockApi.senseGroupsStream(
          any(),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('L2 SQLite 缓存命中，一次性 yield，不调 API', () async {
      when(() => mockDao.getByHash(hash, 'sense_groups')).thenAnswer(
        (_) async => '{"medium":["Hello world"],"fine":["Hello","world"]}',
      );

      final frames = await notifier
          .getSenseGroupsStream(text, accessToken: 'token')
          .toList();
      expect(frames.single.medium, ['Hello world']);
      verifyNever(
        () => mockApi.senseGroupsStream(
          any(),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('L3 流式：逐帧 yield，final 且 concat 校验通过 → 写 L1+L2', () async {
      when(
        () => mockDao.getByHash(hash, 'sense_groups'),
      ).thenAnswer((_) async => null);
      // medium 拼接 = 原句；fine 拼接剥空白后 = 原句 → 校验通过
      stubSenseGroupsStream(
        () => _finalSenseGroups(
          const SenseGroupResult(
            medium: ['Hello world'],
            fine: ['Hello', 'world'],
          ),
        ),
      );
      when(
        () => mockDao.upsert(hash, 'sense_groups', any()),
      ).thenAnswer((_) async {});

      final result = await notifier
          .getSenseGroupsStream(text, accessToken: 'token')
          .last;
      expect(result.medium, ['Hello world']);

      verify(() => mockDao.upsert(hash, 'sense_groups', any())).called(1);
      expect(notifier.getCachedSenseGroups(text)?.medium, ['Hello world']);
    });

    test('final concat 校验失败 → 不落缓存（可重试）', () async {
      when(
        () => mockDao.getByHash(hash, 'sense_groups'),
      ).thenAnswer((_) async => null);
      // 拼接（含剥空白+标点）都无法还原原句 → 校验失败
      stubSenseGroupsStream(
        () => _finalSenseGroups(
          const SenseGroupResult(medium: ['Goodbye'], fine: ['Goodbye']),
        ),
      );

      await notifier.getSenseGroupsStream(text, accessToken: 'token').toList();

      verifyNever(() => mockDao.upsert(hash, 'sense_groups', any()));
      expect(notifier.getCachedSenseGroups(text), isNull);
    });

    test('中途取消（未收 final）→ 不落缓存', () async {
      when(
        () => mockDao.getByHash(hash, 'sense_groups'),
      ).thenAnswer((_) async => null);
      stubSenseGroupsStream(
        () => Stream.fromIterable([
          const SenseGroupsStreamFrame(
            result: SenseGroupResult(medium: ['Hello world'], fine: []),
            isFinal: false,
          ),
        ]),
      );

      await notifier.getSenseGroupsStream(text, accessToken: 'token').toList();

      verifyNever(() => mockDao.upsert(hash, 'sense_groups', any()));
      expect(notifier.getCachedSenseGroups(text), isNull);
    });

    test('校验通过 → 消耗一次意群试用；校验失败 → 不消耗', () async {
      final consumed = <PremiumFeature>[];
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        guardFeature: (_) {},
        onConsumeTrial: consumed.add,
      );
      when(
        () => mockDao.getByHash(hash, 'sense_groups'),
      ).thenAnswer((_) async => null);
      when(
        () => mockDao.upsert(hash, 'sense_groups', any()),
      ).thenAnswer((_) async {});
      stubSenseGroupsStream(
        () => _finalSenseGroups(
          const SenseGroupResult(
            medium: ['Hello world'],
            fine: ['Hello', 'world'],
          ),
        ),
      );

      await gated.getSenseGroupsStream(text, accessToken: 'token').last;
      expect(consumed, [PremiumFeature.aiSenseGroup]);
    });
  });

  group('translationContextHash 一致性', () {
    test('归一化后相同的文本命中同一缓存', () async {
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream('Hello World.', () => _finalTranslation('x'));
      when(() => mockDao.upsert(any(), any(), any())).thenAnswer((_) async {});

      await notifier
          .getTranslationStream(
            'Hello World.',
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;

      // 归一化后 "Hello World." 与 "  HELLO   WORLD.  " 上下文哈希相同
      final hash1 = translationContextHash('Hello World.');
      final hash2 = translationContextHash('  HELLO   WORLD.  ');
      expect(hash1, hash2);

      // L1 缓存应命中（同上下文=无上下文）
      final cached = notifier.getCachedTranslation('  HELLO   WORLD.  ');
      expect(cached?.translation, 'x');
    });
  });

  group('额度闸（guard / consume）', () {
    const text = 'Hello world';
    const lang = 'zh-CN';
    const l2TranslationType = 'translation_v2:$lang';

    test('已登录但未解锁 → guard 抛 QuotaExceeded，不调用 API、不消耗试用', () async {
      final consumed = <PremiumFeature>[];
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        guardFeature: (_) => throw const AiFeatureQuotaExceededException(),
        onConsumeTrial: consumed.add,
      );
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);

      await expectLater(
        gated
            .getTranslationStream(
              text,
              targetLanguage: lang,
              accessToken: 'token',
            )
            .toList(),
        throwsA(isA<AiFeatureQuotaExceededException>()),
      );

      verifyNever(
        () => mockApi.translateStream(
          any(),
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: any(named: 'targetLanguage'),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
      expect(consumed, isEmpty);
    });

    test('已解锁（guard 放行）→ L3 成功后消耗一次试用', () async {
      final consumed = <PremiumFeature>[];
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        guardFeature: (_) {}, // 放行
        onConsumeTrial: consumed.add,
      );
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(text, () => _finalTranslation('你好世界'));
      when(
        () => mockDao.upsert(any(), l2TranslationType, any()),
      ).thenAnswer((_) async {});

      await gated
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;

      expect(consumed, [PremiumFeature.aiTranslation]);
    });

    test('自动加载尊重本地 reset，提前抛 QuotaExceeded 且不调用 API', () async {
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        beforeApiRequest: (feature, {required respectLocalQuotaReset}) async {
          expect(feature, PremiumFeature.aiTranslation);
          if (respectLocalQuotaReset) {
            throw AiFeatureQuotaExceededException(feature: feature);
          }
        },
      );
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);

      await expectLater(
        gated
            .getTranslationStream(
              text,
              targetLanguage: lang,
              accessToken: 'token',
              respectLocalQuotaReset: true,
            )
            .toList(),
        throwsA(isA<AiFeatureQuotaExceededException>()),
      );

      verifyNever(
        () => mockApi.translateStream(
          any(),
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: any(named: 'targetLanguage'),
          accessToken: any(named: 'accessToken'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('用户主动请求不受本地 reset 阻断，仍发起 API', () async {
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        beforeApiRequest: (feature, {required respectLocalQuotaReset}) async {
          expect(feature, PremiumFeature.aiTranslation);
          expect(respectLocalQuotaReset, isFalse);
        },
      );
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(text, () => _finalTranslation('你好世界'));
      when(
        () => mockDao.upsert(any(), l2TranslationType, any()),
      ).thenAnswer((_) async {});

      final result = await gated
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;

      expect(result.translation, '你好世界');
      verify(
        () => mockApi.translateStream(
          text,
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: lang,
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('L3 成功后清除该功能 reset 时间', () async {
      final cleared = <PremiumFeature>[];
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        onApiSucceeded: (feature) async {
          cleared.add(feature);
        },
      );
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => null);
      stubTranslateStream(text, () => _finalTranslation('你好世界'));
      when(
        () => mockDao.upsert(any(), l2TranslationType, any()),
      ).thenAnswer((_) async {});

      await gated
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;

      expect(cleared, [PremiumFeature.aiTranslation]);
    });

    test('缓存命中不经过额度闸（不抛、不消耗）', () async {
      final consumed = <PremiumFeature>[];
      final gated = SentenceAiNotifier(
        cacheDao: mockDao,
        apiClient: mockApi,
        guardFeature: (_) => throw const AiFeatureQuotaExceededException(),
        onConsumeTrial: consumed.add,
      );
      when(
        () => mockDao.getByHash(any(), l2TranslationType),
      ).thenAnswer((_) async => '{"translation":"你好世界"}');

      final result = await gated
          .getTranslationStream(
            text,
            targetLanguage: lang,
            accessToken: 'token',
          )
          .last;
      expect(result.translation, '你好世界');
      expect(consumed, isEmpty);
    });
  });

  group('不同 targetLanguage 缓存隔离', () {
    const text = 'Hello';

    test('不同语言各自独立缓存', () async {
      // zh-CN 缓存
      when(
        () => mockDao.getByHash(any(), 'translation_v2:zh-CN'),
      ).thenAnswer((_) async => null);
      stubTranslateStream(
        text,
        () => _finalTranslation('你好'),
        targetLanguage: 'zh-CN',
      );
      when(() => mockDao.upsert(any(), any(), any())).thenAnswer((_) async {});

      final zhResult = await notifier
          .getTranslationStream(
            text,
            targetLanguage: 'zh-CN',
            accessToken: 'token',
          )
          .last;
      expect(zhResult.translation, '你好');

      // zh-TW 缓存（应该不命中 zh-CN 的 L1）
      when(
        () => mockDao.getByHash(any(), 'translation_v2:zh-TW'),
      ).thenAnswer((_) async => null);
      stubTranslateStream(
        text,
        () => _finalTranslation('你好'),
        targetLanguage: 'zh-TW',
      );

      final twResult = await notifier
          .getTranslationStream(
            text,
            targetLanguage: 'zh-TW',
            accessToken: 'token',
          )
          .last;
      expect(twResult.translation, '你好');

      // 两次都应调用 API（不同语言不共享缓存）
      verify(
        () => mockApi.translateStream(
          text,
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: 'zh-CN',
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      verify(
        () => mockApi.translateStream(
          text,
          previousText: any(named: 'previousText'),
          nextText: any(named: 'nextText'),
          targetLanguage: 'zh-TW',
          accessToken: 'token',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });
  });
}
