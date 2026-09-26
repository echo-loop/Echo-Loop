// 精听播放器页面测试
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/media_intensive_listen_startup.dart';
import 'package:echo_loop/models/media_load_result.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/screens/intensive_listen_player_screen.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/intensive_annotation/intensive_annotation_phase.dart';
import 'package:echo_loop/providers/intensive_annotation/intensive_annotation_state.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/database/app_database.dart' show AudioItem, Bookmark;
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/bookmark_toggle_row.dart';
import 'package:echo_loop/widgets/practice/sentence_annotation_card.dart';
import 'package:echo_loop/widgets/practice/sentence_explanation_view.dart';

import '../helpers/mock_providers.dart';

class _MockApiClient extends Mock implements SentenceAiApiClient {}

/// 测试用 BookmarkDao
class _TestBookmarkDao implements BookmarkDao {
  _TestBookmarkDao({List<Bookmark> bookmarks = const []})
    : _bookmarks = bookmarks;

  final List<Bookmark> _bookmarks;

  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => _bookmarks;

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      Stream<List<Bookmark>>.value(_bookmarks);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Future<void>.value();
  }
}

class _TestAudioItemDao implements AudioItemDao {
  @override
  Future<AudioItem?> getById(String id) async => null;

  @override
  Future<String?> getTranscriptSrt(String audioItemId) async => null;

  @override
  Future<void> updateWordTimestamps(String audioItemId, String? json) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _RecordingIntensiveListenPlayer extends TestIntensiveListenPlayer {
  _RecordingIntensiveListenPlayer(super.initialState, super.testSentences);

  int pauseCalls = 0;
  int resumeCalls = 0;
  int replayInDetailsCalls = 0;
  int replayDuringCountdownCalls = 0;
  int goToNextCalls = 0;
  int goToPreviousCalls = 0;
  int goToSentenceCalls = 0;
  int startPlayingCalls = 0;
  Completer<void>? pendingAnnotationAdvanceGate;

  @override
  Future<void> startPlaying() async {
    startPlayingCalls += 1;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    await super.pause();
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
    await super.resume();
  }

  @override
  Future<void> replayInAnnotationMode() async {
    replayInDetailsCalls += 1;
    await super.replayInAnnotationMode();
  }

  @override
  Future<void> replayDuringCountdown() async {
    replayDuringCountdownCalls += 1;
    await super.replayDuringCountdown();
  }

  @override
  Future<void> goToNext() async {
    goToNextCalls += 1;
    await super.goToNext();
  }

  @override
  Future<void> goToPrevious() async {
    goToPreviousCalls += 1;
    await super.goToPrevious();
  }

  @override
  Future<void> goToSentence(int index) async {
    goToSentenceCalls += 1;
    if (index < 0 || index >= state.totalSentences) return;
    state = state.copyWith(
      currentSentenceIndex: index,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      annotationState: null,
      isTextRevealed: false,
      isCurrentSentenceAutoMarked: false,
    );
  }

  @override
  Future<void> commitPendingAnnotationAdvance(int targetSentenceIndex) async {
    await super.commitPendingAnnotationAdvance(targetSentenceIndex);
    final gate = pendingAnnotationAdvanceGate;
    if (gate != null) await gate.future;
  }

  void emit(IntensiveListenState nextState) {
    state = nextState;
  }
}

class _MutableIntensiveListenPlayer extends TestIntensiveListenPlayer {
  _MutableIntensiveListenPlayer(super.initialState, super.testSentences);

