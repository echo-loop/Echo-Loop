/// 测试用 DAO 替身（共享）
///
/// 供 `test/helpers/mock_providers.dart` 和 `integration_test/helpers/test_notifiers.dart`
/// 共同使用。
///
/// 所有 DAO 替身默认返回空/零值，不访问真实数据库。
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;

import 'package:echo_loop/database/app_database.dart'
    show AudioItem, Bookmark, BookmarksCompanion, SavedWord;
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart'
    show BookmarkDao, BookmarkWithAudio;
import 'package:echo_loop/database/daos/saved_word_dao.dart';
import 'package:echo_loop/database/daos/stage_completion_dao.dart'
    show StageCompletionDao, RecentCompletion;
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/services/source_sentence_anchor.dart';

// ========== FakeAudioItemDao ==========

/// 无操作 AudioItemDao — 默认查询返回 null/空；字幕内容与词级时间戳走内存存储，
/// 方便测试断言 transcript_srt 写入。
class FakeAudioItemDao implements AudioItemDao {
  /// 内存存储：audioItemId → 字幕 SRT 内容
  final Map<String, String?> transcriptSrtStore = {};

  /// 内存存储：audioItemId → 词级时间戳 JSON
  final Map<String, String?> wordTimestampsStore = {};

  @override
  Future<AudioItem?> getById(String id) async => null;

  @override
  Future<String?> getTranscriptSrt(String audioItemId) async =>
      transcriptSrtStore[audioItemId];

  @override
  Future<void> updateTranscriptSrt(String audioItemId, String? srt) async {
    transcriptSrtStore[audioItemId] = srt;
  }

  @override
  Future<String?> getWordTimestamps(String audioItemId) async =>
      wordTimestampsStore[audioItemId];

  @override
  Future<void> updateWordTimestamps(String audioItemId, String? json) async {
    wordTimestampsStore[audioItemId] = json;
  }

  @override
  Future<void> saveTranscriptContent(
    String audioItemId, {
    required String srt,
    required String? wordTimestampsJson,
  }) async {
    transcriptSrtStore[audioItemId] = srt;
    wordTimestampsStore[audioItemId] = wordTimestampsJson;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value();
}

// ========== FakeStageCompletionDao ==========

/// 无操作 StageCompletionDao — 所有查询返回空/即时完成
class FakeStageCompletionDao implements StageCompletionDao {
  @override
  Future<List<RecentCompletion>> getRecentCompletions(DateTime since) async =>
      [];

  @override
  Future<Map<String, Set<String>>> getCompletionKeysByAudio() async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

// ========== FakeBookmarkDao ==========

/// 测试用 BookmarkDao — 内存存储，支持 watchByAudioId
class FakeBookmarkDao implements BookmarkDao {
  /// 用于 watchBookmarkedIndices 返回的书签数量
  int bookmarkCount = 0;

  /// 各音频的当前字幕（测试预置）；与真实 DAO 一样，收藏按区间中点定位到它。
  final Map<String, List<Sentence>> transcripts = {};

  /// 未预置字幕时，用经 [getForSentence] 传入过的句子充当当前字幕。
  final Map<String, Map<int, Sentence>> _seenSentences = {};

  final List<Bookmark> _rows = [];
  int _nextId = 1;

  /// 按区间中点定位到当前字幕，返回句子的 index。
  int? _indexOf(String audioItemId, Duration start, Duration end) {
    final transcript = transcripts[audioItemId];
    final sentences =
        transcript ??
        ((_seenSentences[audioItemId]?.values.toList() ?? <Sentence>[])
          ..sort((a, b) => a.startTime.compareTo(b.startTime)));
    final position = resolveSourceSentenceIndex(
      SourceSentenceAnchor(start: start, end: end),
      sentences,
    );
    return position == null ? null : sentences[position].index;
  }

  int? _indexOfRow(Bookmark row) => _indexOf(
    row.audioItemId,
    Duration(milliseconds: (row.startTime * 1000).round()),
    Duration(milliseconds: (row.endTime * 1000).round()),
  );

