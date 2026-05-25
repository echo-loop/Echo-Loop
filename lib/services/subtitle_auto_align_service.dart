/// AI 字幕自动校准服务。
///
/// 根据本地音频的静音区间微调句子边界。
/// 当原生解码不可用或任意阶段失败时，只记录日志并回退到原始字幕。
///
/// 算法对齐 fluency-frontend 的 auto-align-subtitle.ts（commit 24c8c21），
/// 实现两级校准 + 三重后置保护，宗旨是「校准不能让情况变得更差」。
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/word_timestamp.dart';
import '../utils/srt_generator.dart';
import 'app_logger.dart';
import 'native_audio_decoder.dart';

/// 静音区间。
class SilenceInterval {
  final double startTime;
  final double endTime;

  const SilenceInterval({required this.startTime, required this.endTime});
}

/// 静音检测配置。
class SilenceDetectionConfig {
  /// 动态阈值上限（单位 dB）。
  ///
  /// 实际阈值 = `min(noiseFloor + 10dB, thresholdDb)`，
  /// 其中 `noiseFloor` 是当前候选区间帧级 dBFS 分布下半的中位数。
  final double thresholdDb;

  /// 分帧窗口长度（毫秒）。
  final int analysisWindowMs;

  /// 识别为静音的最小持续时间（毫秒），小于此值的静音段会被合并进语音。
  final int minSilenceMs;

  /// 语音内部允许被填平的噪声突发长度（毫秒）。
  final int noiseBurstMs;

  const SilenceDetectionConfig({
    required this.thresholdDb,
    required this.analysisWindowMs,
    required this.minSilenceMs,
    required this.noiseBurstMs,
  });
}

/// 自动校准配置。
class AutoAlignConfig extends SilenceDetectionConfig {
  /// 检测到静音时边界相对静音端点向内留出的 padding（毫秒）。
  final int paddingMs;

  /// 第二级兜底时单侧位移上限（毫秒）。
  final int boundaryNudgeMs;

  /// 第一级静音校准的位移硬帽（毫秒），防止过度偏离原始边界。
  final int maxBoundaryShiftMs;

  /// 相邻句之间保留的最小间隙（毫秒）。
  final int minBoundaryGapMs;

  const AutoAlignConfig({
    required super.thresholdDb,
    required super.analysisWindowMs,
    required super.minSilenceMs,
    required super.noiseBurstMs,
    required this.paddingMs,
    required this.boundaryNudgeMs,
    required this.maxBoundaryShiftMs,
    required this.minBoundaryGapMs,
  });
}

/// 句子边界更新。
class SentenceBoundaryUpdate {
  final int sentenceIndex;
  final double startTime;
  final double endTime;

  const SentenceBoundaryUpdate({
    required this.sentenceIndex,
    required this.startTime,
    required this.endTime,
  });
}

/// 静音检测策略。
abstract class SilenceDetectionStrategy {
  SilenceInterval? detectLongestSilence(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  );

  List<SilenceInterval> detectSilenceIntervals(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  );
}

/// 自动校准默认配置。
///
/// 默认值来自 fluency-frontend DEFAULT_AUTO_ALIGN_CONFIG。
const defaultAutoAlignConfig = AutoAlignConfig(
  thresholdDb: -35,
  analysisWindowMs: 20,
  minSilenceMs: 25,
  noiseBurstMs: 25,
  paddingMs: 100,
  boundaryNudgeMs: 150,
  maxBoundaryShiftMs: 500,
  minBoundaryGapMs: 50,
);

const _epsilon = 1e-6;
const _logTag = 'SubtitleAutoAlign';

class _FrameRange {
  final int startFrame;
  final int endFrame;
  final bool isSilent;

  const _FrameRange({
    required this.startFrame,
    required this.endFrame,
    required this.isSilent,
  });
}

String _fmtSec(double seconds) => seconds.toStringAsFixed(3);

String _describeSilence(SilenceInterval? silence) {
  if (silence == null) return 'none';
  return '[${_fmtSec(silence.startTime)}s, ${_fmtSec(silence.endTime)}s]';
}

String _describeSentence(int index, TranscriptSentence sentence) {
  final start = _fmtSec(sentence.startTime.inMilliseconds / 1000);
  final end = _fmtSec(sentence.endTime.inMilliseconds / 1000);
  return '#$index [$start-$end] "${sentence.text}"'
      ' words=${sentence.startWordIndex}-${sentence.endWordIndex}';
}

String _describeBoundaryUpdate(SentenceBoundaryUpdate update) {
  return '#${update.sentenceIndex}'
      ' [${_fmtSec(update.startTime)}-${_fmtSec(update.endTime)}]';
}

double _clampDouble(double value, double min, double max) {
  return math.min(math.max(value, min), max);
}

