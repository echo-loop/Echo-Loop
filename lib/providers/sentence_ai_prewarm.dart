/// 句子讲解 AI 内容预热。
///
/// 用户开启自动展示 AI 翻译/解析/意群时，卡片出现才请求会让用户等待流式结果。
/// 预热在当前卡片展示期间，按顺序为后续卡片发起同样的请求：结果由
/// [SentenceAiNotifier] 写入 L1 内存与 L2 SQLite，用户切到该卡片时直接命中缓存；
/// 仍在请求中的同句会复用同一条后端流，不会重复计费。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/ai_prewarm_config.dart';
import '../models/sentence.dart';
import '../services/app_logger.dart';
import '../utils/text_normalize.dart';
import 'audio_sentences_provider.dart';
import 'sentence_ai_provider.dart';

/// 一张待预热的讲解卡片。
///
/// 字段必须与该卡片展示时传给讲解视图的参数一致：翻译缓存键包含按
/// [audioItemId] + [sentenceIndex] 取出的前后句上下文，不一致会导致缓存未命中。
@immutable
class SentenceAiPrewarmTarget {
  const SentenceAiPrewarmTarget({
    required this.text,
    this.audioItemId,
    this.sentenceIndex,
  });

  final String text;
  final String? audioItemId;
  final int? sentenceIndex;

  @override
  bool operator ==(Object other) =>
      other is SentenceAiPrewarmTarget &&
      other.text == text &&
      other.audioItemId == audioItemId &&
      other.sentenceIndex == sentenceIndex;

  @override
  int get hashCode => Object.hash(text, audioItemId, sentenceIndex);
}

/// 取 [position] 之后最多 [kAiPrewarmAheadCount] 句作为预热目标。
///
/// 适用于讲解视图 `sentenceIndex` 取 [Sentence.index] 的分页页面。
List<SentenceAiPrewarmTarget> upcomingSentencePrewarmTargets({
  required List<Sentence> sentences,
  required int position,
  required String? audioItemId,
}) {
  if (position < 0) return const [];
  return sentences
      .skip(position + 1)
      .take(kAiPrewarmAheadCount)
      .map(
        (sentence) => SentenceAiPrewarmTarget(
          text: sentence.text,
          audioItemId: audioItemId,
          sentenceIndex: sentence.index,
        ),
      )
      .toList(growable: false);
}

/// 需要预热的 AI 功能，与讲解视图的自动展示设置一一对应。
@immutable
class SentenceAiPrewarmFeatures {
  const SentenceAiPrewarmFeatures({
    required this.translation,
    required this.analysis,
    required this.senseGroups,
  });

  final bool translation;
  final bool analysis;
  final bool senseGroups;

  bool get isEmpty => !translation && !analysis && !senseGroups;

  SentenceAiPrewarmFeatures copyWith({
    bool? translation,
    bool? analysis,
    bool? senseGroups,
  }) => SentenceAiPrewarmFeatures(
    translation: translation ?? this.translation,
    analysis: analysis ?? this.analysis,
    senseGroups: senseGroups ?? this.senseGroups,
  );

  @override
  String toString() =>
      'translation=$translation analysis=$analysis senseGroups=$senseGroups';
}

/// 单个功能的预热结果。
enum _PrewarmOutcome { completed, skipped, quotaExceeded, authRequired, failed }

/// 按顺序预热讲解卡片的 AI 内容。
///
/// 新一轮开始后，旧一轮若仍在等待其当前卡片，则不再发起后续卡片的请求；
/// 已发出的请求不取消，保证结果写入缓存。
class SentenceAiPrewarmer {
  SentenceAiPrewarmer({
    required SentenceAiNotifier ai,
    required Future<List<Sentence>> Function(String audioItemId) loadSentences,
  }) : _ai = ai,
       _loadSentences = loadSentences;

  final SentenceAiNotifier _ai;
  final Future<List<Sentence>> Function(String audioItemId) _loadSentences;
  int _generation = 0;