  List<Bookmark> _activeOf(String audioItemId) => [
    for (final row in _rows)
      if (row.audioItemId == audioItemId && row.deletedAt == null) row,
  ];

  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async =>
      _activeOf(audioItemId);

  @override
  Future<Bookmark?> getById(int id) async =>
      _rows.where((row) => row.id == id).firstOrNull;

  @override
  Future<Bookmark?> getActiveBySubjectId(String memorySubjectId) async => _rows
      .where(
        (row) =>
            row.memorySubjectId == memorySubjectId && row.deletedAt == null,
      )
      .firstOrNull;

  @override
  Future<Set<int>> getBookmarkedIndices(String audioItemId) async => {
    for (final row in _activeOf(audioItemId)) ?_indexOfRow(row),
  };

  @override
  Future<({int? index, List<Bookmark> bookmarks})> getForSentence(
    String audioItemId,
    Sentence sentence,
  ) async {
    _seenSentences.putIfAbsent(
      audioItemId,
      () => {},
    )[sentence.startTime.inMilliseconds] = sentence;
    final index = _indexOf(audioItemId, sentence.startTime, sentence.endTime);
    if (index == null) return (index: null, bookmarks: const <Bookmark>[]);
    return (
      index: index,
      bookmarks: [
        for (final row in _rows)
          if (row.audioItemId == audioItemId && _indexOfRow(row) == index) row,
      ],
    );
  }

  @override
  Future<void> addBookmark(BookmarksCompanion entry) async {
    final now = DateTime.now();
    final id = _nextId++;
    _rows.add(
      Bookmark(
        id: id,
        memorySubjectId: entry.memorySubjectId.present
            ? entry.memorySubjectId.value
            : 'fake-subject-$id',
        audioItemId: entry.audioItemId.value,
        sentenceText: entry.sentenceText.present
            ? entry.sentenceText.value
            : '',
        startTime: entry.startTime.present ? entry.startTime.value : 0,
        endTime: entry.endTime.present ? entry.endTime.value : 0,
        createdAt: entry.createdAt.present ? entry.createdAt.value : now,
        updatedAt: entry.updatedAt.present ? entry.updatedAt.value : now,
        syncStatus: 0,
      ),
    );
  }

  @override
  Future<void> reviveWithSentence(int id, Sentence sentence) async {
    final i = _rows.indexWhere((row) => row.id == id);
    if (i < 0) return;
    _rows[i] = _rows[i].copyWith(
      sentenceText: sentence.text,
      startTime: sentence.startTime.inMilliseconds / 1000.0,
      endTime: sentence.endTime.inMilliseconds / 1000.0,
      deletedAt: const Value(null),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> softDeleteByIds(Iterable<int> ids) async {
    final idSet = ids.toSet();
    for (var i = 0; i < _rows.length; i++) {
      if (idSet.contains(_rows[i].id)) {
        _rows[i] = _rows[i].copyWith(deletedAt: Value(DateTime.now()));
      }
    }
  }

  @override
  Future<void> restoreById(int id) async {
    final i = _rows.indexWhere((row) => row.id == id);
    if (i >= 0) _rows[i] = _rows[i].copyWith(deletedAt: const Value(null));
  }

  @override
  Future<void> removeAllForAudio(String audioItemId) async {
    _rows.removeWhere((row) => row.audioItemId == audioItemId);
  }

  @override
  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() => Stream.value([
    for (final row in _rows)
      if (row.deletedAt == null)
        BookmarkWithAudio(bookmark: row, audioName: 'Test Audio'),
  ]);

  @override
  Future<int> countAll() async =>
      _rows.where((row) => row.deletedAt == null).length;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    if (memberName.contains('watchBookmarkedIndices')) {
      return Stream.value({for (var i = 0; i < bookmarkCount; i++) i});
    }
    return null;
  }
}

// ========== FakeSavedWordDao ==========

/// 空操作 SavedWordDao — 所有查询返回空
class FakeSavedWordDao implements SavedWordDao {
  @override
  Future<List<SavedWord>> getAll() => Future.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