int _clampInt(int value, int min, int max) {
  return math.min(math.max(value, min), max);
}

double _midpoint(double start, double end) => start + (end - start) / 2;

double _frameDurationSec(SilenceDetectionConfig config) =>
    config.analysisWindowMs / 1000;

double _rangeDurationSec(_FrameRange range, double frameSec) =>
    (range.endFrame - range.startFrame) * frameSec;

double _toDbfs(double rms) {
  if (rms <= 0) {
    return double.negativeInfinity;
  }
  return 20 * math.log(rms) / math.ln10;
}

double _median(List<double> sortedValues) {
  if (sortedValues.isEmpty) {
    return double.negativeInfinity;
  }
  final mid = sortedValues.length ~/ 2;
  if (sortedValues.length.isOdd) {
    return sortedValues[mid];
  }
  return (sortedValues[mid - 1] + sortedValues[mid]) / 2;
}

List<_FrameRange> _buildRanges(List<bool> flags) {
  if (flags.isEmpty) {
    return const [];
  }

  final ranges = <_FrameRange>[];
  var startFrame = 0;
  var current = flags[0];

  for (var i = 1; i < flags.length; i++) {
    if (flags[i] == current) {
      continue;
    }
    ranges.add(
      _FrameRange(startFrame: startFrame, endFrame: i, isSilent: current),
    );
    startFrame = i;
    current = flags[i];
  }

  ranges.add(
    _FrameRange(
      startFrame: startFrame,
      endFrame: flags.length,
      isSilent: current,
    ),
  );
  return ranges;
}

List<bool> _normalizeFlags(List<bool> flags, SilenceDetectionConfig config) {
  if (flags.isEmpty) {
    return flags;
  }

  final normalized = List<bool>.from(flags);
  final frameSec = _frameDurationSec(config);
  final minSilenceSec = config.minSilenceMs / 1000;
  final noiseBurstSec = config.noiseBurstMs / 1000;

  for (final range in _buildRanges(normalized)) {
    if (range.isSilent &&
        _rangeDurationSec(range, frameSec) + _epsilon < minSilenceSec) {
      normalized.fillRange(range.startFrame, range.endFrame, false);
    }
  }

  for (final range in _buildRanges(normalized)) {
    if (!range.isSilent &&
        _rangeDurationSec(range, frameSec) + _epsilon < noiseBurstSec) {
      final prev = range.startFrame > 0
          ? normalized[range.startFrame - 1]
          : null;
      final next = range.endFrame < normalized.length
          ? normalized[range.endFrame]
          : null;
      if (prev == true && next == true) {
        normalized.fillRange(range.startFrame, range.endFrame, true);
      }
    }
  }

  for (final range in _buildRanges(normalized)) {
    if (range.isSilent &&
        _rangeDurationSec(range, frameSec) + _epsilon < minSilenceSec) {
      normalized.fillRange(range.startFrame, range.endFrame, false);
    }
  }

  return normalized;
}

SilenceInterval? _pickLongestCenteredSilence(
  List<SilenceInterval> ranges,
  double candidateStart,
  double candidateEnd,
) {
  final center = _midpoint(candidateStart, candidateEnd);
  SilenceInterval? best;
  var bestDuration = -1.0;
  var bestCenterDistance = double.infinity;

  for (final range in ranges) {
    final startTime = math.max(candidateStart, range.startTime);
    final endTime = math.min(candidateEnd, range.endTime);
    final duration = endTime - startTime;
    if (duration <= 0) {
      continue;
    }

    final distance = (_midpoint(startTime, endTime) - center).abs();
    if (duration > bestDuration + _epsilon ||
        ((duration - bestDuration).abs() <= _epsilon &&
            distance < bestCenterDistance - _epsilon)) {
      best = SilenceInterval(startTime: startTime, endTime: endTime);
      bestDuration = duration;
      bestCenterDistance = distance;
    }
  }

  return best;
}

List<SilenceInterval> _toSilenceIntervals(
  List<_FrameRange> ranges,
  double candidateStart,
  double candidateEnd,
  double frameSec,
) {
  return ranges
      .where((range) => range.isSilent)
      .map((range) {
        return SilenceInterval(
          startTime: candidateStart + range.startFrame * frameSec,
          endTime: math.min(
            candidateEnd,
            candidateStart + range.endFrame * frameSec,
          ),
        );
      })
      .where((range) => range.endTime - range.startTime > _epsilon)
      .toList();
}

SilenceInterval? _findContainingSilence(
  List<SilenceInterval> ranges,
  double time,
) {
  for (final range in ranges) {
    if (range.startTime - _epsilon <= time &&
        time <= range.endTime + _epsilon) {
      return range;
    }
  }
  return null;
}

