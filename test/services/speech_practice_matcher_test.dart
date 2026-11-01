import 'package:flutter_test/flutter_test.dart';
import 'package:lemmatizerx/lemmatizerx.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/services/speech_practice_matcher.dart';

/// 词形还原测试替身。
///
/// 真实 [Lemmatizer] 会惰性加载 lemmatizerx 内嵌的 ~2.3MB 巨型词典（9 个
/// `static final` Map/Set），把 flutter_tester 进程堆撑大约 18MB。这是整个测试
/// 套件里唯一加载该词典的 suite，导致 Linux CI 上进程收尾（finalization）时
/// Dart VM 段错误、job exit 1（断言全过却失败）。
///
/// matcher 自身逻辑只需「调用 lemmatizer 并使用其返回词元」，具体词典内容的正确性
/// 是 lemmatizerx 第三方的责任。故这里用只覆盖少量已知词形的替身，其余返回空
/// （matcher 回退为原词），既保留 matcher 逻辑覆盖，又不加载巨型词典。
class _StubLemmatizer extends Lemmatizer {
  static const Map<String, String> _forms = {
    'walks': 'walk',
    'walked': 'walk',
    'stores': 'store',
  };

  @override
  List<Lemma> lemmas(String form) {
    final lemma = _forms[form.toLowerCase()];
    if (lemma == null) return const [];
    return [
      Lemma(POS.VERB, form, [lemma]),
    ];
  }
}

void main() {
  group('SpeechTranscriptMatcher', () {
    final matcher = SpeechTranscriptMatcher(lemmatizer: _StubLemmatizer());

    test('低于 50% 时不通过', () {
      final result = matcher.evaluate(
        referenceText: 'The quick brown fox jumps over the lazy dog',
        transcript: 'quick fox over dog',
      );

      expect(result.status, SpeechPracticeAttemptStatus.belowThreshold);
      expect(result.score, closeTo(4 / 9, 0.001));
    });

    test('词形还原后可通过', () {
      final result = matcher.evaluate(
        referenceText: 'He walks to the stores',
        transcript: 'he walked to the store',
      );

      expect(result.status, SpeechPracticeAttemptStatus.passed);
      expect(result.matchedTokenCount, 5);
      expect(result.totalTargetTokenCount, 5);
    });

    test('没有英文时返回 noEnglishDetected', () {
      final result = matcher.evaluate(
        referenceText: 'This is a test sentence',
        transcript: '你好 123',
      );

      expect(result.status, SpeechPracticeAttemptStatus.noEnglishDetected);
      expect(result.recognizedEnglishTokenCount, 0);
    });

    test('乱序单词不会被全部命中', () {
      final result = matcher.evaluate(
        referenceText: 'the cat sat on the mat',
        transcript: 'mat the cat sat',
      );

      expect(result.matchedTokenCount, 3);
      expect(result.totalTargetTokenCount, 6);
    });

    test('生成 transcript 高亮片段', () {
      final result = matcher.evaluate(
        referenceText: 'I really like this idea',
        transcript: 'I really love this idea',
      );

      expect(result.transcriptSegments, isNotEmpty);
      expect(
        result.transcriptSegments.where((segment) => segment.isMatched).length,
        greaterThanOrEqualTo(4),
      );
      expect(
        result.referenceSegments.where((segment) => segment.isMatched).length,
        greaterThanOrEqualTo(4),
      );
    });
  });
}
