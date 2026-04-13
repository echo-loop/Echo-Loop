import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/services/speech_completion_detector.dart';

/// 快速构建 SpeechMatchContext
SpeechMatchContext buildCtx(String reference, String transcript) {
  return buildMatchContext(
    referenceText: reference,
    partialTranscript: transcript,
  );
}

void main() {

  // 10 个不重复的单词，用于需要精确定位的测试
  // "alpha bravo charlie delta echo foxtrot golf hotel india juliet"
  const tenWords =
      'alpha bravo charlie delta echo foxtrot golf hotel india juliet';

  // ================================================================
  // 检测 D：剩余词数估算阈值
  // ================================================================
  group('detectRemainingByPosition (规则 D)', () {
    // ── 基本触发 ──

    test('末尾 1 词在 reference 中唯一，有剩余词 → 触发', () {
      // transcript: "alpha bravo charlie" → 末尾 "charlie" 在 reference index 2 唯一
      // remaining = 10 - 3 = 7
      final ctx = buildCtx(tenWords, 'alpha bravo charlie');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      // base=1 + 7*1 = 8s
      expect(result.threshold, const Duration(seconds: 8));
    });

    test('末尾 3 词组成唯一子串 → 触发，用更可靠的长串定位', () {
      // reference: "she went to the big store on the corner"
      // transcript: "she went to the big store"
      // 末尾 5 词 "went to the big store" 唯一 → endIndex 5
      // remaining = 9 - 6 = 3
      final ctx = buildCtx(
        'she went to the big store on the corner',
        'she went to the big store',
      );
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      // base=1 + 3*1 = 4s
      expect(result.threshold, const Duration(seconds: 4));
    });

    test('末尾 5 词唯一子串 → 触发', () {
      // transcript: "alpha bravo charlie delta echo"
      // 末尾 5 词唯一 → endIndex 4, remaining = 10 - 5 = 5
      final ctx = buildCtx(tenWords, 'alpha bravo charlie delta echo');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      // base=1 + 5*1 = 6s
      expect(result.threshold, const Duration(seconds: 6));
    });

    // ── 优先长串 ──

    test('末尾 1 词和 3 词都唯一时 → 选最长（更可靠）', () {
      final ctx = buildCtx(tenWords, 'alpha bravo charlie');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      // 末尾 3 词 "alpha bravo charlie" 唯一 → 选 3 词
      expect(result.description, contains('3词'));
    });

    test('末尾 1 词唯一但 2 词不唯一 → 用 1 词', () {
      // reference: "go to go home now"
      // transcript: "go to go"
      // 末尾 1 词 "go" → 出现 3 次，非唯一
      // 末尾 2 词 "to go" → 出现 1 次 → 唯一
      // 末尾 3 词 "go to go" → 出现 1 次 → 唯一 → 最长优先
      final ctx = buildCtx('go to go home now', 'go to go');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      expect(result.description, contains('3词'));
    });

    // ── 不触发场景 ──

    test('transcript 为空 → 不触发', () {
      final ctx = buildCtx('hello world', '');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isFalse);
      expect(result.description, contains('transcript为空'));
    });

    test('reference 为空 → 不触发', () {
      final ctx = buildCtx('', 'hello');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isFalse);
      expect(result.description, contains('reference为空'));
    });

    test('末尾所有候选子串在 reference 中都非唯一 → 不触发', () {
      final ctx = buildCtx('the the the the the', 'the the');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isFalse);
      expect(result.description, contains('无唯一匹配'));
    });

    test('唯一匹配但 remaining == 0（已在末尾） → 不触发', () {
      final ctx = buildCtx('unique word', 'unique word');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isFalse);
      expect(result.description, contains('剩余0词'));
    });

    // ── 剩余词数计算 ──

    test('reference 10 词，匹配位置在第 3 词 → remaining = 7', () {
      // "charlie" 唯一, index 2, remaining = 10 - 3 = 7
      final ctx = buildCtx(tenWords, 'charlie');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      expect(result.threshold, const Duration(seconds: 8)); // 1+7
    });

    test('reference 10 词，匹配位置在第 9 词（倒数第 2） → remaining = 1', () {
      // "india" 唯一, index 8, remaining = 10 - 9 = 1
      final ctx = buildCtx(tenWords, 'india');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      expect(result.threshold, const Duration(seconds: 2)); // 1+1
    });

    test('reference 10 词，匹配位置在第 10 词（最后） → remaining = 0，不触发', () {
      // "juliet" 唯一, index 9, remaining = 0
      final ctx = buildCtx(tenWords, 'juliet');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isFalse);
    });

    // ── 参数差异 ──

    test('跟读默认参数（base=1, perWord=1）：remaining=5 → 6s', () {
      // "echo" 唯一, index 4, remaining = 10 - 5 = 5
      final ctx = buildCtx(tenWords, 'echo');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      expect(result.threshold, const Duration(seconds: 6));
    });

    test('复述参数（base=2, perWord=3）：remaining=5 → 17s', () {
      final ctx = buildCtx(tenWords, 'echo');
      final result = detectRemainingByPosition(
        ctx,
        secondsPerWord: 3,
        baseSeconds: 2,
      );
      expect(result.triggered, isTrue);
      expect(result.threshold, const Duration(seconds: 17));
    });

    // ── 边界情况 ──

    test('transcript 只有 1 个词 → 只枚举长度 1 的子串', () {
      final ctx = buildCtx('hello world goodbye', 'world');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      // "world" 唯一, endIndex=1, remaining=1
      expect(result.threshold, const Duration(seconds: 2));
      expect(result.description, contains('1词'));
    });

    test('transcript 有 3 个词 → 枚举长度 1-3（不到 5）', () {
      final ctx = buildCtx(tenWords, 'alpha bravo charlie');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      // 末尾 3 词 "alpha bravo charlie" 唯一 → endIndex=2, remaining=7
      expect(result.threshold, const Duration(seconds: 8));
    });

    test('reference 中同一子串出现 2 次 → 非唯一，不触发', () {
      final ctx = buildCtx('go home go home', 'go home');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isFalse);
    });

    test('子串跨越 reference 中不同位置的相同词 → 正确判定唯一性', () {
      // reference: "big cat and small cat here"
      // "cat" 出现 2 次 → 非唯一
      // "small cat" 出现 1 次 (index 3-4) → 唯一! endIndex=4, remaining=1
      final ctx = buildCtx('big cat and small cat here', 'small cat');
      final result = detectRemainingByPosition(ctx);
      expect(result.triggered, isTrue);
      expect(result.threshold, const Duration(seconds: 2)); // 1+1
    });
  });

  // ================================================================
  // 与其他规则的组合
  // ================================================================
  group('combineDetections 与规则 D 组合', () {
    test('D 触发但 A 给出更短阈值 → 取 A（最短）', () {
      // 完全匹配整句 → A 触发 1s，D 不触发（remaining=0）
      final ctx = buildCtx(tenWords, tenWords);
      final ruleD = detectRemainingByPosition(ctx);
      final ruleA = detectTailMatch(ctx);

      expect(ruleA.triggered, isTrue);
      expect(ruleA.threshold, const Duration(seconds: 1));
      expect(ruleD.triggered, isFalse);

      final combined = combineDetections(
        [ruleD, ruleA],
        ctx,
        fallback: const Duration(seconds: 5),
      );
      expect(combined.threshold, const Duration(seconds: 1));
    });

    test('D 触发且阈值最短 → 使用 D 的阈值', () {
      // transcript 说到 "india"(index 8), remaining=1 → D: 1+1=2s
      // C: 末尾 5 词命中 1 个 → 5s
      final ctx = buildCtx(tenWords, 'india');
      final ruleD = detectRemainingByPosition(ctx);
      final ruleC = detectTailHitCount(ctx);

      expect(ruleD.triggered, isTrue);
      expect(ruleD.threshold, const Duration(seconds: 2));
      expect(ruleC.triggered, isTrue);

      final combined = combineDetections(
        [ruleD, ruleC],
        ctx,
        fallback: const Duration(seconds: 5),
      );
      expect(combined.threshold, const Duration(seconds: 2));
    });
  });

  // ================================================================
  // 动态兜底：computeDynamicFallback
  // ================================================================
  group('computeDynamicFallback', () {
    // 基准：referenceDuration = 10s, speedFactor = 1.1 → adjustedDuration = 11s

    const ref10s = Duration(seconds: 10); // 原句 10s

    test('referenceDuration <= 0 → 返回 defaultFallback', () {
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(seconds: 15),
          referenceDuration: Duration.zero,
        ),
        const Duration(seconds: 5),
      );
    });

    test('matchRate < 0.8 → 返回 defaultFallback', () {
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(seconds: 15),
          referenceDuration: ref10s,
          matchRate: 0.5,
        ),
        const Duration(seconds: 5),
      );
    });

    test('matchRate = null（无转录）+ ratio >= 0.95 → 1s', () {
      // voiced = 10.5s, adjusted = 11s → ratio ≈ 0.955
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(milliseconds: 10500),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 1),
      );
    });

    test('matchRate = null + ratio >= 0.90 → 2s', () {
      // voiced = 9.9s, adjusted = 11s → ratio = 0.90
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(milliseconds: 9900),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 2),
      );
    });

    test('matchRate = null + ratio >= 0.85 → 3s', () {
      // voiced = 9.35s, adjusted = 11s → ratio = 0.85
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(milliseconds: 9350),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 3),
      );
    });

    test('matchRate = null + ratio >= 0.80 → 4s', () {
      // voiced = 8.8s, adjusted = 11s → ratio = 0.80
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(milliseconds: 8800),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 4),
      );
    });

    test('matchRate = null + ratio >= 0.75 → 5s', () {
      // voiced = 8.25s, adjusted = 11s → ratio = 0.75
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(milliseconds: 8250),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 5),
      );
    });

    test('matchRate = null + ratio < 0.75 → defaultFallback (5s)', () {
      // voiced = 8s, adjusted = 11s → ratio ≈ 0.727
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(seconds: 8),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 5),
      );
    });

    test('matchRate >= 0.8 时动态兜底生效', () {
      // voiced = 10.5s, adjusted = 11s → ratio ≈ 0.955, matchRate = 0.8 → 1s
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(milliseconds: 10500),
          referenceDuration: ref10s,
          matchRate: 0.8,
        ),
        const Duration(seconds: 1),
      );
    });

    test('matchRate = 0.79 时即使 ratio 很高也返回 defaultFallback', () {
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(seconds: 20),
          referenceDuration: ref10s,
          matchRate: 0.79,
        ),
        const Duration(seconds: 5),
      );
    });

    test('speedFactor 自定义', () {
      // ref = 10s, speedFactor = 1.0 → adjusted = 10s
      // voiced = 10s → ratio = 1.0 → 1s
      expect(
        computeDynamicFallback(
          voicedDuration: const Duration(seconds: 10),
          referenceDuration: ref10s,
          speedFactor: 1.0,
        ),
        const Duration(seconds: 1),
      );
    });
  });

  group('computeRetellDynamicFallback', () {
    // 基准：referenceDuration = 10s, speedFactor = 1.3 → adjustedDuration = 13s

    const ref10s = Duration(seconds: 10);

    test('referenceDuration <= 0 → 返回 defaultFallback (20s)', () {
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(seconds: 15),
          referenceDuration: Duration.zero,
        ),
        const Duration(seconds: 20),
      );
    });

    test('matchRate < 0.8 → 返回 defaultFallback (20s)', () {
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(seconds: 15),
          referenceDuration: ref10s,
          matchRate: 0.5,
        ),
        const Duration(seconds: 20),
      );
    });

    test('matchRate = null（无转录）+ ratio >= 0.95 → 3s', () {
      // voiced = 12.35s, adjusted = 13s → ratio = 0.95
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(milliseconds: 12350),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 3),
      );
    });

    test('matchRate = null + ratio >= 0.90 → 6s', () {
      // voiced = 11.7s, adjusted = 13s → ratio = 0.90
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(milliseconds: 11700),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 6),
      );
    });

    test('matchRate = null + ratio >= 0.85 → 10s', () {
      // voiced = 11.05s, adjusted = 13s → ratio = 0.85
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(milliseconds: 11050),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 10),
      );
    });

    test('matchRate = null + ratio >= 0.80 → 15s', () {
      // voiced = 10.4s, adjusted = 13s → ratio = 0.80
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(milliseconds: 10400),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 15),
      );
    });

    test('matchRate = null + ratio >= 0.75 → 20s', () {
      // voiced = 9.75s, adjusted = 13s → ratio = 0.75
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(milliseconds: 9750),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 20),
      );
    });

    test('matchRate = null + ratio < 0.75 → defaultFallback (20s)', () {
      // voiced = 9s, adjusted = 13s → ratio ≈ 0.692
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(seconds: 9),
          referenceDuration: ref10s,
        ),
        const Duration(seconds: 20),
      );
    });

    test('matchRate >= 0.8 时动态兜底生效', () {
      // voiced = 12.35s, adjusted = 13s → ratio = 0.95, matchRate = 0.8 → 3s
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(milliseconds: 12350),
          referenceDuration: ref10s,
          matchRate: 0.8,
        ),
        const Duration(seconds: 3),
      );
    });

    test('matchRate = 0.79 时即使 ratio 很高也返回 defaultFallback', () {
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(seconds: 20),
          referenceDuration: ref10s,
          matchRate: 0.79,
        ),
        const Duration(seconds: 20),
      );
    });

    test('speedFactor 自定义', () {
      // ref = 10s, speedFactor = 1.0 → adjusted = 10s
      // voiced = 10s → ratio = 1.0 → 3s
      expect(
        computeRetellDynamicFallback(
          voicedDuration: const Duration(seconds: 10),
          referenceDuration: ref10s,
          speedFactor: 1.0,
        ),
        const Duration(seconds: 3),
      );
    });
  });
}
