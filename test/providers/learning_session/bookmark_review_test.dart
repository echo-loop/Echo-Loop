import 'dart:async';
import 'dart:io';

import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_rating.dart';
import 'package:echo_loop/features/memory_scheduler/config/memory_profiles.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_namespaces.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_commands.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_subject_ref.dart';
import 'package:echo_loop/features/memory_scheduler/providers/memory_scheduler_providers.dart';
import 'package:echo_loop/models/favorite_review_settings.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/models/bookmark_review_settings.dart';
import 'package:echo_loop/providers/bookmark_review_settings_provider.dart';
import 'package:echo_loop/providers/favorite_review_settings_provider.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/utils/app_data_dir.dart' as app_data_dir;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import '../../helpers/mock_providers.dart';

import 'package:echo_loop/database/app_database.dart'
    show configureAppDatabaseConnection;

class _TestBookmarkDao implements BookmarkDao {
  _TestBookmarkDao({this.fail = false});
  final bool fail;
  final removedIds = <int>[];

  /// 收藏复习按记忆主体取消收藏：主体 test-subject-N 对应主键 N。
  @override
  Future<db.Bookmark?> getActiveBySubjectId(String memorySubjectId) async {
    final sentenceIndex = int.parse(
      memorySubjectId.substring('test-subject-'.length),
    );
    return db.Bookmark(
      id: sentenceIndex,
      audioItemId: 'audio-1',
      memorySubjectId: memorySubjectId,
      sentenceText: 'Sentence $sentenceIndex',
      startTime: sentenceIndex.toDouble(),
      endTime: sentenceIndex + 1.0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      syncStatus: 0,
    );
  }

