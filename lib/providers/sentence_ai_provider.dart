/// AI 句子翻译/解析 Provider
///
/// 三级缓存查找：L1 内存 → L2 SQLite → L3 API。
/// 支持并发请求去重，避免同一句子重复发起 API 调用。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_logger.dart';

import '../database/daos/sentence_ai_cache_dao.dart';
import '../database/providers.dart';
import '../features/subscription/models/premium_feature.dart';
import '../features/subscription/providers/ai_trial_usage_provider.dart';
import '../features/subscription/providers/ai_quota_limit_provider.dart';
import '../features/subscription/providers/feature_access_provider.dart';
import '../features/subscription/providers/subscription_controller.dart';
import '../features/subscription/providers/subscription_identity.dart';
import '../models/sense_group_result.dart';
import '../models/sentence_ai_result.dart';
import '../services/sentence_ai_api_client.dart';
import '../utils/sense_group_validate.dart';
import '../utils/text_normalize.dart';

/// 请求云端 AI 功能但当前用户未登录。
class AiFeatureAuthRequiredException implements Exception {
  const AiFeatureAuthRequiredException();

  @override
  String toString() => 'AiFeatureAuthRequiredException';
}

/// 已登录但未解锁该 AI 功能（非会员且免费试用已用尽）。
///
/// 由额度闸在发起 L3 请求前抛出，UI 捕获后引导订阅升级（Paywall）。
/// 仅在缓存未命中、确需消耗后端算力时触发，已缓存结果不受影响。
class AiFeatureQuotaExceededException implements Exception {
  const AiFeatureQuotaExceededException({this.feature, this.resetAt});

  /// 被后端或本地 quota reset 阻断的功能。
  final PremiumFeature? feature;

  /// 后端返回的本轮免费额度重置时间。
  final DateTime? resetAt;

  @override
  String toString() =>
      'AiFeatureQuotaExceededException'
      '${feature != null ? '(feature=${feature!.name})' : ''}'
      '${resetAt != null ? '(resetAt=${resetAt!.toIso8601String()})' : ''}';
}

/// 单个句子解析 L3 请求的共享流。
///
/// Provider 用它把同一句、同语言的多个消费者挂到同一条后端流上。最后一个
/// 消费者取消订阅时取消底层 Dio 请求；只有生产端正常收到 final 帧时才落缓存。
class _PendingAnalysisStream {
  final _controller = StreamController<SentenceAnalysis>.broadcast();
  final cancelToken = CancelToken();

  SentenceAnalysis? _latest;
  var _listeners = 0;
  var _closed = false;

  Stream<SentenceAnalysis> subscribe() async* {
    _listeners += 1;
    final latest = _latest;
    if (latest != null) {
      yield latest;
    }
    try {
      await for (final analysis in _controller.stream) {
        yield analysis;
      }
    } finally {
      _listeners -= 1;
      if (_listeners <= 0 && !_closed && !cancelToken.isCancelled) {
        cancelToken.cancel('analysis stream has no active listeners');
      }
    }
  }

  void add(SentenceAnalysis analysis) {
    if (_closed) return;
    _latest = analysis;
    _controller.add(analysis);
  }

  Future<void> close() {
    if (_closed) return Future.value();
    _closed = true;
    return _controller.close();
  }

  Future<void> addError(Object error, StackTrace stackTrace) {
    if (_closed) return Future.value();
    _closed = true;
    _controller.addError(error, stackTrace);
    return _controller.close();
  }
}

/// 单个句子翻译 L3 请求的共享流（与 [_PendingAnalysisStream] 同构）。
///
/// 把同一句、同上下文、同语言的多个消费者挂到同一条后端流上；最后一个消费者
/// 取消订阅时取消底层 Dio 请求；只有生产端正常收到 final 帧时才落缓存。
class _PendingTranslationStream {
  final _controller = StreamController<SentenceTranslation>.broadcast();
  final cancelToken = CancelToken();

