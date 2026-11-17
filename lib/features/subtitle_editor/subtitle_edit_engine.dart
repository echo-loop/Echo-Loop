import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';

/// 句子可拖动的边界端。
enum BoundaryEdge {
  /// 起始边界。
  start,

  /// 结束边界。
  end,
}

/// 波形上一条可绘制 / 可拖动的单词边界。
///
/// 句子的起止边界即首词起点 / 末词终点，故统一用单词边界表达，不再单列句子边界。
/// - [globalIndex]：映射回全篇词列表；`-1` 表示与文本 token 暂不同步（只绘制、不可拖动）。
/// - [word]：句区间内、已贴合句界的显示值。
/// - [primary]：true 为当前选中句（主样式大把手），false 为相邻句（次样式小把手）。
/// - [isSentenceStart] / [isSentenceEnd]：该词是否为所在句的首词起点 / 末词终点
///   （即句子的起止边界）。
typedef WaveformWordBoundary = ({
  int globalIndex,
  WordTimestamp word,
  bool primary,
  bool isSentenceStart,
  bool isSentenceEnd,
});

/// 可以放下一句新字幕的时间区间（位于相邻两句之间的空隙内）。
typedef SentenceSlot = ({Duration start, Duration end});

/// 字幕编辑纯逻辑。
///
/// 句子级结构操作都返回新的句子列表并重新编号，让 UI 和持久化层不必各自维护
/// index 连续性；词级操作负责「改文字后各词时间怎么分」。
class SubtitleEditEngine {
  const SubtitleEditEngine();

  /// 新句子至少需要的空隙；更短的空隙放不下一句可听清的话，插入入口置灰。
  static const Duration minInsertGap = Duration(milliseconds: 300);

  /// 新句子的最长时长：空隙很长（如片头音乐）时只取靠近参考位置的一段，
  /// 避免新句覆盖整段无关音频，用户再按需拖动边界。
  static const Duration maxInsertedSentenceDuration = Duration(seconds: 8);

  /// 重新分配词时间时每个词至少分到的时长。
  static const Duration minWordDuration = Duration(milliseconds: 20);

  /// 第 [index] 句之后、下一句（或音频结尾）之前的可插入区间，新句紧贴第 [index] 句。
  SentenceSlot? slotAfter(
    List<Sentence> sentences,
    int index,
    Duration totalDuration,
  ) {
    if (index < 0 || index >= sentences.length) return null;
    final gapEnd = index + 1 < sentences.length
        ? sentences[index + 1].startTime
        : totalDuration;
    return _fitSlot(sentences[index].endTime, gapEnd, anchorAtStart: true);
  }

  /// 第 [index] 句之前、上一句（或音频开头）之后的可插入区间，新句紧贴第 [index] 句。
  SentenceSlot? slotBefore(List<Sentence> sentences, int index) {
    if (index < 0 || index >= sentences.length) return null;
    final gapStart = index > 0 ? sentences[index - 1].endTime : Duration.zero;
    return _fitSlot(gapStart, sentences[index].startTime, anchorAtStart: false);
  }

  /// [position] 所在空隙的可插入区间；落在某句之内或正好在空隙边缘时返回 null。
  ///
  /// 播完一句后播放头停在句尾（空隙边缘），此时不提示插入，只有用户把播放头
  /// 点进空隙内部才提示。空隙过长时取从 [position] 稍前开始的一段，因为用户通常
  /// 把播放头点在漏掉的那句话附近。
  SentenceSlot? slotAt(
    List<Sentence> sentences,
    Duration position,
    Duration totalDuration,
  ) {
    if (position < Duration.zero || position > totalDuration) return null;
    var gapStart = Duration.zero;
    var gapEnd = totalDuration;
    for (final sentence in sentences) {
      if (position >= sentence.startTime && position < sentence.endTime) {
        return null;
      }
      if (sentence.endTime <= position && sentence.endTime > gapStart) {
        gapStart = sentence.endTime;
      }
      if (sentence.startTime > position && sentence.startTime < gapEnd) {
        gapEnd = sentence.startTime;
      }
    }
    if (position == gapStart || gapEnd - gapStart < minInsertGap) return null;
    if (gapEnd - gapStart <= maxInsertedSentenceDuration) {
      return (start: gapStart, end: gapEnd);
    }
    const lead = Duration(milliseconds: 500);
    var start = position - lead < gapStart ? gapStart : position - lead;
    var end = start + maxInsertedSentenceDuration;
    if (end > gapEnd) {
      end = gapEnd;
      start = end - maxInsertedSentenceDuration;
    }
    return (start: start, end: end);
  }

