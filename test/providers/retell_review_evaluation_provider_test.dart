/// RetellReviewEvaluationController 测试：登录/额度闸门、后端 401/402 映射、计费。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/ai_quota_rejection.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/ai_trial_usage_provider.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/models/retell_review_evaluation.dart';
import 'package:echo_loop/providers/retell_review_evaluation_provider.dart';
import 'package:echo_loop/services/retell_review_audio_preparer.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_io/io.dart';
import '../helpers/mock_providers.dart';

/// 可脚本化的评估流替身，并记录 accessToken 入参。
class _ScriptApi implements SentenceAiApiClient {
  _ScriptApi(this.script);
  final Stream<RetellReviewStreamFrame> Function() script;

  int callCount = 0;
  String? lastAccessToken;

  @override
  Stream<RetellReviewStreamFrame> evaluateReviewStream({
    required File audioFile,
    required String originalText,
    required String targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) {
    callCount++;
    lastAccessToken = accessToken;
    return script();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 记录调用次数的音频准备替身：闸门必须早于它，一次都不该被调到。
class _SpyPreparer implements RetellReviewAudioPreparer {
  _SpyPreparer(this._output);
  final File _output;
  int callCount = 0;

  @override
  Future<File> prepare(File source) async {
    callCount++;
    return _output;
  }
}

class _RecordingTrialUsage extends AiTrialUsageNotifier {
  final consumed = <PremiumFeature>[];
  @override
  Map<PremiumFeature, int> build() => const {};
  @override
  void consume(PremiumFeature feature) => consumed.add(feature);
}

class _FixedSubscription extends SubscriptionController {
  _FixedSubscription(this._state);
  final EntitlementState _state;
  @override
  EntitlementState build() => _state;
}

class _DenyPolicy implements FreeAllowancePolicy {
  const _DenyPolicy();
  @override
  bool allows(PremiumFeature feature) => false;
}

Session _session() => Session(
  accessToken: 'test-token',
  tokenType: 'bearer',
  user: const User(
    id: 'u',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-07-13T00:00:00.000Z',
  ),
);

const _pro = EntitlementState(
  status: EntitlementStatus.premium,
  entitlement: Entitlement(isPremium: true),
);

DioException _httpError(int status, {Object? data}) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/stream/evaluate-review'),
  response: Response(
    requestOptions: RequestOptions(path: '/api/v1/stream/evaluate-review'),
    statusCode: status,
    data: data,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SpyPreparer preparer;
  late _RecordingTrialUsage trialUsage;
  late List<String> divergenceContexts;
  late File prepared;

  setUp(() async {
    prepared = File(
      '${Directory.systemTemp.path}/retell-review-controller-test.m4a',
    );
    await prepared.writeAsBytes([0, 1, 2]);
    preparer = _SpyPreparer(prepared);
    trialUsage = _RecordingTrialUsage();
    divergenceContexts = <String>[];
  });

  tearDown(() async {
    if (await prepared.exists()) await prepared.delete();
  });

  /// 构造容器：默认已登录 + 免费 + 放行。
  ///
  /// supabaseSessionProvider 是 StreamProvider（异步 emit），controller 同步读
  /// `valueOrNull`，故先 await 让其落定，避免误判 AsyncLoading → auth_required。
  Future<ProviderContainer> make(
    _ScriptApi api, {
    bool authenticated = true,
    bool hasSession = true,
    EntitlementState subscription = const EntitlementState.free(),
    FreeAllowancePolicy policy = const AlwaysAllowPolicy(),
  }) async {
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        sentenceAiApiClientProvider.overrideWithValue(api),
        retellReviewAudioPreparerProvider.overrideWithValue(preparer),
        isAuthenticatedProvider.overrideWithValue(authenticated),
        supabaseSessionProvider.overrideWithValue(AsyncData<Session?>(hasSession ? _session() : null)),
        subscriptionControllerProvider.overrideWith(
          () => _FixedSubscription(subscription),
        ),
        freeAllowancePolicyProvider.overrideWithValue(policy),
        aiTrialUsageProvider.overrideWith(() => trialUsage),
        entitlementQuotaDivergenceHandlerProvider.overrideWithValue(
          divergenceContexts.add,
        ),
      ]),
    );
    addTearDown(container.dispose);
    container.listen(retellReviewEvaluationProvider, (_, __) {});
    // Riverpod 3：无监听者的 StreamProvider 会被暂停、不再投递首值，
    // 必须保持一个监听，才能等到 session 落定。
    container.listen(supabaseSessionProvider, (_, __) {});
    await container.read(supabaseSessionProvider.future);
    return container;
  }

