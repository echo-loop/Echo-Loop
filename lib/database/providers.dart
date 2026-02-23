import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/audio_item_dao.dart';
import 'daos/collection_dao.dart';
import 'daos/bookmark_dao.dart';
import 'daos/playback_state_dao.dart';
import 'daos/learning_progress_dao.dart';
import 'daos/stage_completion_dao.dart';
import 'daos/tag_dao.dart';

/// 数据库 Provider
/// 在 main.dart 中通过 ProviderScope override 注入实例
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider 必须在 ProviderScope 中 override');
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
