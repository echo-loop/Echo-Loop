import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/utils/paragraph_grouping.dart';
import 'package:echo_loop/utils/retell_duration_estimator.dart';

/// 辅助：按时长顺序创建相邻句子
List<Sentence> _makeSentences(List<int> durationsMs) {
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

void main() {
  group('段落版估时与原估时一致', () {
    final sentences = _makeSentences([3000, 6000, 2000, 9000, 4000, 5000]);

    for (final target in [-1, 0, 10]) {
      test('target=$target：传入已分段结果与内部分段结果相同', () {
        final viaSentences = estimateRetellSessionDuration(
          sentences: sentences,
          targetSeconds: target,
          pauseMultiplier: 1.5,
          repeatCount: 2,
        );
        final viaParagraphs = estimateRetellParagraphsDuration(
          paragraphs: splitIntoParagraphsForTarget(sentences, target),
          pauseMultiplier: 1.5,
          repeatCount: 2,
        );
        expect(viaParagraphs, viaSentences);
      });
    }
  });
}