SilenceInterval _expandCandidateInterval(
  List<SilenceInterval> ranges,
  double candidateStart,
  double candidateEnd,
) {
  final startRange = _findContainingSilence(ranges, candidateStart);
  final endRange = _findContainingSilence(ranges, candidateEnd);

  return SilenceInterval(
    startTime: startRange == null
        ? candidateStart
        : math.min(startRange.startTime, candidateStart),
    endTime: endRange == null
        ? candidateEnd
        : math.max(endRange.endTime, candidateEnd),
  );
}

/// 动态阈值静音检测。
///
/// 每次调用都会基于当前候选区间内的帧级 dBFS 分布估算噪声底，
/// 实际判静阈值 = `min(noiseFloor + 10dB, config.thresholdDb)`，
/// 其中 `config.thresholdDb` 是绝对上限。
class FixedThresholdSilenceStrategy implements SilenceDetectionStrategy {
  const FixedThresholdSilenceStrategy();

  /// 逐帧计算 dBFS 值（不做判静），供上层决定阈值。
  List<double> _collectFrameDbfs(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  ) {
    if (candidateEnd - candidateStart <= _epsilon) {
      return const [];
    }

    final frameSec = _frameDurationSec(config);
    final totalFrames = math.max(
      1,
      ((candidateEnd - candidateStart) / frameSec).ceil(),
    );
    final sampleRate = audioData.sampleRate;
    final samples = audioData.samples;
    final frameDbfs = List<double>.filled(totalFrames, double.negativeInfinity);

    for (var frame = 0; frame < totalFrames; frame++) {
      final frameStartTime = candidateStart + frame * frameSec;
      final frameEndTime = math.min(candidateEnd, frameStartTime + frameSec);
      final startSample = _clampInt(
        (frameStartTime * sampleRate).floor(),
        0,
        samples.length,
      );
      final endSample = _clampInt(
        (frameEndTime * sampleRate).ceil(),
        startSample + 1,
        samples.length,
      );

      var sumSquares = 0.0;
      for (var sample = startSample; sample < endSample; sample++) {
        final mixed = samples[sample];
        sumSquares += mixed * mixed;
      }

      final count = math.max(1, endSample - startSample);
      final rms = math.sqrt(sumSquares / count);
      frameDbfs[frame] = _toDbfs(rms);
    }

    return frameDbfs;
  }

  /// 基于帧级 dBFS 分布的下半中位数估算噪声底，并以 capDb 兜底。
  double _computeDynamicThresholdDb(List<double> frameDbfs, double capDb) {
    if (frameDbfs.isEmpty) {
      return capDb;
    }

    final sorted = [...frameDbfs]..sort();
    final lowestHalfCount = math.max(1, (sorted.length / 2).ceil());
    final noiseFloor = _median(sorted.sublist(0, lowestHalfCount));
    return math.min(noiseFloor + 10, capDb);
  }

  @override
  List<SilenceInterval> detectSilenceIntervals(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  ) {
    if (candidateEnd - candidateStart <= _epsilon) {
      return const [];
    }

    final frameSec = _frameDurationSec(config);
    final frameDbfs = _collectFrameDbfs(
      audioData,
      candidateStart,
      candidateEnd,
      config,
    );
    final thresholdDb = _computeDynamicThresholdDb(
      frameDbfs,
      config.thresholdDb,
    );
    final silentFrames = [for (final db in frameDbfs) db <= thresholdDb];

    final normalized = _normalizeFlags(silentFrames, config);
    return _toSilenceIntervals(
      _buildRanges(normalized),
      candidateStart,
      candidateEnd,
      frameSec,
    );
  }

  @override
  SilenceInterval? detectLongestSilence(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  ) {
    return _pickLongestCenteredSilence(
      detectSilenceIntervals(audioData, candidateStart, candidateEnd, config),
      candidateStart,
      candidateEnd,
    );
  }
}

// ---- 第一级：静音 + padding + 位移帽 ---------------------------------------

/// 把静音区间换算为带 padding 的边界时间。
double _toPaddedBoundary(
  SilenceInterval silence,
  bool isStartEdge,
  AutoAlignConfig config,
) {
  final paddingSec = config.paddingMs / 1000;
  return isStartEdge
      ? silence.endTime - paddingSec
      : silence.startTime + paddingSec;
}

/// 用 `maxBoundaryShiftMs` 钳制建议位移，防止第一级偏离原始边界过大。
double _truncateBoundaryShift(
  double proposedValue,
  double originalValue,
  AutoAlignConfig config,
) {
  final maxShiftSec = config.maxBoundaryShiftMs / 1000;
  final delta = proposedValue - originalValue;
  if (delta.abs() <= maxShiftSec + _epsilon) {
    return proposedValue;
  }
  return originalValue + (delta.isNegative ? -maxShiftSec : maxShiftSec);
}

