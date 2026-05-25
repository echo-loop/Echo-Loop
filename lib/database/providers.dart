import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/audio_item_dao.dart';
import 'daos/collection_dao.dart';
import 'daos/bookmark_dao.dart';
import 'daos/playback_state_dao.dart';
import 'daos/learning_progress_dao.dart';
import 'daos/stage_completion_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/sentence_ai_cache_dao.dart';
import 'daos/saved_word_dao.dart';
import 'daos/saved_sense_group_dao.dart';
import 'daos/learned_word_form_dao.dart';
import 'daos/daily_study_record_dao.dart';
import 'daos/daily_stage_study_record_dao.dart';
import '../services/study_time_service.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/saved_word_provider.dart';
import '../providers/saved_sense_group_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/blind_listen_player_provider.dart';
import '../providers/learning_session/intensive_listen_player_provider.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../providers/listen_and_repeat/listen_and_repeat_controller.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/flashcard/flashcard_provider.dart';
import '../providers/transcription_task_provider.dart';
import '../providers/study_stats_provider.dart';
import '../providers/study_task_provider.dart';
import '../providers/learned_vocabulary_tracker_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/word_ai_provider.dart';

/// 当前活跃的数据库实例（运行时可切换）。
///
/// 由 [initAppDatabase] 在启动时设置，由 [switchAppDatabase] 在演示模式
/// 切换时更新。Provider 读取此变量以获取当前数据库。
late AppDatabase _appDatabase;

/// 在应用启动时初始化数据库实例。
///
/// 必须在 `runApp()` 之前调用。
void initAppDatabase(AppDatabase db) {
  _appDatabase = db;
}

/// 关闭当前数据库连接。
///
/// 用于演示模式切换：先关闭旧连接，再创建新数据库实例，
/// 避免 Drift "multiple databases" 警告。
Future<void> closeCurrentDatabase() async {
  await _appDatabase.close();
}

/// 运行时切换数据库（如演示模式切换）。
///
/// 设置新实例并显式 invalidate 全部数据相关 Provider。
/// keepAlive 提供者内部使用 `ref.read()` 获取 DAO，不会自动级联，
/// 因此必须在此逐一 invalidate。
///
/// 调用前必须先通过 [closeCurrentDatabase] 关闭旧连接。
void switchAppDatabase(AppDatabase newDb, WidgetRef ref) {
  _appDatabase = newDb;

  // 1. Invalidate 核心数据库提供者
  ref.invalidate(appDatabaseProvider);

  // 2. 显式 invalidate 所有 keepAlive 数据提供者
  //    （它们用 ref.read() 而非 ref.watch()，不会自动级联）
  ref.invalidate(audioLibraryProvider);
  ref.invalidate(collectionListProvider);
  ref.invalidate(learningProgressNotifierProvider);
  ref.invalidate(savedWordListProvider);
  ref.invalidate(savedSenseGroupListProvider);
  ref.invalidate(savedSenseGroupTextsProvider);
  ref.invalidate(tagListProvider);
  ref.invalidate(listeningPracticeProvider);
  ref.invalidate(bookmarkReviewProvider);
  ref.invalidate(learningSessionProvider);
  ref.invalidate(blindListenPlayerProvider);
  ref.invalidate(intensiveListenPlayerProvider);
  ref.invalidate(listenAndRepeatControllerProvider);
  ref.invalidate(retellPlayerProvider);
  ref.invalidate(reviewDifficultPracticeProvider);
  ref.invalidate(flashcardNotifierProvider);
  ref.invalidate(transcriptionTaskManagerProvider);

  ref.invalidate(bookmarkListProvider);

  // 3. Invalidate 非 keepAlive 但依赖 DB 的提供者
  ref.invalidate(studyStatsNotifierProvider);
  ref.invalidate(studyTaskProvider);
  ref.invalidate(learnedVocabularyTrackerProvider);

  // 4. Invalidate AI 缓存提供者（依赖 sentenceAiCacheDao）
  ref.invalidate(sentenceAiNotifierProvider);
  ref.invalidate(wordAiNotifierProvider);
}

/// 数据库 Provider
///
/// 启动时通过 [initAppDatabase] 初始化，运行时通过 [switchAppDatabase] 切换。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return _appDatabase;
});

/// AudioItem DAO Provider
final audioItemDaoProvider = Provider<AudioItemDao>((ref) {
  return ref.watch(appDatabaseProvider).audioItemDao;
});

/// Collection DAO Provider
final collectionDaoProvider = Provider<CollectionDao>((ref) {
  return ref.watch(appDatabaseProvider).collectionDao;
});

/// Bookmark DAO Provider
final bookmarkDaoProvider = Provider<BookmarkDao>((ref) {
  return ref.watch(appDatabaseProvider).bookmarkDao;
});

/// PlaybackState DAO Provider
final playbackStateDaoProvider = Provider<PlaybackStateDao>((ref) {
  return ref.watch(appDatabaseProvider).playbackStateDao;
});

/// LearningProgress DAO Provider
final learningProgressDaoProvider = Provider<LearningProgressDao>((ref) {
  return ref.watch(appDatabaseProvider).learningProgressDao;
});

/// StageCompletion DAO Provider
final stageCompletionDaoProvider = Provider<StageCompletionDao>((ref) {
  return ref.watch(appDatabaseProvider).stageCompletionDao;
});

/// Tag DAO Provider
final tagDaoProvider = Provider<TagDao>((ref) {
  return ref.watch(appDatabaseProvider).tagDao;
});

/// SentenceAiCache DAO Provider
final sentenceAiCacheDaoProvider = Provider<SentenceAiCacheDao>((ref) {
  return ref.watch(appDatabaseProvider).sentenceAiCacheDao;
});

/// SavedWord DAO Provider
final savedWordDaoProvider = Provider<SavedWordDao>((ref) {
  return ref.watch(appDatabaseProvider).savedWordDao;
});

/// SavedSenseGroup DAO Provider
final savedSenseGroupDaoProvider = Provider<SavedSenseGroupDao>((ref) {
  return ref.watch(appDatabaseProvider).savedSenseGroupDao;
});

/// LearnedWordForm DAO Provider
final learnedWordFormDaoProvider = Provider<LearnedWordFormDao>((ref) {
  return ref.watch(appDatabaseProvider).learnedWordFormDao;
});

/// DailyStudyRecord DAO Provider
final dailyStudyRecordDaoProvider = Provider<DailyStudyRecordDao>((ref) {
  return ref.watch(appDatabaseProvider).dailyStudyRecordDao;
});

/// DailyStageStudyRecord DAO Provider
final dailyStageStudyRecordDaoProvider = Provider<DailyStageStudyRecordDao>((
  ref,
) {
  return ref.watch(appDatabaseProvider).dailyStageStudyRecordDao;
});

/// 收藏句子列表 Provider（流式，keepAlive）
///
/// 监听所有收藏书签的变化（含音频名称），按音频分组。
/// keepAlive 避免切换 tab 时重新订阅导致闪烁。
final bookmarkListProvider = StreamProvider<List<BookmarkWithAudio>>((ref) {
  final dao = ref.watch(bookmarkDaoProvider);
  return dao.watchAllWithAudioName();
});

/// StudyTimeService Provider
final studyTimeServiceProvider = Provider<StudyTimeService>((ref) {
  return StudyTimeService(
    ref.watch(dailyStudyRecordDaoProvider),
    ref.watch(dailyStageStudyRecordDaoProvider),
  );
});