  SentenceTranslation? _latest;
  var _listeners = 0;
  var _closed = false;

  Stream<SentenceTranslation> subscribe() async* {
    _listeners += 1;
    final latest = _latest;
    if (latest != null) {
      yield latest;
    }
    try {
      await for (final translation in _controller.stream) {
        yield translation;
      }
    } finally {
      _listeners -= 1;
      if (_listeners <= 0 && !_closed && !cancelToken.isCancelled) {
        cancelToken.cancel('translation stream has no active listeners');
      }
    }
  }

  void add(SentenceTranslation translation) {
    if (_closed) return;
    _latest = translation;
    _controller.add(translation);
  }

  Future<void> close() {
    if (_closed) return Future.value();
    _closed = true;
    return _controller.close();
  }

  Future<void> addError(Object error, StackTrace stackTrace) {
    if (_closed) return Future.value();
    _closed = true;
    _controller.addError(error, stackTrace);
    return _controller.close();
  }
}

/// 单个句子意群拆分 L3 请求的共享流（与 [_PendingAnalysisStream] 同构）。
///
/// 把同一句的多个消费者挂到同一条后端流上；最后一个消费者取消订阅时取消底层 Dio 请求；
/// 只有生产端正常收到 final 帧且 concat 校验通过时才落缓存。
class _PendingSenseGroupStream {
  final _controller = StreamController<SenseGroupResult>.broadcast();
  final cancelToken = CancelToken();

  SenseGroupResult? _latest;
  var _listeners = 0;
  var _closed = false;

  Stream<SenseGroupResult> subscribe() async* {
    _listeners += 1;
    final latest = _latest;
    if (latest != null) {
      yield latest;
    }
    try {
      await for (final result in _controller.stream) {
        yield result;
      }
    } finally {
      _listeners -= 1;
      if (_listeners <= 0 && !_closed && !cancelToken.isCancelled) {
        cancelToken.cancel('sense group stream has no active listeners');
      }
    }
  }

  void add(SenseGroupResult result) {
    if (_closed) return;
    _latest = result;
    _controller.add(result);
  }

  Future<void> close() {
    if (_closed) return Future.value();
    _closed = true;
    return _controller.close();
  }

  Future<void> addError(Object error, StackTrace stackTrace) {
    if (_closed) return Future.value();
    _closed = true;
    _controller.addError(error, stackTrace);
    return _controller.close();
  }
}

/// AI 句子翻译/解析服务
///
/// 通过三级缓存（内存 → SQLite → API）获取句子的翻译和解析结果。
/// 使用 pending 请求 Map 实现并发去重。
class SentenceAiNotifier {
  final SentenceAiCacheDao _cacheDao;
  final SentenceAiApiClient _apiClient;

  /// 额度闸：发起 L3 请求前调用。已登录但未解锁（非会员且免费试用用尽）时
  /// 抛 [AiFeatureQuotaExceededException]；会员或仍有试用额度则放行。
  /// 注入而非内联订阅依赖，保持数据层与订阅状态解耦（通过 [PremiumFeature] 中性枚举）。
  final void Function(PremiumFeature feature)? _guardFeature;

  /// L3 成功后调用：消耗一次免费试用（实现内部对会员不计数）。
  final void Function(PremiumFeature feature)? _onConsumeTrial;

  /// L3 请求前调用：清理过期 reset、会员清 reset；自动加载可选择尊重本地
  /// reset 并提前阻断，用户主动点击始终进入后端裁决。
  final Future<void> Function(
    PremiumFeature feature, {
    required bool respectLocalQuotaReset,
  })?
  _beforeApiRequest;

  /// 后端返回 quota exceeded 后记录 resetAt。
  final Future<void> Function(PremiumFeature feature, DateTime resetAt)?
  _onQuotaExceeded;

