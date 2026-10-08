/// 复述 AI 评估的页面生命周期状态。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

import '../features/auth/providers/auth_providers.dart';
import '../features/subscription/models/ai_quota_rejection.dart';
import '../features/subscription/models/premium_feature.dart';
import '../features/subscription/providers/ai_trial_usage_provider.dart';
import '../features/subscription/providers/feature_access_provider.dart';
import '../features/subscription/providers/subscription_controller.dart';
import '../models/retell_review_evaluation.dart';
import '../models/retell_review_sample.dart';
import '../services/app_logger.dart';
import '../services/retell_review_audio_preparer.dart';
import '../services/sentence_ai_api_client.dart';
import '../services/runtime_endpoint_router.dart';

const _maxReviewAudioBytes = 2 * 1024 * 1024;

/// 评估请求阶段。
enum RetellReviewEvaluationPhase { idle, loading, streaming, completed, failed }

/// 当前录音 attempt 对应的评估 UI 状态。
///
/// [errorCode] 取值：`auth_required`（未登录 / 后端 401）、`quota_exceeded`
/// （本地闸门未过 / 后端 402）、`audio_preparation_failed`、`audio_too_large`、
/// `stream_failed`、`request_failed`。文案与出路见 `retell_review_sheet.dart`。
class RetellReviewEvaluationState {
  final String? attemptKey;
  final RetellReviewEvaluationPhase phase;
  final RetellReviewEvaluation? evaluation;
  final String? errorCode;
  final AiQuotaRejectionReason quotaReason;

  const RetellReviewEvaluationState({
    this.attemptKey,
    this.phase = RetellReviewEvaluationPhase.idle,
    this.evaluation,
    this.errorCode,
    this.quotaReason = AiQuotaRejectionReason.exhausted,
  });

  bool get hasCachedResult =>
      phase == RetellReviewEvaluationPhase.completed && evaluation != null;
}

/// 评估端超出上传上限时的本地 fail-fast 异常。
class RetellReviewAudioTooLargeException implements Exception {
  const RetellReviewAudioTooLargeException();
}

/// 临时音频准备服务的注入点。
final retellReviewAudioPreparerProvider = Provider<RetellReviewAudioPreparer>(
  (_) => FfmpegRetellReviewAudioPreparer(),
);

/// 复述 AI 评估 controller。
///
/// 结果只缓存到当前录音 attempt；录音 badge 消失或换成新文件时，旧请求与旧数据
/// 必须立刻失效，避免异步回调把上一段结果写到下一段。
final retellReviewEvaluationProvider =
    NotifierProvider<
      RetellReviewEvaluationController,
      RetellReviewEvaluationState
    >(RetellReviewEvaluationController.new);

