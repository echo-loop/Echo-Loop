// BookmarkReview 单元测试。
// 测试 BookmarkSentence 数据类和 ReviewDifficultPracticeState 在收藏复习场景下的行为。
// Provider 的播放逻辑依赖 AudioEngine，集成测试在 integration_test 中覆盖。
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/models/bookmark_sentence.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/blind_flow/blind_practice_flow_phase.dart';
import 'package:echo_loop/providers/learned_vocabulary_tracker_provider.dart';
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/services/learned_vocabulary_tracker.dart';

import '../../helpers/mock_providers.dart';

class _ReplayBookmarkAudioEngine extends TestForegroundAudioEngine {
  int _sessionId = 0;

  _ReplayBookmarkAudioEngine()
    : super(
        initialState: const AudioEngineState(
          sessionId: 0,
          currentAudioId: 'audio-1',
        ),
      );

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
}

class _TestStudyStatsNotifier extends StudyStatsNotifier {
  @override
  Future<StudyStats> build() async => const StudyStats();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookmarkSentence', () {
    test('从 BookmarkWithAudio 正确转换', () {
      // 模拟 BookmarkWithAudio → BookmarkSentence 转换逻辑
      const startTime = 1.5; // 秒
      const endTime = 3.2; // 秒
      const sentenceText = 'Hello world';
      const audioItemId = 'audio-1';
      const audioName = 'Test Audio';
      const sentenceIndex = 3;

      final bookmarkSentence = BookmarkSentence(
        sentence: Sentence(
          index: sentenceIndex,
          text: sentenceText,
          startTime: Duration(milliseconds: (startTime * 1000).round()),
          endTime: Duration(milliseconds: (endTime * 1000).round()),
          isBookmarked: true,
        ),
        audioItemId: audioItemId,
        audioName: audioName,
        originalSentenceIndex: sentenceIndex,
      );

      expect(bookmarkSentence.sentence.text, sentenceText);
      expect(
        bookmarkSentence.sentence.startTime,
        const Duration(milliseconds: 1500),
      );
      expect(
        bookmarkSentence.sentence.endTime,
        const Duration(milliseconds: 3200),
      );
      expect(bookmarkSentence.audioItemId, audioItemId);
      expect(bookmarkSentence.audioName, audioName);
      expect(bookmarkSentence.originalSentenceIndex, sentenceIndex);
      expect(bookmarkSentence.sentence.isBookmarked, true);
    });