  void emit(IntensiveListenState nextState) {
    state = nextState;
  }
}

void main() {
  /// 创建测试用的精听状态
  IntensiveListenState createPlayerState({
    int currentSentenceIndex = 0,
    int totalSentences = 5,
    int currentPlayCount = 1,
    IntensiveListenSettings settings = const IntensiveListenSettings(),
    bool isPlaying = true,
    bool isAnnotationMode = false,
    bool isAnnotationReplay = false,
    bool isTextRevealed = false,
    bool isPauseBetweenPlays = false,
    bool isPauseBetweenSentences = false,
    Duration pauseRemaining = Duration.zero,
    Duration pauseDuration = Duration.zero,
    Duration annotationReplayRemaining = Duration.zero,
    Duration annotationReplayDuration = Duration.zero,
    Set<int> difficultSentences = const {},
    bool isCurrentSentenceAutoMarked = false,
    bool isCountdownPaused = false,
    bool isCountdownFastForward = false,
    bool usesMediaEngine = false,
  }) {
    return IntensiveListenState(
      currentSentenceIndex: currentSentenceIndex,
      totalSentences: totalSentences,
      currentPlayCount: currentPlayCount,
      settings: settings,
      isPlaying: isPlaying,
      isAnnotationMode: isAnnotationMode,
      isAnnotationReplay: isAnnotationReplay,
      isTextRevealed: isTextRevealed,
      isPauseBetweenPlays: isPauseBetweenPlays,
      isPauseBetweenSentences: isPauseBetweenSentences,
      pauseRemaining: pauseRemaining,
      pauseDuration: pauseDuration,
      annotationReplayRemaining: annotationReplayRemaining,
      annotationReplayDuration: annotationReplayDuration,
      difficultSentences: difficultSentences,
      isCurrentSentenceAutoMarked: isCurrentSentenceAutoMarked,
      isCountdownPaused: isCountdownPaused,
      isCountdownFastForward: isCountdownFastForward,
      usesMediaEngine: usesMediaEngine,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    IntensiveListenState? playerState,
    LearningSessionState? sessionState,
    _TestBookmarkDao? bookmarkDao,
    List<Override> extraOverrides = const [],
    bool startAtHome = false,
    MediaIntensiveListenStartup? mediaStartup,
    TestIntensiveListenPlayer Function(
      IntensiveListenState initialState,
      List<Sentence> sentences,
    )?
    playerFactory,
  }) {
    final sentences = createTestSentences(count: 5);
    final initialPlayerState = playerState ?? createPlayerState();

    final router = GoRouter(
      initialLocation: startAtHome
          ? '/'
          : '/collections/col-1/test-1/intensive-listen',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    context.push('/collections/col-1/test-1/intensive-listen'),
                child: const Text('Open player'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/intensive-listen',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return IntensiveListenPlayerScreen(
              collectionId: collectionId,
              audioItemId: audioId,
              mediaStartup: mediaStartup,
            );
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        analyticsOverride(),
        ...studyTimeOverrides(),
        ...learningSettingsOverrides(),
        listeningPracticeProvider.overrideWith(
          () => TestListeningPractice(
            ListeningPracticeState(sentences: sentences),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(),
        ),
        learningSessionProvider.overrideWith(
          () =>
              TestLearningSession(sessionState ?? const LearningSessionState()),
        ),
        intensiveListenPlayerProvider.overrideWith(
          () =>
              playerFactory?.call(initialPlayerState, sentences) ??
              TestIntensiveListenPlayer(initialPlayerState, sentences),
        ),
        bookmarkDaoProvider.overrideWithValue(
          bookmarkDao ?? _TestBookmarkDao(),
        ),
        audioItemDaoProvider.overrideWithValue(_TestAudioItemDao()),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: createStubbedMockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  group('IntensiveListenPlayerScreen', () {
    testWidgets('恢复路由缺少启动任务和已初始化会话时返回入口页', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          startAtHome: true,
          playerState: createPlayerState(totalSentences: 0),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      expect(find.text('Open player'), findsOneWidget);
      expect(find.byType(IntensiveListenPlayerScreen), findsNothing);
    });

    testWidgets('视频启动任务未完成时立即显示精听页加载动画', (tester) async {
      final load = Completer<MediaLoadResult>();
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(usesMediaEngine: true),
          mediaStartup: MediaIntensiveListenStartup(
            loadKey: 'video-1',
            load: () => load.future,
            cancel: () async {},
          ),
          playerFactory: (state, sentences) =>
              player = _RecordingIntensiveListenPlayer(state, sentences),
        ),
      );
      await tester.pump();

      expect(find.text('Listen sentence by sentence'), findsOneWidget);
      expect(find.text('Loading video…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsNothing);
      expect(player.startPlayingCalls, 0);

      load.complete(MediaLoadResult.ready);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('media-video-canvas')), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(player.startPlayingCalls, 1);
    });

    testWidgets('视频加载中关闭会取消任务并返回入口页', (tester) async {
      final load = Completer<MediaLoadResult>();
      var cancelCalls = 0;
      await tester.pumpWidget(
        createTestWidget(
          startAtHome: true,
          mediaStartup: MediaIntensiveListenStartup(
            loadKey: 'video-1',
            load: () => load.future,
            cancel: () async => cancelCalls += 1,
          ),
        ),
      );
      await tester.tap(find.text('Open player'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Loading video…'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Open player'), findsOneWidget);
      expect(cancelCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('视频会话显示共享画面', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(usesMediaEngine: true)),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('media-video-canvas')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('media-visual-surface')),
        findsOneWidget,
      );
    });

    testWidgets('显示精听 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Listen sentence by sentence'), findsOneWidget);
    });