class RetellReviewEvaluationController
    extends Notifier<RetellReviewEvaluationState> {
  CancelToken? _cancelToken;
  var _generation = 0;

  @override
  RetellReviewEvaluationState build() {
    ref.onDispose(_cancelActiveRequest);
    return const RetellReviewEvaluationState();
  }

  /// 同步 badge 当前绑定的 attempt；传 null 表示 badge 生命周期已结束。
  void syncAttempt(String? attemptKey) {
    if (state.attemptKey == attemptKey) return;
    _generation += 1;
    _cancelActiveRequest();
    state = RetellReviewEvaluationState(attemptKey: attemptKey);
  }

  /// 拉取当前录音的评估。完整结果由同一 attempt 生命周期内的后续点击复用。
  Future<void> evaluate({
    required String attemptKey,
    required String recordingPath,
    required String originalText,
    required String targetLanguage,
  }) async {
    if (state.attemptKey != attemptKey) syncAttempt(attemptKey);
    if (state.hasCachedResult ||
        state.phase == RetellReviewEvaluationPhase.loading ||
        state.phase == RetellReviewEvaluationPhase.streaming) {
      return;
    }

    // 闸门与 AI 转录 / 对话同一套，且必须早于音频转码与 2MB 上传：撞墙时既不烧
    // 本地转码算力，也不占上行带宽。额度的唯一权威仍是后端 402。
    final accessToken = ref
        .read(supabaseSessionProvider)
        .valueOrNull
        ?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      AppLogger.log('RetellReview', '评估需要登录态，未取到 access token');
      _failFast(attemptKey, 'auth_required');
      return;
    }
    if (!ref.read(featureAccessProvider(PremiumFeature.aiRetellReview))) {
      AppLogger.log('RetellReview', '未解锁 AI 复述评估（非会员且试用用尽）');
      _failFast(attemptKey, 'quota_exceeded');
      return;
    }

    final generation = ++_generation;
    _cancelActiveRequest();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = RetellReviewEvaluationState(
      attemptKey: attemptKey,
      phase: RetellReviewEvaluationPhase.loading,
    );

    File? preparedFile;
    try {
      final source = File(recordingPath);
      preparedFile = await ref
          .read(retellReviewAudioPreparerProvider)
          .prepare(source);
      if (!_isCurrent(generation, attemptKey)) return;
      if (await preparedFile.length() > _maxReviewAudioBytes) {
        throw const RetellReviewAudioTooLargeException();
      }

      var receivedFinalFrame = false;
      await for (final frame
          in ref
              .read(sentenceAiApiClientProvider)
              .evaluateReviewStream(
                audioFile: preparedFile,
                originalText: originalText,
                targetLanguage: targetLanguage,
                accessToken: accessToken,
                cancelToken: cancelToken,
              )) {
        if (!_isCurrent(generation, attemptKey)) return;
        state = RetellReviewEvaluationState(
          attemptKey: attemptKey,
          phase: frame.isFinal
              ? RetellReviewEvaluationPhase.completed
              : RetellReviewEvaluationPhase.streaming,
          evaluation: frame.evaluation,
        );
        receivedFinalFrame = frame.isFinal;
      }
      if (!receivedFinalFrame && _isCurrent(generation, attemptKey)) {
        throw const RetellReviewStreamException();
      }
      _consumeTrial();
    } on RetellReviewAudioPreparationException {
      _setFailure(generation, attemptKey, 'audio_preparation_failed');
    } on RetellReviewAudioTooLargeException {
      _setFailure(generation, attemptKey, 'audio_too_large');
    } on RetellReviewStreamException {
      _setFailure(generation, attemptKey, 'stream_failed');
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return;
      switch (error.response?.statusCode) {
        case 401:
          _setFailure(generation, attemptKey, 'auth_required');
        case 402:
          // E7：后端权威裁决为「无额度」，回源对账收敛本地权益分歧。
          ref.read(entitlementQuotaDivergenceHandlerProvider)('retellReview');
          final rejection = AiQuotaRejection.fromResponseData(
            error.response?.data,
          );
          _setFailure(
            generation,
            attemptKey,
            'quota_exceeded',
            quotaReason: rejection.reason,
          );
        default:
          _setFailure(generation, attemptKey, 'request_failed');
      }
    } catch (error, stackTrace) {
      AppLogger.log(
        'RetellReview',
        '评估失败: error=$error stack=$stackTrace '
            'baseUrl=${runtimeEndpointRouter.apiBaseUrl}',
      );
      _setFailure(generation, attemptKey, 'request_failed');
    } finally {
      if (preparedFile != null) {
        try {
          if (await preparedFile.exists()) await preparedFile.delete();
        } catch (error) {
          AppLogger.log('RetellReview', '临时评估音频清理失败: $error');
        }
      }
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  /// 用调试假数据填充结果，不发请求（见 [retellReviewSampleEnabled]）。
  ///
  /// 同样走 `_generation` 自增并取消在途请求：假数据也要能盖掉上一次真实评估，
  /// 否则旧请求的回调仍会把结果写回来。
  void loadSample({required String attemptKey}) {
    assert(retellReviewSampleEnabled, 'loadSample 只在假数据模式下调用');
    _generation += 1;
    _cancelActiveRequest();
    AppLogger.log('RetellReview', '使用调试假数据: attemptKey=$attemptKey');
    state = RetellReviewEvaluationState(
      attemptKey: attemptKey,
      phase: RetellReviewEvaluationPhase.completed,
      evaluation: retellReviewSampleEvaluation(),
    );
  }

  bool _isCurrent(int generation, String attemptKey) =>
      generation == _generation && state.attemptKey == attemptKey;

  /// 闸门未过：本轮请求尚未发起，直接作废在途请求并置失败态。
  ///
  /// 与 [_setFailure] 的区别是此处还没有 generation 可校验；自增 `_generation`
  /// 保证上一轮的异步回调不会把结果写回来。
  void _failFast(String attemptKey, String errorCode) {
    _generation += 1;
    _cancelActiveRequest();
    state = RetellReviewEvaluationState(
      attemptKey: attemptKey,
      phase: RetellReviewEvaluationPhase.failed,
      errorCode: errorCode,
    );
  }

  /// 成功后消耗一次免费试用（会员不计；本地预测计数，权威在后端）。
  void _consumeTrial() {
    if (ref.read(subscriptionControllerProvider).isActive) return;
    ref
        .read(aiTrialUsageProvider.notifier)
        .consume(PremiumFeature.aiRetellReview);
  }

  void _setFailure(
    int generation,
    String attemptKey,
    String errorCode, {
    AiQuotaRejectionReason quotaReason = AiQuotaRejectionReason.exhausted,
  }) {
    if (!_isCurrent(generation, attemptKey)) return;
    state = RetellReviewEvaluationState(
      attemptKey: attemptKey,
      phase: RetellReviewEvaluationPhase.failed,
      errorCode: errorCode,
      quotaReason: quotaReason,
    );
  }

  void _cancelActiveRequest() {
    _cancelToken?.cancel('retell review attempt invalidated');
    _cancelToken = null;
  }
}
