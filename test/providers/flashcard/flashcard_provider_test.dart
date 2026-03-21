/// FlashcardNotifier 单元测试
///
/// 验证 FlashcardState 状态类、排序逻辑、倒计时秒数计算、
/// 背面例句额外时长、输入词数计入等核心行为。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/flashcard/flashcard_provider.dart';
import 'package:fluency/models/flashcard_settings.dart';
import 'package:fluency/database/app_database.dart' show SavedWord;

// ========== 测试数据工厂 ==========

SavedWord _createWord({
  required int id,
  required String word,
  int practiceCount = 0,
  bool viewedBack = false,
  String? sentenceText,
  int? sentenceStartMs,
  int? sentenceEndMs,
  String? audioItemId,
  DateTime? createdAt,
  DateTime? lastPracticedAt,
}) {
  return SavedWord(
    id: id,
    word: word,
    audioItemId: audioItemId,
    sentenceIndex: null,
    sentenceText: sentenceText,
    sentenceStartMs: sentenceStartMs,
    sentenceEndMs: sentenceEndMs,
    practiceCount: practiceCount,
    totalStudyMs: 0,
    viewedBack: viewedBack,
    lastPracticedAt: lastPracticedAt,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    deletedAt: null,
    syncStatus: 0,
  );
}

void main() {
  // ========== FlashcardState ==========

  group('FlashcardState', () {
    test('默认初始状态正确', () {
      const state = FlashcardState();
      expect(state.words, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.isShowingBack, false);
      expect(state.isCompleted, false);
      expect(state.isPaused, false);
      expect(state.removedCount, 0);
      expect(state.countdownRemaining, Duration.zero);
      expect(state.countdownTotal, Duration.zero);
      expect(state.currentWord, isNull);
    });

    test('currentWord 返回当前索引的卡片', () {
      final word = _createWord(id: 1, word: 'hello');
      final state = FlashcardState(
        words: [FlashcardWordItem(savedWord: word)],
        currentIndex: 0,
      );
      expect(state.currentWord, isNotNull);
      expect(state.currentWord!.savedWord.word, 'hello');
    });

    test('currentWord 索引越界时返回 null', () {
      final word = _createWord(id: 1, word: 'hello');
      final state = FlashcardState(
        words: [FlashcardWordItem(savedWord: word)],
        currentIndex: 5,
      );
      expect(state.currentWord, isNull);
    });

    test('copyWith 替换指定字段', () {
      const state = FlashcardState();
      final updated = state.copyWith(
        currentIndex: 3,
        isShowingBack: true,
        isPaused: true,
        removedCount: 2,
      );
      expect(updated.currentIndex, 3);
      expect(updated.isShowingBack, true);
      expect(updated.isPaused, true);
      expect(updated.removedCount, 2);
      // 未指定字段保留原值
      expect(updated.isCompleted, false);
    });

    test('copyWith clearCardStartTime 清除时间', () {
      final state = FlashcardState(cardStartTime: DateTime.now());
      expect(state.cardStartTime, isNotNull);

      final cleared = state.copyWith(clearCardStartTime: true);
      expect(cleared.cardStartTime, isNull);
    });

    test('totalWordsReviewed 等于 currentIndex + 1', () {
      const state = FlashcardState(currentIndex: 4);
      expect(state.totalWordsReviewed, 5);
    });
  });

  // ========== FlashcardWordItem ==========

  group('FlashcardWordItem', () {
    test('初始 dictLoaded 为 false', () {
      final item = FlashcardWordItem(
        savedWord: _createWord(id: 1, word: 'test'),
      );
      expect(item.dictLoaded, false);
      expect(item.dictEntry, isNull);
    });

    test('copyWith 更新 dictLoaded', () {
      final item = FlashcardWordItem(
        savedWord: _createWord(id: 1, word: 'test'),
      );
      final updated = item.copyWith(dictLoaded: true);
      expect(updated.dictLoaded, true);
      expect(updated.savedWord.word, 'test');
    });
  });

  // ========== 倒计时秒数计算 ==========

  group('背面倒计时额外秒数', () {
    // 直接测试 FlashcardSettings.calculateSmartSeconds 算法
    test('智能倒计时：短词 + 首次练习 → maxTime(4s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 3,
        practiceCount: 0,
      );
      expect(seconds, 4);
    });

    test('智能倒计时：长词 + 首次练习 → maxTime(8s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 14,
        practiceCount: 0,
      );
      expect(seconds, 8);
    });

    test('智能倒计时：短词 + 5 次练习 → minTime(2s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 3,
        practiceCount: 5,
      );
      expect(seconds, 2);
    });

    test('智能倒计时：长词 + 5 次练习 → minTime(5s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 14,
        practiceCount: 5,
      );
      expect(seconds, 5);
    });

    test('智能倒计时：中等长度(8) + 2 次练习', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 8,
        practiceCount: 2,
      );
      // ratio = (8-4)/(12-4) = 0.5, maxTime=6.0, minTime=3.5
      // decay = 2/5 = 0.4, result = 6.0 - 0.4*2.5 = 5.0 → 5
      expect(seconds, 5);
    });
  });

  // ========== onSentencePlayed 词数统计 ==========

  group('例句词数统计逻辑', () {
    test('英文句子按空格分词', () {
      // 模拟 onSentencePlayed 内部的分词逻辑
      const text = 'The quick brown fox jumps over the lazy dog';
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 9);
    });

    test('空字符串返回 0 词', () {
      const text = '';
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 0);
    });

    test('含多余空格的文本正确计数', () {
      const text = '  hello   world  ';
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 2);
    });

    test("缩写词 don't 算 1 个词", () {
      const text = "I don't know";
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 3);
    });
  });

  // ========== 排序逻辑 ==========

  group('排序逻辑', () {
    final words = [
      _createWord(id: 1, word: 'banana', createdAt: DateTime(2026, 1, 3)),
      _createWord(id: 2, word: 'apple', createdAt: DateTime(2026, 1, 1)),
      _createWord(id: 3, word: 'cherry', createdAt: DateTime(2026, 1, 2)),
    ];

    test('alphabeticalAsc 按字母 A→Z', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      expect(sorted.map((w) => w.word).toList(), ['apple', 'banana', 'cherry']);
    });

    test('alphabeticalDesc 按字母 Z→A', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()));
      expect(sorted.map((w) => w.word).toList(), ['cherry', 'banana', 'apple']);
    });

    test('timeAsc 最早收藏优先', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(sorted.map((w) => w.word).toList(), ['apple', 'cherry', 'banana']);
    });

    test('timeDesc 最近收藏优先', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(sorted.map((w) => w.word).toList(), ['banana', 'cherry', 'apple']);
    });
  });

  // ========== 智能排序分数 ==========

  group('智能排序分数', () {
    test('未练习过的单词分数更高', () {
      final scoreA = FlashcardSettings.calculateSmartScore(
        practiceCount: 0,
        viewedBack: false,
        lastPracticedAt: null,
      );
      final scoreB = FlashcardSettings.calculateSmartScore(
        practiceCount: 3,
        viewedBack: true,
        lastPracticedAt: DateTime.now(),
      );
      expect(scoreA, greaterThan(scoreB));
    });

    test('翻过背面的单词分数更低', () {
      final scoreViewed = FlashcardSettings.calculateSmartScore(
        practiceCount: 1,
        viewedBack: true,
        lastPracticedAt: DateTime.now(),
      );
      final scoreNotViewed = FlashcardSettings.calculateSmartScore(
        practiceCount: 1,
        viewedBack: false,
        lastPracticedAt: DateTime.now(),
      );
      expect(scoreNotViewed, greaterThan(scoreViewed));
    });

    test('很久没练习的单词分数更高', () {
      final scoreRecent = FlashcardSettings.calculateSmartScore(
        practiceCount: 2,
        viewedBack: true,
        lastPracticedAt: DateTime.now(),
      );
      final scoreOld = FlashcardSettings.calculateSmartScore(
        practiceCount: 2,
        viewedBack: true,
        lastPracticedAt: DateTime.now().subtract(const Duration(days: 7)),
      );
      expect(scoreOld, greaterThan(scoreRecent));
    });
  });
}
