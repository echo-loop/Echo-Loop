import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/utils/paragraph_grouping.dart';

/// 辅助：按时长顺序创建相邻（无空白）的句子，不会触发硬切
List<Sentence> _contiguous(List<int> durationsMs) {
  var start = 0;
  return [
    for (var i = 0; i < durationsMs.length; i++)
      Sentence(
        index: i,
        text: 'Sentence $i',
        startTime: Duration(milliseconds: start),
        endTime: Duration(milliseconds: start += durationsMs[i]),
      ),
  ];
}

/// 辅助：一组分段的总代价 = Σ (段墙上时长 - 目标)²
double _partitionCost(List<List<Sentence>> groups, int targetMs) {
  var total = 0.0;
  for (final g in groups) {
    final wall =
        g.last.endTime.inMilliseconds - g.first.startTime.inMilliseconds;
    final diff = (wall - targetMs).toDouble();
    total += diff * diff;
  }
  return total;
}

/// 暴力枚举：遍历全部 2^(n-1) 种切分，返回最小代价。
/// [maxSegmentMs] 不为空时，多句段的墙上时长不得超过该值（与窗口版约束一致）。
double _bruteForceMinCost(
  List<Sentence> sentences,
  int targetMs, {
  int? maxSegmentMs,
}) {
  final n = sentences.length;
  var best = double.infinity;
  // 第 b 位为 1 表示在第 b 句之后切开
  for (var mask = 0; mask < (1 << (n - 1)); mask++) {
    final groups = <List<Sentence>>[];
    var start = 0;
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      final cutHere = !isLast && (mask & (1 << i)) != 0;
      if (isLast || cutHere) {
        groups.add(sentences.sublist(start, i + 1));
        start = i + 1;
      }
    }
    if (maxSegmentMs != null &&
        groups.any(
          (g) =>
              g.length > 1 &&
              g.last.endTime.inMilliseconds - g.first.startTime.inMilliseconds >
                  maxSegmentMs,
        )) {
      continue;
    }
    final cost = _partitionCost(groups, targetMs);
    if (cost < best) best = cost;
  }
  return best;
}

void main() {
  group('DP 代价最优（与暴力枚举对照）', () {
    test('全局路径：随机小规模输入的分段代价等于全局最优', () {
      final random = Random(20240601);
      for (var round = 0; round < 200; round++) {
        final n = 1 + random.nextInt(12);
        final sentences = _contiguous([
          for (var i = 0; i < n; i++) 1000 + random.nextInt(59000),
        ]);
        final targetMs = 3000 + random.nextInt(17000);

        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          Duration(milliseconds: targetMs),
          windowedDpThreshold: 1 << 30,
        );

        expect(
          _partitionCost(paragraphs, targetMs),
          closeTo(_bruteForceMinCost(sentences, targetMs), 1e-6),
          reason: '第 $round 轮（$n 句，目标 ${targetMs}ms）代价不是全局最优',
        );
      }
    });

    test('窗口路径：随机小规模输入的分段代价等于窗口约束下的最优', () {
      final random = Random(7321);
      for (var round = 0; round < 200; round++) {
        final n = 1 + random.nextInt(12);
        final sentences = _contiguous([
          for (var i = 0; i < n; i++) 1000 + random.nextInt(59000),
        ]);
        final targetMs = 3000 + random.nextInt(17000);

        final paragraphs = groupSentencesIntoParagraphs(
          sentences,
          Duration(milliseconds: targetMs),
          windowedDpThreshold: 0,
        );

        expect(
          _partitionCost(paragraphs, targetMs),
          closeTo(
            _bruteForceMinCost(
              sentences,
              targetMs,
              maxSegmentMs: kWindowMultiplier * targetMs,
            ),
            1e-6,
          ),
          reason: '第 $round 轮（$n 句，目标 ${targetMs}ms）窗口版代价不是窗口约束下的最优',
        );
      }
    });
  });
}