bool _hasMeaningfulShift(double next, double original) {
  return (next - original).abs() > _epsilon;
}

bool _hasEnoughGap(double endTime, double startTime, AutoAlignConfig config) {
  return startTime - endTime + _epsilon >= config.minBoundaryGapMs / 1000;
}

// ---- 第二级：150ms 对称兜底 ------------------------------------------------

class _GapFallback {
  final double endTime;
  final double startTime;

  const _GapFallback({required this.endTime, required this.startTime});
}

/// 无静音或第一级不完全生效时，以原始边界为起点在 slack 内对称微调。
///
/// 宗旨：至多把 end 向后移 / start 向前移 `boundaryNudgeMs`，
/// 且分配后的间隙不得小于 `minBoundaryGapMs`。如果原端点已落在静音内，
/// 则该侧保持原值（避免把边界推出静音）。
_GapFallback? _applyGapFallbackAdjustment(
  double currentEndTime,
  double nextStartTime,
  List<SilenceInterval> silenceRanges,
  AutoAlignConfig config,
) {
  final minGapSec = config.minBoundaryGapMs / 1000;
  final maxNudgeSec = config.boundaryNudgeMs / 1000;
  final gap = nextStartTime - currentEndTime;
  if (gap + _epsilon < minGapSec) {
    return null;
  }

  final canMoveEnd =
      _findContainingSilence(silenceRanges, currentEndTime) == null;
  final canMoveStart =
      _findContainingSilence(silenceRanges, nextStartTime) == null;
  if (!canMoveEnd && !canMoveStart) {
    return null;
  }

  var remainingSlack = math.max(0.0, gap - minGapSec);
  var endShift = 0.0;
  var startShift = 0.0;

  if (canMoveEnd && canMoveStart) {
    final sharedShift = math.min(maxNudgeSec, remainingSlack / 2);
    endShift = sharedShift;
    startShift = sharedShift;
    remainingSlack -= sharedShift * 2;

    final endExtra = math.min(maxNudgeSec - endShift, remainingSlack);
    endShift += endExtra;
    remainingSlack -= endExtra;

    final startExtra = math.min(maxNudgeSec - startShift, remainingSlack);
    startShift += startExtra;
  } else if (canMoveEnd) {
    endShift = math.min(maxNudgeSec, remainingSlack);
  } else if (canMoveStart) {
    startShift = math.min(maxNudgeSec, remainingSlack);
  }

  final endTime = currentEndTime + endShift;
  final startTime = nextStartTime - startShift;
  if (startTime - endTime + _epsilon < minGapSec) {
    return _GapFallback(endTime: currentEndTime, startTime: nextStartTime);
  }

  return _GapFallback(endTime: endTime, startTime: startTime);
}

// ---- 合法性门禁与原值回退 ---------------------------------------------------

double _safeTime(double? value, double fallback, double duration) {
  if (value == null || !value.isFinite) {
    return _clampDouble(fallback, 0, duration);
  }
  return _clampDouble(value, 0, duration);
}

SentenceBoundaryUpdate _safeOriginalBoundary(
  TranscriptSentence sentence,
  List<WordTimestamp> words,
  double duration,
  int sentenceIndex,
) {
  final startWordIndex = sentence.startWordIndex;
  final endWordIndex = sentence.endWordIndex;
  final firstWord =
      (startWordIndex != null &&
          startWordIndex >= 0 &&
          startWordIndex < words.length)
      ? words[startWordIndex]
      : null;
  final lastWord =
      (endWordIndex != null && endWordIndex >= 0 && endWordIndex < words.length)
      ? words[endWordIndex]
      : null;
  final wordStart = firstWord == null
      ? null
      : _clampDouble(firstWord.startTime.inMilliseconds / 1000, 0, duration);
  final wordEnd = lastWord == null
      ? null
      : _clampDouble(lastWord.endTime.inMilliseconds / 1000, 0, duration);

  var startTime = _safeTime(
    sentence.startTime.inMilliseconds / 1000,
    wordStart ?? 0,
    duration,
  );
  var endTime = _safeTime(
    sentence.endTime.inMilliseconds / 1000,
    wordEnd ?? startTime,
    duration,
  );

  if (startTime > endTime + _epsilon) {
    if (wordStart != null &&
        wordEnd != null &&
        wordStart <= wordEnd + _epsilon) {
      startTime = wordStart;
      endTime = wordEnd;
    } else {
      endTime = startTime;
    }
  }

  return SentenceBoundaryUpdate(
    sentenceIndex: sentenceIndex,
    startTime: startTime,
    endTime: endTime,
  );
}

