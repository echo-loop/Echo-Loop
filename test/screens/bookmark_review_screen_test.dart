import 'dart:async';

import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/user_region/user_region_bootstrapper.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_rating.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_model_adapter.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_results.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_schedule.dart';
import 'package:echo_loop/features/scheduled_flashcard/domain/review_session_summary.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/bookmark_sentence.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/bookmark_review_settings_provider.dart';
import 'package:echo_loop/providers/favorite_review_settings_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/screens/bookmark_review_screen.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/services/pronunciation/local_audio_sense_group_range_playback.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:echo_loop/widgets/practice/sentence_explanation_view.dart';
import 'package:echo_loop/widgets/review/review_completion_summary.dart';
import 'package:echo_loop/widgets/selection/app_selectable_text.dart';
import 'package:dio/dio.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/utils/time_format.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

class _NoopSentenceAiApiClient extends SentenceAiApiClient {
  _NoopSentenceAiApiClient() : super.withDio(Dio());
}

/// 页面测试不加载原生 media_kit，发音按钮使用无副作用的短音频后端。
class _NoopShortAudioBackend implements AudioClipPlayerBackend {
  @override
  Stream<void> get completed => const Stream<void>.empty();

  @override
  Stream<String> get errors => const Stream<String>.empty();

  @override
  Stream<Duration> get positions => const Stream<Duration>.empty();

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> open(String filePath, {Duration start = Duration.zero}) async {}

  @override
  Future<void> stop() async {}
}

/// 测试词典源：让收藏背面的点词测试完整构建面板，而不触达真实词典服务。
class _EchoDictionarySource implements DictionarySource {
  @override
  String get id => 'local';

  @override
  IconData get icon => Icons.abc;

  @override
  bool get canBeDisabled => false;

  @override
  bool get requiresNetwork => false;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async => LocalDictResult(
    DictEntry(word: request.word, phonetic: 'x', translation: 'definition'),
  );
}

class _TestBookmarkReview extends BookmarkReview {
  _TestBookmarkReview({this.disposeSessionWaiter});

  final Future<void> Function()? disposeSessionWaiter;

  @override
  BookmarkReviewState build() {
    final now = DateTime.now().toUtc();
    final preview = MemoryRatingPreviewSet(
      scheduleId: 'test-schedule',
      revision: 1,
      reviewedAt: now,
      again: _preview(MemoryRating.again, now.add(const Duration(minutes: 9))),
      hard: _preview(MemoryRating.hard, now.add(const Duration(hours: 1))),
      good: _preview(MemoryRating.good, now.add(const Duration(hours: 3))),
      easy: _preview(MemoryRating.easy, now.add(const Duration(days: 16))),
    );
    return BookmarkReviewState(
      currentCard: BookmarkSentence(
        sentence: Sentence(
          index: 2,
          text: 'Hidden sentence',
          startTime: Duration(seconds: 1),
          endTime: Duration(milliseconds: 3500),
          isBookmarked: true,
        ),
        audioItemId: 'audio-1',
        memorySubjectId: 'test-subject-2',
        audioName: 'Daily Listening',
        originalSentenceIndex: 2,
      ),
      initialTotal: 1,
      remainingCount: 1,
      preview: preview,
    );
  }

  /// 构建固定的评分预览，供评分栏展示回归测试使用。
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
          state: MemoryModelState(
            version: 1,
            values: const <String, Object?>{},
          ),
          phase: MemorySchedulePhase.review,
          dueAt: dueAt,
          lastReviewedAt: DateTime.now().toUtc(),
        ),
      );

  @override
  Future<void> startCurrentCard() async {}
  @override
  Future<void> replayCurrent() async {
    state = state.copyWith(playbackState: BookmarkReviewPlaybackState.playing);
  }

  @override
  Future<void> interruptPlayback() async {
    state = state.copyWith(playbackState: BookmarkReviewPlaybackState.idle);
  }

  @override
  Future<void> toggleCurrentPlayback() async {
    if (state.playbackState == BookmarkReviewPlaybackState.playing) {
      await interruptPlayback();
    } else {
      await replayCurrent();
    }
  }

  @override
  Future<void> disposeSession() async {
    state = const BookmarkReviewState();
    final waiter = disposeSessionWaiter;
    if (waiter != null) await waiter();
  }

  @override
  Future<void> revealBack() async {
    state = state.copyWith(face: BookmarkReviewFace.back);
  }

  @override
  Future<void> removeCurrentBookmark() async {
    state = state.copyWith(
      clearCurrentCard: true,
      completionSummary: const ReviewSessionSummary(),
    );
  }
}