  /// 后端请求成功后清除该功能 reset，说明用户当前已经恢复可用额度。
  final Future<void> Function(PremiumFeature feature)? _onApiSucceeded;

  /// L1 内存缓存
  final Map<String, SentenceTranslation> _translationCache = {};
  final Map<String, SentenceAnalysis> _analysisCache = {};
  final Map<String, SenseGroupResult> _senseGroupCache = {};

  /// 正在进行的请求（用于去重）
  final Map<String, _PendingTranslationStream> _pendingTranslations = {};
  final Map<String, _PendingAnalysisStream> _pendingAnalyses = {};
  final Map<String, _PendingSenseGroupStream> _pendingSenseGroups = {};

  SentenceAiNotifier({
    required SentenceAiCacheDao cacheDao,
    required SentenceAiApiClient apiClient,
    void Function(PremiumFeature feature)? guardFeature,
    void Function(PremiumFeature feature)? onConsumeTrial,
    Future<void> Function(
      PremiumFeature feature, {
      required bool respectLocalQuotaReset,
    })?
    beforeApiRequest,
    Future<void> Function(PremiumFeature feature, DateTime resetAt)?
    onQuotaExceeded,
    Future<void> Function(PremiumFeature feature)? onApiSucceeded,
  }) : _cacheDao = cacheDao,
       _apiClient = apiClient,
       _guardFeature = guardFeature,
       _onConsumeTrial = onConsumeTrial,
       _beforeApiRequest = beforeApiRequest,
       _onQuotaExceeded = onQuotaExceeded,
       _onApiSucceeded = onApiSucceeded;

