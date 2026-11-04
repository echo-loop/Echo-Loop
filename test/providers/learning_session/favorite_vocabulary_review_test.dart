import 'dart:async';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/daos/saved_word_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_rating.dart';
import 'package:echo_loop/features/memory_scheduler/config/memory_profiles.dart';
import 'package:echo_loop/providers/learning_session/favorite_vocabulary_review_provider.dart';
import 'package:echo_loop/providers/favorite_review_settings_provider.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_schedule.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_commands.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_subject_ref.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_namespaces.dart';
import 'package:echo_loop/features/memory_scheduler/providers/memory_scheduler_providers.dart';
import 'package:echo_loop/models/favorite_review_settings.dart';
import 'package:echo_loop/models/flashcard_item.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart'
    show configureAppDatabaseConnection;

import '../../helpers/mock_providers.dart';

class _FakeTextPlaybackController extends TextPlaybackController {
  int stops = 0;
  final spoken = <String>[];
  bool holdSpeak = false;
  AudioPlaybackResult result = AudioPlaybackResult.completed;
  final speakStarted = Completer<void>();
  Completer<void>? pendingSpeak;

  @override
  TextPlaybackState build() => const TextPlaybackState();

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    spoken.add(text);
    if (!speakStarted.isCompleted) speakStarted.complete();
    if (holdSpeak) {
      final pending = pendingSpeak ??= Completer<void>();
      await pending.future;
    }
    return result;
  }

  @override
  Future<void> stop() async {
    stops++;
    pendingSpeak?.complete();
    pendingSpeak = null;
  }
}

class _FakeTtsController extends TtsController {
  bool holdSpeak = false;
  AudioPlaybackResult result = AudioPlaybackResult.completed;
  final spoken = <String>[];
  final speakStarted = Completer<void>();
  Completer<void>? pendingSpeak;

  @override
  TtsControllerState build() => const TtsControllerState();

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    spoken.add(text);
    state = TtsControllerState(speakingKey: key ?? text);
    if (!speakStarted.isCompleted) speakStarted.complete();
    if (holdSpeak) {
      final pending = pendingSpeak ??= Completer<void>();
      await pending.future;
    }
    state = const TtsControllerState();
    return result;
  }

  @override
  Future<void> stop() async {
    pendingSpeak?.complete();
    pendingSpeak = null;
    state = const TtsControllerState();
  }
}

class _TestFavoriteReviewSettings extends FavoriteReviewSettingsNotifier {
  _TestFavoriteReviewSettings(this.autoPlayFront);

  final bool autoPlayFront;

  @override
  FavoriteReviewSettings build() =>
      FavoriteReviewSettings(autoPlayFront: autoPlayFront);
}

class _FailingSavedWordDao extends SavedWordDao {
  _FailingSavedWordDao(super.database);

  @override
  Future<void> removeWord(String word) => throw StateError('remove failed');
}

db.SavedWord _word(String subjectId, String text, {String? sentenceText}) =>
    db.SavedWord(
      id: subjectId.hashCode,
      word: text,
      memorySubjectId: subjectId,
      practiceCount: 0,
      totalStudyMs: 0,
      viewedBack: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      syncStatus: 0,
      sentenceText: sentenceText,
    );

