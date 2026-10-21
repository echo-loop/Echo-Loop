import 'dart:async';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_rating.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_model_adapter.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_results.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_schedule.dart';
import 'package:echo_loop/features/scheduled_flashcard/domain/review_session_summary.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/user_region/user_region_bootstrapper.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/models/flashcard_item.dart';
import 'package:echo_loop/models/favorite_review_settings.dart';
import 'package:echo_loop/models/pronunciation/pronunciation_clip.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/favorite_review_settings_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/learning_session/favorite_vocabulary_review_provider.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/screens/favorite_vocabulary_review_screen.dart';
import 'package:echo_loop/widgets/review/review_completion_summary.dart';
import 'package:echo_loop/widgets/practice/selectable_sentence_text.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary/local_dictionary_source.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/utils/time_format.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedWord _word(
  String text, {
  required String memorySubjectId,
  String? sentenceText,
}) => SavedWord(
  id: memorySubjectId.hashCode,
  word: text,
  memorySubjectId: memorySubjectId,
  practiceCount: 0,
  totalStudyMs: 0,
  viewedBack: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  sentenceText: sentenceText,
  syncStatus: 0,
);

MemoryRatingPreview _preview(MemoryRating rating, DateTime dueAt) =>
    MemoryRatingPreview(
      scheduleId: 'test-schedule',
      revision: 0,
      rating: rating,
      reviewedAt: DateTime.now().toUtc(),
      dueAt: dueAt,
      interval: dueAt.difference(DateTime.now().toUtc()),
      phase: MemorySchedulePhase.review,
      transition: MemoryModelTransition(
        state: MemoryModelState(version: 1, values: const <String, Object?>{}),
        phase: MemorySchedulePhase.review,
        dueAt: dueAt,
        lastReviewedAt: DateTime.now().toUtc(),
      ),
    );

class _TestFavoriteReviewSettings extends FavoriteReviewSettingsNotifier {
  _TestFavoriteReviewSettings(
    this.showNextReviewTime, {
    this.autoShowAiLookup = false,
    this.showVocabularyOnFront = false,
  });

  final bool showNextReviewTime;
  final bool autoShowAiLookup;
  final bool showVocabularyOnFront;

  @override
  FavoriteReviewSettings build() => FavoriteReviewSettings(
    showNextReviewTime: showNextReviewTime,
    autoShowAiLookup: autoShowAiLookup,
    showVocabularyOnFront: showVocabularyOnFront,
  );
}

class _TestFavoriteVocabularyReview extends FavoriteVocabularyReview {
  _TestFavoriteVocabularyReview({
    this.withSource = false,
    this.vocabulary = 'apple',
    this.disposeSessionWaiter,
  });

  final bool withSource;
  final String vocabulary;
  final Future<void> Function()? disposeSessionWaiter;

  @override
  FavoriteVocabularyReviewState build() {
    final now = DateTime.now().toUtc();
    return FavoriteVocabularyReviewState(
      currentCard: FlashcardWordItem(
        savedWord: _word(
          vocabulary,
          memorySubjectId: 'w-1',
          sentenceText: withSource ? 'I ate an apple this morning.' : null,
        ),
      ),
      initialTotal: 1,
      remainingCount: 1,
      preview: MemoryRatingPreviewSet(
        scheduleId: 'test-schedule',
        revision: 1,
        reviewedAt: now,
        again: _preview(
          MemoryRating.again,
          now.add(const Duration(minutes: 9)),
        ),
        hard: _preview(MemoryRating.hard, now.add(const Duration(hours: 1))),
        good: _preview(MemoryRating.good, now.add(const Duration(hours: 3))),
        easy: _preview(MemoryRating.easy, now.add(const Duration(days: 16))),
      ),
    );
  }

  @override
  Future<void> startCurrentCard() async {}

  @override
  Future<void> replayCurrent() async {
    state = state.copyWith(
      wordPlaybackState: FavoriteVocabularyReviewPlaybackState.playing,
      sourcePlaybackState: FavoriteVocabularyReviewPlaybackState.idle,
    );
  }