  @override
  Future<void> softDeleteByIds(Iterable<int> ids) async {
    if (fail) throw StateError('failed');
    removedIds.addAll(ids);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeShortAudioPlayer extends LocalAudioClipPlayer {
  _FakeShortAudioPlayer() : super(backend: UnavailableAudioClipPlayerBackend());

  int stops = 0;
  int rangePlays = 0;
  final paths = <String>[];
  final ranges = <(Duration, Duration)>[];
  Completer<AudioPlaybackResult>? pendingRangePlay;
  final _rangePlaybackStartWaiters = <Completer<void>>[];
  int _unobservedRangePlaybackStarts = 0;
  String? _playingKey;

  @override
  LocalAudioClipPlaybackState get state =>
      LocalAudioClipPlaybackState(playingKey: _playingKey);

  @override
  Future<AudioPlaybackResult> playRangeFile(
    String filePath, {
    required Duration start,
    required Duration end,
    String? playbackKey,
  }) {
    rangePlays++;
    paths.add(filePath);
    ranges.add((start, end));
    _playingKey = playbackKey;
    if (_rangePlaybackStartWaiters.isNotEmpty) {
      _rangePlaybackStartWaiters.removeAt(0).complete();
    } else {
      _unobservedRangePlaybackStarts++;
    }
    return (pendingRangePlay ??= Completer<AudioPlaybackResult>()).future;
  }

  Future<void> waitForRangePlaybackStart() {
    if (_unobservedRangePlaybackStarts > 0) {
      _unobservedRangePlaybackStarts--;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _rangePlaybackStartWaiters.add(waiter);
    return waiter.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    _playingKey = null;
    pendingRangePlay?.complete(AudioPlaybackResult.cancelled);
    pendingRangePlay = null;
  }

  void completeRange(AudioPlaybackResult result) {
    _playingKey = null;
    pendingRangePlay?.complete(result);
    pendingRangePlay = null;
  }
}

class _RecordingForegroundAudioEngine extends TestForegroundAudioEngine {
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}

/// 固定「显示视频画面」开关；原有用例只验证音频路径，默认关闭。
class _TestBookmarkReviewSettings extends BookmarkReviewSettingsNotifier {
  _TestBookmarkReviewSettings({required this.showVideo});

  final bool showVideo;

  @override
  BookmarkReviewSettings build() =>
      BookmarkReviewSettings(showVideo: showVideo);

  @override
  Future<void> update(BookmarkReviewSettings settings) async {
    state = settings;
  }
}

class _TestFavoriteReviewSettings extends FavoriteReviewSettingsNotifier {
  _TestFavoriteReviewSettings({
    required this.autoPlayFront,
    required this.autoPlayBack,
  });

  final bool autoPlayFront;
  final bool autoPlayBack;

  @override
  FavoriteReviewSettings build() => FavoriteReviewSettings(
    autoPlayFront: autoPlayFront,
    autoPlayBack: autoPlayBack,
  );
}

BookmarkWithAudio _bookmark(int id) => BookmarkWithAudio(
  bookmark: db.Bookmark(
    id: id,
    audioItemId: 'audio-1',
    memorySubjectId: 'test-subject-$id',
    sentenceText: 'Sentence $id',
    startTime: id.toDouble(),
    endTime: id + 1.0,
    createdAt: DateTime(2026, 1, 20 - id),
    updatedAt: DateTime(2026, 1, 20 - id),
    syncStatus: 0,
  ),
  audioName: 'Material',
);

ProviderContainer _container(
  _TestBookmarkDao dao,
  db.AppDatabase database, {
  required _FakeShortAudioPlayer shortAudioPlayer,
  bool autoPlayFront = false,
  bool autoPlayBack = false,
  bool showVideo = false,
  List<Override> extraOverrides = const [],
}) => ProviderContainer(
  overrides: dedupeOverrides([
    appDatabaseProvider.overrideWithValue(database),
    bookmarkDaoProvider.overrideWithValue(dao),
    audioEngineProvider.overrideWith(TestAudioEngine.new),
    foregroundAudioEngineProvider.overrideWith(
      _RecordingForegroundAudioEngine.new,
    ),
    shortAudioPlayerProvider.overrideWithValue(shortAudioPlayer),
    favoriteReviewSettingsProvider.overrideWith(
      () => _TestFavoriteReviewSettings(
        autoPlayFront: autoPlayFront,
        autoPlayBack: autoPlayBack,
      ),
    ),
    bookmarkReviewSettingsProvider.overrideWith(
      () => _TestBookmarkReviewSettings(showVideo: showVideo),
    ),
    analyticsOverride(),
    ...extraOverrides,
  ]),
);

/// 可控的媒体引擎：记录加载 / 定位 / 区间播放，不触达原生播放器。
/// 可控的材料读取：测试里让指定材料的读取挂起或失败，复现切卡窗口期与同步异常。
class _ControlledAudioItemDao extends AudioItemDao {
  _ControlledAudioItemDao(super.db);

  final gates = <String, Completer<void>>{};

  /// 下一次读取这些材料时抛错，之后恢复正常（音频播放也会读取同一张表）。
  final failingIds = <String>{};

  @override
  Future<db.AudioItem?> getById(String id) async {
    if (failingIds.remove(id)) throw StateError('audio item read failed');
    await gates[id]?.future;
    return super.getById(id);
  }
}

class _FakeVideoEngine extends MediaEngine {
  bool loadSucceeds = true;
  final loads = <String>[];
  final previews = <Duration>[];
  final ranges = <(Duration, Duration)>[];
  final videoTrackCalls = <bool>[];
  int releaseCalls = 0;
  int cancelCalls = 0;
  Completer<SentencePlaybackResult>? pendingRange;

  @override
  Future<Duration?> loadMedia(
    AudioItem item,
    double speed, {
    Duration initialPosition = Duration.zero,
    bool publishToSystemMediaSession = true,
  }) async {
    loads.add(item.id);
    return loadSucceeds ? const Duration(minutes: 1) : null;
  }

  @override
  double? get videoAspectRatio => 16 / 9;

  @override
  Stream<double?> get videoAspectRatioStream => const Stream.empty();

  @override
  Future<void> seekForPreview(Duration pos) async => previews.add(pos);

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end, {
    required double speed,
    VoidCallback? onRangeReady,
    int? sessionId,
  }) {
    ranges.add((start, end));
    return (pendingRange = Completer<SentencePlaybackResult>()).future;
  }

  @override
  Future<void> cancelActiveRange({String reason = 'caller-cancel'}) async {
    cancelCalls++;
    pendingRange?.complete(SentencePlaybackResult.cancelled);
    pendingRange = null;
  }

  @override
  Future<void> releaseFromScreen() async {
    releaseCalls++;
    newSession();
  }

  @override
  Future<void> setVideoTrackEnabled(bool enabled) async =>
      videoTrackCalls.add(enabled);

  @override
  Future<void> setSubtitleTrackData(String? srt) async {}
}

/// 打开「显示视频画面」并注入可控引擎的复习容器。
({
  ProviderContainer container,
  db.AppDatabase database,
  _FakeShortAudioPlayer player,
  _FakeVideoEngine engine,
  _ControlledAudioItemDao audioItemDao,
})
_videoScope({bool showVideo = true}) {
  final database = db.AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
  final player = _FakeShortAudioPlayer();
  final audioItemDao = _ControlledAudioItemDao(database);
  final container = _container(
    _TestBookmarkDao(),
    database,
    shortAudioPlayer: player,
    showVideo: showVideo,
    extraOverrides: [
      mediaEngineProvider.overrideWith(_FakeVideoEngine.new),
      audioItemDaoProvider.overrideWithValue(audioItemDao),
    ],
  );
  return (
    container: container,
    database: database,
    player: player,
    engine: container.read(mediaEngineProvider.notifier) as _FakeVideoEngine,
    audioItemDao: audioItemDao,
  );
}

Future<void> _disposeBookmarkContainer(ProviderContainer container) async {
  await container.read(bookmarkReviewProvider.notifier).disposeSession();
  container.dispose();
}

({
  ProviderContainer container,
  db.AppDatabase database,
  _FakeShortAudioPlayer player,
})
_testScope(
  _TestBookmarkDao dao, {
  bool autoPlayFront = false,
  bool autoPlayBack = false,
}) {
  final database = db.AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
  final player = _FakeShortAudioPlayer();
  return (
    container: _container(
      dao,
      database,
      shortAudioPlayer: player,
      autoPlayFront: autoPlayFront,
      autoPlayBack: autoPlayBack,
    ),
    database: database,
    player: player,
  );
}

Future<void> _addPlayableMedia(db.AppDatabase database) {
  final now = DateTime.now();
  return database.audioItemDao.upsert(
    db.AudioItemsCompanion(
      id: const Value('audio-1'),
      name: const Value('Material'),
      audioPath: const Value('media/test.mp4'),
      addedDate: Value(now),
      updatedAt: Value(now),
    ),
  );
}

Future<void> _initializeBookmarkReview(
  ProviderContainer container,
  List<BookmarkWithAudio> bookmarks,
) async {
  final database = container.read(appDatabaseProvider);
  await _addPlayableMedia(database);
  final scheduler = container.read(memorySchedulerProvider);
  for (final item in bookmarks) {
    final bookmark = item.bookmark;
    await database
        .into(database.bookmarks)
        .insertOnConflictUpdate(
          db.BookmarksCompanion.insert(
            memorySubjectId: Value(bookmark.memorySubjectId),
            audioItemId: bookmark.audioItemId,
            sentenceText: bookmark.sentenceText,
            startTime: bookmark.startTime,
            endTime: bookmark.endTime,
            createdAt: bookmark.createdAt,
            updatedAt: bookmark.updatedAt,
            deletedAt: Value(bookmark.deletedAt),
          ),
        );
    final subjectId = bookmark.memorySubjectId;
    if (subjectId == null || subjectId.trim().isEmpty) continue;
    final subject = MemorySubjectRef(
      namespace: kSavedSentenceNamespace,
      subjectId: subjectId,
    );
    if (await scheduler.getSchedule(subject) == null) {
      await scheduler.ensureSchedule(
        EnsureMemoryScheduleCommand(
          subject: subject,
          profile: kFsrsDefaultProfileRef,
          occurredAt: DateTime.now(),
        ),
      );
    }
  }
  await container.read(bookmarkReviewProvider.notifier).initialize();
}

late Directory _testAppDataDirectory;

void main() {
  setUpAll(() async {
    _testAppDataDirectory = await Directory.systemTemp.createTemp(
      'echo_loop_bookmark_review_test-',
    );
    app_data_dir.appDataDirectoryOverride = _testAppDataDirectory;
  });

  tearDownAll(() async {
    app_data_dir.appDataDirectoryOverride = null;
    if (_testAppDataDirectory.existsSync()) {
      await _testAppDataDirectory.delete(recursive: true);
    }
  });

  test('initialize filters invalid bookmarks and starts on front', () async {
    final scope = _testScope(_TestBookmarkDao());
    final database = scope.database;
    final container = scope.container;
    addTearDown(() async {
      await _disposeBookmarkContainer(container);
      await database.close();
    });
    final invalid = BookmarkWithAudio(
      bookmark: _bookmark(9).bookmark.copyWith(endTime: 9),
      audioName: 'Material',
    );
    await _initializeBookmarkReview(container, [_bookmark(1), invalid]);
    final state = container.read(bookmarkReviewProvider);
    expect(state.initialTotal, 1);
    expect(state.face, BookmarkReviewFace.front);
    expect(state.currentCard?.sentence.text, 'Sentence 1');
  });

  test(
    'changing order during review selects the new first unreviewed card',
    () async {
      final scope = _testScope(_TestBookmarkDao());
      final container = scope.container;
      addTearDown(() async {
        await _disposeBookmarkContainer(container);
        await scope.database.close();
      });
      await _initializeBookmarkReview(container, [
        _bookmark(3),
        _bookmark(2),
        _bookmark(1),
      ]);
      expect(
        container.read(bookmarkReviewProvider).currentCard?.sentence.text,
        'Sentence 3',
      );

      final reordered = Completer<void>();
      final subscription = container.listen(bookmarkReviewProvider, (_, next) {
        if (next.currentCard?.sentence.text == 'Sentence 1' &&
            !reordered.isCompleted) {
          reordered.complete();
        }
      });
      addTearDown(subscription.close);

      await container
          .read(favoriteReviewSettingsProvider.notifier)
          .update(
            const FavoriteReviewSettings(
              autoPlayFront: false,
              autoPlayBack: false,
              order: FavoriteReviewOrder.dueAt,
            ),
          );
      await reordered.future.timeout(const Duration(seconds: 3));

      final state = container.read(bookmarkReviewProvider);
      expect(state.currentCard?.sentence.text, 'Sentence 1');
      expect(state.reviewedCount, 0);
      expect(state.remainingCount, 3);
    },
  );

  test('reveal stops playback and exposes placeholder back', () async {
    final scope = _testScope(_TestBookmarkDao());
    final container = scope.container;
    addTearDown(() async {
      await _disposeBookmarkContainer(container);
      await scope.database.close();
    });
    final notifier = container.read(bookmarkReviewProvider.notifier);
    await _addPlayableMedia(scope.database);
    await _initializeBookmarkReview(container, [_bookmark(1)]);
    await notifier.revealBack();
    expect(
      container.read(bookmarkReviewProvider).face,
      BookmarkReviewFace.back,
    );
    expect(scope.player.stops, greaterThan(0));
  });

  test(
    'does not stop foreground engine when no legacy playback is active',
    () async {
      final scope = _testScope(_TestBookmarkDao());
      final container = scope.container;
      addTearDown(() async {
        await _disposeBookmarkContainer(container);
        await scope.database.close();
      });
      final foreground = container.read(
        foregroundAudioEngineProvider.notifier,
      ) as _RecordingForegroundAudioEngine;
      final notifier = container.read(bookmarkReviewProvider.notifier);

      await _initializeBookmarkReview(container, [_bookmark(1)]);
      await notifier.revealBack();
      await notifier.interruptPlayback();

      expect(foreground.stopCalls, 0);
    },
  );

  test('stops foreground engine when legacy playback is active', () async {
    final scope = _testScope(_TestBookmarkDao());
    final container = scope.container;
    addTearDown(() async {
      await _disposeBookmarkContainer(container);
      await scope.database.close();
    });
    final foreground = container.read(
      foregroundAudioEngineProvider.notifier,
    ) as _RecordingForegroundAudioEngine;
    final notifier = container.read(bookmarkReviewProvider.notifier);

    foreground.isPlaying = true;
    await notifier.interruptPlayback();

    expect(foreground.stopCalls, 1);
    expect(foreground.isPlaying, isFalse);
  });

  test('shared auto-play settings control sentence front and back', () async {
    final disabled = _testScope(
      _TestBookmarkDao(),
      autoPlayFront: false,
      autoPlayBack: false,
    );
    addTearDown(() async {
      await _disposeBookmarkContainer(disabled.container);
      await disabled.database.close();
    });
    final disabledNotifier = disabled.container.read(
      bookmarkReviewProvider.notifier,
    );
    await _initializeBookmarkReview(disabled.container, [_bookmark(1)]);
    await disabledNotifier.startCurrentCard();
    await disabledNotifier.revealBack();
    expect(disabled.player.rangePlays, 0);

    final enabled = _testScope(
      _TestBookmarkDao(),
      autoPlayFront: true,
      autoPlayBack: true,
    );
    addTearDown(() async {
      await _disposeBookmarkContainer(enabled.container);
      await enabled.database.close();
    });
    final enabledNotifier = enabled.container.read(
      bookmarkReviewProvider.notifier,
    );
    await _addPlayableMedia(enabled.database);
    await _initializeBookmarkReview(enabled.container, [_bookmark(1)]);
    unawaited(enabledNotifier.startCurrentCard());
    await enabled.player.waitForRangePlaybackStart();
    expect(enabled.player.rangePlays, 1);
    expect(enabled.player.paths.single, endsWith('media/test.mp4'));
    expect(enabled.player.ranges.single, (
      const Duration(seconds: 1),
      const Duration(seconds: 2),
    ));
    await enabledNotifier.interruptPlayback();
    await enabledNotifier.revealBack();
    await enabled.player.waitForRangePlaybackStart();
    expect(enabled.player.rangePlays, 2);
    await enabledNotifier.interruptPlayback();
  });

  test('back can play and stop the current sentence', () async {
    final scope = _testScope(_TestBookmarkDao());
    final container = scope.container;
    addTearDown(() async {
      await _disposeBookmarkContainer(container);
      await scope.database.close();
    });
    final notifier = container.read(bookmarkReviewProvider.notifier);
    await _addPlayableMedia(scope.database);
    await _initializeBookmarkReview(container, [_bookmark(1)]);
    await notifier.revealBack();

    final playback = notifier.toggleCurrentPlayback();
    await scope.player.waitForRangePlaybackStart();
    expect(scope.player.rangePlays, 1);
    expect(
      container.read(bookmarkReviewProvider).playbackState,
      BookmarkReviewPlaybackState.playing,
    );

    await notifier.toggleCurrentPlayback();
    expect(scope.player.stops, greaterThan(0));
    expect(
      container.read(bookmarkReviewProvider).playbackState,
      BookmarkReviewPlaybackState.idle,
    );
    await playback;
  });

  test('completed sentence playback returns to idle', () async {
    final scope = _testScope(_TestBookmarkDao());
    addTearDown(() async {
      await _disposeBookmarkContainer(scope.container);
      await scope.database.close();
    });
    final notifier = scope.container.read(bookmarkReviewProvider.notifier);
    await _addPlayableMedia(scope.database);
    await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
    await notifier.revealBack();

    final playback = notifier.toggleCurrentPlayback();
    await scope.player.waitForRangePlaybackStart();
    scope.player.completeRange(AudioPlaybackResult.completed);
    await playback;

    expect(
      scope.container.read(bookmarkReviewProvider).playbackState,
      BookmarkReviewPlaybackState.idle,
    );
  });

  test('completed sentence playback writes new statistics', () async {
    final scope = _testScope(_TestBookmarkDao());
    addTearDown(() async {
      await _disposeBookmarkContainer(scope.container);
      await scope.database.close();
    });
    final notifier = scope.container.read(bookmarkReviewProvider.notifier);
    await _addPlayableMedia(scope.database);
    await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
    await notifier.revealBack();

    final playback = notifier.toggleCurrentPlayback();
    await scope.player.waitForRangePlaybackStart();
    scope.player.completeRange(AudioPlaybackResult.completed);
    await playback;
    await notifier.disposeSession();

    final record = await scope.database.dailyStudyRecordDao.getByDate(
      DateTime.now(),
    );
    expect(record?.inputWords, 2);
    expect(record?.inputTimeMilliseconds, 1000);
    final forms = await scope.database
        .select(scope.database.learnedWordForms)
        .get();
    expect(forms.map((form) => form.wordForm), contains('sentence'));
  });

  test(
    'interrupted sentence playback does not write input statistics',
    () async {
      final scope = _testScope(_TestBookmarkDao());
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _addPlayableMedia(scope.database);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.revealBack();

      final playback = notifier.toggleCurrentPlayback();
      await scope.player.waitForRangePlaybackStart();
      await notifier.interruptPlayback();
      await playback;
      await notifier.disposeSession();

      final record = await scope.database.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      );
      expect(record?.inputWords ?? 0, 0);
      expect(record?.inputTimeMilliseconds ?? 0, 0);
    },
  );

  test(
    'rating the last card stops playback before showing completion',
    () async {
      final scope = _testScope(_TestBookmarkDao(), autoPlayBack: true);
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _addPlayableMedia(scope.database);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.revealBack();
      await scope.player.waitForRangePlaybackStart();
      expect(scope.player.pendingRangePlay, isNotNull);

      await notifier.selectRating(MemoryRating.good);

      expect(scope.player.stops, greaterThan(0));
      expect(scope.container.read(bookmarkReviewProvider).currentCard, isNull);
      expect(
        scope.container.read(bookmarkReviewProvider).completionSummary,
        isNotNull,
      );
    },
  );

  test('failed sentence playback exposes the existing failed state', () async {
    final scope = _testScope(_TestBookmarkDao());
    addTearDown(() async {
      await _disposeBookmarkContainer(scope.container);
      await scope.database.close();
    });
    final notifier = scope.container.read(bookmarkReviewProvider.notifier);
    await _addPlayableMedia(scope.database);
    await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
    await notifier.revealBack();

    final playback = notifier.toggleCurrentPlayback();
    await scope.player.waitForRangePlaybackStart();
    scope.player.completeRange(AudioPlaybackResult.failed);
    await playback;

    final state = scope.container.read(bookmarkReviewProvider);
    expect(state.playbackState, BookmarkReviewPlaybackState.failed);
    expect(state.mediaError, 'audio_unavailable');
  });

  test('successful unsave removes current card and advances', () async {
    final dao = _TestBookmarkDao();
    final scope = _testScope(dao);
    final container = scope.container;
    addTearDown(() async {
      await _disposeBookmarkContainer(container);
      await scope.database.close();
    });
    final notifier = container.read(bookmarkReviewProvider.notifier);
    await _initializeBookmarkReview(container, [_bookmark(1), _bookmark(2)]);
    final removed = container.read(bookmarkReviewProvider).currentCard!;
    await notifier.removeCurrentBookmark();
    // 按卡片的记忆主体取消收藏：主体 test-subject-N 对应主键 N。
    final removedId = int.parse(
      removed.memorySubjectId.substring('test-subject-'.length),
    );
    expect(dao.removedIds, [removedId]);
    expect(container.read(bookmarkReviewProvider).remainingCount, 1);
    expect(
      container.read(bookmarkReviewProvider).face,
      BookmarkReviewFace.front,
    );
  });

  test('empty deck creates a zero-stat completion summary', () async {
    final scope = _testScope(_TestBookmarkDao());
    addTearDown(() async {
      await _disposeBookmarkContainer(scope.container);
      await scope.database.close();
    });

    await scope.container.read(bookmarkReviewProvider.notifier).initialize();

    final state = scope.container.read(bookmarkReviewProvider);
    expect(state.currentCard, isNull);
    expect(state.completionSummary, isNotNull);
    expect(state.completionSummary?.reviewedCount, 0);
    expect(state.completionSummary?.ratingCount, 0);
  });

  test(
    'unsaving the only sentence shows a zero-stat completion summary',
    () async {
      final scope = _testScope(_TestBookmarkDao());
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);

      await notifier.removeCurrentBookmark();

      final state = scope.container.read(bookmarkReviewProvider);
      expect(state.currentCard, isNull);
      expect(state.completionSummary, isNotNull);
      expect(state.completionSummary?.reviewedCount, 0);
      expect(state.completionSummary?.ratingCount, 0);
    },
  );