Future<void> _initializeFavoriteVocabularyReview(
  ProviderContainer container,
  List<db.SavedWord> words,
  List<db.SavedSenseGroup> phrases,
) async {
  final database = container.read(appDatabaseProvider);
  final scheduler = container.read(memorySchedulerProvider);
  final now = DateTime.now();
  for (final word in words) {
    final existing = await (database.select(
      database.savedWords,
    )..where((table) => table.word.equals(word.word))).getSingleOrNull();
    final savedWord = existing ?? word;
    if (existing == null) {
      await database
          .into(database.savedWords)
          .insert(
            db.SavedWordsCompanion.insert(
              word: word.word,
              memorySubjectId: Value(word.memorySubjectId),
              sentenceText: Value(word.sentenceText),
              createdAt: word.createdAt,
              updatedAt: word.updatedAt,
              deletedAt: Value(word.deletedAt),
            ),
          );
    }
    final subjectId = savedWord.memorySubjectId;
    if (subjectId == null || subjectId.trim().isEmpty) continue;
    final subject = MemorySubjectRef(
      namespace: kSavedWordOrPhraseNamespace,
      subjectId: subjectId,
    );
    if (await scheduler.getSchedule(subject) == null) {
      await scheduler.ensureSchedule(
        EnsureMemoryScheduleCommand(
          subject: subject,
          profile: kFsrsDefaultProfileRef,
          occurredAt: now,
        ),
      );
    }
  }
  for (final phrase in phrases) {
    final existing =
        await (database.select(database.savedSenseGroups)
              ..where((table) => table.phraseText.equals(phrase.phraseText)))
            .getSingleOrNull();
    final savedPhrase = existing ?? phrase;
    if (existing == null) {
      await database
          .into(database.savedSenseGroups)
          .insert(
            db.SavedSenseGroupsCompanion.insert(
              phraseText: phrase.phraseText,
              memorySubjectId: Value(phrase.memorySubjectId),
              displayText: phrase.displayText,
              sentenceText: Value(phrase.sentenceText),
              createdAt: phrase.createdAt,
              updatedAt: phrase.updatedAt,
              deletedAt: Value(phrase.deletedAt),
            ),
          );
    }
    final subjectId = savedPhrase.memorySubjectId;
    if (subjectId == null || subjectId.trim().isEmpty) continue;
    final subject = MemorySubjectRef(
      namespace: kSavedSenseGroupNamespace,
      subjectId: subjectId,
    );
    if (await scheduler.getSchedule(subject) == null) {
      await scheduler.ensureSchedule(
        EnsureMemoryScheduleCommand(
          subject: subject,
          profile: kFsrsDefaultProfileRef,
          occurredAt: now,
        ),
      );
    }
  }
  await container.read(favoriteVocabularyReviewProvider.notifier).initialize();
}

