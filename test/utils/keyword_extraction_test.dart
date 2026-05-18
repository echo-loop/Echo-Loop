import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/utils/keyword_extraction.dart';
import 'package:echo_loop/utils/stopwords.dart';

/// 辅助函数：创建带指定文本的句子列表
List<Sentence> _makeSentences(List<String> texts) {
  return texts
      .asMap()
      .entries
      .map(
        (e) => Sentence(
          index: e.key,
          text: e.value,
          startTime: Duration(seconds: e.key * 5),
          endTime: Duration(seconds: (e.key + 1) * 5),
        ),
      )
      .toList();
}

/// 辅助函数：统计关键词总数
int _totalKeywords(Map<int, Set<int>> result) {
  return result.values.fold<int>(0, (sum, s) => sum + s.length);
}

void main() {
  group('extractKeywords', () {
    test('空句子列表返回空映射', () {
      final result = extractKeywords([]);
      expect(result, isEmpty);
    });

    test('所有词长度 ≤ 2 返回空映射', () {
      final sentences = _makeSentences(['I am a', 'Go to']);
      final result = extractKeywords(sentences, random: Random(42));
      expect(result, isEmpty);
    });

    test('至少提取 1 个关键词（保底机制）', () {
      final sentences = _makeSentences([
        'The beautiful sunset illuminated the entire valley',
      ]);
      final result = extractKeywords(sentences, random: Random(42));
      expect(_totalKeywords(result), greaterThanOrEqualTo(1));
    });

    test('关键词索引在有效范围内', () {
      final sentences = _makeSentences([
        'Understanding complex algorithms requires practice',
        'Mathematical foundations provide essential knowledge',
      ]);
      final result = extractKeywords(sentences, random: Random(42));
      for (final entry in result.entries) {
        expect(entry.key, inInclusiveRange(0, 1), reason: '句子索引超出范围');
        for (final wordIdx in entry.value) {
          final words = tokenize(sentences[entry.key].text);
          expect(
            wordIdx,
            inInclusiveRange(0, words.length - 1),
            reason: '词索引超出范围',
          );
        }
      }
    });

    test('固定种子产生确定性结果', () {
      final sentences = _makeSentences([
        'Understanding complex algorithms requires extensive practice',
        'Mathematical foundations provide essential knowledge',
      ]);
      final result1 = extractKeywords(sentences, random: Random(123));
      final result2 = extractKeywords(sentences, random: Random(123));
      expect(result1.keys.toSet(), result2.keys.toSet());
      for (final key in result1.keys) {
        expect(result1[key], result2[key]);
      }
    });

    group('比例测试', () {
      // 构造全为非停用词的句子用于比例验证
      final sentences = _makeSentences([
        'absolutely beautiful certainly delightful especially fantastic generally hopefully',
        'incredibly joyfully knowledgeable lovingly meaningfully naturally obviously potentially',
        'remarkably significantly tremendously unfortunately wonderfully yesterday',
      ]);

      // 总词数 22，全部 > 2 字符且非停用词
      test('veryEasy 20% 选出约 20% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.veryEasy,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.20 ≈ 4
        expect(count, inInclusiveRange(3, 7));
      });

      test('easy 30% 选出约 30% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.easy,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.30 ≈ 7
        expect(count, inInclusiveRange(4, 10));
      });

      test('medium 40% 选出约 40% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.medium,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.4 ≈ 9
        expect(count, inInclusiveRange(6, 12));
      });

      test('hard 50% 选出约 50% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.hard,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.5 ≈ 11
        expect(count, inInclusiveRange(8, 14));
      });

      test('veryHard 60% 选出约 60% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.veryHard,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.6 ≈ 13
        expect(count, inInclusiveRange(10, 16));
      });

      test('真实英文句高比例靠停用词补足，可见词数贴近总词×ratio', () {
        // 模拟 UI 中实际场景：句子停用词较多，旧算法会被候选词数 clamp 住。
        final sentences = _makeSentences([
          'You may take notes while you are listening.', // 8 词，候选 3
          'You will hear the passage only once.',         // 7 词，候选 2
        ]);
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.veryHard,
          random: Random(42),
        );
        // round(8 * 0.6) = 5，round(7 * 0.6) = 4
        expect(result[0]?.length, 5);
        expect(result[1]?.length, 4);
      });
    });

    group('停用词过滤', () {
      test('停用词不会被选为关键词', () {
        final sentences = _makeSentences([
          'The beautiful sunset was absolutely wonderful',
        ]);
        for (var seed = 0; seed < 100; seed++) {
          final result = extractKeywords(
            sentences,
            ratio: KeywordRatio.hard,
            random: Random(seed),
          );
          if (result.containsKey(0)) {
            final words = tokenize(sentences[0].text);
            for (final idx in result[0]!) {
              expect(
                isStopword(words[idx]),
                isFalse,
                reason: '停用词 "${words[idx]}" 不应被选为关键词 (seed=$seed)',
              );
            }
          }
        }
      });

      test('仅含停用词的句子不产生关键词', () {
        final sentences = _makeSentences(['The and with from they were']);
        final result = extractKeywords(sentences, random: Random(42));
        expect(result, isEmpty);
      });

      test('带标点的停用词也能正确过滤', () {
        final sentences = _makeSentences(['The, beautiful through. wonderful']);
        for (var seed = 0; seed < 50; seed++) {
          final result = extractKeywords(
            sentences,
            ratio: KeywordRatio.hard,
            random: Random(seed),
          );
          if (result.containsKey(0)) {
            final words = tokenize(sentences[0].text);
            for (final idx in result[0]!) {
              expect(
                isStopword(words[idx]),
                isFalse,
                reason: '停用词 "${words[idx]}" 不应被选中 (seed=$seed)',
              );
            }
          }
        }
      });

      test('候选不够时用停用词补足，达到总词数 × ratio', () {
        // 12 个词：6 个停用词 (The/and/but/or/yet/also) + 6 个内容词
        final sentences = _makeSentences([
          'The beautiful and wonderful but magnificent or spectacular yet incredible also extraordinary',
        ]);
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.veryHard,
          random: Random(42),
        );
        // 总词数 12，ratio 60% → targetCount = round(12 * 0.6) = 7
        // 候选 6 个 + 停用词补 1 个 = 7
        final count = _totalKeywords(result);
        expect(count, 7);
        // 所有内容词都应被选中（优先）
        final words = tokenize(sentences[0].text);
        final picked = result[0]!;
        final pickedNonStopwordCount = picked
            .where((i) => words[i].length > 2 && !isStopword(words[i]))
            .length;
        expect(pickedNonStopwordCount, 6);
      });
    });
  });

  group('tokenize', () {
    test('按空格分词，保留标点附着在单词上', () {
      expect(tokenize('Hello, world!'), ['Hello,', 'world!']);
      expect(tokenize("it's a beautiful day"), [
        "it's",
        'a',
        'beautiful',
        'day',
      ]);
      expect(tokenize('one-two—three'), ['one-two—three']);
    });

    test('撇号缩写和所有格不拆分', () {
      expect(tokenize("don't stop"), ["don't", 'stop']);
      expect(tokenize("library's book"), ["library's", 'book']);
    });

    test('标点符号保留在输出中', () {
      expect(tokenize('Yes, I can.'), ['Yes,', 'I', 'can.']);
      expect(tokenize('Wait... what?'), ['Wait...', 'what?']);
      expect(tokenize('Hello; goodbye'), ['Hello;', 'goodbye']);
    });

    test('空字符串返回空列表', () {
      expect(tokenize(''), isEmpty);
    });
  });

  group('KeywordRatio.forDifficulty', () {
    test('5 档难度一一映射到 5 档比例', () {
      expect(
        KeywordRatio.forDifficulty(DifficultyLevel.veryEasy),
        KeywordRatio.veryEasy,
      );
      expect(
        KeywordRatio.forDifficulty(DifficultyLevel.easy),
        KeywordRatio.easy,
      );
      expect(
        KeywordRatio.forDifficulty(DifficultyLevel.medium),
        KeywordRatio.medium,
      );
      expect(
        KeywordRatio.forDifficulty(DifficultyLevel.hard),
        KeywordRatio.hard,
      );
      expect(
        KeywordRatio.forDifficulty(DifficultyLevel.veryHard),
        KeywordRatio.veryHard,
      );
    });

    test('percent 与 value 一致', () {
      expect(KeywordRatio.veryEasy.percent, 20);
      expect(KeywordRatio.veryEasy.value, closeTo(0.20, 1e-9));
      expect(KeywordRatio.easy.percent, 30);
      expect(KeywordRatio.medium.percent, 40);
      expect(KeywordRatio.hard.percent, 50);
      expect(KeywordRatio.veryHard.percent, 60);
      expect(KeywordRatio.veryHard.value, closeTo(0.60, 1e-9));
    });
  });

  group('KeywordRatio.forDifficultyAndStage', () {
    /// 期望表（5 难度 × 9 stage）。
    final expected = <DifficultyLevel, Map<LearningStage, KeywordRatio>>{
      DifficultyLevel.veryEasy: {
        LearningStage.firstLearn: KeywordRatio.medium,    // 40%
        LearningStage.review0: KeywordRatio.medium,
        LearningStage.review1: KeywordRatio.easy,         // 25%
        LearningStage.review2: KeywordRatio.easy,
        LearningStage.review4: KeywordRatio.easy,
        LearningStage.review7: KeywordRatio.veryEasy,     // 15%
        LearningStage.review14: KeywordRatio.veryEasy,
        LearningStage.review28: KeywordRatio.veryEasy,
        LearningStage.completed: KeywordRatio.veryEasy,
      },
      DifficultyLevel.easy: {
        LearningStage.firstLearn: KeywordRatio.hard,      // 60%
        LearningStage.review0: KeywordRatio.hard,
        LearningStage.review1: KeywordRatio.medium,       // 40%
        LearningStage.review2: KeywordRatio.medium,
        LearningStage.review4: KeywordRatio.medium,
        LearningStage.review7: KeywordRatio.easy,         // 25%
        LearningStage.review14: KeywordRatio.easy,
        LearningStage.review28: KeywordRatio.easy,
        LearningStage.completed: KeywordRatio.easy,
      },
      DifficultyLevel.medium: {
        LearningStage.firstLearn: KeywordRatio.veryHard,  // 80%
        LearningStage.review0: KeywordRatio.veryHard,
        LearningStage.review1: KeywordRatio.hard,         // 60%
        LearningStage.review2: KeywordRatio.hard,
        LearningStage.review4: KeywordRatio.hard,
        LearningStage.review7: KeywordRatio.medium,       // 40%
        LearningStage.review14: KeywordRatio.medium,
        LearningStage.review28: KeywordRatio.medium,
        LearningStage.completed: KeywordRatio.medium,
      },
      DifficultyLevel.hard: {
        // hard 比 medium 后移 1 stage 进入下一档
        LearningStage.firstLearn: KeywordRatio.veryHard,  // 80%
        LearningStage.review0: KeywordRatio.veryHard,
        LearningStage.review1: KeywordRatio.veryHard,
        LearningStage.review2: KeywordRatio.hard,         // 60%
        LearningStage.review4: KeywordRatio.hard,
        LearningStage.review7: KeywordRatio.hard,
        LearningStage.review14: KeywordRatio.medium,      // 40%
        LearningStage.review28: KeywordRatio.medium,
        LearningStage.completed: KeywordRatio.medium,
      },
      DifficultyLevel.veryHard: {
        // veryHard 比 medium 后移 2 stage
        LearningStage.firstLearn: KeywordRatio.veryHard,  // 80%
        LearningStage.review0: KeywordRatio.veryHard,
        LearningStage.review1: KeywordRatio.veryHard,
        LearningStage.review2: KeywordRatio.veryHard,
        LearningStage.review4: KeywordRatio.hard,         // 60%
        LearningStage.review7: KeywordRatio.hard,
        LearningStage.review14: KeywordRatio.hard,
        LearningStage.review28: KeywordRatio.medium,      // 40%
        LearningStage.completed: KeywordRatio.medium,
      },
    };

    for (final difficulty in DifficultyLevel.values) {
      for (final stage in LearningStage.values) {
        test('${difficulty.name} @ ${stage.name}', () {
          expect(
            KeywordRatio.forDifficultyAndStage(difficulty, stage),
            expected[difficulty]![stage],
            reason: '${difficulty.name} @ ${stage.name}',
          );
        });
      }
    }
  });
}