  /// 获取翻译（流式，三级缓存查找，带前后句上下文）
  ///
  /// L1 内存 / L2 SQLite 命中：一次性 yield 完整译文后结束。
  /// 未命中走 L3 流式：`translation` 逐帧 yield 渐显（供 UI 逐词显示），**仅收到完整
  /// 末帧才**写 L1+L2 并消耗一次试用；中途取消（客户端关流）不落缓存、不计费。
  ///
  /// 只译目标句 [text]，[previous]/[next] 仅作上下文（缺失即首/末句，可为 null），
  /// 且**进入缓存键**（[translationContextHash]）：不同上下文互不串缓存。
  /// 鉴权/额度：未登录抛 [AiFeatureAuthRequiredException]；后端 402 由内部映射为
  /// [AiFeatureQuotaExceededException]。[targetLanguage] 为 BCP 47 代码。
  Stream<SentenceTranslation> getTranslationStream(
    String text, {
    required String targetLanguage,
    String? previous,
    String? next,
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    final hash = translationContextHash(text, previous: previous, next: next);
    final cacheKey = '$hash:$targetLanguage';
    final l2Type = 'translation_v2:$targetLanguage';

    // L1: 内存缓存
    final l1 = _translationCache[cacheKey];
    if (l1 != null) {
      yield l1;
      return;
    }

    // L2: SQLite 缓存（JSON 损坏/空译文时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, l2Type);
    if (dbResult != null) {
      try {
        final translation = SentenceTranslation.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (translation.translation.isNotEmpty) {
          _translationCache[cacheKey] = translation;
          yield translation;
          return;
        }
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 流式调用
      }
    }

    // L3: 流式 API 调用
    if (accessToken == null || accessToken.isEmpty) {
      AppLogger.log('SentenceAI', '翻译 L3 需要登录，未发现 Supabase access token');
      throw const AiFeatureAuthRequiredException();
    }
    await _beforeApiRequest?.call(
      PremiumFeature.aiTranslation,
      respectLocalQuotaReset: respectLocalQuotaReset,
    );
    _guardFeature?.call(PremiumFeature.aiTranslation);

    final existing = _pendingTranslations[cacheKey];
    if (existing != null) {
      yield* existing.subscribe();
      return;
    }

    final pending = _PendingTranslationStream();
    _pendingTranslations[cacheKey] = pending;
    unawaited(
      _pumpTranslationStream(
        pending,
        cacheKey: cacheKey,
        hash: hash,
        l2Type: l2Type,
        text: text,
        previous: previous,
        next: next,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
      ),
    );
    yield* pending.subscribe();
  }

  /// 生产共享翻译流，并在完整完成后写 L1/L2 缓存。
  Future<void> _pumpTranslationStream(
    _PendingTranslationStream pending, {
    required String cacheKey,
    required String hash,
    required String l2Type,
    required String text,
    required String? previous,
    required String? next,
    required String targetLanguage,
    required String accessToken,
  }) async {
    SentenceTranslation? finalTranslation;
    try {
      var attempt = 0;
      while (true) {
        attempt += 1;
        try {
          await for (final frame in _apiClient.translateStream(
            text,
            previousText: previous,
            nextText: next,
            targetLanguage: targetLanguage,
            accessToken: accessToken,
            cancelToken: pending.cancelToken,
          )) {
            pending.add(frame.translation);
            if (frame.isFinal) finalTranslation = frame.translation;
          }
          break;
        } on DioException catch (e, stackTrace) {
          if (pending.cancelToken.isCancelled) {
            await pending.close();
            return;
          }
          final quota = await _quotaExceptionFor(
            PremiumFeature.aiTranslation,
            e,
          );
          if (quota != null) {
            await pending.addError(quota, stackTrace);
            return;
          }
          if (attempt < 2) {
            AppLogger.log('SentenceAI', '翻译 L3 失败，重试一次: $e');
            continue;
          }
          await pending.addError(e, stackTrace);
          return;
        } catch (e, stackTrace) {
          if (pending.cancelToken.isCancelled) {
            await pending.close();
            return;
          }
          if (attempt < 2) {
            AppLogger.log('SentenceAI', '翻译流失败，重试一次: $e');
            continue;
          }
          await pending.addError(e, stackTrace);
          return;
        }
      }

      // 仅「完整完成」且译文非空才落缓存并计一次试用；未收到 final（取消/EOF）不写。
      if (finalTranslation != null && finalTranslation.translation.isNotEmpty) {
        _translationCache[cacheKey] = finalTranslation;
        await _cacheDao.upsert(
          hash,
          l2Type,
          jsonEncode({'translation': finalTranslation.translation}),
        );
        await _onApiSucceeded?.call(PremiumFeature.aiTranslation);
        _onConsumeTrial?.call(PremiumFeature.aiTranslation);
      }
      await pending.close();
    } catch (e, stackTrace) {
      if (pending.cancelToken.isCancelled) {
        await pending.close();
      } else {
        await pending.addError(e, stackTrace);
      }
    } finally {
      _pendingTranslations.remove(cacheKey);
    }
  }

  /// 获取解析（流式，三级缓存查找）
  ///
  /// L1 内存 / L2 SQLite 命中：一次性 yield 完整结果后结束。
  /// 未命中走 L3 流式：逐帧 yield 部分结果（供 UI 渐显），**仅收到完整末帧才**
  /// 写 L1+L2 并消耗一次试用；中途取消（客户端关流）不落缓存、不计费。
  ///
  /// 鉴权/额度：未登录抛 [AiFeatureAuthRequiredException]；后端 402 由内部映射为
  /// [AiFeatureQuotaExceededException]。[targetLanguage] 为 BCP 47 代码。
  Stream<SentenceAnalysis> getAnalysisStream(
    String text, {
    required String targetLanguage,
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';
    final l2Type = 'analysis_v2:$targetLanguage';

    // L1: 内存缓存
    final l1 = _analysisCache[cacheKey];
    if (l1 != null) {
      yield l1;
      return;
    }

    // L2: SQLite 缓存（JSON 损坏/空结果时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, l2Type);
    if (dbResult != null) {
      try {
        final analysis = SentenceAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (analysis.isNotEmpty) {
          _analysisCache[cacheKey] = analysis;
          yield analysis;
          return;
        }
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 流式调用
      }
    }

    // L3: 流式 API 调用
    if (accessToken == null || accessToken.isEmpty) {
      AppLogger.log('SentenceAI', '解析 L3 需要登录，未发现 Supabase access token');
      throw const AiFeatureAuthRequiredException();
    }
    await _beforeApiRequest?.call(
      PremiumFeature.aiAnalysis,
      respectLocalQuotaReset: respectLocalQuotaReset,
    );
    _guardFeature?.call(PremiumFeature.aiAnalysis);

    final existing = _pendingAnalyses[cacheKey];
    if (existing != null) {
      yield* existing.subscribe();
      return;
    }

    final pending = _PendingAnalysisStream();
    _pendingAnalyses[cacheKey] = pending;
    unawaited(
      _pumpAnalysisStream(
        pending,
        cacheKey: cacheKey,
        hash: hash,
        l2Type: l2Type,
        text: text,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
      ),
    );
    yield* pending.subscribe();
  }

  /// 生产共享解析流，并在完整完成后写 L1/L2 缓存。
  Future<void> _pumpAnalysisStream(
    _PendingAnalysisStream pending, {
    required String cacheKey,
    required String hash,
    required String l2Type,
    required String text,
    required String targetLanguage,
    required String accessToken,
  }) async {
    SentenceAnalysis? finalAnalysis;
    try {
      var attempt = 0;
      while (true) {
        attempt += 1;
        try {
          await for (final frame in _apiClient.analyzeStream(
            text,
            targetLanguage: targetLanguage,
            accessToken: accessToken,
            cancelToken: pending.cancelToken,
          )) {
            pending.add(frame.analysis);
            if (frame.isFinal) finalAnalysis = frame.analysis;
          }
          break;
        } on DioException catch (e, stackTrace) {
          if (pending.cancelToken.isCancelled) {
            await pending.close();
            return;
          }
          final quota = await _quotaExceptionFor(PremiumFeature.aiAnalysis, e);
          if (quota != null) {
            await pending.addError(quota, stackTrace);
            return;
          }
          if (attempt < 2) {
            AppLogger.log('SentenceAI', '解析 L3 失败，重试一次: $e');
            continue;
          }
          await pending.addError(e, stackTrace);
          return;
        } catch (e, stackTrace) {
          if (pending.cancelToken.isCancelled) {
            await pending.close();
            return;
          }
          if (attempt < 2) {
            AppLogger.log('SentenceAI', '解析流失败，重试一次: $e');
            continue;
          }
          await pending.addError(e, stackTrace);
          return;
        }
      }

      // 仅「完整完成」且解析非空才落缓存并计一次试用；空解析允许后续重试。
      if (finalAnalysis != null && finalAnalysis.isNotEmpty) {
        _analysisCache[cacheKey] = finalAnalysis;
        await _cacheDao.upsert(
          hash,
          l2Type,
          jsonEncode(finalAnalysis.toJson()),
        );
        await _onApiSucceeded?.call(PremiumFeature.aiAnalysis);
        _onConsumeTrial?.call(PremiumFeature.aiAnalysis);
      } else if (finalAnalysis != null) {
        AppLogger.log('SentenceAI', '解析最终结果为空，不落缓存（可重试）');
      }
      await pending.close();
    } catch (e, stackTrace) {
      if (pending.cancelToken.isCancelled) {
        await pending.close();
      } else {
        await pending.addError(e, stackTrace);
      }
    } finally {
      _pendingAnalyses.remove(cacheKey);
    }
  }

  /// 获取意群拆分（流式，三级缓存查找）
  ///
  /// L1 内存 / L2 SQLite 命中：一次性 yield 完整结果后结束。
  /// 未命中走 L3 流式：medium 意群逐帧渐显（fine 随后），**仅收到完整末帧且 concat 校验通过才**
  /// 写 L1+L2 并消耗一次试用；中途取消（客户端关流）或校验失败一律不落缓存、不计费。
  ///
  /// 意群与目标语言无关（chunk 是原句子串的切分），缓存 key 仅 [hashText]，无语言维度。
  /// 鉴权/额度：未登录抛 [AiFeatureAuthRequiredException]；后端 402 由内部映射为
  /// [AiFeatureQuotaExceededException]。
  Stream<SenseGroupResult> getSenseGroupsStream(
    String text, {
    String? accessToken,
    CancelToken? cancelToken,
    bool respectLocalQuotaReset = false,
  }) async* {
    final hash = hashText(text);

    // L1: 内存缓存（空结果不视为有效缓存）
    final l1 = _senseGroupCache[hash];
    if (l1 != null && l1.medium.isNotEmpty) {
      yield l1;
      return;
    }
    if (l1 != null) {
      _senseGroupCache.remove(hash);
    }

    // L2: SQLite 缓存（JSON 损坏/空结果时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, 'sense_groups');
    if (dbResult != null) {
      try {
        final result = SenseGroupResult.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (result.medium.isNotEmpty) {
          _senseGroupCache[hash] = result;
          yield result;
          return;
        }
        // 空结果视为旧格式缓存，删除并 fallthrough 到 L3
        await _cacheDao.deleteByHash(hash, 'sense_groups');
      } catch (_) {
        // L2 数据损坏或结构变更，删除后继续到 L3 流式调用
        await _cacheDao.deleteByHash(hash, 'sense_groups');
      }
    }

    // L3: 流式 API 调用
    if (accessToken == null || accessToken.isEmpty) {
      AppLogger.log('SenseGroup', 'L3 需要登录，未发现 Supabase access token');
      throw const AiFeatureAuthRequiredException();
    }
    await _beforeApiRequest?.call(
      PremiumFeature.aiSenseGroup,
      respectLocalQuotaReset: respectLocalQuotaReset,
    );
    _guardFeature?.call(PremiumFeature.aiSenseGroup);

    final existing = _pendingSenseGroups[hash];
    if (existing != null) {
      yield* existing.subscribe();
      return;
    }

    final pending = _PendingSenseGroupStream();
    _pendingSenseGroups[hash] = pending;
    unawaited(
      _pumpSenseGroupStream(
        pending,
        hash: hash,
        text: text,
        accessToken: accessToken,
      ),
    );
    yield* pending.subscribe();
  }

  /// 生产共享意群流，并在完整完成且 concat 校验通过后写 L1/L2 缓存。
  Future<void> _pumpSenseGroupStream(
    _PendingSenseGroupStream pending, {
    required String hash,
    required String text,
    required String accessToken,
  }) async {
    SenseGroupResult? finalResult;
    try {
      var attempt = 0;
      while (true) {
        attempt += 1;
        try {
          await for (final frame in _apiClient.senseGroupsStream(
            text,
            accessToken: accessToken,
            cancelToken: pending.cancelToken,
          )) {
            pending.add(frame.result);
            if (frame.isFinal) finalResult = frame.result;
          }
          break;
        } on DioException catch (e, stackTrace) {
          if (pending.cancelToken.isCancelled) {
            await pending.close();
            return;
          }
          final quota = await _quotaExceptionFor(
            PremiumFeature.aiSenseGroup,
            e,
          );
          if (quota != null) {
            await pending.addError(quota, stackTrace);
            return;
          }
          if (attempt < 2) {
            AppLogger.log('SenseGroup', '意群 L3 失败，重试一次: $e');
            continue;
          }
          await pending.addError(e, stackTrace);
          return;
        } catch (e, stackTrace) {
          if (pending.cancelToken.isCancelled) {
            await pending.close();
            return;
          }
          if (attempt < 2) {
            AppLogger.log('SenseGroup', '意群流失败，重试一次: $e');
            continue;
          }
          await pending.addError(e, stackTrace);
          return;
        }
      }

      // 仅「完整完成」且 medium 非空、concat 校验通过（两级粒度拼接均能还原原句）才落缓存并计一次试用。
      // 校验失败/空/未收到 final（取消/EOF）一律不写——允许重试重生成，镜像后端 onComplete「不合法不入库」。
      if (finalResult != null &&
          finalResult.medium.isNotEmpty &&
          validateSenseGroupChunks(finalResult.medium, text) &&
          validateSenseGroupChunks(finalResult.fine, text)) {
        _senseGroupCache[hash] = finalResult;
        await _cacheDao.upsert(
          hash,
          'sense_groups',
          jsonEncode(finalResult.toJson()),
        );
        await _onApiSucceeded?.call(PremiumFeature.aiSenseGroup);
        _onConsumeTrial?.call(PremiumFeature.aiSenseGroup);
      } else if (finalResult != null) {
        AppLogger.log('SenseGroup', '最终结果空或 concat 校验失败，不落缓存（可重试）');
      }
      await pending.close();
    } catch (e, stackTrace) {
      if (pending.cancelToken.isCancelled) {
        await pending.close();
      } else {
        await pending.addError(e, stackTrace);
      }
    } finally {
      _pendingSenseGroups.remove(hash);
    }
  }

  /// 同步查找 L1 翻译缓存（仅内存）
  ///
  /// [previous]/[next] 为前后句上下文（进缓存键）；[targetLanguage] 不传时遍历所有
  /// 语言版本（向后兼容），传入时精确匹配。
  SentenceTranslation? getCachedTranslation(
    String text, {
    String? previous,
    String? next,
    String? targetLanguage,
  }) {
    final hash = translationContextHash(text, previous: previous, next: next);
    if (targetLanguage != null) {
      return _translationCache['$hash:$targetLanguage'];
    }
    // 向后兼容：遍历查找任意语言版本
    for (final entry in _translationCache.entries) {
      if (entry.key.startsWith('$hash:')) return entry.value;
    }
    return null;
  }

  /// 同步查找 L1 解析缓存（仅内存）
  ///
  /// [targetLanguage] 不传时遍历所有语言版本（向后兼容），传入时精确匹配。
  SentenceAnalysis? getCachedAnalysis(String text, {String? targetLanguage}) {
    final hash = hashText(text);
    if (targetLanguage != null) {
      return _analysisCache['$hash:$targetLanguage'];
    }
    for (final entry in _analysisCache.entries) {
      if (entry.key.startsWith('$hash:')) return entry.value;
    }
    return null;
  }

  /// 同步查找 L1 意群缓存（仅内存）
  SenseGroupResult? getCachedSenseGroups(String text) {
    return _senseGroupCache[hashText(text)];
  }

  /// 从 L2 SQLite 预加载翻译到 L1 内存（不调用 L3 API）
  ///
  /// [previous]/[next] 为前后句上下文（进缓存键）。返回 true 表示 L1 或 L2 命中。
  Future<bool> preloadTranslationFromDb(
    String text, {
    required String targetLanguage,
    String? previous,
    String? next,
  }) async {
    final hash = translationContextHash(text, previous: previous, next: next);
    final cacheKey = '$hash:$targetLanguage';
    if (_translationCache.containsKey(cacheKey)) return true;
    final dbResult = await _cacheDao.getByHash(
      hash,
      'translation_v2:$targetLanguage',
    );
    if (dbResult != null) {
      try {
        final translation = SentenceTranslation.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (translation.translation.isEmpty) return false;
        _translationCache[cacheKey] = translation;
        return true;
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 从 L2 SQLite 预加载解析到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadAnalysisFromDb(
    String text, {
    required String targetLanguage,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';
    if (_analysisCache.containsKey(cacheKey)) return true;
    final dbResult = await _cacheDao.getByHash(
      hash,
      'analysis_v2:$targetLanguage',
    );
    if (dbResult != null) {
      try {
        final analysis = SentenceAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (analysis.isNotEmpty) {
          _analysisCache[cacheKey] = analysis;
          return true;
        }
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 从 L2 SQLite 预加载意群到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadSenseGroupsFromDb(String text) async {
    final hash = hashText(text);
    if (_senseGroupCache.containsKey(hash)) return true;
    final dbResult = await _cacheDao.getByHash(hash, 'sense_groups');
    if (dbResult != null) {
      try {
        final result = SenseGroupResult.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (result.medium.isNotEmpty) {
          _senseGroupCache[hash] = result;
          return true;
        }
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 清除内存缓存
  void clearMemoryCache() {
    _translationCache.clear();
    _analysisCache.clear();
    _senseGroupCache.clear();
  }

  Future<AiFeatureQuotaExceededException?> _quotaExceptionFor(
    PremiumFeature feature,
    DioException error,
  ) async {
    if (error.response?.statusCode != 402) return null;
    final data = error.response?.data;
    if (data is Map && data['code'] != 'quota_exceeded') return null;
    final resetAt = _quotaResetAtFrom(data);
    if (resetAt != null) {
      await _onQuotaExceeded?.call(feature, resetAt);
    }
    return AiFeatureQuotaExceededException(feature: feature, resetAt: resetAt);
  }

  DateTime? _quotaResetAtFrom(Object? data) {
    if (data is! Map) return null;
    final quota = data['quota'];
    if (quota is! Map) return null;
    final rawResetAt = quota['resetAt'];
    if (rawResetAt is! String || rawResetAt.isEmpty) return null;
    return DateTime.tryParse(rawResetAt)?.toUtc();
  }
}

/// SentenceAiNotifier Provider
final sentenceAiNotifierProvider = Provider<SentenceAiNotifier>((ref) {
  ref.watch(aiQuotaLimitCleanupProvider);
  return SentenceAiNotifier(
    cacheDao: ref.watch(sentenceAiCacheDaoProvider),
    apiClient: ref.watch(sentenceAiApiClientProvider),
    // 额度闸：已登录前提下未解锁（非会员且试用用尽）→ 抛配额超限。
    guardFeature: (feature) {
      if (!ref.read(featureAccessProvider(feature))) {
        throw const AiFeatureQuotaExceededException();
      }
    },
    // 消耗一次免费试用；会员无限不计数。
    onConsumeTrial: (feature) {
      if (ref.read(subscriptionControllerProvider).isActive) return;
      ref.read(aiTrialUsageProvider.notifier).consume(feature);
    },
    beforeApiRequest: (feature, {required respectLocalQuotaReset}) async {
      final userId = ref.read(subscriptionIdentityProvider).userId;
      if (userId == null) return;
      final store = ref.read(aiQuotaLimitStoreProvider);
      if (ref.read(subscriptionControllerProvider).isActive) {
        await store.clearAllResets(userId);
        return;
      }
      await store.clearExpiredResets(userId);
      if (!respectLocalQuotaReset) return;
      final resetAt = store.activeResetAt(userId, feature);
      if (resetAt != null) {
        throw AiFeatureQuotaExceededException(
          feature: feature,
          resetAt: resetAt,
        );
      }
    },
    onQuotaExceeded: (feature, resetAt) async {
      final userId = ref.read(subscriptionIdentityProvider).userId;
      if (userId == null) return;
      await ref
          .read(aiQuotaLimitStoreProvider)
          .recordResetAt(userId, feature, resetAt);
    },
    onApiSucceeded: (feature) async {
      final userId = ref.read(subscriptionIdentityProvider).userId;
      if (userId == null) return;
      await ref.read(aiQuotaLimitStoreProvider).clearReset(userId, feature);
    },
  );
});