  /// 预热 [targets]：先完成首张（当前卡片），再并行预热其余后续卡片；同一卡片内各功能并行请求。
  ///
  /// 调用方应把当前卡片放在首位：它与卡片自身的自动请求共享同一条流，
  /// 等它完成再请求后续卡片，避免预热抢占当前卡片的响应速度。后续卡片并行
  /// 而非逐张串行，是因为解析流式耗时可达数秒，串行会让第二张后续卡片在
  /// 用户连续切卡时来不及就绪。
  /// 当前卡片某功能额度用尽时，后续卡片跳过该功能；未登录则结束本轮。
  /// [source] 仅用于日志，标识发起预热的页面。
  Future<void> prewarm(
    List<SentenceAiPrewarmTarget> targets, {
    required SentenceAiPrewarmFeatures features,
    required String targetLanguage,
    required String accessToken,
    required String source,
  }) async {
    if (targets.isEmpty) return;
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();
    AppLogger.log(
      _tag,
      'gen=$generation 开始 source=$source '
      'sentences=${targets.map((t) => t.sentenceIndex).join(',')} '
      '$features',
    );
    final enabled = await _prewarmTarget(
      targets.first,
      generation: generation,
      role: 'current',
      features: features,
      targetLanguage: targetLanguage,
      accessToken: accessToken,
    );
    final upcoming = targets.skip(1).toList(growable: false);
    final String reason;
    var done = 1;
    if (upcoming.isEmpty) {
      reason = 'completed';
    } else if (generation != _generation) {
      reason = 'superseded(by gen=$_generation)';
    } else if (enabled.isEmpty) {
      reason = 'featuresDisabled';
    } else {
      await Future.wait([
        for (var i = 0; i < upcoming.length; i++)
          _prewarmTarget(
            upcoming[i],
            generation: generation,
            role: 'upcoming${i + 1}',
            features: enabled,
            targetLanguage: targetLanguage,
            accessToken: accessToken,
          ),
      ]);
      done += upcoming.length;
      reason = 'completed';
    }
    AppLogger.log(
      _tag,
      'gen=$generation 结束 reason=$reason done=$done/${targets.length} '
      'elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  Future<SentenceAiPrewarmFeatures> _prewarmTarget(
    SentenceAiPrewarmTarget target, {
    required int generation,
    required String role,
    required SentenceAiPrewarmFeatures features,
    required String targetLanguage,
    required String accessToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final logPrefix = 'gen=$generation sentence=${target.sentenceIndex}';
    // 预热前内存中已有结果的功能记为 cached，便于区分「本次请求」与「早已就绪」。
    final analysisCached =
        _ai.getCachedAnalysis(target.text, targetLanguage: targetLanguage) !=
        null;
    final senseGroupsCached = _ai.getCachedSenseGroups(target.text) != null;
    const skipped = _PrewarmOutcome.skipped;
    final outcomes = await Future.wait([
      features.translation
          ? _prewarmTranslation(
              target,
              logPrefix: logPrefix,
              targetLanguage: targetLanguage,
              accessToken: accessToken,
            )
          : Future.value('skipped'),
      features.analysis
          ? _drain(
              'analysis',
              logPrefix,
              _ai.getAnalysisStream(
                target.text,
                targetLanguage: targetLanguage,
                accessToken: accessToken,
                respectLocalQuotaReset: true,
              ),
            ).then((outcome) => _label(outcome, wasCached: analysisCached))
          : Future.value(skipped.name),
      features.senseGroups
          ? _drain(
              'senseGroups',
              logPrefix,
              _ai.getSenseGroupsStream(
                target.text,
                accessToken: accessToken,
                respectLocalQuotaReset: true,
              ),
            ).then((outcome) => _label(outcome, wasCached: senseGroupsCached))
          : Future.value(skipped.name),
    ]);
    // role=current 为当前卡片（与卡片自身请求共享），upcomingN 为提前预热的后续卡片。
    AppLogger.log(
      _tag,
      '$logPrefix 卡片完成 role=$role '
      'textKey=${aiCacheLogKey(hashText(target.text))} '
      'translation=${outcomes[0]} analysis=${outcomes[1]} '
      'senseGroups=${outcomes[2]} '
      'elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    if (outcomes.contains(_PrewarmOutcome.authRequired.name)) {
      return const SentenceAiPrewarmFeatures(
        translation: false,
        analysis: false,
        senseGroups: false,
      );
    }
    final quotaExceeded = _PrewarmOutcome.quotaExceeded.name;
    return features.copyWith(
      translation: features.translation && outcomes[0] != quotaExceeded,
      analysis: features.analysis && outcomes[1] != quotaExceeded,
      senseGroups: features.senseGroups && outcomes[2] != quotaExceeded,
    );
  }

  /// 翻译缓存键含前后句，需先按讲解视图同样的规则取上下文再请求；返回结果标签。
  Future<String> _prewarmTranslation(
    SentenceAiPrewarmTarget target, {
    required String logPrefix,
    required String targetLanguage,
    required String accessToken,
  }) async {
    final audioItemId = target.audioItemId;
    final sentenceIndex = target.sentenceIndex;
    String? previous;
    String? next;
    if (audioItemId != null &&
        audioItemId.isNotEmpty &&
        sentenceIndex != null) {
      final List<Sentence> sentences;
      try {
        sentences = await _loadSentences(audioItemId);
      } catch (error) {
        // 字幕读取失败无法得到与卡片一致的缓存键，跳过本句翻译预热。
        AppLogger.log(
          _tag,
          '$logPrefix 预热失败 feature=translation 字幕读取失败 error=$error',
        );
        return _PrewarmOutcome.failed.name;
      }
      String? at(int i) =>
          (i >= 0 && i < sentences.length) ? sentences[i].text : null;
      previous = at(sentenceIndex - 1);
      next = at(sentenceIndex + 1);
    }
    final cached =
        _ai.getCachedTranslation(
          target.text,
          previous: previous,
          next: next,
          targetLanguage: targetLanguage,
        ) !=
        null;
    // 与 SentenceAI 日志及「进入卡片缓存状态」的 translationKey 同口径，
    // 可核对卡片展示时读取的是否为同一缓存键。
    AppLogger.log(
      _tag,
      '$logPrefix 翻译上下文 key=${aiCacheLogKey(translationContextHash(target.text, previous: previous, next: next))} '
      'hasPrevious=${previous != null} hasNext=${next != null}',
    );
    final outcome = await _drain(
      'translation',
      logPrefix,
      _ai.getTranslationStream(
        target.text,
        previous: previous,
        next: next,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
        respectLocalQuotaReset: true,
      ),
    );
    return _label(outcome, wasCached: cached);
  }

  /// 消费整条流，使结果落入缓存；预热是尽力而为的后台边界，失败只记录不外抛。
  Future<_PrewarmOutcome> _drain(
    String feature,
    String logPrefix,
    Stream<Object> stream,
  ) async {
    try {
      await stream.drain<void>();
      return _PrewarmOutcome.completed;
    } on AiFeatureQuotaExceededException catch (error) {
      AppLogger.log(
        _tag,
        '$logPrefix 额度不足，本轮跳过该功能 feature=$feature '
        'reason=${error.reason.name}',
      );
      return _PrewarmOutcome.quotaExceeded;
    } on AiFeatureAuthRequiredException {
      AppLogger.log(_tag, '$logPrefix 登录失效，停止本轮预热 feature=$feature');
      return _PrewarmOutcome.authRequired;
    } catch (error) {
      // 网络/服务端/解析错误：不影响后续卡片，卡片展示时会按原流程重新请求并展示错误态。
      AppLogger.log(_tag, '$logPrefix 预热失败 feature=$feature error=$error');
      return _PrewarmOutcome.failed;
    }
  }
}

const _tag = 'SentenceAiPrewarm';

/// 结果标签：预热前已在内存缓存中的功能记为 cached。
String _label(_PrewarmOutcome outcome, {required bool wasCached}) =>
    outcome == _PrewarmOutcome.completed && wasCached ? 'cached' : outcome.name;

/// 全局共享一个预热器，保证同一时刻只有一轮预热在调度。
final sentenceAiPrewarmerProvider = Provider<SentenceAiPrewarmer>((ref) {
  return SentenceAiPrewarmer(
    ai: ref.watch(sentenceAiNotifierProvider),
    // 字幕投影是 autoDispose：预热的卡片可能来自当前页面未监听的音频
    // （如收藏复习跨音频），读取期间临时持有订阅，避免加载中被释放。
    loadSentences: (audioItemId) async {
      final subscription = ref.listen(
        audioSentencesProvider(audioItemId).future,
        (_, _) {},
      );
      try {
        return await subscription.read();
      } finally {
        subscription.close();
      }
    },
  );
});