    test('句子时长计算正确', () {
      final bookmarkSentence = BookmarkSentence(
        sentence: Sentence(
          index: 0,
          text: 'Test',
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 4),
        ),
        audioItemId: 'audio-1',
        audioName: 'Audio 1',
        originalSentenceIndex: 0,
      );

      expect(bookmarkSentence.sentence.duration, const Duration(seconds: 3));
    });
  });

  group('ReviewDifficultPracticeState（收藏复习场景）', () {
    test('初始化收藏复习 — 状态正确', () {
      // 模拟 initialize 后的状态
      const state = ReviewDifficultPracticeState(
        currentSentenceIndex: 0,
        totalSentences: 5,
      );

      expect(state.currentSentenceIndex, 0);
      expect(state.totalSentences, 5);
      expect(state.isPlaying, false);
    });

    test('取消收藏后列表更新 — 移除中间句子', () {
      const state = ReviewDifficultPracticeState(
        currentSentenceIndex: 2,
        totalSentences: 5,
      );

      // 模拟 removeBookmark 后的状态（移除索引 2 后，索引不变）
      final afterRemove = state.copyWith(
        currentSentenceIndex: 2,
        totalSentences: 4,
        isPlaying: false,
        isAnnotationMode: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        currentPlayCount: 1,
      );

      expect(afterRemove.totalSentences, 4);
      expect(afterRemove.currentSentenceIndex, 2);
    });

    test('取消收藏后列表更新 — 移除最后一句回退索引', () {
      const state = ReviewDifficultPracticeState(
        currentSentenceIndex: 4,
        totalSentences: 5,
      );

      // 移除最后一句后，索引回退
      final afterRemove = state.copyWith(
        currentSentenceIndex: 3,
        totalSentences: 4,
      );

      expect(afterRemove.currentSentenceIndex, 3);
      expect(afterRemove.totalSentences, 4);
    });

    test('取消收藏后列表为空 — 停止播放', () {
      const state = ReviewDifficultPracticeState(
        currentSentenceIndex: 0,
        totalSentences: 1,
      );

      final afterRemove = state.copyWith(isPlaying: false, totalSentences: 0);

      expect(afterRemove.isPlaying, false);
      expect(afterRemove.totalSentences, 0);
    });

    test('重置到第一句（再来一遍）', () {
      // 模拟 resetToStart 后的状态
      const reset = ReviewDifficultPracticeState(
        currentSentenceIndex: 0,
        totalSentences: 5,
      );

      expect(reset.currentSentenceIndex, 0);
      expect(reset.totalSentences, 5);
    });
  });

  group('按音频分组乱序逻辑', () {
    test('同一音频的句子保持 sentenceIndex 顺序', () {
      // 模拟 3 个音频的书签
      final sentences = [
        _makeBookmarkSentence('audio-1', 'Audio 1', 0),
        _makeBookmarkSentence('audio-1', 'Audio 1', 2),
        _makeBookmarkSentence('audio-1', 'Audio 1', 5),
        _makeBookmarkSentence('audio-2', 'Audio 2', 1),
        _makeBookmarkSentence('audio-2', 'Audio 2', 3),
        _makeBookmarkSentence('audio-3', 'Audio 3', 0),
      ];

      // 按音频分组
      final grouped = <String, List<BookmarkSentence>>{};
      for (final s in sentences) {
        (grouped[s.audioItemId] ??= []).add(s);
      }

      // 验证每组内部顺序正确
      for (final group in grouped.values) {
        for (int i = 1; i < group.length; i++) {
          expect(
            group[i].originalSentenceIndex >=
                group[i - 1].originalSentenceIndex,
            true,
            reason: '组内句子应按 sentenceIndex 顺序排列',
          );
        }
      }

      expect(grouped.length, 3);
      expect(grouped['audio-1']!.length, 3);
      expect(grouped['audio-2']!.length, 2);
      expect(grouped['audio-3']!.length, 1);
    });

    test('组间乱序后组内顺序不变', () {
      final sentences = [
        _makeBookmarkSentence('audio-A', 'A', 0),
        _makeBookmarkSentence('audio-A', 'A', 1),
        _makeBookmarkSentence('audio-B', 'B', 0),
        _makeBookmarkSentence('audio-B', 'B', 1),
      ];

      final grouped = <String, List<BookmarkSentence>>{};
      for (final s in sentences) {
        (grouped[s.audioItemId] ??= []).add(s);
      }

      // 乱序音频组
      final audioIds = grouped.keys.toList()..shuffle();
      final result = <BookmarkSentence>[];
      for (final id in audioIds) {
        result.addAll(grouped[id]!);
      }

      // 验证组内顺序
      String? currentAudioId;
      int lastIndex = -1;
      for (final s in result) {
        if (s.audioItemId != currentAudioId) {
          currentAudioId = s.audioItemId;
          lastIndex = -1;
        }
        expect(s.originalSentenceIndex > lastIndex, true, reason: '组内顺序应递增');
        lastIndex = s.originalSentenceIndex;
      }
    });
  });

  group('BookmarkReview provider', () {
    test('dispose 后重新 initialize，盲听仍可再次播放', () async {
      final testDb = db.AppDatabase(
        NativeDatabase.memory(
          setup: (database) => database.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          foregroundAudioEngineProvider.overrideWith(
            () => _ReplayBookmarkAudioEngine(),
          ),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          learnedVocabularyTrackerProvider.overrideWithValue(
            LearnedVocabularyTracker(
              persistWordForms: (_) async {},
              onStatsUpdated: () {},
            ),
          ),
          studyStatsNotifierProvider.overrideWith(_TestStudyStatsNotifier.new),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(testDb.close);
      addTearDown(container.dispose);

      container.read(bookmarkReviewProvider);
      final notifier = container.read(bookmarkReviewProvider.notifier);
      final bookmarks = [
        BookmarkWithAudio(
          bookmark: db.Bookmark(
            id: 1,
            audioItemId: 'audio-1',
            sentenceIndex: 0,
            sentenceText: 'First sentence',
            startTime: 0,
            endTime: 1,
            createdAt: DateTime(2026, 4, 3, 9),
            updatedAt: DateTime(2026, 4, 3, 9),
            syncStatus: 0,
          ),
          audioName: 'Audio 1',
        ),
      ];

      notifier.initialize(bookmarks, getAudioItemById: (_) async => null);
      unawaited(notifier.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(bookmarkReviewProvider).blindFlowState?.phase,
        isA<BlindPlayingPrompt>(),
      );

      notifier.disposePlayer();

      notifier.initialize(bookmarks, getAudioItemById: (_) async => null);
      unawaited(notifier.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(bookmarkReviewProvider);
      expect(state.totalSentences, 1);
      expect(state.blindFlowState?.phase, isA<BlindPlayingPrompt>());
      expect(state.isPlaying, isTrue);

      notifier.disposePlayer();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });
}

/// 辅助方法：创建 BookmarkSentence
BookmarkSentence _makeBookmarkSentence(
  String audioId,
  String audioName,
  int sentenceIndex,
) {
  return BookmarkSentence(
    sentence: Sentence(
      index: sentenceIndex,
      text: 'Sentence $sentenceIndex from $audioName',
      startTime: Duration(seconds: sentenceIndex * 5),
      endTime: Duration(seconds: sentenceIndex * 5 + 3),
      isBookmarked: true,
    ),
    audioItemId: audioId,
    audioName: audioName,
    originalSentenceIndex: sentenceIndex,
  );
}