bool _hasValidBoundaryWords(
  TranscriptSentence sentence,
  List<WordTimestamp> words,
) {
  final startWordIndex = sentence.startWordIndex;
  final endWordIndex = sentence.endWordIndex;
  if (startWordIndex == null ||
      endWordIndex == null ||
      startWordIndex < 0 ||
      endWordIndex < startWordIndex ||
      endWordIndex >= words.length) {
    return false;
  }
  final firstWord = words[startWordIndex];
  final lastWord = words[endWordIndex];
  // 对齐 TS 的 isFiniteNumber 四字段检查：Duration 天然有限，实际检查非负。
  return firstWord.startTime.inMilliseconds >= 0 &&
      firstWord.endTime.inMilliseconds >= 0 &&
      lastWord.startTime.inMilliseconds >= 0 &&
      lastWord.endTime.inMilliseconds >= 0;
}

SentenceBoundaryUpdate _restoreOriginal(SentenceBoundaryUpdate original) {
  return SentenceBoundaryUpdate(
    sentenceIndex: original.sentenceIndex,
    startTime: original.startTime,
    endTime: original.endTime,
  );
}

// ---- 主算法 ----------------------------------------------------------------

/// 计算句子边界的校准更新（纯函数，便于测试直接注入 Mock Strategy）。
List<SentenceBoundaryUpdate> computeAutoAlignedSentenceBoundaries({
  required List<TranscriptSentence> sentences,
  required List<WordTimestamp> words,
  required DecodedAudioData audioData,
  SilenceDetectionStrategy strategy = const FixedThresholdSilenceStrategy(),
  AutoAlignConfig config = defaultAutoAlignConfig,
}) {
  if (sentences.isEmpty) {
    return const [];
  }

  final duration = audioData.samples.length / audioData.sampleRate;
  final originals = <SentenceBoundaryUpdate>[
    for (var i = 0; i < sentences.length; i++)
      _safeOriginalBoundary(sentences[i], words, duration, i),
  ];
  final nextBoundaries = <SentenceBoundaryUpdate>[
    for (final original in originals) _restoreOriginal(original),
  ];

  AppLogger.log(
    _logTag,
    'auto-align begin: sentences=${sentences.length} duration=${_fmtSec(duration)}s',
  );

  // ① 首句起点
  {
    final first = sentences[0];
    final firstPairSilenceRanges = strategy.detectSilenceIntervals(
      audioData,
      0,
      originals[0].startTime,
      config,
    );
    final firstCandidate = _expandCandidateInterval(
      firstPairSilenceRanges,
      0,
      originals[0].startTime,
    );
    if (_hasValidBoundaryWords(first, words)) {
      final startSilence = strategy.detectLongestSilence(
        audioData,
        firstCandidate.startTime,
        firstCandidate.endTime,
        config,
      );
      AppLogger.log(
        _logTag,
        'first-start candidate=${_describeSilence(firstCandidate)} chosen=${_describeSilence(startSilence)}',
      );
      if (startSilence != null) {
        final proposed = _toPaddedBoundary(startSilence, true, config);
        final nextStart = _truncateBoundaryShift(
          proposed,
          originals[0].startTime,
          config,
        );
        nextBoundaries[0] = SentenceBoundaryUpdate(
          sentenceIndex: 0,
          startTime: nextStart,
          endTime: nextBoundaries[0].endTime,
        );
      }
    }
  }

  // ② 相邻句对
  for (var i = 0; i < sentences.length - 1; i++) {
    if (!_hasValidBoundaryWords(sentences[i], words) ||
        !_hasValidBoundaryWords(sentences[i + 1], words)) {
      AppLogger.log(_logTag, 'pair-skip-invalid left=$i right=${i + 1}');
      continue;
    }

    final originalEndTime = originals[i].endTime;
    final originalStartTime = originals[i + 1].startTime;

    final pairSilenceRanges = strategy.detectSilenceIntervals(
      audioData,
      originalEndTime,
      originalStartTime,
      config,
    );
    final candidate = _expandCandidateInterval(
      pairSilenceRanges,
      originalEndTime,
      originalStartTime,
    );
    final silence = strategy.detectLongestSilence(
      audioData,
      candidate.startTime,
      candidate.endTime,
      config,
    );

    var appliedSilenceEnd = false;
    var appliedSilenceStart = false;

    if (silence != null) {
      final nextEndTime = _truncateBoundaryShift(
        _toPaddedBoundary(silence, false, config),
        originalEndTime,
        config,
      );
      final nextStartTime = _truncateBoundaryShift(
        _toPaddedBoundary(silence, true, config),
        originalStartTime,
        config,
      );
      nextBoundaries[i] = SentenceBoundaryUpdate(
        sentenceIndex: i,
        startTime: nextBoundaries[i].startTime,
        endTime: nextEndTime,
      );
      nextBoundaries[i + 1] = SentenceBoundaryUpdate(
        sentenceIndex: i + 1,
        startTime: nextStartTime,
        endTime: nextBoundaries[i + 1].endTime,
      );
      appliedSilenceEnd = _hasMeaningfulShift(nextEndTime, originalEndTime);
      appliedSilenceStart = _hasMeaningfulShift(
        nextStartTime,
        originalStartTime,
      );

      AppLogger.log(
        _logTag,
        'pair-silence left=$i right=${i + 1}'
        ' candidate=${_describeSilence(candidate)}'
        ' silence=${_describeSilence(silence)}'
        ' nextEnd=${_fmtSec(nextEndTime)} nextStart=${_fmtSec(nextStartTime)}'
        ' appliedEnd=$appliedSilenceEnd appliedStart=$appliedSilenceStart',
      );

      if (appliedSilenceEnd &&
          appliedSilenceStart &&
          _hasEnoughGap(nextEndTime, nextStartTime, config)) {
        continue;
      }

      if (!_hasEnoughGap(nextEndTime, nextStartTime, config)) {
        nextBoundaries[i] = SentenceBoundaryUpdate(
          sentenceIndex: i,
          startTime: nextBoundaries[i].startTime,
          endTime: originalEndTime,
        );
        nextBoundaries[i + 1] = SentenceBoundaryUpdate(
          sentenceIndex: i + 1,
          startTime: originalStartTime,
          endTime: nextBoundaries[i + 1].endTime,
        );
        appliedSilenceEnd = false;
        appliedSilenceStart = false;
        AppLogger.log(
          _logTag,
          'pair-silence-gap-rejected left=$i right=${i + 1}'
          ' minGapMs=${config.minBoundaryGapMs}',
        );
      }
    }

    final fallback = _applyGapFallbackAdjustment(
      originalEndTime,
      originalStartTime,
      pairSilenceRanges,
      config,
    );
    if (fallback == null) {
      AppLogger.log(
        _logTag,
        'pair-no-fallback left=$i right=${i + 1}'
        ' silence=${_describeSilence(silence)}',
      );
      continue;
    }

    if (!appliedSilenceEnd) {
      nextBoundaries[i] = SentenceBoundaryUpdate(
        sentenceIndex: i,
        startTime: nextBoundaries[i].startTime,
        endTime: fallback.endTime,
      );
    }
    if (!appliedSilenceStart) {
      nextBoundaries[i + 1] = SentenceBoundaryUpdate(
        sentenceIndex: i + 1,
        startTime: fallback.startTime,
        endTime: nextBoundaries[i + 1].endTime,
      );
    }

    AppLogger.log(
      _logTag,
      'pair-fallback left=$i right=${i + 1}'
      ' fallbackEnd=${_fmtSec(fallback.endTime)} fallbackStart=${_fmtSec(fallback.startTime)}'
      ' finalEnd=${_fmtSec(nextBoundaries[i].endTime)}'
      ' finalStart=${_fmtSec(nextBoundaries[i + 1].startTime)}',
    );
  }

  // ③ 末句终点
  {
    final lastIndex = sentences.length - 1;
    final last = sentences[lastIndex];
    final lastPairSilenceRanges = strategy.detectSilenceIntervals(
      audioData,
      originals[lastIndex].endTime,
      duration,
      config,
    );
    final lastCandidate = _expandCandidateInterval(
      lastPairSilenceRanges,
      originals[lastIndex].endTime,
      duration,
    );
    if (_hasValidBoundaryWords(last, words)) {
      final endSilence = strategy.detectLongestSilence(
        audioData,
        lastCandidate.startTime,
        lastCandidate.endTime,
        config,
      );
      AppLogger.log(
        _logTag,
        'last-end candidate=${_describeSilence(lastCandidate)} chosen=${_describeSilence(endSilence)}',
      );
      if (endSilence != null) {
        final proposed = _toPaddedBoundary(endSilence, false, config);
        final nextEnd = _truncateBoundaryShift(
          proposed,
          originals[lastIndex].endTime,
          config,
        );
        nextBoundaries[lastIndex] = SentenceBoundaryUpdate(
          sentenceIndex: lastIndex,
          startTime: nextBoundaries[lastIndex].startTime,
          endTime: nextEnd,
        );
      }
    }
  }

  // ④ 后置 R1: 时长合法性
  for (var i = 0; i < nextBoundaries.length; i++) {
    final boundary = nextBoundaries[i];
    var startTime = _clampDouble(boundary.startTime, 0, duration);
    var endTime = _clampDouble(boundary.endTime, 0, duration);
    if (startTime > endTime + _epsilon) {
      startTime = originals[i].startTime;
      endTime = originals[i].endTime;
    }
    nextBoundaries[i] = SentenceBoundaryUpdate(
      sentenceIndex: boundary.sentenceIndex,
      startTime: startTime,
      endTime: endTime,
    );
  }

  // ⑤ 后置 R2: 词边界保护
  for (var i = 0; i < nextBoundaries.length; i++) {
    final boundary = nextBoundaries[i];
    final sentence = sentences[i];
    final startWordIndex = sentence.startWordIndex;
    final endWordIndex = sentence.endWordIndex;
    if (startWordIndex == null ||
        endWordIndex == null ||
        startWordIndex < 0 ||
        endWordIndex < startWordIndex ||
        endWordIndex >= words.length) {
      continue;
    }
    final firstWord = words[startWordIndex];
    final lastWord = words[endWordIndex];
    var startTime = boundary.startTime;
    var endTime = boundary.endTime;
    if (startTime > firstWord.endTime.inMilliseconds / 1000 + _epsilon) {
      startTime = originals[i].startTime;
    }
    if (endTime + _epsilon < lastWord.startTime.inMilliseconds / 1000) {
      endTime = originals[i].endTime;
    }
    if (startTime > endTime + _epsilon) {
      startTime = originals[i].startTime;
      endTime = originals[i].endTime;
    }
    nextBoundaries[i] = SentenceBoundaryUpdate(
      sentenceIndex: boundary.sentenceIndex,
      startTime: startTime,
      endTime: endTime,
    );
  }

  // ⑥ 后置 R3: 最小间隙终检（重叠 / 间隙不足 → 两侧都回原值）
  final minBoundaryGapSec = config.minBoundaryGapMs / 1000;
  for (var i = 0; i < nextBoundaries.length - 1; i++) {
    final current = nextBoundaries[i];
    final next = nextBoundaries[i + 1];
    if (next.startTime - current.endTime + _epsilon >= minBoundaryGapSec) {
      continue;
    }
    nextBoundaries[i] = _restoreOriginal(originals[i]);
    nextBoundaries[i + 1] = _restoreOriginal(originals[i + 1]);
  }

  // NaN / Infinity / start>end 最终扫描
  for (var i = 0; i < nextBoundaries.length; i++) {
    final boundary = nextBoundaries[i];
    if (!boundary.startTime.isFinite ||
        !boundary.endTime.isFinite ||
        boundary.startTime > boundary.endTime + _epsilon) {
      nextBoundaries[i] = _restoreOriginal(originals[i]);
    }
  }

  return nextBoundaries;
}