  test('failed unsave keeps current card', () async {
    final scope = _testScope(_TestBookmarkDao(fail: true));
    final container = scope.container;
    addTearDown(() async {
      await _disposeBookmarkContainer(container);
      await scope.database.close();
    });
    final notifier = container.read(bookmarkReviewProvider.notifier);
    await _initializeBookmarkReview(container, [_bookmark(1)]);
    await notifier.removeCurrentBookmark();
    final state = container.read(bookmarkReviewProvider);
    expect(state.remainingCount, 1);
    expect(state.removeError, isNotNull);
    expect(state.isRemoving, isFalse);
  });

  group('视频材料', () {
    test('显示画面时加载视频并由媒体引擎播放，不再走短音频', () async {
      final scope = _videoScope();
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.startCurrentCard();

      final state = scope.container.read(bookmarkReviewProvider);
      expect(scope.engine.loads, ['audio-1']);
      expect(state.videoPhase, BookmarkReviewVideoPhase.ready);
      expect(state.videoAspectRatio, closeTo(16 / 9, 0.001));
      expect(notifier.videoSession, isNotNull);

      final playback = notifier.replayCurrent();
      await Future<void>.delayed(Duration.zero);
      expect(scope.engine.ranges, [
        (const Duration(seconds: 1), const Duration(seconds: 2)),
      ]);
      expect(scope.player.rangePlays, 0);
      scope.engine.pendingRange!.complete(SentencePlaybackResult.completed);
      await playback;
      expect(
        scope.container.read(bookmarkReviewProvider).playbackState,
        BookmarkReviewPlaybackState.idle,
      );
    });

    test('打断播放会取消媒体引擎的区间播放', () async {
      final scope = _videoScope();
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.startCurrentCard();
      final playback = notifier.replayCurrent();
      await Future<void>.delayed(Duration.zero);

      await notifier.interruptPlayback();
      await playback;

      expect(scope.engine.cancelCalls, greaterThan(0));
      expect(
        scope.container.read(bookmarkReviewProvider).playbackState,
        BookmarkReviewPlaybackState.idle,
      );
    });

    test('设置关闭时不加载视频，仍用短音频播放', () async {
      final scope = _videoScope(showVideo: false);
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.startCurrentCard();

      expect(scope.engine.loads, isEmpty);
      expect(
        scope.container.read(bookmarkReviewProvider).videoPhase,
        BookmarkReviewVideoPhase.none,
      );
      unawaited(notifier.replayCurrent());
      await scope.player.waitForRangePlaybackStart();
      expect(scope.player.rangePlays, 1);
    });

    test('视频加载失败时退回音频播放', () async {
      final scope = _videoScope();
      scope.engine.loadSucceeds = false;
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.startCurrentCard();

      expect(scope.engine.loads, ['audio-1']);
      expect(
        scope.container.read(bookmarkReviewProvider).videoPhase,
        BookmarkReviewVideoPhase.none,
      );
      expect(notifier.videoSession, isNull);
      unawaited(notifier.replayCurrent());
      await scope.player.waitForRangePlaybackStart();
      expect(scope.player.rangePlays, 1);
      expect(scope.engine.ranges, isEmpty);
    });

    test('同一材料的下一张卡只定位到句首，不重新加载；隐藏画面跨卡保留', () async {
      final scope = _videoScope();
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [
        _bookmark(1),
        _bookmark(2),
      ]);
      await notifier.startCurrentCard();
      await notifier.videoSession!.setVisualTrackVisible(false);
      expect(
        scope.container.read(bookmarkReviewProvider).isVideoVisualVisible,
        isFalse,
      );

      await notifier.removeCurrentBookmark();
      await Future<void>.delayed(Duration.zero);

      final state = scope.container.read(bookmarkReviewProvider);
      final next = state.currentCard!;
      expect(scope.engine.loads, ['audio-1']);
      expect(scope.engine.previews.last, next.sentence.startTime);
      expect(state.videoPhase, BookmarkReviewVideoPhase.ready);
      expect(state.isVideoVisualVisible, isFalse);
    });

    test('复习中关闭设置立即释放视频并回到音频', () async {
      final scope = _videoScope();
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.startCurrentCard();
      final settings = scope.container.read(
        bookmarkReviewSettingsProvider.notifier,
      );

      await settings.update(
        scope.container
            .read(bookmarkReviewSettingsProvider)
            .copyWith(showVideo: false),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        scope.container.read(bookmarkReviewProvider).videoPhase,
        BookmarkReviewVideoPhase.none,
      );
      expect(notifier.videoSession, isNull);
      expect(scope.engine.releaseCalls, 1);
    });

    test('退出复习释放视频会话', () async {
      final scope = _videoScope();
      addTearDown(() async {
        scope.container.dispose();
        await scope.database.close();
      });
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);
      await notifier.startCurrentCard();

      await notifier.disposeSession();

      expect(scope.engine.releaseCalls, 1);
      expect(notifier.videoSession, isNull);
    });

