import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/utils/paragraph_grouping.dart';

/// 辅助函数：按给定时长顺序创建相邻（无空白）的句子列表
List<Sentence> _makeSentences(List<int> durationsMs) {
  final sentences = <Sentence>[];
  var start = 0;
  for (var i = 0; i < durationsMs.length; i++) {
    sentences.add(
      Sentence(
        index: i,
        text: 'Sentence $i',
        startTime: Duration(milliseconds: start),
        endTime: Duration(milliseconds: start + durationsMs[i]),
      ),
    );
    start += durationsMs[i];
  }
  return sentences;
}

/// 辅助函数：把分组结果按顺序拍平，用于校验覆盖与顺序
List<Sentence> _flatten(List<List<Sentence>> paragraphs) => [
  for (final p in paragraphs) ...p,
];

/// 辅助函数：段落墙上时长（毫秒）
int _paragraphDurationMs(List<Sentence> paragraph) =>
    paragraph.last.endTime.inMilliseconds -
    paragraph.first.startTime.inMilliseconds;

/// 辅助函数：生成确定性的随机句长列表（1–8 秒）
List<int> _randomDurationsMs(Random random, int count) => [
  for (var i = 0; i < count; i++) 1000 + random.nextInt(7000),
];

void main() {
  group('窗口化 DP 与全局 DP 的关系', () {
    test('随机输入：窗口版与全局版分段结果一致', () {
      // 窗口上限为 3 × 目标时长，最优解的段长几乎不会超过它，两者应给出相同分组
      final random = Random(42);
      const target = Duration(seconds: 10);
      for (var round = 0; round < 20; round++) {
        final count = 5 + random.nextInt(36);
        final sentences = _makeSentences(_randomDurationsMs(random, count));

        final global = groupSentencesIntoParagraphs(
          sentences,
          target,
          windowedDpThreshold: 1 << 30,
        );
        final windowed = groupSentencesIntoParagraphs(
          sentences,
          target,
          windowedDpThreshold: 0,
        );

        expect(
          windowed.map((p) => p.map((s) => s.index).toList()).toList(),
          global.map((p) => p.map((s) => s.index).toList()).toList(),
          reason: '第 $round 轮（$count 句）两种实现分段不一致',
        );
      }
    });

    test('含超长单句：窗口版仍覆盖全部句子且顺序不变', () {
      // 单句 60s 远超窗口上限 30s，必须允许它独立成段，否则 DP 无解
      final sentences = _makeSentences([4000, 4000, 60000, 4000, 4000]);
      const target = Duration(seconds: 10);

      final windowed = groupSentencesIntoParagraphs(
        sentences,
        target,
        windowedDpThreshold: 0,
      );

      expect(_flatten(windowed).map((s) => s.index).toList(), [0, 1, 2, 3, 4]);
      final longParagraph = windowed.firstWhere(
        (p) => p.any((s) => s.index == 2),
      );
      expect(longParagraph.map((s) => s.index).toList(), [2]);
    });
  });

  group('阈值切换', () {
    // 模式段：47s 长句紧邻 1s 短句。全局 DP 会把二者合成一段（合并后 48s 的偏差
    // 小于分开的代价），窗口版因合并段超过 3 × 13s = 39s 而禁止合并。
    // 因此该模式能区分两条路径，用来验证阈值确实切换了算法。
    const target = Duration(seconds: 13);
    final pattern = [57000, 47000, 1000, 54000, 23000, 29000];
    const globalGroups = [
      [0],
      [1, 2],
      [3],
      [4],
      [5],
    ];
    const windowedGroups = [
      [0],
      [1],
      [2],
      [3],
      [4],
      [5],
    ];

    /// 模式段 + 若干与之隔开（20s 空白，必触发硬切）的 1s 句子，共 6 + extra 句
    List<Sentence> withIsolatedPadding(int extra) {
      final sentences = _makeSentences(pattern);
      var start = sentences.last.endTime.inMilliseconds + 20000;
      for (var i = 0; i < extra; i++) {
        final index = sentences.length;
        sentences.add(
          Sentence(
            index: index,
            text: 'Padding $index',
            startTime: Duration(milliseconds: start),
            endTime: Duration(milliseconds: start + 1000),
          ),
        );
        start += 21000;
      }
      return sentences;
    }

    List<List<int>> indexGroups(List<List<Sentence>> paragraphs) =>
        paragraphs.map((p) => p.map((s) => s.index).toList()).toList();

    test('阈值设为极大：强制全局 DP，模式段合并长句与短句', () {
      final paragraphs = groupSentencesIntoParagraphs(
        withIsolatedPadding(0),
        target,
        windowedDpThreshold: 1 << 30,
      );
      expect(indexGroups(paragraphs).take(5).toList(), globalGroups);
    });

    test('阈值设为 0：强制窗口 DP，模式段禁止合并超窗长段', () {
      final paragraphs = groupSentencesIntoParagraphs(
        withIsolatedPadding(0),
        target,
        windowedDpThreshold: 0,
      );
      expect(indexGroups(paragraphs).take(6).toList(), windowedGroups);
    });

    test('默认阈值：句子数 50（不超过）走全局 DP', () {
      final paragraphs = groupSentencesIntoParagraphs(
        withIsolatedPadding(44),
        target,
      );
      expect(indexGroups(paragraphs).take(5).toList(), globalGroups);
    });

    test('默认阈值：句子数 51（超过）走窗口 DP', () {
      final paragraphs = groupSentencesIntoParagraphs(
        withIsolatedPadding(45),
        target,
      );
      expect(indexGroups(paragraphs).take(6).toList(), windowedGroups);
      expect(
        _flatten(paragraphs).map((s) => s.index).toList(),
        List<int>.generate(51, (i) => i),
      );
    });
  });

  group('按目标时长切段 splitIntoParagraphsForTarget', () {
    final sentences = _makeSentences([4000, 4000, 4000, 4000]);

    test('-1（不分段）：整篇作为一段', () {
      final paragraphs = splitIntoParagraphsForTarget(sentences, -1);
      expect(paragraphs.length, 1);
      expect(paragraphs.first.length, 4);
    });

    test('0（逐句）：每句一段', () {
      final paragraphs = splitIntoParagraphsForTarget(sentences, 0);
      expect(paragraphs.length, 4);
      expect(paragraphs.every((p) => p.length == 1), isTrue);
    });

    test('正数：与 groupSentencesIntoParagraphs 结果一致', () {
      final paragraphs = splitIntoParagraphsForTarget(sentences, 8);
      final expected = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 8),
      );
      expect(
        paragraphs.map((p) => p.map((s) => s.index).toList()).toList(),
        expected.map((p) => p.map((s) => s.index).toList()).toList(),
      );
    });
  });

  group('分段诊断摘要 summarizeParagraphDurations', () {
    test('空分段输出 paragraphs=0', () {
      final summary = summarizeParagraphDurations(
        const [],
        const Duration(seconds: 10),
      );
      expect(summary, contains('paragraphs=0'));
    });

    test('统计段数、明显偏短段数，并列出各段时长（秒）', () {
      final sentences = _makeSentences([10000, 4000, 12000]);
      final paragraphs = [
        [sentences[0]],
        [sentences[1]],
        [sentences[2]],
      ];
      final summary = summarizeParagraphDurations(
        paragraphs,
        const Duration(seconds: 10),
      );
      expect(summary, contains('paragraphs=3'));
      // 4s < 目标的一半(5s)，计为偏短段
      expect(summary, contains('shortCount=1'));
      expect(summary, contains('durations=[10.0,4.0,12.0]'));
    });
  });

  group('窗口下界 windowLowerBounds', () {
    test('均匀 1s 句子、窗口 2.5s：每个句尾允许的最早起点', () {
      final sentences = _makeSentences([1000, 1000, 1000, 1000]);
      expect(windowLowerBounds(sentences, 2500), [0, 0, 0, 1, 2]);
    });

    test('超长单句：段长始终超窗时仍只允许单句段（下界 = i-1）', () {
      final sentences = _makeSentences([1000, 10000, 1000]);
      final lower = windowLowerBounds(sentences, 2500);
      expect(lower[2], 1);
      expect(lower[3], 2);
    });
  });

  group('长音频回归（590 句，约 41 分钟）', () {
    test('目标 10s 时在毫秒级完成，段落覆盖全部句子且段长受窗口约束', () {
      // 修复前全量 DP 在本机约 8 秒；阈值 2 秒仅作为明显回退的护栏
      final sentences = _makeSentences(List.filled(590, 4200));
      const target = Duration(seconds: 10);

      final stopwatch = Stopwatch()..start();
      final paragraphs = groupSentencesIntoParagraphs(sentences, target);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(
        _flatten(paragraphs).map((s) => s.index).toList(),
        List<int>.generate(590, (i) => i),
      );
      for (final p in paragraphs) {
        if (p.length == 1) continue;
        expect(
          _paragraphDurationMs(p),
          lessThanOrEqualTo(3 * target.inMilliseconds),
        );
      }
    });
  });
}