/// 自动校准服务。
class SubtitleAutoAlignService {
  final NativeAudioDecoder _decoder;
  final Duration Function(Duration estimatedAudioDuration) _timeoutForDuration;

  SubtitleAutoAlignService({
    required NativeAudioDecoder decoder,
    Duration Function(Duration estimatedAudioDuration)? timeoutForDuration,
  }) : _decoder = decoder,
       _timeoutForDuration =
           timeoutForDuration ??
           SubtitleAutoAlignService.defaultTimeoutForAudio;

  static Duration defaultTimeoutForAudio(Duration estimatedAudioDuration) {
    final seconds = estimatedAudioDuration.inMilliseconds / 1000;
    final timeoutSeconds = math.min(20.0, math.max(3.0, 3.0 + seconds * 0.08));
    return Duration(milliseconds: (timeoutSeconds * 1000).round());
  }

  /// 尝试使用本地音频静音区间校准句子边界。
  ///
  /// 任意阶段失败都只记录日志并返回原始 [sentences]。
  Future<List<TranscriptSentence>> alignIfPossible({
    required String audioPath,
    required List<TranscriptSentence> sentences,
    required List<WordTimestamp> words,
  }) async {
    AppLogger.log(
      _logTag,
      'start auto-align: audioPath=$audioPath sentences=${sentences.length} words=${words.length}',
    );
    if (sentences.isEmpty || words.isEmpty) {
      AppLogger.log(
        _logTag,
        'skip auto-align: empty transcript sentences=${sentences.length} words=${words.length}',
      );
      return sentences;
    }
    if (!_decoder.isSupported) {
      AppLogger.log(
        _logTag,
        'skip auto-align: native decode unsupported on current platform',
      );
      return sentences;
    }
    if (!_hasUsableWordBoundaries(sentences, words.length)) {
      AppLogger.log(
        _logTag,
        'skip auto-align: transcript is missing usable word boundaries',
      );
      return sentences;
    }

    final estimatedAudioDuration = _estimateAudioDuration(sentences, words);
    final timeout = _timeoutForDuration(estimatedAudioDuration);
    AppLogger.log(
      _logTag,
      'auto-align timeout budget: estimatedAudio=${estimatedAudioDuration.inMilliseconds}ms timeout=${timeout.inMilliseconds}ms',
    );

    for (var i = 0; i < sentences.length; i++) {
      AppLogger.log(
        _logTag,
        'input sentence ${_describeSentence(i, sentences[i])}',
      );
    }

    try {
      return await _runAutoAlign(
        audioPath: audioPath,
        sentences: sentences,
        words: words,
      ).timeout(
        timeout,
        onTimeout: () {
          AppLogger.log(
            _logTag,
            'skip auto-align: timed out after ${timeout.inMilliseconds}ms',
          );
          return sentences;
        },
      );
    } catch (error) {
      AppLogger.log(
        _logTag,
        'skip auto-align: native decode or alignment failed ($error)',
      );
      return sentences;
    }
  }