    test('切到其它材料的卡片时，旧视频会话不再对外可用', () async {
      final scope = _videoScope();
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      await _addAudioOnlyMedia(scope.database);
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [
        _bookmark(1),
        _bookmarkOf('audio-2', 2),
      ]);
      await notifier.startCurrentCard();
      expect(
        scope.container.read(bookmarkReviewProvider).currentCard?.audioItemId,
        'audio-1',
      );
      expect(notifier.videoSession, isNotNull);

      final gate = scope.audioItemDao.gates['audio-2'] = Completer<void>();
      // 断言失败时也要放行挂起的读取，否则拆除阶段会一直等待。
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });

      // 音频材料的读取挂起期间，页面不得继续拿到上一份视频的会话。
      await notifier.removeCurrentBookmark();
      expect(
        scope.container.read(bookmarkReviewProvider).currentCard?.audioItemId,
        'audio-2',
      );
      expect(notifier.videoSession, isNull);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        scope.container.read(bookmarkReviewProvider).videoPhase,
        BookmarkReviewVideoPhase.none,
      );
      expect(scope.engine.releaseCalls, 1);
    });

    test('视频同步异常时退回音频，仍可自动播放当前句', () async {
      final scope = _videoScope();
      addTearDown(() async {
        await _disposeBookmarkContainer(scope.container);
        await scope.database.close();
      });
      scope.audioItemDao.failingIds.add('audio-1');
      final notifier = scope.container.read(bookmarkReviewProvider.notifier);
      await _initializeBookmarkReview(scope.container, [_bookmark(1)]);

      await notifier.startCurrentCard();

      expect(
        scope.container.read(bookmarkReviewProvider).videoPhase,
        BookmarkReviewVideoPhase.none,
      );
      expect(notifier.videoSession, isNull);
      unawaited(notifier.replayCurrent());
      await scope.player.waitForRangePlaybackStart();
      expect(scope.player.rangePlays, 1);
      expect(scope.engine.ranges, isEmpty);
    });
  });
}

/// 指定材料的书签；供需要多份材料的视频测试使用。
BookmarkWithAudio _bookmarkOf(String audioItemId, int id) => BookmarkWithAudio(
  bookmark: db.Bookmark(
    id: id,
    audioItemId: audioItemId,
    memorySubjectId: 'test-subject-$audioItemId-$id',
    sentenceText: 'Sentence $id',
    startTime: id.toDouble(),
    endTime: id + 1.0,
    // 晚于 _bookmark 的书签，保证视频材料的卡片先被复习。
    createdAt: DateTime(2026, 1, 20 + id),
    updatedAt: DateTime(2026, 1, 20 + id),
    syncStatus: 0,
  ),
  audioName: 'Audio only',
);

Future<void> _addAudioOnlyMedia(db.AppDatabase database) {
  final now = DateTime.now();
  return database.audioItemDao.upsert(
    db.AudioItemsCompanion(
      id: const Value('audio-2'),
      name: const Value('Audio only'),
      audioPath: const Value('media/audio.mp3'),
      addedDate: Value(now),
      updatedAt: Value(now),
    ),
  );
}
