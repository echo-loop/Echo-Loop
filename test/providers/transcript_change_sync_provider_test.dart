// 字幕替换后学习数据同步：真实数据库 + 真实收藏生命周期 / 学习进度持久化。
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/favorite_sentence_lifecycle_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/source_sentence_index_provider.dart';
import 'package:echo_loop/providers/transcript_change_sync_provider.dart';
import 'package:echo_loop/services/subtitle_parser.dart';
import 'package:echo_loop/utils/srt_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

const _audioId = 'audio-1';

/// 只覆盖 build 初始状态，持久化走真实 DAO。
class _EmptyLearningProgressNotifier extends LearningProgressNotifier {
  @override
  LearningProgressState build() {
    super.build();
    return const LearningProgressState();
  }
}

String _srt(List<(int, int, String)> cues) => generateSrtContent([
  for (final cue in cues)
    TranscriptSentence(
      text: cue.$3,
      startTime: Duration(seconds: cue.$1),
      endTime: Duration(seconds: cue.$2),
    ),
]);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  /// 原字幕：S0..S5，每句 2 秒。
  final originalCues = [
    for (var i = 0; i < 6; i++) (i * 2, i * 2 + 2, 'Sentence $i'),
  ];

  /// 编辑后：S0 拆成两句、S1+S2 合并、S3 改字、S4 删除、S5 不变。
  final editedCues = [
    (0, 1, 'Sentence'),
    (1, 2, '0'),
    (2, 6, 'Sentence 1 Sentence 2'),
    (6, 8, 'Sentence three'),
    (10, 12, 'Sentence 5'),
  ];

  late List<Sentence> oldSentences;
  late List<Sentence> newSentences;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    container = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(db),
        learningProgressProvider.overrideWith(
          _EmptyLearningProgressNotifier.new,
        ),
        analyticsOverride(),
        notificationPermissionOverride(),
        ...learningSettingsOverrides(),
      ]),
    );
    final now = DateTime(2026, 11, 17);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value(_audioId),
        name: const Value('Audio'),
        audioPath: const Value('audio.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
    final originalSrt = _srt(originalCues);
    await db.audioItemDao.updateTranscriptSrt(_audioId, originalSrt);
    oldSentences = await SubtitleParser.parseSubtitleString(originalSrt);
    newSentences = await SubtitleParser.parseSubtitleString(_srt(editedCues));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> replaceTranscript() async {
    await db.audioItemDao.updateTranscriptSrt(_audioId, _srt(editedCues));
    await container
        .read(transcriptChangeSyncProvider)
        .apply(
          _audioId,
          oldSentences: oldSentences,
          newSentences: newSentences,
        );
  }

  test('收藏句改写为新字幕中对应的句子，复习调度不受影响', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    for (final index in [1, 3, 4]) {
      await lifecycle.save(_audioId, oldSentences[index]);
    }
    final before = {
      for (final b in await db.bookmarkDao.getByAudioId(_audioId))
        b.memorySubjectId: b,
    };

    await replaceTranscript();

    // S1 → 合并句 2，S3 → 改字后的 3；S4 已删除，不再计入句子收藏。
    expect(await db.bookmarkDao.getBookmarkedIndices(_audioId), {2, 3});
    final rows = await db.bookmarkDao.getByAudioId(_audioId);
    expect(rows, hasLength(3), reason: '来源句被删除的收藏仍保留在收藏列表');
    expect(rows.map((b) => b.memorySubjectId).toSet(), before.keys.toSet());
    final byId = {for (final b in rows) b.id: b};
    final merged = byId[before.values.firstWhere((b) => b.startTime == 2).id]!;
    expect(
      (merged.sentenceText, merged.startTime, merged.endTime),
      ('Sentence 1 Sentence 2', 2.0, 6.0),
    );
    final edited = byId[before.values.firstWhere((b) => b.startTime == 6).id]!;
    expect(
      (edited.sentenceText, edited.startTime, edited.endTime),
      ('Sentence three', 6.0, 8.0),
    );
    final orphan = byId[before.values.firstWhere((b) => b.startTime == 8).id]!;
    expect(
      (orphan.sentenceText, orphan.startTime, orphan.endTime),
      ('Sentence 4', 8.0, 10.0),
      reason: '来源句已删除时保持原样',
    );

    final schedules = await (db.select(
      db.memorySchedules,
    )..where((t) => t.subjectId.isIn(before.keys.whereType<String>()))).get();
    expect(schedules, hasLength(3));
    expect(schedules.map((s) => s.status).toSet(), {'active'});
  });

  test('拆分收藏句后：收藏文字与定位到的句子一致，重复同步结果不变', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[0]);

    await replaceTranscript();
    // 收藏列表读收藏文字，随心听 / 讲解页按区间定位；两者必须是同一句。
    final indices = await db.bookmarkDao.getBookmarkedIndices(_audioId);
    final row = (await db.bookmarkDao.getByAudioId(_audioId)).single;
    expect(indices, hasLength(1));
    final located = newSentences[indices.single];
    expect(row.sentenceText, located.text);
    expect(row.startTime, located.startTime.inMilliseconds / 1000.0);
    expect(row.endTime, located.endTime.inMilliseconds / 1000.0);

    await replaceTranscript();
    final again = (await db.bookmarkDao.getByAudioId(_audioId)).single;
    expect(again, row);
  });

  test('回收站中的收藏也改写为新字幕中的句子', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[3]);
    await lifecycle.remove(_audioId, oldSentences[3]);

    await replaceTranscript();

    final deleted = await db.bookmarkDao.getDeletedBookmarks(
      sortMode: RecycleBinSortMode.timeDesc,
    );
    expect(deleted.single.bookmark.sentenceText, 'Sentence three');
  });

  test('合并句的两条收藏：再次收藏不新增，取消收藏一起取消', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[1]);
    await lifecycle.save(_audioId, oldSentences[2]);
    await replaceTranscript();

    await lifecycle.save(_audioId, newSentences[2]);
    expect(await db.bookmarkDao.getByAudioId(_audioId), hasLength(2));

    await lifecycle.remove(_audioId, newSentences[2]);
    expect(await db.bookmarkDao.getByAudioId(_audioId), isEmpty);
    expect(await db.bookmarkDao.getBookmarkedIndices(_audioId), isEmpty);
  });

  test('取消后重新收藏同一句：复用原记录与记忆主体', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[3]);
    final original = (await db.bookmarkDao.getByAudioId(_audioId)).single;
    await lifecycle.remove(_audioId, oldSentences[3]);
    await replaceTranscript();

    await lifecycle.save(_audioId, newSentences[3]);

    final rows = await db.select(db.bookmarks).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, original.id);
    expect(rows.single.memorySubjectId, original.memorySubjectId);
    expect(rows.single.deletedAt, isNull);
    expect(rows.single.sentenceText, 'Sentence three');
  });

  test('合并句有两条收藏时，按收藏本身 / 记忆主体取消只删目标那一条', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[1]);
    await lifecycle.save(_audioId, oldSentences[2]);
    await replaceTranscript();
    final rows = await db.bookmarkDao.getByAudioId(_audioId);
    expect(rows, hasLength(2));

    await lifecycle.removeBookmark(rows.first);
    expect(await db.bookmarkDao.getByAudioId(_audioId), [rows.last]);
    expect(await db.bookmarkDao.getBookmarkedIndices(_audioId), {2});

    await lifecycle.removeBySubjectId(rows.last.memorySubjectId!);
    expect(await db.bookmarkDao.getByAudioId(_audioId), isEmpty);
    final schedules = await db.select(db.memorySchedules).get();
    expect(schedules.map((s) => s.status).toSet(), {'archived'});
  });

  test('回收站恢复时同一句已有收藏：两条并存，句子收藏不重复计数', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[1]);
    await lifecycle.remove(_audioId, oldSentences[1]);
    await lifecycle.save(_audioId, oldSentences[2]);
    await replaceTranscript();
    // 合并后句 1、2 同属新句 2；恢复回收站中原句 1 的收藏。
    final deleted = await db.bookmarkDao.getDeletedBookmarks(
      sortMode: RecycleBinSortMode.timeDesc,
    );

    await lifecycle.restore(deleted.single);

    expect(await db.bookmarkDao.getByAudioId(_audioId), hasLength(2));
    expect(await db.bookmarkDao.getBookmarkedIndices(_audioId), {2});
  });

  test('调用方持有编辑前的旧句子列表时，收藏仍按时间落到正确的句子', () async {
    await replaceTranscript();
    // 旧列表里 S5 的 index 是 5，当前字幕中它是第 4 句。
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[5]);

    expect(await db.bookmarkDao.getBookmarkedIndices(_audioId), {4});
    // 再次收藏同一句（旧 index）不新增。
    await lifecycle.save(_audioId, oldSentences[5]);
    expect(await db.bookmarkDao.getByAudioId(_audioId), hasLength(1));
  });

  test('用编辑前的旧句子取消收藏：只取消这句话，不误伤占了旧编号的句子', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await replaceTranscript();
    // 当前字幕：第 1 句是 S0 拆出的后半句 "0"，第 2 句是合并句（S1+S2）。
    await lifecycle.save(_audioId, newSentences[1]);
    await lifecycle.save(_audioId, newSentences[2]);

    // 页面仍持有旧列表，用户取消旧 S1（旧编号 1）。按编号取消会误删新字幕第 1 句
    // 的收藏；按时间定位，S1 属于合并句 2。
    await lifecycle.remove(_audioId, oldSentences[1]);

    expect(await db.bookmarkDao.getBookmarkedIndices(_audioId), {1});
    final remaining = (await db.bookmarkDao.getByAudioId(_audioId)).single;
    expect(remaining.sentenceText, newSentences[1].text);
  });

  test('取消一个已不在当前字幕中的句子：不动任何收藏', () async {
    final lifecycle = container.read(favoriteSentenceLifecycleProvider);
    await lifecycle.save(_audioId, oldSentences[5]);
    await replaceTranscript();

    // 旧 S2 已被删除。
    await lifecycle.remove(_audioId, oldSentences[2]);

    expect(await db.bookmarkDao.getByAudioId(_audioId), hasLength(1));
  });

  test('收藏词汇 / 意群的来源句改写为新字幕中含该词的句子', () async {
    // 'sentence' 来自 S0：S0 被拆成 "Sentence" + "0"，区间中点落在后半句，
    // 但应关联含该词的前半句。
    await db.savedWordDao.saveWord(
      word: 'sentence',
      audioItemId: _audioId,
      sentenceText: 'Sentence 0',
      sentenceStartMs: 0,
      sentenceEndMs: 2000,
    );
    // 'three' 是词元匹配不到的情形（S3 改字前是 "Sentence 3"）：退回区间中点。
    await db.savedWordDao.saveWord(
      word: 'three',
      audioItemId: _audioId,
      sentenceText: 'Sentence 3',
      sentenceStartMs: 6000,
      sentenceEndMs: 8000,
    );
    // 来源句 S4 已删除：保持原样。
    await db.savedWordDao.saveWord(
      word: 'four',
      audioItemId: _audioId,
      sentenceText: 'Sentence 4',
      sentenceStartMs: 8000,
      sentenceEndMs: 10000,
    );
    await db.savedSenseGroupDao.saveSenseGroup(
      phraseText: 'sentence 2',
      displayText: 'Sentence 2',
      audioItemId: _audioId,
      sentenceText: 'Sentence 2',
      sentenceStartMs: 4000,
      sentenceEndMs: 6000,
      groupStartMs: 4000,
      groupEndMs: 6000,
    );

    await replaceTranscript();

    final words = {
      for (final w in await db.savedWordDao.getByAudioId(_audioId))
        w.word: (w.sentenceText, w.sentenceStartMs, w.sentenceEndMs),
    };
    expect(words, {
      'sentence': ('Sentence', 0, 1000),
      'three': ('Sentence three', 6000, 8000),
      'four': ('Sentence 4', 8000, 10000),
    });
    final group = (await db.savedSenseGroupDao.getByAudioId(_audioId)).single;
    expect(
      (group.sentenceText, group.sentenceStartMs, group.sentenceEndMs),
      ('Sentence 1 Sentence 2', 2000, 6000),
    );
    expect((group.groupStartMs, group.groupEndMs), (4000, 6000));
    // 需要前后句时现算编号，与改写后的来源句一致。
    final groupIndex = await container.read(
      sourceSentenceIndexProvider((
        audioItemId: _audioId,
        startMs: group.sentenceStartMs,
        endMs: group.sentenceEndMs,
      )).future,
    );
    expect(groupIndex, 2);
  });

  test('学习进度保留阶段与复习时间，断点换算到新字幕', () async {
    final firstLearnCompletedAt = DateTime(2026, 11, 10);
    final notifier = container.read(learningProgressProvider.notifier);
    final progress = await notifier.ensureProgress(_audioId);
    await notifier.saveBlindListenSentenceIndex(_audioId, 4, isFreePlay: false);
    await notifier.saveIntensiveListenSentenceIndex(
      _audioId,
      3,
      isFreePlay: true,
    );
    await notifier.saveShadowingSentenceIndex(_audioId, 1, isFreePlay: false);
    await notifier.saveDifficultPracticeSentenceIndex(
      _audioId,
      2,
      isFreePlay: true,
    );
    await notifier.saveRetellSentenceIndex(_audioId, 0, isFreePlay: false);
    await (db.update(
      db.learningProgresses,
    )..where((t) => t.audioItemId.equals(_audioId))).write(
      LearningProgressesCompanion(
        firstLearnCompletedAt: Value(firstLearnCompletedAt),
      ),
    );

    await replaceTranscript();

    final latest = (await notifier.getLatestByAudioId(_audioId))!;
    expect(latest.currentStage, progress.currentStage);
    expect(latest.currentSubStage, progress.currentSubStage);
    expect(latest.firstLearnCompletedAt, firstLearnCompletedAt);
    expect(latest.blindListenSentenceIndex, 4, reason: 'S4 已删，停在其后的 S5');
    expect(latest.freePlayIntensiveListenSentenceIndex, 3);
    expect(latest.retellSentenceIndex, 0, reason: 'S0 被拆分，从前半句续学');
    expect(latest.shadowingSentenceIndex, isNull, reason: '难句列表内位置无法换算，清除');
    expect(latest.freePlayDifficultPracticeSentenceIndex, isNull);
  });

  test('只改时间或文字（结构不变）时不改动学习断点', () async {
    final notifier = container.read(learningProgressProvider.notifier);
    await notifier.ensureProgress(_audioId);
    await notifier.saveShadowingSentenceIndex(_audioId, 2, isFreePlay: false);
    final sameStructure = await SubtitleParser.parseSubtitleString(
      _srt([
        for (final (start, end, text) in originalCues) (start, end, '$text!'),
      ]),
    );

    await container
        .read(transcriptChangeSyncProvider)
        .apply(
          _audioId,
          oldSentences: oldSentences,
          newSentences: sameStructure,
        );

    final latest = (await notifier.getLatestByAudioId(_audioId))!;
    expect(latest.shadowingSentenceIndex, 2);
  });
}