  @override
  Future<void> interruptPlayback() async {
    state = state.copyWith(
      wordPlaybackState: FavoriteVocabularyReviewPlaybackState.idle,
      sourcePlaybackState: FavoriteVocabularyReviewPlaybackState.idle,
    );
  }

  @override
  Future<void> toggleSourcePlayback() async {
    state = state.copyWith(
      wordPlaybackState: FavoriteVocabularyReviewPlaybackState.idle,
      sourcePlaybackState:
          state.sourcePlaybackState ==
              FavoriteVocabularyReviewPlaybackState.playing
          ? FavoriteVocabularyReviewPlaybackState.idle
          : FavoriteVocabularyReviewPlaybackState.playing,
    );
  }

  @override
  Future<void> revealBack() async {
    state = state.copyWith(face: FavoriteVocabularyReviewFace.back);
  }

  @override
  Future<void> removeCurrentVocabulary() async {
    state = state.copyWith(
      clearCurrentCard: true,
      completionSummary: const ReviewSessionSummary(),
    );
  }

  @override
  Future<void> disposeSession() async {
    state = const FavoriteVocabularyReviewState();
    final waiter = disposeSessionWaiter;
    if (waiter != null) await waiter();
  }
}

class _TestLocalDictionarySource extends LocalDictionarySource {
  _TestLocalDictionarySource() : super(DictionaryService.instance);

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async => LocalDictResult(
    DictEntry(word: request.word, phonetic: 'x', translation: '释义'),
  );
}

late SharedPreferences _sharedPreferences;

Finder get _favoriteVocabularyReviewPopScope =>
    find.byWidgetPredicate((widget) => widget is PopScope);

Widget _app({
  bool showNextReviewTime = false,
  bool autoShowAiLookup = false,
  bool showVocabularyOnFront = false,
  bool withSource = false,
  String vocabulary = 'apple',
  List<PronunciationClip> pronunciationClips = const [],
  GoRouter? router,
  Future<void> Function()? disposeSessionWaiter,
}) {
  final child = router == null
      ? MaterialApp(
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FavoriteVocabularyReviewScreen(),
        )
      : MaterialApp.router(
          locale: const Locale('zh'),
          theme: AppTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        );
  return ProviderScope(
    overrides: [
      favoriteVocabularyReviewProvider.overrideWith(
        () => _TestFavoriteVocabularyReview(
          withSource: withSource,
          vocabulary: vocabulary,
          disposeSessionWaiter: disposeSessionWaiter,
        ),
      ),
      favoriteReviewSettingsProvider.overrideWith(
        () => _TestFavoriteReviewSettings(
          showNextReviewTime,
          autoShowAiLookup: autoShowAiLookup,
          showVocabularyOnFront: showVocabularyOnFront,
        ),
      ),
      sharedPreferencesProvider.overrideWithValue(_sharedPreferences),
      userRegionBootstrapProvider.overrideWith(
        (ref) async => const UserRegionBootstrapResult(
          isChinaUser: false,
          source: UserRegionDecisionSource.systemFallback,
          remoteConfig: RemoteConfig.defaults,
        ),
      ),
      localDictionarySourceProvider.overrideWithValue(
        _TestLocalDictionarySource(),
      ),
      pronunciationClipsProvider.overrideWith(
        (ref, word) => pronunciationClips,
      ),
    ],
    child: child,
  );
}

