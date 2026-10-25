import 'package:echo_loop/utils/learning_duration_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateIntensiveListenDuration', () {
    test('按每句重复次数估算听和停顿时长', () {
      expect(
        estimateIntensiveListenDuration(
          sentenceDuration: const Duration(seconds: 30),
          repeatCount: 4,
        ),
        const Duration(seconds: 240),
      );
    });

    test('无限重复或没有句子时不返回有限时长', () {
      expect(
        estimateIntensiveListenDuration(
          sentenceDuration: const Duration(seconds: 30),
          repeatCount: 0,
        ),
        isNull,
      );
      expect(
        estimateIntensiveListenDuration(
          sentenceDuration: Duration.zero,
          repeatCount: 2,
        ),
        isNull,
      );
    });
  });

  group('estimateDifficultPracticeDuration', () {
    test('分别累计盲听和跟读遍数', () {
      expect(
        estimateDifficultPracticeDuration(
          difficultSentenceDuration: const Duration(seconds: 30),
          blindListenRepeatCount: 2,
          shadowReadingRepeatCount: 5,
        ),
        const Duration(seconds: 210),
      );
    });

    test('任一阶段无限重复或没有难句时不返回有限时长', () {
      expect(
        estimateDifficultPracticeDuration(
          difficultSentenceDuration: const Duration(seconds: 30),
          blindListenRepeatCount: 0,
          shadowReadingRepeatCount: 2,
        ),
        isNull,
      );
      expect(
        estimateDifficultPracticeDuration(
          difficultSentenceDuration: Duration.zero,
          blindListenRepeatCount: 1,
          shadowReadingRepeatCount: 3,
        ),
        isNull,
      );
    });
  });
}