  Future<List<TranscriptSentence>> _runAutoAlign({
    required String audioPath,
    required List<TranscriptSentence> sentences,
    required List<WordTimestamp> words,
  }) async {
    AppLogger.log(_logTag, 'decode start: $audioPath');
    final decoded = await _decoder.decode(audioPath);
    if (decoded == null || decoded.samples.isEmpty || decoded.sampleRate <= 0) {
      AppLogger.log(
        _logTag,
        'skip auto-align: native decoder returned no samples',
      );
      return sentences;
    }
    final durationSec = decoded.samples.length / decoded.sampleRate;
    AppLogger.log(
      _logTag,
      'decode success: sampleRate=${decoded.sampleRate} samples=${decoded.samples.length} duration=${_fmtSec(durationSec)}s',
    );

    final updates = computeAutoAlignedSentenceBoundaries(
      sentences: sentences,
      words: words,
      audioData: decoded,
    );
    if (updates.isEmpty) {
      AppLogger.log(_logTag, 'no boundary updates generated');
      return sentences;
    }
    for (final update in updates) {
      AppLogger.log(
        _logTag,
        'computed boundary ${_describeBoundaryUpdate(update)}',
      );
    }
    final aligned = _applyUpdates(sentences, updates);
    for (var i = 0; i < aligned.length; i++) {
      final before = sentences[i];
      final after = aligned[i];
      AppLogger.log(
        _logTag,
        'apply sentence #$i: ${_fmtSec(before.startTime.inMilliseconds / 1000)}-${_fmtSec(before.endTime.inMilliseconds / 1000)}'
        ' -> ${_fmtSec(after.startTime.inMilliseconds / 1000)}-${_fmtSec(after.endTime.inMilliseconds / 1000)}',
      );
    }
    AppLogger.log(_logTag, 'auto-align done: updated=${updates.length}');
    return aligned;
  }

