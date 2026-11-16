import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../utils/srt_generator.dart';

/// 剪辑流程中可向用户解释的失败原因；界面按枚举映射本地化文案。
enum MediaTrimFailure {
  sourceMissing,
  transcriptNotReady,
  transcriptInvalid,
  transcriptOutOfRange,
  durationUnreadable,
  clipTooShort,
  clipOutOfRange,
  clipSplitsSentence,
  noClips,
  invalidCollection,
  collectionNameEmpty,
  encodeFailed,
  outputInvalid,
  playbackFailed,
  cancelled,
  unexpected,
}

class MediaTrimException implements Exception {
  const MediaTrimException(this.failure, [this.cause]);

  final MediaTrimFailure failure;

  /// 底层原因，仅用于日志诊断，不直接展示给用户。
  final Object? cause;

  @override
  String toString() =>
      'MediaTrimException(${failure.name}${cause == null ? '' : ': $cause'})';
}

/// 片段边界的一端。
enum MediaTrimEdge { start, end }

/// 一个待导出的片段，时间均为原媒体坐标。
class MediaTrimClip {
  const MediaTrimClip({
    required this.id,
    required this.start,
    required this.end,
    this.customName,
  });

  /// 仅在本次编辑期内稳定，用于选中态和列表 key；不会写入数据库。
  final int id;
  final Duration start;
  final Duration end;

  /// 用户重命名后的名称；为 null 时按排序位置生成默认名。
  final String? customName;

  Duration get duration => end - start;

  bool hasSameRange(MediaTrimClip other) =>
      start == other.start && end == other.end;

  bool containsTime(Duration time) => time >= start && time < end;

  MediaTrimClip copyWith({
    Duration? start,
    Duration? end,
    String? customName,
    bool clearCustomName = false,
  }) => MediaTrimClip(
    id: id,
    start: start ?? this.start,
    end: end ?? this.end,
    customName: clearCustomName ? null : (customName ?? this.customName),
  );

  /// 片段内完整包含的句子，按原顺序返回。
  List<Sentence> sentencesWithin(List<Sentence> sentences) => [
    for (final sentence in sentences)
      if (sentence.startTime >= start && sentence.endTime <= end) sentence,
  ];

  /// 新材料的字幕：只整体平移，不做校准或缩放。
  String shiftedSubtitle(List<Sentence> sentences) => generateSrtContent([
    for (final sentence in sentencesWithin(sentences))
      TranscriptSentence(
        text: sentence.text,
        startTime: sentence.startTime - start,
        endTime: sentence.endTime - start,
      ),
  ]);

  /// 新材料的词级时间戳：只保留完整落在片段内的词并整体平移。
  List<WordTimestamp> shiftedWords(List<WordTimestamp> words) => [
    for (final word in words)
      if (word.startTime >= start && word.endTime <= end)
        word.copyWith(
          startTime: word.startTime - start,
          endTime: word.endTime - start,
        ),
  ];
}

/// 时间重叠的字幕合并成的不可拆分单元。
class MediaTrimSentenceSpan {
  const MediaTrimSentenceSpan({required this.start, required this.end});

  final Duration start;
  final Duration end;
}

/// 片段边界规则：有字幕时只能落在句间空隙，无字幕时可任意定位。
///
/// 有字幕时，片段起止会向句间空隙外扩 [sentencePadding]，但不越过空隙中点，
/// 用来吸收字幕时间戳的少量误差，避免切掉首尾音节；相邻片段因此恰好衔接。
class MediaTrimBoundaries {
  MediaTrimBoundaries({required this.total, required List<Sentence> sentences})
    : sentences = List.unmodifiable(sentences),
      spans = List.unmodifiable(_mergeSpans(sentences));

  static const Duration sentencePadding = Duration(milliseconds: 300);
  static const Duration minClipDuration = Duration(milliseconds: 300);

  /// 无字幕时，新片段默认长度。
  static const Duration defaultFreeClipDuration = Duration(seconds: 30);

  /// 无字幕时，微调按钮的步长。
  static const Duration freeStep = Duration(milliseconds: 100);

