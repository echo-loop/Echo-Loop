import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/ai_quota_rejection.dart';
import 'package:echo_loop/features/usage/usage_counters.dart';
import 'package:echo_loop/features/usage/usage_event.dart';
import 'package:echo_loop/features/usage/usage_providers.dart';
import 'package:echo_loop/features/usage/usage_tracker.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/ai_dictionary_source.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../helpers/mock_providers.dart';

/// 记录 record 事件的 tracker 桩，用于断言成功计数是否被触发
class _RecordingUsageTracker implements UsageTracker {
  final List<UsageEvent> events = [];

  @override
  Future<void> record(
    UsageEvent event, {
    Map<String, Object>? analyticsParams,
  }) async {
    events.add(event);
  }

  @override
  UsageCounters loadCounters() => const UsageCounters();

  @override
  Future<void> resetForTests() async {}
}

/// 假 AI 源：满足 `is AiDictionarySource`，lookupStream 单帧返回可控结果/异常。
/// controller 对 AI 源走 lookupStream；结果类型不影响成功计数判定
/// （只看最终结果 != null + 源类型）。
class _FakeAiSource extends AiDictionarySource {
  _FakeAiSource({this.result, this.error})
    : super(
        cacheDao: () => throw UnimplementedError(),
        apiClient: () => throw UnimplementedError(),
      );

  final DictionaryLookupResult? result;
  final Object? error;

  @override
  Stream<DictionaryLookupResult?> lookupStream(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async* {
    if (error != null) throw error!;
    yield result;
  }
}

/// 可控 AI 源：每次 lookupStream 返回一个可手动驱动的 StreamController，
/// 用于编排流式多帧 / 竞态时序。满足 `is AiDictionarySource`。
class _ControllableAiSource extends AiDictionarySource {
  _ControllableAiSource()
    : super(
        cacheDao: () => throw UnimplementedError(),
        apiClient: () => throw UnimplementedError(),
      );

  final List<StreamController<DictionaryLookupResult?>> calls = [];

  @override
  Stream<DictionaryLookupResult?> lookupStream(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) {
    final ctrl = StreamController<DictionaryLookupResult?>();
    calls.add(ctrl);
    return ctrl.stream;
  }
}

/// 按请求 token 决定结果的 AI 源：用于验证登录事件会续跑同一 controller。
class _AuthAwareAiSource extends AiDictionarySource {
  _AuthAwareAiSource({required this.result})
    : super(
        cacheDao: () => throw UnimplementedError(),
        apiClient: () => throw UnimplementedError(),
      );

  final DictionaryLookupResult result;
  final List<DictionaryLookupRequest> requests = [];

  @override
  Stream<DictionaryLookupResult?> lookupStream(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async* {
    requests.add(request);
    if (request.accessToken == null || request.accessToken!.isEmpty) {
      throw const DictionaryAuthRequiredException();
    }
    yield result;
  }
}

/// 构造一个 AI 结果（部分/完整均可，只需 headword）
AiDictResult _aiResult(String headword) => AiDictResult(
  DictionaryEntry(
    headword: headword,
    pronunciation: const Pronunciation(uk: '', us: ''),
    meanings: const [],
    commonExpressions: const [],
    wordFamily: const [],
    forms: const [],
    etymology: '',
    learnerTips: const [],
  ),
);

/// 可控源：每次 lookup 返回一个手动完成的 Future，用于编排竞态时序
class ControllableSource implements DictionarySource {
  @override
  final String id;
  @override
  final bool requiresNetwork;
  ControllableSource(this.id, {this.requiresNetwork = true});

  final List<Completer<DictionaryLookupResult?>> calls = [];

  /// 记录每次 lookup 收到的请求，供断言归一化结果
  final List<DictionaryLookupRequest> requests = [];