  Duration _estimateAudioDuration(
    List<TranscriptSentence> sentences,
    List<WordTimestamp> words,
  ) {
    var maxMs = 0;
    for (final sentence in sentences) {
      if (sentence.endTime.inMilliseconds > maxMs) {
        maxMs = sentence.endTime.inMilliseconds;
      }
    }
    for (final word in words) {
      if (word.endTime.inMilliseconds > maxMs) {
        maxMs = word.endTime.inMilliseconds;
      }
    }
    return Duration(milliseconds: math.max(1000, maxMs));
  }

  bool _hasUsableWordBoundaries(
    List<TranscriptSentence> sentences,
    int wordsLength,
  ) {
    for (final sentence in sentences) {
      final startWordIndex = sentence.startWordIndex;
      final endWordIndex = sentence.endWordIndex;
      if (startWordIndex == null ||
          endWordIndex == null ||
          startWordIndex < 0 ||
          endWordIndex < startWordIndex ||
          endWordIndex >= wordsLength) {
        return false;
      }
    }
    return true;
  }

  List<TranscriptSentence> _applyUpdates(
    List<TranscriptSentence> sentences,
    List<SentenceBoundaryUpdate> updates,
  ) {
    final updateByIndex = {
      for (final update in updates) update.sentenceIndex: update,
    };
    return [
      for (var i = 0; i < sentences.length; i++)
        if (updateByIndex.containsKey(i))
          TranscriptSentence(
            text: sentences[i].text,
            startTime: Duration(
              milliseconds: (updateByIndex[i]!.startTime * 1000).round(),
            ),
            endTime: Duration(
              milliseconds: (updateByIndex[i]!.endTime * 1000).round(),
            ),
            startWordIndex: sentences[i].startWordIndex,
            endWordIndex: sentences[i].endWordIndex,
          )
        else
          sentences[i],
    ];
  }
}

/// 自动校准服务 Provider。
final subtitleAutoAlignServiceProvider = Provider<SubtitleAutoAlignService>(
  (ref) =>
      SubtitleAutoAlignService(decoder: ref.read(nativeAudioDecoderProvider)),
);