  final Duration total;
  final List<Sentence> sentences;
  final List<MediaTrimSentenceSpan> spans;

  bool get hasSentences => spans.isNotEmpty;

  static List<MediaTrimSentenceSpan> _mergeSpans(List<Sentence> sentences) {
    final ordered = [...sentences]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final result = <MediaTrimSentenceSpan>[];
    for (final sentence in ordered) {
      final last = result.isEmpty ? null : result.last;
      if (last != null && sentence.startTime < last.end) {
        result[result.length - 1] = MediaTrimSentenceSpan(
          start: last.start,
          end: sentence.endTime > last.end ? sentence.endTime : last.end,
        );
      } else {
        result.add(
          MediaTrimSentenceSpan(
            start: sentence.startTime,
            end: sentence.endTime,
          ),
        );
      }
    }
    return result;
  }

  /// 以第 [span] 个单元开头时的片段起点。
  Duration startAt(int span) {
    final current = spans[span].start;
    final floor = span == 0
        ? Duration.zero
        : _midpoint(spans[span - 1].end, current);
    final padded = current - sentencePadding;
    return padded < floor ? floor : padded;
  }

  /// 以第 [span] 个单元结尾时的片段终点。
  Duration endAt(int span) {
    final current = spans[span].end;
    final ceiling = span == spans.length - 1
        ? total
        : _midpoint(current, spans[span + 1].start);
    final padded = current + sentencePadding;
    return padded > ceiling ? ceiling : padded;
  }

  static Duration _midpoint(Duration a, Duration b) =>
      Duration(microseconds: (a.inMicroseconds + b.inMicroseconds) ~/ 2);

  /// 包含某句的单元下标。
  int spanOfSentence(int sentenceIndex) {
    final sentence = sentences[sentenceIndex];
    return spans.indexWhere(
      (span) =>
          sentence.startTime >= span.start && sentence.endTime <= span.end,
    );
  }

  /// [time] 所在单元；处于空隙时返回其后的单元，越过最后一句时返回最后一个。
  int spanAtOrAfter(Duration time) {
    final index = spans.indexWhere((span) => span.end > time);
    return index < 0 ? spans.length - 1 : index;
  }

  /// 片段起点所在的单元（起点之后的第一个单元）。
  int firstSpanOf(MediaTrimClip clip) {
    final index = spans.indexWhere((span) => span.start >= clip.start);
    return index < 0 ? spans.length - 1 : index;
  }

  /// 片段终点所在的单元（终点之前的最后一个单元）。
  int lastSpanOf(MediaTrimClip clip) {
    final index = spans.lastIndexWhere((span) => span.end <= clip.end);
    return index < 0 ? 0 : index;
  }

  /// 由连续单元构成的片段范围。
  (Duration, Duration) rangeForSpans(int first, int last) =>
      (startAt(first), endAt(last));