void main() {
  late db.AppDatabase database;
  late ProviderContainer container;
  late _FakeTextPlaybackController fakePlayback;
  late _FakeTtsController fakeTts;

  setUp(() {
    database = db.AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    fakePlayback = _FakeTextPlaybackController();
    fakeTts = _FakeTtsController();
    container = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(database),
        textPlaybackProvider.overrideWith(() => fakePlayback),
        ttsControllerProvider.overrideWith(() => fakeTts),
      ]),
    );
  });

  tearDown(() async {
    if (container.exists(favoriteVocabularyReviewProvider)) {
      await container
          .read(favoriteVocabularyReviewProvider.notifier)
          .disposeSession();
    }
    container.dispose();
    await database.close();
  });

  test('initialize builds the deck and starts on front', () async {
    await _initializeFavoriteVocabularyReview(container, [
      _word('w1', 'apple'),
      _word('w2', 'banana'),
    ], []);

    final state = container.read(favoriteVocabularyReviewProvider);
    expect(state.initialTotal, 2);
    expect(state.face, FavoriteVocabularyReviewFace.front);
    expect(state.currentCard?.displayText, isNotEmpty);
  });

  test(
    'replayCurrent uses the shared speech path for a single-word card',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'apple'),
      ], []);
      final card = container
          .read(favoriteVocabularyReviewProvider)
          .currentCard!;

      await notifier.replayCurrent();

      expect(fakePlayback.spoken, [card.displayText]);
      expect(
        container.read(favoriteVocabularyReviewProvider).wordPlaybackState,
        FavoriteVocabularyReviewPlaybackState.idle,
      );
    },
  );

  test(
    'replayCurrent keeps multi-word cards on the existing speech path',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'hello world'),
      ], []);

      await notifier.replayCurrent();

      expect(fakePlayback.spoken, ['hello world']);
    },
  );

  test(
    'completed vocabulary playback writes actual phrase statistics',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'hello world'),
      ], []);

      await notifier.replayCurrent();
      await notifier.disposeSession();

      final record = await database.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      );
      expect(record?.inputWords, 2);
      expect(record?.inputTimeMilliseconds, greaterThanOrEqualTo(0));
      final forms = await database.select(database.learnedWordForms).get();
      expect(
        forms.map((form) => form.wordForm),
        containsAll(['hello', 'world']),
      );
    },
  );

  test('failed vocabulary playback does not write input statistics', () async {
    final notifier = container.read(favoriteVocabularyReviewProvider.notifier);
    await _initializeFavoriteVocabularyReview(container, [
      _word('w1', 'hello world'),
    ], []);
    fakePlayback.result = AudioPlaybackResult.failed;

    await notifier.replayCurrent();
    final state = container.read(favoriteVocabularyReviewProvider);
    expect(
      state.wordPlaybackState,
      FavoriteVocabularyReviewPlaybackState.failed,
    );
    expect(state.mediaError, 'audio_unavailable');

    await notifier.disposeSession();
    final record = await database.dailyStudyRecordDao.getByDate(DateTime.now());
    expect(record?.inputWords ?? 0, 0);
    expect(record?.inputTimeMilliseconds ?? 0, 0);
  });

  test(
    'cancelled vocabulary playback does not write input statistics',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'hello world'),
      ], []);
      fakePlayback.result = AudioPlaybackResult.cancelled;

      await notifier.replayCurrent();

      final state = container.read(favoriteVocabularyReviewProvider);
      expect(
        state.wordPlaybackState,
        FavoriteVocabularyReviewPlaybackState.idle,
      );
      expect(state.mediaError, isNull);
      await notifier.disposeSession();
      final record = await database.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      );
      expect(record?.inputWords ?? 0, 0);
    },
  );

  test(
    'interrupted vocabulary playback does not write input statistics',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'hello world'),
      ], []);
      fakePlayback.holdSpeak = true;

      final playback = notifier.replayCurrent();
      await fakePlayback.speakStarted.future;
      await notifier.interruptPlayback();
      await playback;
      await notifier.disposeSession();

      final record = await database.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      );
      expect(record?.inputWords ?? 0, 0);
      expect(record?.inputTimeMilliseconds ?? 0, 0);
    },
  );

  test(
    'completed source sentence playback writes sentence statistics',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'apple', sentenceText: 'I ate an apple.'),
      ], []);
      await notifier.revealBack();

      await notifier.playSourceSentence();
      await notifier.disposeSession();

      final record = await database.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      );
      expect(record?.inputWords, 4);
      expect(record?.inputTimeMilliseconds, greaterThanOrEqualTo(0));
    },
  );

  test(
    'failed source sentence playback does not write input statistics',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'apple', sentenceText: 'I ate an apple.'),
      ], []);
      await notifier.revealBack();
      fakeTts.result = AudioPlaybackResult.failed;

      await notifier.playSourceSentence();

      final state = container.read(favoriteVocabularyReviewProvider);
      expect(
        state.sourcePlaybackState,
        FavoriteVocabularyReviewPlaybackState.idle,
      );
      expect(state.mediaError, 'audio_unavailable');
      await notifier.disposeSession();
      final record = await database.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      );
      expect(record?.inputWords ?? 0, 0);
      expect(record?.inputTimeMilliseconds ?? 0, 0);
    },
  );

  test(
    'cancelled source sentence playback does not write input statistics',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'apple', sentenceText: 'I ate an apple.'),
      ], []);
      await notifier.revealBack();
      fakeTts.result = AudioPlaybackResult.cancelled;

      await notifier.playSourceSentence();

      final state = container.read(favoriteVocabularyReviewProvider);
      expect(
        state.sourcePlaybackState,
        FavoriteVocabularyReviewPlaybackState.idle,
      );
      expect(state.mediaError, isNull);
      await notifier.disposeSession();
      final record = await database.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      );
      expect(record?.inputWords ?? 0, 0);
    },
  );

  test('shared front auto-play setting controls vocabulary playback', () async {
    final disabledContainer = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(database),
        textPlaybackProvider.overrideWith(() => fakePlayback),
        favoriteReviewSettingsProvider.overrideWith(
          () => _TestFavoriteReviewSettings(false),
        ),
      ]),
    );
    addTearDown(() async {
      await disabledContainer
          .read(favoriteVocabularyReviewProvider.notifier)
          .disposeSession();
      disabledContainer.dispose();
    });
    final notifier = disabledContainer.read(
      favoriteVocabularyReviewProvider.notifier,
    );
    await _initializeFavoriteVocabularyReview(disabledContainer, [
      _word('w1', 'apple'),
    ], []);
    await notifier.startCurrentCard();
    expect(fakePlayback.spoken, isEmpty);
  });

  test('source playback toggles between replay and stop', () async {
    final notifier = container.read(favoriteVocabularyReviewProvider.notifier);
    await _initializeFavoriteVocabularyReview(container, [
      _word('w1', 'apple', sentenceText: 'I ate an apple.'),
    ], []);
    await notifier.revealBack();

    fakeTts.holdSpeak = true;
    final playback = notifier.toggleSourcePlayback();
    await fakeTts.speakStarted.future;
    expect(
      container.read(favoriteVocabularyReviewProvider).sourcePlaybackState,
      FavoriteVocabularyReviewPlaybackState.playing,
    );

    await notifier.toggleSourcePlayback();
    expect(
      container.read(favoriteVocabularyReviewProvider).sourcePlaybackState,
      FavoriteVocabularyReviewPlaybackState.idle,
    );
    expect(fakePlayback.stops, greaterThan(0));
    await playback;
  });

  test('revealBack fetches ratings and submitting advances the deck', () async {
    final notifier = container.read(favoriteVocabularyReviewProvider.notifier);
    await _initializeFavoriteVocabularyReview(container, [
      _word('w1', 'apple'),
      _word('w2', 'banana'),
    ], []);

    await notifier.revealBack();

    final revealed = container.read(favoriteVocabularyReviewProvider);
    expect(revealed.face, FavoriteVocabularyReviewFace.back);
    expect(revealed.preview, isNotNull);
    expect(fakePlayback.stops, greaterThan(0));

    await notifier.selectRating(MemoryRating.good);

    final advanced = container.read(favoriteVocabularyReviewProvider);
    expect(advanced.face, FavoriteVocabularyReviewFace.front);
    expect(advanced.currentCard?.displayText, 'banana');
  });

  test(
    'rating the last card stops word playback before showing completion',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await _initializeFavoriteVocabularyReview(container, [
        _word('w1', 'apple'),
      ], []);
      await notifier.revealBack();

      fakePlayback.holdSpeak = true;
      final playback = notifier.replayCurrent();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(favoriteVocabularyReviewProvider).wordPlaybackState,
        FavoriteVocabularyReviewPlaybackState.playing,
      );

      await notifier.selectRating(MemoryRating.good);
      await playback;

      expect(fakePlayback.stops, greaterThan(0));
      expect(
        container.read(favoriteVocabularyReviewProvider).currentCard,
        isNull,
      );
      expect(
        container.read(favoriteVocabularyReviewProvider).completionSummary,
        isNotNull,
      );
    },
  );

  test('unsaving a word archives its schedule and advances the deck', () async {
    final notifier = container.read(favoriteVocabularyReviewProvider.notifier);
    await database.savedWordDao.saveWord(word: 'apple');
    await database.savedWordDao.saveWord(word: 'banana');
    final words = await database.savedWordDao.getAll();
    await _initializeFavoriteVocabularyReview(container, words, []);
    final removed = switch (container
        .read(favoriteVocabularyReviewProvider)
        .currentCard) {
      FlashcardWordItem item => item,
      _ => throw StateError('current card must be a word'),
    };

    await notifier.removeCurrentVocabulary();

    final state = container.read(favoriteVocabularyReviewProvider);
    expect(state.currentCard?.dbKey, isNot(removed.dbKey));
    expect(
      await database.savedWordDao.isWordSaved(removed.savedWord.word),
      isFalse,
    );
    final subjectId = removed.memorySubjectId;
    if (subjectId == null) fail('saved word must have a memory subject ID');
    final schedule = await container
        .read(memorySchedulerProvider)
        .getSchedule(
          MemorySubjectRef(
            namespace: kSavedWordOrPhraseNamespace,
            subjectId: subjectId,
          ),
        );
    expect(schedule?.status, MemoryScheduleStatus.archived);
  });

  test('empty deck creates a zero-stat completion summary', () async {
    final notifier = container.read(favoriteVocabularyReviewProvider.notifier);

    await notifier.initialize();

    final state = container.read(favoriteVocabularyReviewProvider);
    expect(state.currentCard, isNull);
    expect(state.completionSummary, isNotNull);
    expect(state.completionSummary?.reviewedCount, 0);
    expect(state.completionSummary?.ratingCount, 0);
  });

  test(
    'unsaving a sense group archives its schedule and completes the deck',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await database.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'on the table',
        displayText: 'on the table',
      );
      final first = (await database.savedSenseGroupDao.watchAll().first).single;
      await _initializeFavoriteVocabularyReview(container, [], [first]);

      await notifier.removeCurrentVocabulary();

      final state = container.read(favoriteVocabularyReviewProvider);
      expect(state.currentCard, isNull);
      expect(state.completionSummary, isNotNull);
      expect(state.completionSummary?.reviewedCount, 0);
      expect(state.completionSummary?.ratingCount, 0);
      expect(
        await database.savedSenseGroupDao.isSenseGroupSaved(first.phraseText),
        isFalse,
      );
      final subjectId = first.memorySubjectId;
      if (subjectId == null) {
        fail('saved sense group must have a memory subject ID');
      }
      final schedule = await container
          .read(memorySchedulerProvider)
          .getSchedule(
            MemorySubjectRef(
              namespace: kSavedSenseGroupNamespace,
              subjectId: subjectId,
            ),
          );
      expect(schedule?.status, MemoryScheduleStatus.archived);
    },
  );

  test('failed unsave keeps the current card and exposes an error', () async {
    await database.savedWordDao.saveWord(word: 'apple');
    final failingContainer = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(database),
        textPlaybackProvider.overrideWith(() => fakePlayback),
        savedWordDaoProvider.overrideWithValue(_FailingSavedWordDao(database)),
      ]),
    );
    addTearDown(failingContainer.dispose);
    final notifier = failingContainer.read(
      favoriteVocabularyReviewProvider.notifier,
    );
    await _initializeFavoriteVocabularyReview(failingContainer, [
      _word('w1', 'apple'),
    ], []);

    await notifier.removeCurrentVocabulary();

    final state = failingContainer.read(favoriteVocabularyReviewProvider);
    expect(state.currentCard?.displayText, 'apple');
    expect(state.isRemoving, isFalse);
    expect(state.removeError, 'unsave_failed');
    await notifier.disposeSession();
  });

  test(
    'unsaving the only word creates a zero-stat completion summary',
    () async {
      final notifier = container.read(
        favoriteVocabularyReviewProvider.notifier,
      );
      await database.savedWordDao.saveWord(word: 'apple');
      final first = (await database.savedWordDao.getAll()).single;
      await _initializeFavoriteVocabularyReview(container, [first], const []);

      await notifier.removeCurrentVocabulary();

      final state = container.read(favoriteVocabularyReviewProvider);
      expect(state.currentCard, isNull);
      expect(state.completionSummary, isNotNull);
      expect(state.completionSummary?.reviewedCount, 0);
      expect(state.completionSummary?.ratingCount, 0);
    },
  );
}