void main() {
  setUpAll(() async {
    initTimeago();
    SharedPreferences.setMockInitialValues({});
    _sharedPreferences = await SharedPreferences.getInstance();
  });

  testWidgets('front shows title, progress bar and equal listen/reveal split', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.text('收藏词汇复习'), findsOneWidget);
    expect(
      find.byKey(const Key('favorite-vocabulary-review-progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('favorite-vocabulary-review-status-bar')),
      findsOneWidget,
    );
    final progressBottom = tester
        .getBottomLeft(
          find.byKey(const Key('favorite-vocabulary-review-progress')),
        )
        .dy;
    final listenTop = tester
        .getTopLeft(
          find.byKey(const Key('favorite-vocabulary-review-listen-zone')),
        )
        .dy;
    expect(listenTop - progressBottom, closeTo(4, 0.1));
    final listen = tester.getSize(
      find.byKey(const Key('favorite-vocabulary-review-listen-zone')),
    );
    final reveal = tester.getSize(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    expect(reveal.height / listen.height, closeTo(1, 0.02));
    final revealBottom = tester
        .getBottomLeft(
          find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
        )
        .dy;
    final statusTop = tester
        .getTopLeft(
          find.byKey(const Key('favorite-vocabulary-review-status-bar')),
        )
        .dy;
    expect(statusTop - revealBottom, closeTo(4, 0.1));
  });

  testWidgets('front hides vocabulary by default', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(
      find.byKey(const Key('favorite-vocabulary-review-front-word')),
      findsNothing,
    );
  });

  testWidgets('front shows vocabulary in the listen zone when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(showVocabularyOnFront: true));
    await tester.pump();
    final word = find.byKey(const Key('favorite-vocabulary-review-front-word'));
    expect(word, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('favorite-vocabulary-review-listen-zone')),
        matching: word,
      ),
      findsOneWidget,
    );
    expect(find.text('apple'), findsOneWidget);
  });

  testWidgets('front playback icon uses neutral and active colors', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final theme = Theme.of(
      tester.element(
        find.byKey(const Key('favorite-vocabulary-review-listen-zone')),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.volume_up_rounded)).color,
      theme.colorScheme.onSurfaceVariant,
    );

    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-listen-zone')),
    );
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.volume_up_rounded)).color,
      theme.colorScheme.primary,
    );
  });

  testWidgets('back groups vocabulary playback separately from unsave', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    final playback = find.byKey(
      const Key('favorite-vocabulary-review-word-playback'),
    );
    final unsave = find.byKey(const Key('favorite-vocabulary-review-unsave'));
    expect(playback, findsOneWidget);
    expect(unsave, findsOneWidget);
    expect(
      tester.getSize(playback).height,
      lessThanOrEqualTo(tester.getSize(unsave).height),
    );
    expect(
      tester.getTopRight(playback).dx,
      lessThan(tester.getTopLeft(unsave).dx),
    );
    expect(
      tester.getTopRight(unsave).dx,
      closeTo(
        tester
            .getTopRight(
              find.byKey(const Key('favorite-vocabulary-review-progress')),
            )
            .dx,
        0.1,
      ),
    );
    expect(tester.getSize(playback).width, lessThan(200));
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-back-word')),
    );
    await tester.pump();
    final theme = Theme.of(tester.element(playback));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.volume_up_outlined)).color,
      theme.colorScheme.primary,
    );
  });

  testWidgets('long vocabulary stays inline and wraps without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(vocabulary: 'a tendency towards something remarkably memorable'),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final word = tester.widget<Text>(
      find.byKey(const Key('favorite-vocabulary-review-back-word')),
    );
    expect(word.softWrap, isTrue);
    var hasInlinePlayback = false;
    word.textSpan?.visitChildren((span) {
      if (span is WidgetSpan && span.alignment == PlaceholderAlignment.middle) {
        hasInlinePlayback = true;
      }
      return true;
    });
    expect(hasInlinePlayback, isTrue);
    expect(
      find.byKey(const Key('favorite-vocabulary-review-word-playback')),
      findsOneWidget,
    );

    final playback = find.byKey(
      const Key('favorite-vocabulary-review-word-playback'),
    );
    final theme = Theme.of(tester.element(playback));
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-back-word')),
    );
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.volume_up_outlined)).color,
      theme.colorScheme.primary,
    );
  });

  testWidgets(
    'close falls back to favorites when the review route cannot pop',
    (tester) async {
      final disposeGate = Completer<void>();
      addTearDown(() {
        if (!disposeGate.isCompleted) disposeGate.complete();
      });
      final router = GoRouter(
        initialLocation: '/favorite-vocabulary-review',
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (context, state) =>
                const Scaffold(body: Text('Favorites')),
          ),
          GoRoute(
            path: '/favorite-vocabulary-review',
            builder: (context, state) => const FavoriteVocabularyReviewScreen(),
            onExit: (_, __) async {
              await disposeGate.future;
              return true;
            },
          ),
        ],
      );
      await tester.pumpWidget(
        _app(router: router, disposeSessionWaiter: () => disposeGate.future),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('favorite-vocabulary-review-close')),
      );
      await tester.pump();

      expect(find.byType(ReviewCompletionSummary), findsNothing);

      disposeGate.complete();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/favorites');
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('本次复习已没有收藏词汇。'), findsNothing);
    },
  );

  testWidgets('native route pop stays enabled while dictionary is closed', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(
      tester.widget<PopScope>(_favoriteVocabularyReviewPopScope).canPop,
      isTrue,
    );
  });

  testWidgets('status bar stays at the bottom on both card faces', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final status = find.byKey(
      const Key('favorite-vocabulary-review-status-bar'),
    );
    expect(
      tester.getTopLeft(status).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
            )
            .dy,
      ),
    );

    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();
    expect(status, findsOneWidget);
    expect(
      tester.getTopLeft(status).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const Key('favorite-vocabulary-review-back-word')),
            )
            .dy,
      ),
    );
  });

  testWidgets(
    'upper zone replays and lower zone reveals the word and ratings',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('favorite-vocabulary-review-listen-zone')),
      );
      await tester.pump();
      expect(find.text('正在播放'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('favorite-vocabulary-review-back-word')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('favorite-vocabulary-review-word-speak')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('favorite-vocabulary-review-ai-toggle')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('flashcard-rating-again')), findsOneWidget);
      expect(find.byKey(const Key('flashcard-rating-good')), findsOneWidget);
      expect(find.byKey(const Key('flashcard-rating-easy')), findsOneWidget);
      expect(find.textContaining('后'), findsNothing);
    },
  );

  testWidgets('rating previews show relative future times when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(showNextReviewTime: true));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    expect(find.text('9分钟后'), findsOneWidget);
    expect(find.text('3小时后'), findsOneWidget);
    expect(find.text('16天后'), findsOneWidget);
  });

  testWidgets('自动显示 AI 查词开启时翻面自动展示 AI 结果', (tester) async {
    await tester.pumpWidget(_app(autoShowAiLookup: true));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('favorite-vocabulary-review-ai-toggle')),
      findsOneWidget,
    );
    expect(find.text('AI 查词'), findsOneWidget);
    expect(find.text('查看智能释义与例句'), findsNothing);
  });

  testWidgets('自动显示 AI 查词关闭时翻面保持折叠', (tester) async {
    await tester.pumpWidget(_app(autoShowAiLookup: false));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '显示 AI 查词' &&
            widget.properties.toggled == false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('来源句、来源材料和 AI 查词入口使用分组内容层级', (tester) async {
    await tester.pumpWidget(_app(withSource: true));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    expect(find.text('来源句子'), findsNothing);
    expect(
      find.byKey(const Key('favorite-vocabulary-review-source')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('favorite-vocabulary-review-source')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('favorite-vocabulary-review-ai-toggle')),
      findsOneWidget,
    );
    expect(find.byType(SelectableSentenceText), findsOneWidget);
    expect(
      find.byKey(const Key('favorite-vocabulary-review-source-play')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('favorite-vocabulary-review-source-playback')),
      findsOneWidget,
    );
  });

  testWidgets('来源句播放控件位于评分栏上方并切换播放与停止图标', (tester) async {
    await tester.pumpWidget(_app(withSource: true));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    final theme = Theme.of(
      tester.element(
        find.byKey(const Key('favorite-vocabulary-review-source-playback')),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
      theme.colorScheme.onSurfaceVariant,
    );
    final playback = find.byKey(
      const Key('favorite-vocabulary-review-source-playback'),
    );
    final ratings = find.byKey(
      const Key('favorite-vocabulary-review-rating-bar'),
    );
    final status = find.byKey(
      const Key('favorite-vocabulary-review-status-bar'),
    );
    expect(tester.getSize(playback).height, 44);
    expect(tester.getSize(playback).width, tester.getSize(ratings).width);
    expect(
      tester.getTopLeft(ratings).dy - tester.getBottomLeft(playback).dy,
      closeTo(8, 0.1),
    );
    expect(
      tester.getTopLeft(status).dy - tester.getBottomLeft(ratings).dy,
      closeTo(8, 0.1),
    );

    await tester.tap(
      find.byKey(
        const Key('favorite-vocabulary-review-source-playback-toggle'),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.stop_rounded)).color,
      theme.colorScheme.primary,
    );

    await tester.tap(
      find.byKey(
        const Key('favorite-vocabulary-review-source-playback-toggle'),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
      theme.colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('词汇和来源句播放互相抢占但不联动图标状态', (tester) async {
    await tester.pumpWidget(_app(withSource: true));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-word-speak')),
    );
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    final theme = Theme.of(
      tester.element(
        find.byKey(const Key('favorite-vocabulary-review-back-word')),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.volume_up_outlined)).color,
      theme.colorScheme.primary,
    );

    await tester.tap(
      find.byKey(
        const Key('favorite-vocabulary-review-source-playback-toggle'),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.volume_up_outlined)).color,
      theme.colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('背面内容与进度条及评分栏左右对齐', (tester) async {
    await tester.pumpWidget(_app(withSource: true));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();

    final progress = tester.getTopLeft(
      find.byKey(const Key('favorite-vocabulary-review-progress')),
    );
    final source = tester.getTopLeft(
      find.byKey(const Key('favorite-vocabulary-review-source')),
    );
    final ratingBar = tester.getTopLeft(
      find.byKey(const Key('favorite-vocabulary-review-rating-bar')),
    );

    expect(source.dx, progress.dx);
    expect(ratingBar.dx, progress.dx);
  });

  testWidgets('multiple pronunciations keep badges and hide title playback', (
    tester,
  ) async {
    const clips = [
      PronunciationClip(
        word: 'apple',
        locale: 'us',
        audioFilename: 'apple_v_past.opus',
        absolutePath: '/audio/apple_v_past.opus',
        reason: PronunciationReason.pastTense,
      ),
      PronunciationClip(
        word: 'apple',
        locale: 'us',
        audioFilename: 'apple_v_present.opus',
        absolutePath: '/audio/apple_v_present.opus',
        reason: PronunciationReason.presentTense,
      ),
    ];
    await tester.pumpWidget(_app(pronunciationClips: clips));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('favorite-vocabulary-review-word-speak')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('favorite-vocabulary-review-word-playback')),
      findsNothing,
    );
    expect(find.byKey(const Key('dict_pronunciation_badges')), findsOneWidget);
    expect(find.text('过去式'), findsOneWidget);
    expect(find.text('一般现在时'), findsOneWidget);
  });

  testWidgets(
    'back has a trailing unsave action that removes the current card',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('favorite-vocabulary-review-reveal-zone')),
      );
      await tester.pump();

      final action = find.byKey(const Key('favorite-vocabulary-review-unsave'));
      expect(action, findsOneWidget);
      expect(
        find.descendant(of: action, matching: find.text('取消收藏')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: action, matching: find.byIcon(Icons.bookmark)),
        findsOneWidget,
      );

      await tester.tap(action);
      await tester.pump();
      expect(find.byType(ReviewCompletionSummary), findsOneWidget);
      expect(find.text('本次复习已没有收藏词汇。'), findsNothing);
    },
  );

  testWidgets('settings opens the shared sheet with vocabulary controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('favorite-vocabulary-review-settings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('显示下次复习时间'), findsOneWidget);
    expect(find.text('复习顺序'), findsOneWidget);
    expect(find.text('收藏词汇复习'), findsNWidgets(2));
    expect(find.text('自动显示 AI 讲解'), findsOneWidget);
    expect(find.text('正面显示词汇'), findsOneWidget);
    expect(find.text('收藏句子复习'), findsOneWidget);

    final toggle = find.byKey(
      const Key('favorite-review-show-vocabulary-on-front'),
    );
    final switchControl = find.descendant(
      of: toggle,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(switchControl).value, isFalse);
    await tester.tap(switchControl);
    await tester.pump();
    expect(tester.widget<Switch>(switchControl).value, isTrue);
  });
}
