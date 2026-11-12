import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';
import 'package:echo_loop/providers/sentence_ai_prewarm.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

const _lang = 'zh-CN';
const _token = 'token';
const _analysis = SentenceAnalysis(
  grammar: [GrammarPoint(point: 'g', note: 'n')],
);

Sentence _sentence(int index, String text) => Sentence(
  index: index,
  text: text,
  startTime: Duration(seconds: index),
  endTime: Duration(seconds: index + 1),
);

Stream<SentenceTranslationStreamFrame> _translationFrame(String text) =>
    Stream.value(
      SentenceTranslationStreamFrame(
        translation: SentenceTranslation(translation: '译:$text'),
        isFinal: true,
      ),
    );

Stream<SentenceAnalysisStreamFrame> _analysisFrame() => Stream.value(
  const SentenceAnalysisStreamFrame(analysis: _analysis, isFinal: true),
);

/// 先让出事件循环再抛 402，确保共享流订阅者已挂载。
Stream<SentenceAnalysisStreamFrame> _quotaExceeded() async* {
  await Future<void>.delayed(Duration.zero);
  final options = RequestOptions(path: '/api/v1/stream/analyze');
  throw DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: 402,
      data: {'code': 'quota_exceeded'},
    ),
  );
}

void main() {
  late _MockCacheDao dao;
  late _MockApiClient api;
  late SentenceAiNotifier ai;
  late SentenceAiPrewarmer prewarmer;

  final sentences = [
    _sentence(0, 'A.'),
    _sentence(1, 'B.'),
    _sentence(2, 'C.'),
    _sentence(3, 'D.'),
  ];

  SentenceAiPrewarmTarget target(int index) => SentenceAiPrewarmTarget(
    text: sentences[index].text,
    audioItemId: 'audio',
    sentenceIndex: index,
  );

  void stubTranslation(
    String text, {
    Stream<SentenceTranslationStreamFrame>? stream,
  }) {
    when(
      () => api.translateStream(
        text,
        accessToken: _token,
        previousText: any(named: 'previousText'),
        nextText: any(named: 'nextText'),
        targetLanguage: _lang,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => stream ?? _translationFrame(text));
  }

  void stubAnalysis(
    String text,
    Stream<SentenceAnalysisStreamFrame> Function() stream,
  ) {
    when(
      () => api.analyzeStream(
        text,
        accessToken: _token,
        targetLanguage: _lang,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => stream());
  }

  List<String> prewarmLogs() => AppLogger.instance.entries
      .where((entry) => entry.tag == 'SentenceAiPrewarm')
      .map((entry) => entry.message)
      .toList();

  setUp(() {
    AppLogger.instance.clear();
    dao = _MockCacheDao();
    api = _MockApiClient();
    when(() => dao.getByHash(any(), any())).thenAnswer((_) async => null);
    when(() => dao.upsert(any(), any(), any())).thenAnswer((_) async {});
    ai = SentenceAiNotifier(cacheDao: dao, apiClient: api);
    prewarmer = SentenceAiPrewarmer(
      ai: ai,
      loadSentences: (_) async => sentences,
    );
  });

  test('upcomingSentencePrewarmTargets 取当前位置之后最多两句', () {
    expect(
      upcomingSentencePrewarmTargets(
        sentences: sentences,
        position: 1,
        audioItemId: 'audio',
      ),
      [target(2), target(3)],
    );
    expect(
      upcomingSentencePrewarmTargets(
        sentences: sentences,
        position: 3,
        audioItemId: 'audio',
      ),
      isEmpty,
    );
  });

  test('当前句完成后才依次预热后续句，翻译带前后句上下文并写入缓存', () async {
    final currentTranslation =
        StreamController<SentenceTranslationStreamFrame>();
    stubTranslation('B.', stream: currentTranslation.stream);
    stubTranslation('C.');
    stubTranslation('D.');

    final run = prewarmer.prewarm(
      [target(1), target(2), target(3)],
      features: const SentenceAiPrewarmFeatures(
        translation: true,
        analysis: false,
        senseGroups: false,
      ),
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );
    await pumpEventQueue();
    verifyNever(
      () => api.translateStream(
        'C.',
        accessToken: any(named: 'accessToken'),
        previousText: any(named: 'previousText'),
        nextText: any(named: 'nextText'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );

    currentTranslation.add(
      const SentenceTranslationStreamFrame(
        translation: SentenceTranslation(translation: '译:B.'),
        isFinal: true,
      ),
    );
    await currentTranslation.close();
    await run;

    verify(
      () => api.translateStream(
        'C.',
        accessToken: _token,
        previousText: 'B.',
        nextText: 'D.',
        targetLanguage: _lang,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    verify(
      () => api.translateStream(
        'D.',
        accessToken: _token,
        previousText: 'C.',
        nextText: null,
        targetLanguage: _lang,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    // 与讲解视图同一缓存键：切到该卡片时可同步读到。
    expect(
      ai
          .getCachedTranslation(
            'C.',
            previous: 'B.',
            next: 'D.',
            targetLanguage: _lang,
          )
          ?.translation,
      '译:C.',
    );
    verify(() => dao.upsert(any(), 'translation_v2:$_lang', any())).called(3);
  });

  test('额度不足的功能在后续卡片跳过，其它功能继续预热', () async {
    for (final text in ['B.', 'C.', 'D.']) {
      stubTranslation(text);
    }
    stubAnalysis('B.', _quotaExceeded);
    stubAnalysis('C.', _analysisFrame);
    stubAnalysis('D.', _analysisFrame);

    await prewarmer.prewarm(
      [target(1), target(2), target(3)],
      features: const SentenceAiPrewarmFeatures(
        translation: true,
        analysis: true,
        senseGroups: false,
      ),
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );

    verifyNever(
      () => api.analyzeStream(
        'C.',
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
    expect(
      ai.getCachedTranslation('D.', previous: 'C.', targetLanguage: _lang),
      isNotNull,
    );
  });

  test('新一轮预热开始后，旧一轮不再调度剩余卡片', () async {
    final blocked = StreamController<SentenceAnalysisStreamFrame>();
    stubAnalysis('A.', () => blocked.stream);
    stubAnalysis('B.', _analysisFrame);
    stubAnalysis('D.', _analysisFrame);
    const features = SentenceAiPrewarmFeatures(
      translation: false,
      analysis: true,
      senseGroups: false,
    );

    final oldRun = prewarmer.prewarm(
      [target(0), target(1)],
      features: features,
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );
    await pumpEventQueue();
    final newRun = prewarmer.prewarm(
      [target(3)],
      features: features,
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );
    blocked.add(
      const SentenceAnalysisStreamFrame(analysis: _analysis, isFinal: true),
    );
    await blocked.close();
    await Future.wait([oldRun, newRun]);

    // 已发出的旧请求照常完成并写缓存，但被取代的轮次不再请求后续卡片。
    expect(ai.getCachedAnalysis('A.', targetLanguage: _lang), isNotNull);
    expect(ai.getCachedAnalysis('D.', targetLanguage: _lang), isNotNull);
    verifyNever(
      () => api.analyzeStream(
        'B.',
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
    // 日志可据此判断轮次被取代、各卡片结果与是否发起了网络请求。
    final logs = prewarmLogs();
    expect(
      logs,
      contains(allOf(contains('结束 reason=superseded'), contains('done=1/2'))),
    );
    expect(
      logs,
      contains(
        allOf(contains('sentence=0 卡片完成'), contains('analysis=completed')),
      ),
    );
    expect(
      AppLogger.instance.entries
          .where((entry) => entry.tag == 'SentenceAI')
          .map((entry) => entry.message),
      contains(startsWith('解析发起网络请求')),
    );
  });

  test('已缓存的卡片在日志中标记为 cached', () async {
    stubAnalysis('B.', _analysisFrame);
    const features = SentenceAiPrewarmFeatures(
      translation: false,
      analysis: true,
      senseGroups: false,
    );
    await prewarmer.prewarm(
      [target(1)],
      features: features,
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );
    AppLogger.instance.clear();

    await prewarmer.prewarm(
      [target(1)],
      features: features,
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );

    expect(
      prewarmLogs(),
      contains(allOf(contains('sentence=1 卡片完成'), contains('analysis=cached'))),
    );
    verify(
      () => api.analyzeStream(
        'B.',
        accessToken: _token,
        targetLanguage: _lang,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('当前句完成后，后续卡片并行预热，不互相等待', () async {
    stubAnalysis('B.', _analysisFrame);
    final slowUpcoming = StreamController<SentenceAnalysisStreamFrame>();
    stubAnalysis('C.', () => slowUpcoming.stream);
    stubAnalysis('D.', _analysisFrame);

    final run = prewarmer.prewarm(
      [target(1), target(2), target(3)],
      features: const SentenceAiPrewarmFeatures(
        translation: false,
        analysis: true,
        senseGroups: false,
      ),
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );
    await pumpEventQueue();

    // 第一张后续卡片仍在流式中，第二张已请求并就绪。
    expect(ai.getCachedAnalysis('D.', targetLanguage: _lang), isNotNull);
    expect(ai.getCachedAnalysis('C.', targetLanguage: _lang), isNull);

    slowUpcoming.add(
      const SentenceAnalysisStreamFrame(analysis: _analysis, isFinal: true),
    );
    await slowUpcoming.close();
    await run;
    expect(ai.getCachedAnalysis('C.', targetLanguage: _lang), isNotNull);
    expect(prewarmLogs(), contains(contains('结束 reason=completed done=3/3')));
  });

  test('翻译已缓存时日志标记为 cached', () async {
    stubTranslation('B.');
    const features = SentenceAiPrewarmFeatures(
      translation: true,
      analysis: false,
      senseGroups: false,
    );
    Future<void> run() => prewarmer.prewarm(
      [target(1)],
      features: features,
      targetLanguage: _lang,
      accessToken: _token,
      source: 'test',
    );
    await run();
    AppLogger.instance.clear();

    await run();

    expect(
      prewarmLogs(),
      contains(
        allOf(contains('sentence=1 卡片完成'), contains('translation=cached')),
      ),
    );
  });
}
