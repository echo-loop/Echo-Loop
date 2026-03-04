import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/retell_settings.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/utils/keyword_extraction.dart';

/// 辅助函数：创建带指定文本的句子列表
List<Sentence> _makeSentences(List<String> texts) {
  return texts.asMap().entries.map((e) => Sentence(
        index: e.key,
        text: e.value,
        startTime: Duration(seconds: e.key * 5),
        endTime: Duration(seconds: (e.key + 1) * 5),
      )).toList();
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

    test('短句（所有词 ≤ 4 字符但 > 2 字符）也能选出关键词', () {
      final sentences = _makeSentences(['I am a dog', 'Go to bed now']);
      final result = extractKeywords(sentences, random: Random(42));
      // 候选词（长度>2）：dog(3), bed(3), now(3) → 应有关键词
      expect(result, isNotEmpty);
      expect(_totalKeywords(result), greaterThanOrEqualTo(1));
    });

    test('至少提取 1 个关键词（保底机制）', () {
      final sentences = _makeSentences([
        'The beautiful sunset illuminated the entire valley',
      ]);
      final result = extractKeywords(sentences, random: Random(42));
      expect(_totalKeywords(result), greaterThanOrEqualTo(1));
    });

    test('单词句也能选出 1 个关键词', () {
      final sentences = _makeSentences(['Hello']);
      final result = extractKeywords(sentences, random: Random(42));
      // "Hello" 长度 5 > 2，是候选词
      expect(_totalKeywords(result), equals(1));
    });

    test('关键词索引在有效范围内', () {
      final sentences = _makeSentences([
        'Understanding complex algorithms requires practice',
        'Mathematical foundations provide essential knowledge',
      ]);
      final result = extractKeywords(sentences, random: Random(42));
      for (final entry in result.entries) {
        expect(entry.key, inInclusiveRange(0, 1),
            reason: '句子索引超出范围');
        for (final wordIdx in entry.value) {
          final words = tokenize(sentences[entry.key].text);
          expect(wordIdx, inInclusiveRange(0, words.length - 1),
              reason: '词索引超出范围');
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

    test('每句至少有 1 个关键词（有候选词的情况下）', () {
      final sentences = _makeSentences([
        'The beautiful sunset illuminated the valley',
        'Complex algorithms require practice',
        'Mathematical foundations knowledge',
      ]);
      final result = extractKeywords(
        sentences,
        ratio: KeywordRatio.oneTenth,
        random: Random(42),
      );
      // 每句都有候选词（长度>2），所以每句至少 1 个
      for (var i = 0; i < sentences.length; i++) {
        expect(result.containsKey(i), isTrue,
            reason: '句子 $i 应该至少有 1 个关键词');
        expect(result[i]!.length, greaterThanOrEqualTo(1));
      }
    });

    group('比例测试', () {
      // 构造大量长词句子用于比例验证
      final sentences = _makeSentences([
        'absolutely beautiful certainly delightful especially fantastic generally hopefully',
        'incredibly joyfully knowledgeable lovingly meaningfully naturally obviously potentially',
        'remarkably significantly tremendously unfortunately wonderfully yesterday',
      ]);

      // 总词数 22，全部 > 2 字符
      test('1/2 比例选出约 50% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.half,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.5 = 11
        expect(count, inInclusiveRange(8, 14));
      });

      test('1/3 比例选出约 33% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.oneThird,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.333 ≈ 7
        expect(count, inInclusiveRange(5, 10));
      });

      test('1/5 比例选出约 20% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.oneFifth,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.2 ≈ 4，但每句至少 1 个（3 句 → 至少 3）
        expect(count, inInclusiveRange(3, 7));
      });

      test('1/10 比例选出约 10% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.oneTenth,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.1 ≈ 2，但每句至少 1 个（3 句 → 至少 3）
        expect(count, inInclusiveRange(3, 5));
      });
    });

    test('长词被选中的概率更高（统计验证）', () {
      // 构造一个短候选词（3 字母）和一个长候选词（15 字母）
      final sentences = _makeSentences([
        'dog internationally',
      ]);
      // 运行多次统计
      var longWordSelected = 0;
      const runs = 1000;
      for (var i = 0; i < runs; i++) {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.oneTenth,
          random: Random(i),
        );
        // ratio 1/10 → target = max(1, round(2*0.1)) = 1，但每句至少1
        // 所以只选 1 个关键词
        if (result.isNotEmpty && result[0]!.contains(1)) {
          longWordSelected++;
        }
      }
      // "internationally"(15 字母) 应比 "dog"(3 字母) 更常被选中
      // 期望比例：15/(15+3) ≈ 83%
      expect(longWordSelected, greaterThan(runs * 0.6));
    });
  });

  group('tokenize', () {
    test('按空格和标点分词', () {
      expect(tokenize('Hello, world!'), ['Hello', 'world']);
      expect(tokenize("it's a beautiful day"), ["it's", 'a', 'beautiful', 'day']);
      expect(tokenize('one-two—three'), ['one', 'two', 'three']);
    });

    test('撇号缩写和所有格不拆分', () {
      expect(tokenize("don't stop"), ["don't", 'stop']);
      expect(tokenize("library's book"), ["library's", 'book']);
    });

    test('空字符串返回空列表', () {
      expect(tokenize(''), isEmpty);
    });
  });
}
