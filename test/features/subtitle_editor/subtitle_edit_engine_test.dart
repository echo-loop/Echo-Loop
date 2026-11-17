import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = SubtitleEditEngine();

  List<Sentence> sentences() => [
    Sentence(
      index: 0,
      text: 'Hello world.',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 2),
    ),
    Sentence(
      index: 1,
      text: 'Next sentence.',
      startTime: const Duration(seconds: 2),
      endTime: const Duration(seconds: 4),
    ),
    Sentence(
      index: 2,
      text: 'Last one.',
      startTime: const Duration(seconds: 4),
      endTime: const Duration(seconds: 6),
    ),
  ];

  group('SubtitleEditEngine', () {
    test('mergeWithNext 合并文本和时间并重排 index', () {
      final result = engine.mergeWithNext(sentences(), 0);

      expect(result, hasLength(2));
      expect(result[0].index, 0);
      expect(result[0].text, 'Hello world. Next sentence.');
      expect(result[0].startTime, Duration.zero);
      expect(result[0].endTime, const Duration(seconds: 4));
      expect(result[1].index, 1);
      expect(result[1].text, 'Last one.');
    });

    test('mergeWithNext 最后一句不变', () {
      final input = sentences();
      final result = engine.mergeWithNext(input, 2);

      expect(result, same(input));
    });

    test('deleteSentence 删除句子并重排 index', () {
      final result = engine.deleteSentence(sentences(), 1);

      expect(result, hasLength(2));
      expect(result[0].index, 0);
      expect(result[0].text, 'Hello world.');
      expect(result[1].index, 1);
      expect(result[1].text, 'Last one.');
    });

    test('deleteSentence 不允许删除到空字幕', () {
      final input = [
        Sentence(
          index: 0,
          text: 'Only one.',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ];

      final result = engine.deleteSentence(input, 0);

      expect(result, same(input));
    });

    test('splitSentence 拆成两句并设置文本/时间，重排 index', () {
      final result = engine.splitSentence(
        sentences(),
        0,
        firstText: 'Hello',
        firstEnd: const Duration(seconds: 1),
        secondText: 'world.',
        secondStart: const Duration(seconds: 1),
      );

      expect(result, hasLength(4));
      expect(result[0].index, 0);
      expect(result[0].text, 'Hello');
      expect(result[0].startTime, Duration.zero);
      expect(result[0].endTime, const Duration(seconds: 1));
      expect(result[1].index, 1);
      expect(result[1].text, 'world.');
      expect(result[1].startTime, const Duration(seconds: 1));
      expect(result[1].endTime, const Duration(seconds: 2));
      expect(result[2].index, 2);
      expect(result[2].text, 'Next sentence.');
      expect(result[3].index, 3);
      expect(result[3].text, 'Last one.');
    });

    test('splitSentence 越界返回原列表', () {
      final input = sentences();
      expect(
        engine.splitSentence(
          input,
          5,
          firstText: 'a',
          firstEnd: Duration.zero,
          secondText: 'b',
          secondStart: Duration.zero,
        ),
        same(input),
      );
    });
  });

  group('词对齐与重新分时间', () {
    WordTimestamp word(String text, int startMs, int endMs) => WordTimestamp(
      word: text,
      startTime: Duration(milliseconds: startMs),
      endTime: Duration(milliseconds: endMs),
    );

    test('matchTokens 保留未改动的词，改写 / 新增的词为 null', () {
      expect(
        engine.matchTokens(
          ['the', 'cat', 'the', 'dog'],
          ['the', 'cat', 'a', 'dog', 'ran'],
        ),
        [0, 1, null, 3, null],
      );
      expect(engine.matchTokens(['a', 'b'], []), isEmpty);
    });

    test('retimeTokens 新词分到前后保留词之间的空隙', () {
      final words = engine.retimeTokens(
        oldWords: [word('one', 0, 1000), word('two', 2000, 3000)],
        newTokens: ['one', 'big', 'two'],
        matches: [0, null, 1],
        sentenceStart: Duration.zero,
        sentenceEnd: const Duration(seconds: 3),
      );
      expect(words[1].startTime, const Duration(seconds: 1));
      expect(words[1].endTime, const Duration(seconds: 2));
      expect(words[0].endTime, const Duration(seconds: 1));
    });

    test('retimeTokens 句首没有空隙时向后借首个保留词', () {
      final words = engine.retimeTokens(
        oldWords: [word('one', 0, 1000), word('two', 1000, 2000)],
        newTokens: ['zero', 'one', 'two'],
        matches: [null, 0, 1],
        sentenceStart: Duration.zero,
        sentenceEnd: const Duration(seconds: 2),
      );
      // 'zero'(4) + 'one'(3) 分 [0,1s]。
      expect(words[0].startTime, Duration.zero);
      expect(words[0].endTime, const Duration(milliseconds: 571));
      expect(words[1].endTime, const Duration(seconds: 1));
      expect(words[2].startTime, const Duration(seconds: 1));
    });
  });

  group('插入新句区间', () {
    List<Sentence> gapped() => [
      Sentence(
        index: 0,
        text: 'a',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 2),
      ),
      Sentence(
        index: 1,
        text: 'b',
        startTime: const Duration(seconds: 20),
        endTime: const Duration(seconds: 22),
      ),
    ];

    test('长空隙只取紧贴参照句的一段（最长 8s）', () {
      expect(engine.slotAfter(gapped(), 0, const Duration(seconds: 30)), (
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 10),
      ));
      expect(engine.slotBefore(gapped(), 1), (
        start: const Duration(seconds: 12),
        end: const Duration(seconds: 20),
      ));
    });

    test('播放头所在长空隙从播放头前 0.5s 开始取，靠近下一句时整体前移', () {
      expect(
        engine.slotAt(
          gapped(),
          const Duration(seconds: 5),
          const Duration(seconds: 30),
        ),
        (
          start: const Duration(milliseconds: 4500),
          end: const Duration(milliseconds: 12500),
        ),
      );
      expect(
        engine.slotAt(
          gapped(),
          const Duration(seconds: 15),
          const Duration(seconds: 30),
        ),
        (start: const Duration(seconds: 12), end: const Duration(seconds: 20)),
      );
    });

    test('播放头正好停在句尾（空隙边缘）时不提示插入', () {
      expect(
        engine.slotAt(
          gapped(),
          const Duration(seconds: 2),
          const Duration(seconds: 30),
        ),
        isNull,
      );
    });

    test('不足 300ms 的空隙不可插入', () {
      final list = [
        Sentence(
          index: 0,
          text: 'a',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
        Sentence(
          index: 1,
          text: 'b',
          startTime: const Duration(milliseconds: 1200),
          endTime: const Duration(seconds: 2),
        ),
      ];
      expect(engine.slotAfter(list, 0, const Duration(seconds: 2)), isNull);
      expect(
        engine.slotAt(
          list,
          const Duration(milliseconds: 1100),
          const Duration(seconds: 2),
        ),
        isNull,
      );
    });

    test('insertSentence 按时间放到正确位置并重排序号', () {
      final result = engine.insertSentence(gapped(), (
        start: const Duration(seconds: 5),
        end: const Duration(seconds: 8),
      ), ' new one ');
      expect(result.index, 1);
      expect(result.sentences.map((s) => s.text).toList(), [
        'a',
        'new one',
        'b',
      ]);
      expect(result.sentences.map((s) => s.index).toList(), [0, 1, 2]);
    });
  });
}