class _TestDao implements BookmarkDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

late final SharedPreferences _sharedPreferences;
final _dictionarySource = _EchoDictionarySource();

Finder get _bookmarkReviewPopScope =>
    find.byWidgetPredicate((widget) => widget is PopScope);

Widget _app({
  Locale locale = const Locale('zh'),
  GoRouter? router,
  Future<void> Function()? disposeSessionWaiter,
}) {
  final child = router == null
      ? MaterialApp(
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BookmarkReviewScreen(),
        )
      : MaterialApp.router(
          locale: locale,
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
      bookmarkReviewProvider.overrideWith(
        () => _TestBookmarkReview(disposeSessionWaiter: disposeSessionWaiter),
      ),
      bookmarkDaoProvider.overrideWithValue(_TestDao()),
      audioItemDaoProvider.overrideWithValue(FakeAudioItemDao()),
      sentenceAiNotifierProvider.overrideWithValue(
        SentenceAiNotifier(
          cacheDao: createStubbedMockCacheDao(),
          apiClient: _NoopSentenceAiApiClient(),
        ),
      ),
      ...learningSettingsOverrides(),
      analyticsOverride(),
      dictionaryOverride(),
      sharedPreferencesProvider.overrideWithValue(_sharedPreferences),
      userRegionBootstrapProvider.overrideWith(
        (ref) async => const UserRegionBootstrapResult(
          isChinaUser: false,
          source: UserRegionDecisionSource.systemFallback,
          remoteConfig: RemoteConfig.defaults,
        ),
      ),
      dictionarySourcesProvider.overrideWithValue([_dictionarySource]),
      dictionarySourcesByIdProvider.overrideWithValue({
        _dictionarySource.id: _dictionarySource,
      }),
      resolvedDefaultSourceIdProvider.overrideWithValue(_dictionarySource.id),
      shortAudioPlayerProvider.overrideWithValue(
        LocalAudioClipPlayer(backend: _NoopShortAudioBackend()),
      ),
      dictionaryLookupContextProvider.overrideWithValue(
        const DictionaryLookupContext(targetLanguage: 'zh-CN'),
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

  testWidgets('front is minimal and shows source duration and unsave', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.text('收藏句复习'), findsOneWidget);
    expect(find.text('来自：Daily Listening'), findsOneWidget);
    expect(find.text('2.5秒'), findsOneWidget);
    expect(find.text('取消收藏'), findsOneWidget);
    expect(find.text('偷看字幕'), findsNothing);
    expect(find.text('听不太懂'), findsNothing);
    expect(find.text('Hidden sentence'), findsNothing);
    expect(find.byKey(const Key('bookmark-review-progress')), findsOneWidget);
    expect(find.byKey(const Key('bookmark-review-status-bar')), findsOneWidget);
  });

  testWidgets('sentence review uses its AI auto-display settings', (
    tester,
  ) async {
    await _sharedPreferences.clear();
    await _sharedPreferences.setBool(
      LearningSettingsKeys.autoShowAiExplanation,
      false,
    );
    addTearDown(_sharedPreferences.clear);
    await tester.pumpWidget(_app());
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookmarkReviewScreen)),
    );
    expect(
      container.read(learningSettingsProvider).autoShowAiExplanation,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final defaultExplanation = tester.widget<SentenceExplanationView>(
      find.byType(SentenceExplanationView),
    );
    expect(defaultExplanation.autoShowAiExplanation, isTrue);

    final settings = container.read(bookmarkReviewSettingsProvider);
    await container
        .read(bookmarkReviewSettingsProvider.notifier)
        .update(
          settings.copyWith(
            autoShowAiExplanation: false,
            autoShowAiAnalysis: true,
            autoShowAiTranslation: true,
            autoShowAiSenseGroups: true,
          ),
        );
    await tester.pump();

    final explanation = tester.widget<SentenceExplanationView>(
      find.byType(SentenceExplanationView),
    );
    expect(explanation.autoShowAiExplanation, isFalse);
    expect(explanation.autoShowAiAnalysis, isTrue);
    expect(explanation.autoShowAiTranslation, isTrue);
    expect(explanation.autoShowAiSenseGroups, isTrue);
  });

  testWidgets('unsaving the final sentence shows the completion summary', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byKey(const Key('bookmark-review-unsave')));
    await tester.pump();

    expect(find.byType(ReviewCompletionSummary), findsOneWidget);
    expect(find.text('本次复习已没有收藏句。'), findsNothing);
  });

  testWidgets(
    'close falls back to favorites when the review route cannot pop',
    (tester) async {
      final disposeGate = Completer<void>();
      addTearDown(() {
        if (!disposeGate.isCompleted) disposeGate.complete();
      });
      final router = GoRouter(
        initialLocation: '/bookmark-review',
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (context, state) =>
                const Scaffold(body: Text('Favorites')),
          ),
          GoRoute(
            path: '/bookmark-review',
            builder: (context, state) => const BookmarkReviewScreen(),
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

      await tester.tap(find.byKey(const Key('bookmark-review-close')));
      await tester.pump();

      expect(find.byType(ReviewCompletionSummary), findsNothing);

      disposeGate.complete();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/favorites');
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('本次复习已没有收藏句。'), findsNothing);
    },
  );

  testWidgets('status bar stays at the bottom on both card faces', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final status = find.byKey(const Key('bookmark-review-status-bar'));
    expect(
      tester.getTopLeft(status).dy,
      greaterThanOrEqualTo(
        tester
            .getBottomLeft(find.byKey(const Key('bookmark-review-reveal-zone')))
            .dy,
      ),
    );

    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();
    expect(status, findsOneWidget);
    expect(
      tester.getTopLeft(status).dy,
      greaterThanOrEqualTo(
        tester
            .getBottomLeft(find.byKey(const Key('bookmark-review-answer')))
            .dy,
      ),
    );
  });

  testWidgets('front uses an equal listening and reveal split', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    final listen = tester.getSize(
      find.byKey(const Key('bookmark-review-listen-zone')),
    );
    final reveal = tester.getSize(
      find.byKey(const Key('bookmark-review-reveal-zone')),
    );
    expect(reveal.height / listen.height, closeTo(1, 0.02));
  });

  testWidgets('upper zone replays and lower zone reveals explanation back', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-listen-zone')));
    await tester.pump();
    expect(find.text('正在播放'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();
    expect(find.byKey(const Key('bookmark-review-answer')), findsOneWidget);
    expect(find.text('听不懂'), findsOneWidget);
    expect(find.text('听懂了'), findsOneWidget);
    expect(find.text('轻松听懂'), findsOneWidget);
    expect(find.text('😕'), findsOneWidget);
    expect(find.text('🙂'), findsOneWidget);
    expect(find.text('😎'), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets('front playback icon uses neutral and active colors', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final theme = Theme.of(
      tester.element(find.byKey(const Key('bookmark-review-listen-zone'))),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.headphones_rounded)).color,
      theme.colorScheme.onSurfaceVariant,
    );

    await tester.tap(find.byKey(const Key('bookmark-review-listen-zone')));
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.headphones_rounded)).color,
      theme.colorScheme.primary,
    );
  });

  testWidgets('back explanation uses the local clip playback adapter', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final annotation = find.byType(SentenceExplanationView);
    expect(annotation, findsOneWidget);
    final explanation = tester.widget<SentenceExplanationView>(annotation);
    expect(
      explanation.senseGroupRangePlayback,
      isA<LocalAudioSenseGroupRangePlayback>(),
    );
    expect(explanation.wordHighlightSource?.audioItemId, 'audio-1');
  });

  testWidgets('page owns the back explanation dictionary panel host', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    expect(find.byType(DictionaryPanelHost), findsOneWidget);
  });

  testWidgets('native route pop stays enabled while dictionary is closed', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(tester.widget<PopScope>(_bookmarkReviewPopScope).canPop, isTrue);
  });

  testWidgets('back explanation opens dictionary when a word is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final selectable = tester.state<AppSelectableTextState>(
      find.byType(AppSelectableText),
    );
    final paragraph = selectable.contentParagraph!;
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 6),
        )
        .first
        .toRect();
    await tester.tapAt(paragraph.localToGlobal(box.center));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dict_panel_surface')), findsOneWidget);
    final panel = tester.getRect(find.byKey(const Key('dict_panel_surface')));
    final host = tester.getRect(find.byType(DictionaryPanelHost));
    final footer = tester.getRect(
      find.byKey(const Key('flashcard-rating-action-bar')),
    );
    // 页面级宿主让面板从复习页底边滑出，并覆盖固定评分栏。
    expect(panel.bottom, host.bottom);
    expect(panel.bottom, greaterThan(footer.top));
  });

  testWidgets('back closes the open dictionary before leaving review', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final selectable = tester.state<AppSelectableTextState>(
      find.byType(AppSelectableText),
    );
    final paragraph = selectable.contentParagraph!;
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 6),
        )
        .first
        .toRect();
    await tester.tapAt(paragraph.localToGlobal(box.center));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_panel_surface')), findsOneWidget);
    expect(tester.widget<PopScope>(_bookmarkReviewPopScope).canPop, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dict_panel_surface')), findsNothing);
    expect(find.byKey(const Key('bookmark-review-answer')), findsOneWidget);
    expect(tester.widget<PopScope>(_bookmarkReviewPopScope).canPop, isTrue);
  });

  testWidgets('back explanation looks up multiple selected words', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final selectable = tester.state<AppSelectableTextState>(
      find.byType(AppSelectableText),
    );
    final paragraph = selectable.contentParagraph!;
    Offset pointForRange(int start, int end) => paragraph.localToGlobal(
      paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
          )
          .first
          .toRect()
          .center,
    );
    final gesture = await tester.startGesture(pointForRange(0, 1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(pointForRange(7, 14));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectable.selectedText.trim().split(' '), hasLength(2));
    expect(find.byKey(const Key('dict_panel_surface')), findsOneWidget);
  });

  testWidgets('rating footer remains outside the explanation scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final footer = tester.getRect(
      find.byKey(const Key('flashcard-rating-action-bar')),
    );
    final scroll = find.descendant(
      of: find.byKey(const Key('bookmark-review-answer')),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('flashcard-rating-action-bar')),
        matching: scroll,
      ),
      findsNothing,
    );
    await tester.drag(scroll, const Offset(0, -120));
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const Key('flashcard-rating-action-bar'))),
      footer,
    );
  });

  testWidgets('back places a compact playback control above rating actions', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final playback = tester.getRect(
      find.byKey(const Key('bookmark-review-sentence-playback')),
    );
    final ratings = tester.getRect(
      find.byKey(const Key('flashcard-rating-action-bar')),
    );
    final status = tester.getRect(
      find.byKey(const Key('bookmark-review-status-bar')),
    );
    expect(playback.height, 44);
    expect(playback.width, ratings.width);
    expect(ratings.top - playback.bottom, closeTo(8, 0.1));
    expect(status.top - ratings.bottom, closeTo(8, 0.1));
    expect(find.text('再听一遍'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    final theme = Theme.of(
      tester.element(find.byKey(const Key('bookmark-review-answer'))),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
      theme.colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('back playback control switches between play and stop', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    final toggle = find.byKey(
      const Key('bookmark-review-sentence-playback-toggle'),
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('停止播放'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    final theme = Theme.of(
      tester.element(find.byKey(const Key('bookmark-review-answer'))),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.stop_rounded)).color,
      theme.colorScheme.primary,
    );

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('再听一遍'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
      theme.colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('settings opens FSRS review controls', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byKey(const Key('bookmark-review-settings')));
    await tester.pumpAndSettle();
    expect(find.text('显示下次复习时间'), findsOneWidget);
    expect(find.text('自动播放正面'), findsOneWidget);
    expect(find.text('自动播放背面'), findsOneWidget);
    expect(find.text('翻面自动播放来源例句'), findsNothing);
    expect(find.text('收藏句子复习'), findsOneWidget);
    expect(find.text('收藏词汇复习'), findsOneWidget);
    expect(find.text('复习顺序'), findsOneWidget);
    expect(find.text('自动显示 AI 讲解'), findsOneWidget);
    expect(find.text('进入句子讲解时自动显示选中的 AI 辅助内容'), findsNothing);
    expect(find.text('AI 解析'), findsOneWidget);
    expect(find.text('AI 翻译'), findsOneWidget);
    expect(find.text('AI 意群分割'), findsOneWidget);
  });

  testWidgets('review order uses localized content-width segments', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: const Locale('en')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Smart'), findsNothing);
    final earliestDueText = tester.getRect(find.text('Earliest due first'));
    final autoSegment = tester.getRect(
      find.byKey(const Key('bookmark-review-order-smart')),
    );
    final earliestDueSegment = tester.getRect(
      find.byKey(const Key('bookmark-review-order-dueAt')),
    );
    final randomSegment = tester.getRect(
      find.byKey(const Key('bookmark-review-order-random')),
    );
    expect(earliestDueText.height, lessThanOrEqualTo(24));
    expect(earliestDueSegment.width, greaterThan(autoSegment.width));
    expect(earliestDueSegment.width, greaterThan(randomSegment.width));
    expect(autoSegment.height, 40);
  });

  testWidgets(
    'settings controls update immediately while the sheet stays open',
    (tester) async {
      await _sharedPreferences.clear();
      addTearDown(_sharedPreferences.clear);
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tap(find.byKey(const Key('bookmark-review-settings')));
      await tester.pumpAndSettle();

      final nextReviewTimeSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('显示下次复习时间'),
          matching: find.byType(SwitchListTile),
        ),
        matching: find.byType(Switch),
      );
      final switchControl = tester.widget<Switch>(nextReviewTimeSwitch);
      switchControl.onChanged!(true);
      await tester.pump();
      expect(tester.widget<Switch>(nextReviewTimeSwitch).value, isTrue);

      await tester.tap(find.byKey(const Key('bookmark-review-order-random')));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.text('复习顺序')),
      );
      final settings = container.read(favoriteReviewSettingsProvider);
      expect(settings.showNextReviewTime, isTrue);
      expect(settings.order.name, 'random');

      Switch switchFor(String title) => tester.widget<Switch>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        ),
      );

      expect(switchFor('自动显示 AI 讲解').value, isTrue);
      expect(switchFor('AI 解析').value, isFalse);
      expect(switchFor('AI 翻译').value, isTrue);
      expect(switchFor('AI 意群分割').value, isFalse);

      switchFor('自动显示 AI 讲解').onChanged!(false);
      await tester.pump();
      expect(find.text('AI 解析'), findsNothing);
      expect(find.text('AI 翻译'), findsNothing);
      expect(find.text('AI 意群分割'), findsNothing);
      expect(
        container.read(bookmarkReviewSettingsProvider).autoShowAiExplanation,
        isFalse,
      );
    },
  );

  testWidgets('rating previews show relative future times when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bookmark-review-settings')));
    await tester.pumpAndSettle();
    final nextReviewTimeSwitch = find.descendant(
      of: find.ancestor(
        of: find.text('显示下次复习时间'),
        matching: find.byType(SwitchListTile),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(nextReviewTimeSwitch);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bookmark-review-reveal-zone')));
    await tester.pump();

    expect(find.text('9分钟后'), findsOneWidget);
    expect(find.text('3小时后'), findsOneWidget);
    expect(find.text('16天后'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('narrow screen and large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsave is the trailing action below the progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    final progress = tester.getRect(
      find.byKey(const Key('bookmark-review-progress')),
    );
    final source = tester.getRect(
      find.byKey(const Key('bookmark-review-source')),
    );
    final unsave = tester.getRect(
      find.byKey(const Key('bookmark-review-unsave')),
    );
    expect(source.top, greaterThan(progress.bottom));
    expect((source.center.dy - unsave.center.dy).abs(), lessThan(2));
    expect(unsave.right, greaterThan(source.right));
  });

  testWidgets('unsave uses a plain label and filled bookmark icon', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final action = find.byKey(const Key('bookmark-review-unsave'));
    final bookmark = find.descendant(
      of: action,
      matching: find.byIcon(Icons.bookmark),
    );
    expect(bookmark, findsOneWidget);
    expect(
      find.descendant(of: action, matching: find.byType(TextButton)),
      findsNothing,
    );
    final label = tester.widget<Text>(find.text('取消收藏'));
    expect(label.style?.fontWeight, FontWeight.normal);
    expect(label.style?.fontSize, 14);
    expect(tester.widget<Icon>(bookmark).color, AppTheme.bookmarkColor);
  });
}