  Future<void> evaluate(ProviderContainer c) => c
      .read(retellReviewEvaluationProvider.notifier)
      .evaluate(
        attemptKey: 'p1:/tmp/retell.m4a',
        recordingPath: prepared.path,
        originalText: 'Practice every day.',
        targetLanguage: 'zh-CN',
      );

  RetellReviewEvaluationState st(ProviderContainer c) =>
      c.read(retellReviewEvaluationProvider);

  Stream<RetellReviewStreamFrame> okStream() async* {
    yield const RetellReviewStreamFrame(
      evaluation: RetellReviewEvaluation(summary: '表达清楚'),
      isFinal: false,
    );
    yield const RetellReviewStreamFrame(
      evaluation: RetellReviewEvaluation(
        summary: '表达清楚',
        rating: RetellReviewRating.good,
      ),
      isFinal: true,
    );
  }

  test('成功评估：带上 accessToken，完成后计一次试用', () async {
    final api = _ScriptApi(okStream);
    final c = await make(api);
    await evaluate(c);

    expect(st(c).phase, RetellReviewEvaluationPhase.completed);
    expect(api.lastAccessToken, 'test-token');
    expect(trialUsage.consumed, [PremiumFeature.aiRetellReview]);
  });

  test('会员成功不计试用', () async {
    final api = _ScriptApi(okStream);
    final c = await make(api, subscription: _pro);
    await evaluate(c);

    expect(st(c).phase, RetellReviewEvaluationPhase.completed);
    expect(trialUsage.consumed, isEmpty);
  });

  test('未登录直接失败，不转码也不发请求', () async {
    final api = _ScriptApi(okStream);
    final c = await make(api, authenticated: false, hasSession: false);
    await evaluate(c);

    expect(st(c).phase, RetellReviewEvaluationPhase.failed);
    expect(st(c).errorCode, 'auth_required');
    // 闸门必须早于 ffmpeg 转码与 2MB 上传。
    expect(preparer.callCount, 0);
    expect(api.callCount, 0);
  });

  test('已登录未解锁直接失败，不转码也不发请求', () async {
    final api = _ScriptApi(okStream);
    final c = await make(api, policy: const _DenyPolicy());
    await evaluate(c);

    expect(st(c).phase, RetellReviewEvaluationPhase.failed);
    expect(st(c).errorCode, 'quota_exceeded');
    expect(preparer.callCount, 0);
    expect(api.callCount, 0);
  });

  test('后端 401 → auth_required', () async {
    final api = _ScriptApi(() => Stream.error(_httpError(401)));
    final c = await make(api);
    await evaluate(c);

    expect(st(c).errorCode, 'auth_required');
    expect(divergenceContexts, isEmpty);
  });

  test('后端 402 → quota_exceeded，并触发权益分歧收敛', () async {
    final api = _ScriptApi(
      () => Stream.error(
        _httpError(
          402,
          data: {
            'code': 'quota_exceeded',
            'quota': {'used': 0, 'limit': 0},
          },
        ),
      ),
    );
    final c = await make(api);
    await evaluate(c);

    expect(st(c).errorCode, 'quota_exceeded');
    expect(st(c).quotaReason, AiQuotaRejectionReason.unsupportedForFreePlan);
    expect(divergenceContexts, ['retellReview']);
    expect(trialUsage.consumed, isEmpty);
  });

  test('其余后端错误仍为 request_failed', () async {
    final api = _ScriptApi(() => Stream.error(_httpError(503)));
    final c = await make(api);
    await evaluate(c);

    expect(st(c).errorCode, 'request_failed');
    expect(divergenceContexts, isEmpty);
  });
}