  @override
  IconData get icon => Icons.abc;
  @override
  bool get canBeDisabled => true;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) {
    requests.add(request);
    final c = Completer<DictionaryLookupResult?>();
    calls.add(c);
    return c.future;
  }
}

DictionaryLookupResult _result(String word) => WebDictResult(
  sourceId: 'cambridge',
  url: Uri.parse('https://x/$word'),
  word: word,
);

Session _session(String accessToken) => Session(
  accessToken: accessToken,
  tokenType: 'bearer',
  refreshToken: 'refresh-token',
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-08-30T00:00:00.000Z',
  ),
);

void main() {
  // 让 build() 里的 Future.microtask 跑完
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  ProviderContainer makeContainer(
    Map<String, DictionarySource> sources, {
    String defaultId = 'a',
  }) {
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue(sources),
        resolvedDefaultSourceIdProvider.overrideWithValue(defaultId),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ]),
    );
    addTearDown(c.dispose);
    return c;
  }

  /// 启动 controller 并保持订阅（autoDispose 在测试中无监听会被立即销毁）
  DictionaryLookupController start(
    ProviderContainer c,
    String word, {
    String? preferredSourceId,
  }) {
    final p = dictionaryLookupControllerProvider(
      word,
      preferredSourceId: preferredSourceId,
    );
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    return c.read(p.notifier);
  }

  test('进入即查默认源 → Loading 然后 Loaded', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final ctrl = start(c, 'run');

    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoading>(),
    );

    a.calls.single.complete(_result('run'));
    await pump();
    final state = c.read(dictionaryLookupControllerProvider('run'));
    expect(state.current, isA<LookupLoaded>());
    expect((state.current! as LookupLoaded).result.headword, 'run');
    expect(ctrl, isNotNull);
  });

  test('切到另一个源加载；切回不重复查询', () async {
    final a = ControllableSource('a');
    final b = ControllableSource('b');
    final c = makeContainer({'a': a, 'b': b});
    final ctrl = start(c, 'run');
    await pump();
    a.calls.single.complete(_result('a-run'));
    await pump();

    ctrl.selectSource('b');
    await pump();
    b.calls.single.complete(_result('b-run'));
    await pump();
    expect(
      (c.read(dictionaryLookupControllerProvider('run')).current!
              as LookupLoaded)
          .result
          .headword,
      'b-run',
    );

    // 切回 a：复用缓存，不再调用 a.lookup
    ctrl.selectSource('a');
    await pump();
    expect(a.calls, hasLength(1)); // 仍只调用过一次
    expect(
      (c.read(dictionaryLookupControllerProvider('run')).current!
              as LookupLoaded)
          .result
          .headword,
      'a-run',
    );
  });

  test('未收录 → LookupNotFound', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    start(c, 'run');
    await pump();
    a.calls.single.complete(null);
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupNotFound>(),
    );
  });

  test('需登录 → LookupAuthRequired', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    start(c, 'run');
    await pump();
    a.calls.single.completeError(const DictionaryAuthRequiredException());
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupAuthRequired>(),
    );
  });

  test('登录成功后自动续跑当前 AI 查询，并使用最新 token', () async {
    final authEvents = StreamController<Session?>.broadcast();
    addTearDown(authEvents.close);
    final ai = _AuthAwareAiSource(result: _aiResult('run'));
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue({'ai': ai}),
        resolvedDefaultSourceIdProvider.overrideWithValue('ai'),
        supabaseSessionProvider.overrideWith((ref) => authEvents.stream),
        dictionaryLookupContextProvider.overrideWith((ref) {
          final session = ref.watch(supabaseSessionProvider).value;
          return DictionaryLookupContext(
            accessToken: session?.accessToken,
            targetLanguage: 'zh-CN',
          );
        }),
        usageTrackerProvider.overrideWithValue(_RecordingUsageTracker()),
      ]),
    );
    addTearDown(c.dispose);
    start(c, 'run');

    await pump();
    expect(ai.requests, hasLength(1));
    expect(ai.requests.single.accessToken, isNull);
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupAuthRequired>(),
    );

    authEvents.add(_session('fresh-token'));
    await pump();
    await pump();

    expect(ai.requests, hasLength(2));
    expect(ai.requests.last.accessToken, 'fresh-token');
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoaded>(),
    );

    // token 刷新仍是已登录态，不应把已加载的 AI 结果重复请求一次。
    authEvents.add(_session('refreshed-token'));
    await pump();
    expect(ai.requests, hasLength(2));
  });

  test('词组过长 → LookupPhraseTooLong', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    start(c, 'run');
    await pump();
    a.calls.single.completeError(const DictionaryPhraseTooLongException());
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupPhraseTooLong>(),
    );
  });

  test('失败 → LookupError；retry 重新查询', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final ctrl = start(c, 'run');
    await pump();
    a.calls.single.completeError(Exception('boom'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupError>(),
    );

    ctrl.retry();
    await pump();
    expect(a.calls, hasLength(2));
    a.calls.last.complete(_result('run'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoaded>(),
    );
  });

  test('后端 402（本月额度用尽）→ LookupQuotaExceeded', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    start(c, 'run');
    await pump();
    a.calls.single.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
          statusCode: 402,
        ),
      ),
    );
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupQuotaExceeded>(),
    );
  });

  test('后端 402 quota_exceeded + limit=0 → 免费版不支持原因', () async {
    final source = ControllableSource('a');
    final container = makeContainer({'a': source});
    start(container, 'run');
    await pump();
    source.calls.single.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v2/ai/dictionary'),
          statusCode: 402,
          data: {
            'code': 'quota_exceeded',
            'quota': {'used': 0, 'limit': 0},
          },
        ),
      ),
    );
    await pump();

    final state = container
        .read(dictionaryLookupControllerProvider('run'))
        .current;
    expect(state, isA<LookupQuotaExceeded>());
    expect(
      (state as LookupQuotaExceeded).reason,
      AiQuotaRejectionReason.unsupportedForFreePlan,
    );
  });

  test('同源竞态：旧查询晚到被丢弃，只保留新结果', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final ctrl = start(c, 'run');
    await pump(); // 第 1 次查询发起

    ctrl.retry(); // 第 2 次查询发起（同源）
    await pump();
    expect(a.calls, hasLength(2));

    // 旧查询(call#0)晚到 → 应被丢弃
    a.calls[0].complete(_result('OLD'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoading>(),
    );

    // 新查询(call#1)到达 → 生效
    a.calls[1].complete(_result('NEW'));
    await pump();
    expect(
      (c.read(dictionaryLookupControllerProvider('run')).current!
              as LookupLoaded)
          .result
          .headword,
      'NEW',
    );
  });

  test('controller 销毁后在途请求完成不写已销毁状态（不抛错）', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final p = dictionaryLookupControllerProvider('run');
    final sub = c.listen(p, (_, _) {});
    await pump();
    expect(a.calls, hasLength(1));

    // 关闭订阅 → autoDispose 销毁 controller（模拟关闭词典弹窗）
    sub.close();
    await pump();

    // 在途请求此刻才完成（AI 后台跑完的回调晚于 dispose 到达）：
    // disposed 守卫应丢弃回调，不对已销毁 Notifier 写 state，否则会抛错。
    a.calls.single.complete(_result('run'));
    await pump();
    // 跑到这里无未捕获异常即通过
  });

  test('word（已由调用方归一化）原样透传给各源，controller 不再归一', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    // family key 已是归一化结果（由 widget 层 normalizeWord 产出）
    start(c, "dogs'");
    await pump();
    expect(a.requests.single.word, "dogs'");
  });

  test('词组（含空格）：AI 源可见时初始源为 AI，忽略全局默认源', () async {
    final a = ControllableSource('a');
    final ai = ControllableSource('ai');
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue({'a': a, 'ai': ai}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
        visibleDictionarySourcesProvider.overrideWithValue([a, ai]),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ]),
    );
    addTearDown(c.dispose);
    start(c, 'give up');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('give up')).selectedSourceId,
      'ai',
    );
    expect(ai.calls, hasLength(1)); // 进入即查 AI 源
    expect(a.calls, isEmpty);
    expect(ai.requests.single.word, 'give up');
  });

  test('词组：AI 源不可见时回退全局默认源', () async {
    final a = ControllableSource('a');
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue({'a': a}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
        visibleDictionarySourcesProvider.overrideWithValue([a]),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ]),
    );
    addTearDown(c.dispose);
    start(c, 'give up');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('give up')).selectedSourceId,
      'a',
    );
    expect(a.calls, hasLength(1));
  });

  test('单词（无空格）初始源沿用全局默认源，不读可见源列表', () async {
    final a = ControllableSource('a');
    // 不 override visibleDictionarySourcesProvider：单词路径不应读它
    final c = makeContainer({'a': a});
    start(c, 'run2');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run2')).selectedSourceId,
      'a',
    );
  });

  test('会话粘滞源：手动切源后，切词（新 controller）沿用该源不回退默认', () async {
    final a = ControllableSource('a');
    final b = ControllableSource('b');
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue({'a': a, 'b': b}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
        visibleDictionarySourcesProvider.overrideWithValue([a, b]),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ]),
    );
    addTearDown(c.dispose);
    final ctrl = start(c, 'run');
    await pump();
    ctrl.selectSource('b'); // 用户手动切到 b
    await pump();

    // 切词：新 family controller 初始源应为粘滞的 b，而非默认 a
    start(c, 'walk');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('walk')).selectedSourceId,
      'b',
    );

    // 粘滞源优先于词组的 AI 偏好
    start(c, 'give up');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('give up')).selectedSourceId,
      'b',
    );

    // 会话结束（面板关闭清除粘滞源）后恢复默认源
    c.read(dictionarySessionSourceProvider.notifier).clear();
    start(c, 'jump');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('jump')).selectedSourceId,
      'a',
    );
  });

  test('会话粘滞源已不可见（设置隐藏）时回退默认源', () async {
    final a = ControllableSource('a');
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue({'a': a}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
        visibleDictionarySourcesProvider.overrideWithValue([a]),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ]),
    );
    addTearDown(c.dispose);
    c.read(dictionarySessionSourceProvider.notifier).remember('gone');
    start(c, 'run');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).selectedSourceId,
      'a',
    );
  });

  test('显式 preferredSourceId 优先于会话粘滞源，且只影响本次查询', () async {
    final a = ControllableSource('a');
    final b = ControllableSource('b');
    final ai = ControllableSource('ai');
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue({
          'a': a,
          'b': b,
          'ai': ai,
        }),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
        visibleDictionarySourcesProvider.overrideWithValue([a, b, ai]),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ]),
    );
    addTearDown(c.dispose);
    c.read(dictionarySessionSourceProvider.notifier).remember('b');

    start(c, 'small prompts', preferredSourceId: 'ai');
    await pump();
    expect(
      c
          .read(
            dictionaryLookupControllerProvider(
              'small prompts',
              preferredSourceId: 'ai',
            ),
          )
          .selectedSourceId,
      'ai',
    );
    expect(ai.calls, hasLength(1));
    expect(b.calls, isEmpty);

    // 普通后续查询未传 preferredSourceId，仍沿用用户手动选择的会话源。
    start(c, 'ordinary');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('ordinary')).selectedSourceId,
      'b',
    );
  });

  ProviderContainer makeAiContainer(
    Map<String, DictionarySource> sources,
    _RecordingUsageTracker tracker, {
    required String defaultId,
  }) {
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue(sources),
        resolvedDefaultSourceIdProvider.overrideWithValue(defaultId),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
        usageTrackerProvider.overrideWithValue(tracker),
      ]),
    );
    addTearDown(c.dispose);
    return c;
  }

  test('AI 源成功返回结果 → 记录一次 aiWordAnalysisSucceeded', () async {
    final tracker = _RecordingUsageTracker();
    final ai = _FakeAiSource(result: _result('run'));
    final c = makeAiContainer({'ai': ai}, tracker, defaultId: 'ai');
    start(c, 'run');
    await pump();

    expect(tracker.events, [UsageEvent.aiWordAnalysisSucceeded]);
  });

  test('AI 源未收录(null) → 不记录成功次数', () async {
    final tracker = _RecordingUsageTracker();
    final ai = _FakeAiSource(result: null);
    final c = makeAiContainer({'ai': ai}, tracker, defaultId: 'ai');
    start(c, 'run');
    await pump();

    expect(tracker.events, isEmpty);
  });

  test('AI 源抛异常 → 不记录成功次数', () async {
    final tracker = _RecordingUsageTracker();
    final ai = _FakeAiSource(error: const DictionaryAuthRequiredException());
    final c = makeAiContainer({'ai': ai}, tracker, defaultId: 'ai');
    start(c, 'run');
    await pump();

    expect(tracker.events, isEmpty);
  });

  test('非 AI 源成功返回 → 不记录 AI 成功次数', () async {
    final tracker = _RecordingUsageTracker();
    final a = ControllableSource('a');
    final c = makeAiContainer({'a': a}, tracker, defaultId: 'a');
    start(c, 'run');
    await pump();
    a.calls.single.complete(_result('run'));
    await pump();

    expect(tracker.events, isEmpty);
  });

  test('AI 流式：Loading → Streaming（逐帧）→ Loaded，记录一次成功', () async {
    final tracker = _RecordingUsageTracker();
    final ai = _ControllableAiSource();
    final c = makeAiContainer({'ai': ai}, tracker, defaultId: 'ai');
    start(c, 'run');
    await pump();

    // 起播前：Loading
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoading>(),
    );

    // 首帧部分结果 → Streaming
    ai.calls.single.add(_aiResult(''));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupStreaming>(),
    );

    // 更完整帧 → 仍 Streaming（未 close）
    ai.calls.single.add(_aiResult('run'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupStreaming>(),
    );

    // 流关闭（完整完成）→ Loaded + 记一次成功
    await ai.calls.single.close();
    await pump();
    final state = c.read(dictionaryLookupControllerProvider('run'));
    expect(state.current, isA<LookupLoaded>());
    expect((state.current! as LookupLoaded).result.headword, 'run');
    expect(tracker.events, [UsageEvent.aiWordAnalysisSucceeded]);
  });

  test('AI 流式竞态：重查后旧流的帧被丢弃', () async {
    final tracker = _RecordingUsageTracker();
    final ai = _ControllableAiSource();
    final c = makeAiContainer({'ai': ai}, tracker, defaultId: 'ai');
    final ctrl = start(c, 'run');
    await pump();

    ctrl.retry(); // 第二次查询（新 seq），取消旧流
    await pump();
    expect(ai.calls, hasLength(2));

    // 旧流的帧晚到 → 丢弃，状态维持 Loading
    ai.calls[0].add(_aiResult('OLD'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoading>(),
    );

    // 新流的帧生效
    ai.calls[1].add(_aiResult('NEW'));
    await pump();
    final cur = c.read(dictionaryLookupControllerProvider('run')).current;
    expect(cur, isA<LookupStreaming>());
    expect((cur! as LookupStreaming).result.headword, 'NEW');

    await ai.calls[0].close();
    await ai.calls[1].close();
  });

  test('AI 流式中途错误（DictionaryStreamException）→ LookupError', () async {
    final tracker = _RecordingUsageTracker();
    final ai = _ControllableAiSource();
    final c = makeAiContainer({'ai': ai}, tracker, defaultId: 'ai');
    start(c, 'run');
    await pump();

    ai.calls.single.add(_aiResult('run')); // 先来一帧
    await pump();
    ai.calls.single.addError(const DictionaryStreamException());
    await pump();

    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupError>(),
    );
    // 未完整完成 → 不记成功
    expect(tracker.events, isEmpty);
  });

  test('不需联网的源不读取上下文也能查', () async {
    final a = ControllableSource('a', requiresNetwork: false);
    // 不 override context：若 controller 误读会抛错
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesByIdProvider.overrideWithValue({'a': a}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
      ]),
    );
    addTearDown(c.dispose);
    start(c, 'run');
    await pump();
    a.calls.single.complete(_result('run'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoaded>(),
    );
  });
}
