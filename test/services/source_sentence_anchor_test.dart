import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/services/source_sentence_anchor.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _s(double seconds) => Duration(milliseconds: (seconds * 1000).round());

List<Sentence> _sentences(List<(double, double, String)> cues) => [
  for (final (i, cue) in cues.indexed)
    Sentence(
      index: i,
      text: cue.$3,
      startTime: _s(cue.$1),
      endTime: _s(cue.$2),
    ),
];

SourceSentenceAnchor _anchor(double start, double end) =>
    SourceSentenceAnchor(start: _s(start), end: _s(end));

void main() {
  /// 原始字幕：A [0,2)、B [2,4)、C [4,6)、D [6,8)。
  final original = _sentences([
    (0, 2, 'A a.'),
    (2, 4, 'B b.'),
    (4, 6, 'C c.'),
    (6, 8, 'D d.'),
  ]);

  group('resolveSourceSentenceIndex', () {
    test('取收藏区间中点所在的句子', () {
      expect(resolveSourceSentenceIndex(_anchor(4, 6), original), 2);
    });

    test('前面插入句子后，收藏跟随时间落到新位置', () {
      final inserted = _sentences([
        (0, 1, 'New.'),
        (1, 2, 'A a.'),
        (2, 4, 'B b.'),
        (4, 6, 'C c.'),
      ]);
      expect(resolveSourceSentenceIndex(_anchor(4, 6), inserted), 3);
    });

    test('拖边界、改字后仍落在同一句', () {
      final edited = _sentences([(0, 2.3, 'A!'), (2.3, 4, 'B, b.')]);
      expect(resolveSourceSentenceIndex(_anchor(2, 4), edited), 1);
    });

    test('合并后两条收藏都落在合并句', () {
      final merged = _sentences([
        (0, 2, 'A a.'),
        (2, 6, 'B b. C c.'),
        (6, 8, 'D d.'),
      ]);
      expect(resolveSourceSentenceIndex(_anchor(2, 4), merged), 1);
      expect(resolveSourceSentenceIndex(_anchor(4, 6), merged), 1);
    });

    test('拆分后落在包含中点的那一半', () {
      final split = _sentences([(0, 2, 'A a.'), (2, 2.6, 'B'), (2.6, 4, 'b.')]);
      expect(resolveSourceSentenceIndex(_anchor(2, 4), split), 2);
    });

    test('多句同时包含中点时取重叠最长的，一样长取靠前的', () {
      final nested = _sentences([(0, 10, 'Long.'), (3, 5, 'Inner.')]);
      // 收藏区间 [0,10) 与 Long 重叠 10 秒，与 Inner 重叠 2 秒。
      expect(resolveSourceSentenceIndex(_anchor(0, 10), nested), 0);
      // 收藏区间 [3,5) 与两句都重叠 2 秒：取靠前的。
      expect(resolveSourceSentenceIndex(_anchor(3, 5), nested), 0);
    });

    test('来源句被删除（中点落在空隙）时返回 null，不按文字去找其他句子', () {
      final deleted = _sentences([
        (0, 2, 'A a.'),
        (4, 6, 'B b.'),
        (6, 8, 'D d.'),
      ]);
      expect(resolveSourceSentenceIndex(_anchor(2, 4), deleted), isNull);
    });

    test('没有有效时间时返回 null', () {
      expect(
        resolveSourceSentenceIndex(
          const SourceSentenceAnchor(start: Duration.zero, end: Duration.zero),
          original,
        ),
        isNull,
      );
      expect(
        resolveSourceSentenceIndex(
          SourceSentenceAnchor.fromMilliseconds(startMs: null, endMs: null),
          original,
        ),
        isNull,
      );
    });

    test('无字幕返回 null', () {
      expect(resolveSourceSentenceIndex(_anchor(0, 2), const []), isNull);
    });
  });

  group('resolveVocabularySourceSentenceIndex', () {
    /// "It's so exciting. I often watch games." 拆成两句，中点落在后半句。
    final split = _sentences([
      (0, 1.5, "It's so exciting."),
      (1.5, 5, 'I often watch games.'),
    ]);

    test('拆分后关联含该词的那一半，而不是中点所在的句子', () {
      expect(resolveSourceSentenceIndex(_anchor(0, 5), split), 1);
      expect(
        resolveVocabularySourceSentenceIndex(_anchor(0, 5), split, 'exciting'),
        0,
      );
      expect(
        resolveVocabularySourceSentenceIndex(
          _anchor(0, 5),
          split,
          'So Exciting',
        ),
        0,
        reason: '不区分大小写，意群也能匹配',
      );
    });

    test('词元能匹配变形，但不匹配词中间的片段', () {
      expect(
        resolveVocabularySourceSentenceIndex(_anchor(0, 5), split, 'watch'),
        1,
      );
      // "it" 只出现在 "exciting" 中间，不算命中，退回中点规则。
      final noIt = _sentences([(0, 1.5, 'So exciting.'), (1.5, 5, 'Go.')]);
      expect(
        resolveVocabularySourceSentenceIndex(_anchor(0, 5), noIt, 'it'),
        1,
      );
    });

    test('只在与收藏区间重叠的句子里找；都不含时按中点定位', () {
      final sentences = _sentences([
        (0, 2, 'Games again.'),
        (2, 4, 'B b.'),
        (4, 6, 'C c.'),
      ]);
      expect(
        resolveVocabularySourceSentenceIndex(_anchor(2, 6), sentences, 'games'),
        2,
        reason: '第 0 句含该词但不在收藏区间内，按中点 4s 落在第 2 句',
      );
    });

    test('来源句被删除或没有有效时间时返回 null', () {
      final sentences = _sentences([(0, 2, 'A a.'), (6, 8, 'D d.')]);
      expect(
        resolveVocabularySourceSentenceIndex(_anchor(3, 5), sentences, 'a'),
        isNull,
      );
      expect(
        resolveVocabularySourceSentenceIndex(
          const SourceSentenceAnchor(start: null, end: null),
          sentences,
          'a',
        ),
        isNull,
      );
    });
  });

  group('remapSentenceIndex', () {
    test('合并后断点落在合并句，拆分后落在前半句（不跳过内容）', () {
      final edited = _sentences([
        (0, 1, 'A'),
        (1, 2, 'a.'),
        (2, 6, 'B b. C c.'),
        (6, 7.5, 'D d'),
        (7.5, 8, '.'),
      ]);
      expect(remapSentenceIndex(0, original, edited), 0);
      expect(remapSentenceIndex(1, original, edited), 2);
      expect(remapSentenceIndex(2, original, edited), 2);
      expect(remapSentenceIndex(3, original, edited), 3);
    });

    test('前面插入句子后断点顺延；相邻句因拖边界略有重叠不算', () {
      final edited = _sentences([
        (0, 0.5, 'New.'),
        (0.5, 2.3, 'A a.'),
        (2.3, 4, 'B b.'),
        (4, 6, 'C c.'),
      ]);
      expect(remapSentenceIndex(1, original, edited), 2);
      expect(remapSentenceIndex(2, original, edited), 3);
    });

    test('断点句被删除时停在其后第一句，后面没有句子返回 null', () {
      final deleted = _sentences([(0, 2, 'A a.'), (4, 6, 'C c.')]);
      expect(remapSentenceIndex(1, original, deleted), 1);
      expect(remapSentenceIndex(3, original, deleted), isNull);
    });

    test('越界索引返回 null', () {
      expect(remapSentenceIndex(9, original, original), isNull);
    });
  });

  group('hasSameSentenceStructure', () {
    test('只调整时间或文字时结构不变', () {
      final edited = _sentences([
        (0, 2.2, 'A!'),
        (2.2, 4, 'B b.'),
        (4, 6, 'C c.'),
        (6, 8, 'D d.'),
      ]);
      expect(hasSameSentenceStructure(original, edited), isTrue);
    });

    test('数量不变但句子错位（拆一句合一句）时结构变化', () {
      final shifted = _sentences([
        (0, 1, 'A'),
        (1, 2, 'a.'),
        (2, 6, 'B b. C c.'),
        (6, 8, 'D d.'),
      ]);
      expect(hasSameSentenceStructure(original, shifted), isFalse);
    });
  });
}