    testWidgets('显示进度文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Sentence 3/10" (1-based)
      expect(find.text('Sentence 3/10'), findsOneWidget);
      expect(
        tester.getTopRight(find.byType(BookmarkToggleRow)).dx,
        closeTo(tester.getSize(find.byType(Scaffold)).width - AppSpacing.m, 1),
      );
    });

    testWidgets('普通模式显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek at subtitles'), findsOneWidget);
      expect(find.text('Unclear'), findsOneWidget);
    });

    testWidgets('讲解工具栏随内容滚动，句次和收藏保留在顶部进度区', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isAnnotationMode: true),
        ),
      );
      await tester.pumpAndSettle();

      final scrollView = find.descendant(
        of: find.byType(SentenceExplanationView),
        matching: find.byType(SingleChildScrollView),
      );

      expect(scrollView, findsOneWidget);
      expect(
        find.ancestor(of: find.text('Sentence 1/5'), matching: scrollView),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byType(BookmarkToggleRow),
          matching: find.byType(SentenceExplanationView),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.byType(SentenceExplanationView)).left,
        closeTo(tester.getRect(find.text('Sentence 1/5')).left, 1),
      );
    });

    testWidgets('普通模式显示播放遍数（默认 1 次）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(currentPlayCount: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Auto · Round 1/1 · 1.0x'), findsOneWidget);
    });

    testWidgets('自定义遍数正确显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentPlayCount: 2,
            settings: const IntensiveListenSettings(repeatCount: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Auto · Round 2/3 · 1.0x'), findsOneWidget);
    });

    testWidgets('详情模式显示带文字的继续按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final continueButtonFinder = find.byKey(
        const ValueKey('intensive-annotation-continue-button'),
      );
      expect(continueButtonFinder, findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      final continueLabel = tester.widget<Text>(find.text('Next'));
      expect(continueLabel.maxLines, 1);
      expect(continueLabel.softWrap, isFalse);
      final continueIcon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward_rounded),
      );
      expect(continueIcon.size, 20);

      final continueButton = tester.widget<FilledButton>(continueButtonFinder);
      expect(continueButton.style?.shape?.resolve({}), isA<StadiumBorder>());
      expect(continueButton.style?.fixedSize?.resolve({}), const Size(128, 48));
      expect(
        continueButton.style?.padding?.resolve({}),
        const EdgeInsets.symmetric(horizontal: 16),
      );
    });

    testWidgets('从普通倒计时点击听不懂进入详情页时只显示继续按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: false,
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unclear'));
      await tester.pumpAndSettle();

      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('intensive-annotation-continue-button')),
        findsOneWidget,
      );
      expect(find.text('3s'), findsNothing);
      expect(find.text('Listen again to help it stick'), findsNothing);
    });

    testWidgets('详情重播时保留详情页并显示重播提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isAnnotationReplay: true,
            isPlaying: true,
            annotationReplayRemaining: const Duration(seconds: 3),
            annotationReplayDuration: const Duration(seconds: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Listen again to help it stick'), findsOneWidget);
    });

    testWidgets('详情页重播后显示正常样式倒计时', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
            isCountdownPaused: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('详情页倒计时使用 pauseDuration 作为总时长', (tester) async {
      late _MutableIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 5),
            isCountdownPaused: true,
          ),
          playerFactory: (state, sentences) {
            player = _MutableIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      // CountdownChip 使用 pauseDuration 作为总时长，初始显示 5s
      expect(find.text('5'), findsOneWidget);

      // 改变 pauseDuration 会触发 countdown 重建
      player.emit(
        createPlayerState(
          isAnnotationMode: true,
          isPauseBetweenPlays: true,
          isPauseBetweenSentences: true,
          isPlaying: false,
          pauseRemaining: const Duration(seconds: 2),
          pauseDuration: const Duration(seconds: 3),
          isCountdownPaused: true,
        ),
      );
      await tester.pump();

      // 新的 pauseDuration 为 3s，显示 '3'
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('显示播放/暂停和上下句按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      // 播放中显示暂停图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('第一句时上一句按钮透明度降低（禁用态）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(currentSentenceIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      // _NavButton 使用 AnimatedOpacity，禁用态 opacity=0.15
      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      expect(prevIcon, findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: prevIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(opacity.opacity, 0.15);
    });

    testWidgets('最后一句时下一句按钮变为完成图标且可点击', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 4,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 最后一句显示 check_circle 图标
      final checkIcon = find.byIcon(Icons.check_circle_rounded);
      expect(checkIcon, findsOneWidget);
      // 始终可点击（opacity 0.6）
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: checkIcon, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.6);
    });

    testWidgets('遍间停顿显示倒计时控件', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: false,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // CountdownChip 显示秒数文本和进度环
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('句间停顿显示倒计时控件', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // CountdownChip 显示秒数文本和进度环
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('点击设置按钮打开设置面板', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // 设置面板标题
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('标注模式不显示难句标记行（onToggle 为 null）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            difficultSentences: {0},
            isCurrentSentenceAutoMarked: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 标注模式现在也显示书签标记行（通过 _AnnotationWithBookmark）
      // difficultSentences 包含 0 且 currentSentenceIndex=0，所以显示 bookmark 实心图标
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('正常模式下难句显示标记行和取消标记按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            difficultSentences: {0},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 难句标记行：★ + 文案
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('Unsave'), findsOneWidget);
      // 底部显示"取消标记"和"听不懂"按钮
      expect(find.text('Unmark'), findsOneWidget);
      expect(find.text('Unclear'), findsOneWidget);
    });

    testWidgets('正常模式下非难句显示空心星标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            difficultSentences: {1, 2},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 当前句子（索引0）不在难句集合中，显示空心星标 + 灰色文案
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('偷看字幕点击切换 — 初始隐藏', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 隐藏状态：听觉图标可见，句子文本不可见
      expect(find.byIcon(Icons.hearing), findsOneWidget);
      expect(find.text('Test sentence number 1.'), findsNothing);
      // 偷看按钮显示 visibility_outlined 图标
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('偷看字幕点击切换 — 点击显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击偷看按钮切换为显示
      await tester.tap(find.text('Peek at subtitles'));
      await tester.pumpAndSettle();

      // 统一可点词组件：整句渲染为单个 RichText
      expect(
        find.textContaining('Test sentence number', findRichText: true),
        findsOneWidget,
      );
      // 偷看按钮图标变为 visibility_off
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('偷看字幕点击切换 — 再次点击隐藏', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 第一次点击显示
      await tester.tap(find.text('Peek at subtitles'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Test sentence number', findRichText: true),
        findsOneWidget,
      );

      // 第二次点击隐藏（文案已变为 Hide）
      await tester.tap(find.text('Hide subtitles'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Test sentence number', findRichText: true),
        findsNothing,
      );
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('偷看字幕切换句子后自动重置', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: true,
            currentSentenceIndex: 0,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始为已显示状态
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // 切到下一句（TestIntensiveListenPlayer.goToNext 会 reset isTextRevealed）
      final nextIcon = find.byIcon(Icons.skip_next_rounded);
      await tester.tap(nextIcon);
      await tester.pumpAndSettle();

      // 下一句应自动隐藏
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('正文左滑切到下一句并同步进度', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(player.goToSentenceCalls, 1);
      expect(player.currentIndex, 3);
      expect(find.text('Sentence 4/5'), findsOneWidget);
    });

    testWidgets('正文右滑切到上一句并同步进度', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(player.goToSentenceCalls, 1);
      expect(player.currentIndex, 1);
      expect(find.text('Sentence 2/5'), findsOneWidget);
    });

    testWidgets('外部自动切句驱动分页但不会重复切句', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      // 模拟盲听流程自然播完后推进到相邻句。
      player.emit(player.state.copyWith(currentSentenceIndex: 3));
      await tester.pumpAndSettle();

      expect(player.currentIndex, 3);
      expect(player.goToSentenceCalls, 0);
      expect(find.text('Sentence 4/5'), findsOneWidget);
    });

    testWidgets('从首句自动推进时分页使用 320ms 横滑动画', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            totalSentences: 5,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      player.emit(player.state.copyWith(currentSentenceIndex: 1));
      await tester.pump();
      // 分页同步通过 post-frame 回调启动动画，先让该回调完成。
      await tester.pump();
      // 300ms 时动画仍未结束，避免时长退回较快的 280ms。
      await tester.pump(const Duration(milliseconds: 300));

      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
      );
      expect(pageView.controller!.page, greaterThan(0));
      expect(pageView.controller!.page, lessThan(1));
      expect(player.goToSentenceCalls, 0);
    });

    testWidgets('短距离或垂直拖动正文不会切句', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(currentSentenceIndex: 2),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
        const Offset(-32, 0),
      );
      await tester.drag(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();

      expect(player.goToSentenceCalls, 0);
      expect(player.currentIndex, 2);
    });

    testWidgets('讲解状态下横滑也会切句', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            isAnnotationMode: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(player.goToSentenceCalls, 1);
      expect(player.currentIndex, 3);
      expect(player.state.isAnnotationMode, isFalse);
    });

    testWidgets('讲解状态横滑停稳前目标页显示盲听且不重置源句', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            isAnnotationMode: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('intensive-sentence-page-view')),
        ),
      );
      final pagerSize = tester.getSize(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
      );
      await gesture.moveBy(Offset(-pagerSize.width * 0.75, 0));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('intensive-sentence-mode-3-blind')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('intensive-sentence-mode-3-blind')),
          matching: find.text('Continue'),
        ),
        findsNothing,
      );
      expect(player.goToSentenceCalls, 0);
      expect(player.currentIndex, 2);
      expect(player.state.isAnnotationMode, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(player.goToSentenceCalls, 1);
      expect(player.currentIndex, 3);
      expect(player.state.isAnnotationMode, isFalse);
    });

    testWidgets('讲解自动翻页动画期间保持讲解页，不闪回当前句盲听页', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      player.emit(
        player.state.copyWith(
          isAnnotationMode: true,
          isAnnotationReplay: false,
          isPlaying: false,
          annotationState: const IntensiveAnnotationState(
            phase: WaitingAnnotationPageTransition(targetSentenceIndex: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('intensive-sentence-mode-0-blind')),
        findsNothing,
      );
      expect(player.currentIndex, 0);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(player.currentIndex, 1);
      expect(player.state.isAnnotationMode, isFalse);
      expect(
        find.byKey(const ValueKey('intensive-sentence-mode-1-blind')),
        findsOneWidget,
      );
    });

    testWidgets('自动翻到新句后播放未结束也允许继续切句', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      final playbackGate = Completer<void>();
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences)
              ..pendingAnnotationAdvanceGate = playbackGate;
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      player.emit(
        player.state.copyWith(
          isAnnotationMode: true,
          isAnnotationReplay: false,
          isPlaying: false,
          annotationState: const IntensiveAnnotationState(
            phase: WaitingAnnotationPageTransition(targetSentenceIndex: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(player.currentIndex, 1);
      expect(player.state.annotationState, isNull);

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      expect(player.goToNextCalls, 1);
      expect(player.currentIndex, 2);

      playbackGate.complete();
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets('讲解状态取消横滑时保留源句讲解态', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            isAnnotationMode: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('intensive-sentence-page-view')),
        const Offset(-32, 0),
      );
      await tester.pumpAndSettle();

      expect(player.goToSentenceCalls, 0);
      expect(player.currentIndex, 2);
      expect(player.state.isAnnotationMode, isTrue);
    });

    testWidgets('讲解状态底部右侧继续按钮退出当前句讲解', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            isAnnotationMode: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('intensive-annotation-continue-button')),
      );
      await tester.pumpAndSettle();

      expect(player.goToNextCalls, 0);
      expect(player.currentIndex, 2);
      expect(player.state.isAnnotationMode, isTrue);
      expect(player.state.isAnnotationReplay, isTrue);
    });

    testWidgets('标注模式下导航按钮可用（非重播状态）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
            isAnnotationMode: true,
            isPlaying: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 标注模式下（非 annotationReplay）右侧位置由继续按钮接管。
      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      expect(prevIcon, findsOneWidget);
      expect(
        find.byKey(const ValueKey('intensive-annotation-continue-button')),
        findsOneWidget,
      );

      final prevOpacity = tester.widget<Opacity>(
        find.ancestor(of: prevIcon, matching: find.byType(Opacity)).first,
      );
      expect(prevOpacity.opacity, 0.6);
    });

    testWidgets('详情页重播中导航按钮仍可用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
            isAnnotationMode: true,
            isAnnotationReplay: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final nextIcon = find.byIcon(Icons.skip_next_rounded);
      final prevOpacity = tester.widget<Opacity>(
        find.ancestor(of: prevIcon, matching: find.byType(Opacity)).first,
      );
      final nextOpacity = tester.widget<Opacity>(
        find.ancestor(of: nextIcon, matching: find.byType(Opacity)).first,
      );

      expect(prevOpacity.opacity, 0.6);
      expect(nextOpacity.opacity, 0.6);
    });

    testWidgets('详情页倒计时中导航按钮仍可用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
            isAnnotationMode: true,
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final nextIcon = find.byIcon(Icons.skip_next_rounded);
      final prevOpacity = tester.widget<Opacity>(
        find.ancestor(of: prevIcon, matching: find.byType(Opacity)).first,
      );
      final nextOpacity = tester.widget<Opacity>(
        find.ancestor(of: nextIcon, matching: find.byType(Opacity)).first,
      );

      expect(prevOpacity.opacity, 0.6);
      expect(nextOpacity.opacity, 0.6);
    });

    testWidgets('详情页重播中点击播放按钮先暂停，不触发详情页内重播', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isAnnotationReplay: true,
            isPlaying: true,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(player.pauseCalls, 1);
      expect(player.resumeCalls, 0);
      expect(player.replayInDetailsCalls, 0);
    });

    testWidgets('详情页重播暂停后点击播放会从当前句重新开始', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isAnnotationReplay: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(player.resumeCalls, 1);
      expect(player.replayInDetailsCalls, 0);
    });

    testWidgets('详情页查看讲解时点击播放不显示重播提示且保留继续按钮', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(player.replayInDetailsCalls, 1);
      expect(find.text('Listen again to help it stick'), findsNothing);
      expect(
        find.byKey(const ValueKey('intensive-annotation-continue-button')),
        findsOneWidget,
      );
    });

    testWidgets('详情页倒计时中点击播放按钮会回到带字幕重播态', (tester) async {
      late _RecordingIntensiveListenPlayer player;
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: true,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
          playerFactory: (state, sentences) {
            player = _RecordingIntensiveListenPlayer(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(player.replayDuringCountdownCalls, 1);
      expect(player.replayInDetailsCalls, 0);
      expect(player.resumeCalls, 0);
      expect(find.text('Listen again to help it stick'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('偷看按钮点击切换 isTextRevealed（非按住）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isTextRevealed: false)),
      );
      await tester.pumpAndSettle();

      // 找到偷看按钮并点击
      final peekButton = find.byIcon(Icons.visibility_outlined);
      expect(peekButton, findsOneWidget);

      await tester.tap(peekButton);
      await tester.pumpAndSettle();

      // 点击后应切换为 revealed，图标变为 visibility_off
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('偷看按钮再次点击取消显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isTextRevealed: true)),
      );
      await tester.pumpAndSettle();

      // 已显示状态，图标为 visibility_off
      final peekButton = find.byIcon(Icons.visibility_off_outlined);
      expect(peekButton, findsOneWidget);

      await tester.tap(peekButton);
      await tester.pumpAndSettle();

      // 点击后应切换回隐藏，图标变为 visibility
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });
}