  /// 拖动或输入时间后吸附到合法边界。无字幕时只钳制到媒体范围。
  Duration snap(MediaTrimEdge edge, Duration time) {
    final clamped = _clamp(time);
    if (!hasSentences) return _roundToMillisecond(clamped);
    var best = Duration.zero;
    var bestDistance = -1;
    for (var i = 0; i < spans.length; i++) {
      final candidate = edge == MediaTrimEdge.start ? startAt(i) : endAt(i);
      final distance = (candidate - clamped).inMicroseconds.abs();
      if (bestDistance < 0 || distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// 微调一端：有字幕时移动一整句，无字幕时移动 [freeStep]。
  Duration step(MediaTrimClip clip, MediaTrimEdge edge, int direction) {
    if (!hasSentences) {
      final current = edge == MediaTrimEdge.start ? clip.start : clip.end;
      return _roundToMillisecond(_clamp(current + freeStep * direction));
    }
    if (edge == MediaTrimEdge.start) {
      final next = (firstSpanOf(clip) + direction).clamp(0, spans.length - 1);
      return startAt(next);
    }
    final next = (lastSpanOf(clip) + direction).clamp(0, spans.length - 1);
    return endAt(next);
  }

  /// 在 [position] 处新建片段的默认范围。
  (Duration, Duration) defaultRangeAt(Duration position) {
    if (hasSentences) {
      final span = spanAtOrAfter(position);
      return rangeForSpans(span, span);
    }
    var start = _roundToMillisecond(_clamp(position));
    var end = start + defaultFreeClipDuration;
    if (end > total) end = total;
    if (end - start < minClipDuration) {
      start = total - defaultFreeClipDuration;
      if (start < Duration.zero) start = Duration.zero;
      end = total;
    }
    return (start, end);
  }

  /// 把一端移到 [time]，另一端保持不动。
  ///
  /// 一端不能越过另一端：越界时停在最短合法长度处（有字幕时收缩为片段内首 / 末
  /// 一个单元，无字幕时为 [minClipDuration]），与系统相册裁剪把手的行为一致，
  /// 避免拖过头时整段片段跳到别处。
  (Duration, Duration) moveEdge(
    MediaTrimClip clip,
    MediaTrimEdge edge,
    Duration time,
  ) {
    final target = snap(edge, time);
    if (edge == MediaTrimEdge.start) {
      if (clip.end - target >= minClipDuration) return (target, clip.end);
      if (!hasSentences) return (clip.end - minClipDuration, clip.end);
      final start = startAt(lastSpanOf(clip));
      return start >= clip.start && clip.end - start >= minClipDuration
          ? (start, clip.end)
          : (clip.start, clip.end);
    }
    if (target - clip.start >= minClipDuration) return (clip.start, target);
    if (!hasSentences) return (clip.start, clip.start + minClipDuration);
    final end = endAt(firstSpanOf(clip));
    return end <= clip.end && end - clip.start >= minClipDuration
        ? (clip.start, end)
        : (clip.start, clip.end);
  }

  MediaTrimFailure? validate(MediaTrimClip clip) {
    if (clip.start < Duration.zero || clip.end > total) {
      return MediaTrimFailure.clipOutOfRange;
    }
    if (clip.duration < minClipDuration) return MediaTrimFailure.clipTooShort;
    for (final sentence in sentences) {
      bool inside(Duration time) =>
          time > sentence.startTime && time < sentence.endTime;
      if (inside(clip.start) || inside(clip.end)) {
        return MediaTrimFailure.clipSplitsSentence;
      }
    }
    return null;
  }

  /// 按目标时长把整段切成多段。
  ///
  /// 有字幕时按整句累积，段长不超过目标（单句超长除外）；无字幕时等分。
  /// 末段不足目标三成时并入前一段，避免产生零碎短片段。
  List<(Duration, Duration)> autoSplit(Duration target) {
    if (target <= Duration.zero) {
      throw ArgumentError.value(target, 'target', '目标时长必须为正');
    }
    if (!hasSentences) {
      var count = (total.inMicroseconds / target.inMicroseconds).ceil();
      final remainder = total - target * (count - 1);
      if (count > 1 && remainder < target * 0.3) count--;
      if (count < 1) count = 1;
      final length = total.inMicroseconds / count;
      return [
        for (var i = 0; i < count; i++)
          (
            Duration(microseconds: (length * i).round()),
            i == count - 1
                ? total
                : Duration(microseconds: (length * (i + 1)).round()),
          ),
      ];
    }
    final groups = <(int, int)>[];
    var first = 0;
    for (var i = 1; i < spans.length; i++) {
      if (endAt(i) - startAt(first) > target) {
        groups.add((first, i - 1));
        first = i;
      }
    }
    groups.add((first, spans.length - 1));
    if (groups.length > 1) {
      final last = groups.removeLast();
      if (endAt(last.$2) - startAt(last.$1) < target * 0.3) {
        final previous = groups.removeLast();
        groups.add((previous.$1, last.$2));
      } else {
        groups.add(last);
      }
    }
    return [for (final group in groups) rangeForSpans(group.$1, group.$2)];
  }

  Duration _clamp(Duration time) {
    if (time < Duration.zero) return Duration.zero;
    if (time > total) return total;
    return time;
  }

  static Duration _roundToMillisecond(Duration time) =>
      Duration(milliseconds: (time.inMicroseconds / 1000).round());
}