  SentenceSlot? _fitSlot(
    Duration gapStart,
    Duration gapEnd, {
    required bool anchorAtStart,
  }) {
    if (gapEnd - gapStart < minInsertGap) return null;
    if (gapEnd - gapStart <= maxInsertedSentenceDuration) {
      return (start: gapStart, end: gapEnd);
    }
    return anchorAtStart
        ? (start: gapStart, end: gapStart + maxInsertedSentenceDuration)
        : (start: gapEnd - maxInsertedSentenceDuration, end: gapEnd);
  }

  /// 在 [slot] 处插入文本为 [text] 的新句，按开始时间放到正确位置。
  ///
  /// 返回新列表与新句的序号。
  ({List<Sentence> sentences, int index}) insertSentence(
    List<Sentence> sentences,
    SentenceSlot slot,
    String text,
  ) {
    var index = sentences.indexWhere((s) => s.startTime >= slot.end);
    if (index < 0) index = sentences.length;
    final next = [...sentences]
      ..insert(
        index,
        Sentence(
          index: index,
          text: text.trim(),
          startTime: slot.start,
          endTime: slot.end,
        ),
      );
    return (sentences: _reindex(next), index: index);
  }

  /// 按最长公共子序列把新旧 token 对齐：返回每个新 token 对应的旧 token 序号，
  /// 未改动的词有对应序号，新增或改写的词为 null。
  ///
  /// 用于整句改文字后保留未改动词的时间，只给改动的部分重新分配时间。
  List<int?> matchTokens(List<String> oldTokens, List<String> newTokens) {
    final rows = oldTokens.length;
    final cols = newTokens.length;
    // lengths[i][j]：oldTokens[i..] 与 newTokens[j..] 的最长公共子序列长度。
    final lengths = List.generate(rows + 1, (_) => List.filled(cols + 1, 0));
    for (var i = rows - 1; i >= 0; i--) {
      for (var j = cols - 1; j >= 0; j--) {
        lengths[i][j] = oldTokens[i] == newTokens[j]
            ? lengths[i + 1][j + 1] + 1
            : (lengths[i + 1][j] >= lengths[i][j + 1]
                  ? lengths[i + 1][j]
                  : lengths[i][j + 1]);
      }
    }
    final matches = List<int?>.filled(cols, null);
    var i = 0;
    var j = 0;
    while (i < rows && j < cols) {
      if (oldTokens[i] == newTokens[j]) {
        matches[j] = i;
        i++;
        j++;
      } else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return matches;
  }

  /// 文字改动后重新计算一句内各词的时间。
  ///
  /// - 对应到旧词的 token（[matches] 非 null）保留旧词时间。
  /// - 连续的新 token 分到前后两个保留词之间的时间（句首 / 句尾以句界为界），
  ///   按字符数比例切分。
  /// - 这段时间不够分（如在两个紧挨的词之间插词）时，向前借一个保留词（没有前一个
  ///   就向后借）与新词一起按比例重新切分。
  ///
  /// 删除的旧词直接去掉，时间留空；调用方据首 / 末词更新句子起止。
  List<WordTimestamp> retimeTokens({
    required List<WordTimestamp> oldWords,
    required List<String> newTokens,
    required List<int?> matches,
    required Duration sentenceStart,
    required Duration sentenceEnd,
  }) {
    assert(matches.length == newTokens.length);
    final count = newTokens.length;
    final result = List<WordTimestamp?>.filled(count, null);
    for (var k = 0; k < count; k++) {
      final match = matches[k];
      if (match != null) {
        result[k] = oldWords[match].copyWith(word: newTokens[k]);
      }
    }
    var k = 0;
    while (k < count) {
      if (result[k] != null) {
        k++;
        continue;
      }
      var runStart = k;
      var runEnd = k;
      while (runEnd < count && result[runEnd] == null) {
        runEnd++;
      }
      var spanStart = runStart > 0
          ? result[runStart - 1]!.endTime
          : sentenceStart;
      var spanEnd = runEnd < count ? result[runEnd]!.startTime : sentenceEnd;
      if (spanEnd - spanStart < minWordDuration * (runEnd - runStart)) {
        if (runStart > 0) {
          runStart--;
          spanStart = result[runStart]!.startTime;
        } else if (runEnd < count) {
          spanEnd = result[runEnd]!.endTime;
          runEnd++;
        }
      }
      final distributed = distributeTokens(
        newTokens.sublist(runStart, runEnd),
        spanStart,
        spanEnd,
      );
      for (var j = 0; j < distributed.length; j++) {
        result[runStart + j] = distributed[j];
      }
      k = runEnd;
    }
    return result.cast<WordTimestamp>();
  }

  /// 按各词字符数比例把 `[start, end]` 切给 [tokens]（无真实词级时间时使用）。
  static List<WordTimestamp> distributeTokens(
    List<String> tokens,
    Duration start,
    Duration end,
  ) {
    final startMs = start.inMilliseconds;
    final endMs = end.inMilliseconds;
    final span = endMs - startMs;
    final weights = [for (final token in tokens) _tokenWeight(token)];
    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
    final result = <WordTimestamp>[];
    var currentMs = startMs;
    var consumed = 0;
    for (var i = 0; i < tokens.length; i++) {
      consumed += weights[i];
      final nextMs = i == tokens.length - 1
          ? endMs
          : (span <= 0 || totalWeight <= 0
                ? startMs
                : startMs + (span * consumed / totalWeight).round());
      result.add(
        WordTimestamp(
          word: tokens[i],
          startTime: Duration(milliseconds: currentMs),
          endTime: Duration(milliseconds: nextMs),
        ),
      );
      currentMs = nextMs;
    }
    return result;
  }

  /// 词的时长权重：字母数字字符数（纯标点 token 记 1，保证也分到时间）。
  static int _tokenWeight(String token) {
    final alnum = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length;
    return alnum > 0 ? alnum : 1;
  }

  /// 将 [index] 对应句子与下一句合并。
  List<Sentence> mergeWithNext(List<Sentence> sentences, int index) {
    if (index < 0 || index >= sentences.length - 1) {
      return sentences;
    }

    final next = [...sentences];
    final current = next[index];
    final following = next[index + 1];
    next[index] = current.copyWith(
      text: _joinSentenceText(current.text, following.text),
      endTime: following.endTime,
      isBookmarked: current.isBookmarked || following.isBookmarked,
    );
    next.removeAt(index + 1);
    return _reindex(next);
  }

  /// 把第 [index] 句从中间拆成两句。
  ///
  /// 前半保留原起点、文本设为 [firstText]、终点设为 [firstEnd]；后半起点
  /// [secondStart]、文本 [secondText]、保留原终点。文本由调用方按 token 切好传入
  /// （词级时间对齐由 controller 负责）。原句的 bookmark 归前半，后半不收藏。
  /// 拆完重排 index 保持连续。
  List<Sentence> splitSentence(
    List<Sentence> sentences,
    int index, {
    required String firstText,
    required Duration firstEnd,
    required String secondText,
    required Duration secondStart,
  }) {
    if (index < 0 || index >= sentences.length) {
      return sentences;
    }
    final original = sentences[index];
    final next = [...sentences];
    next[index] = original.copyWith(text: firstText, endTime: firstEnd);
    next.insert(
      index + 1,
      Sentence(
        index: index + 1,
        text: secondText,
        startTime: secondStart,
        endTime: original.endTime,
        isBookmarked: false,
      ),
    );
    return _reindex(next);
  }

  /// 删除指定句子；不允许删除到空字幕。
  List<Sentence> deleteSentence(List<Sentence> sentences, int index) {
    if (sentences.length <= 1 || index < 0 || index >= sentences.length) {
      return sentences;
    }

    final next = [...sentences]..removeAt(index);
    return _reindex(next);
  }

  List<Sentence> _reindex(List<Sentence> sentences) {
    return [
      for (final (index, sentence) in sentences.indexed)
        sentence.copyWith(index: index),
    ];
  }

  String _joinSentenceText(String first, String second) {
    final left = first.trim();
    final right = second.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }
}
