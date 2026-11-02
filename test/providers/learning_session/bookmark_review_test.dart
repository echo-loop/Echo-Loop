import 'dart:async';
import 'dart:io';

import 'package:echo_loop/database/app_database.dart' as db;
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
import 'package:echo_loop/providers/favorite_review_settings_provider.dart';
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/utils/app_data_dir.dart' as app_data_dir;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import '../../helpers/mock_providers.dart';
import 'package:echo_loop/database/app_database.dart' show configureAppDatabaseConnection;

class _TestBookmarkDao implements BookmarkDao {
  _TestBookmarkDao({this.fail = false});
  final bool fail;
  final removed = <(String, int)>[];

  @override
  Future<void> removeBookmark(String audioItemId, int sentenceIndex) async {
    if (fail) throw StateError('failed');
    removed.add((audioItemId, sentenceIndex));
  }

  @override
  Future<void> removeBookmarks(
    String audioItemId,
    Set<int> sentenceIndices,
  ) async {
    if (fail) throw StateError('failed');
    for (final sentenceIndex in sentenceIndices) {
      removed.add((audioItemId, sentenceIndex));
    }
  }

  @override
  Future<db.Bookmark?> getByAudioAndSentence(
    String audioItemId,
    int sentenceIndex,
  ) async => db.Bookmark(
    id: sentenceIndex,
    audioItemId: audioItemId,
    memorySubjectId: 'test-subject-$sentenceIndex',
    sentenceIndex: sentenceIndex,
    sentenceText: 'Sentence $sentenceIndex',
    startTime: sentenceIndex.toDouble(),
    endTime: sentenceIndex + 1.0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    syncStatus: 0,
  );

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
    sentenceIndex: id,
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
    analyticsOverride(),
  ]),
);

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
  final database = db.AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
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
            sentenceIndex: bookmark.sentenceIndex,
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
        container.read(bookmarkReviewProvider).currentCard?.sentence.index,
        3,
      );

      final reordered = Completer<void>();
      final subscription = container.listen(bookmarkReviewProvider, (_, next) {
        if (next.currentCard?.sentence.index == 1 && !reordered.isCompleted) {
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
      expect(state.currentCard?.sentence.index, 1);
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
      final foreground =
          container.read(foregroundAudioEngineProvider.notifier)
              as _RecordingForegroundAudioEngine;
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
    final foreground =
        container.read(foregroundAudioEngineProvider.notifier)
            as _RecordingForegroundAudioEngine;
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
    expect(dao.removed, [(removed.audioItemId, removed.originalSentenceIndex)]);
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
}
