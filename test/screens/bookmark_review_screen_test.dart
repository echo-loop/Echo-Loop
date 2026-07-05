// 收藏句子复习页面 Widget 测试
//
// 验证盲听/跟读模式 UI、进度显示、音频来源标签、偷看字幕、完成弹窗等。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/screens/bookmark_review_screen.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_engine.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_phase.dart' as flow;
import 'package:echo_loop/providers/repeat_flow/repeat_flow_state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';

import 'package:echo_loop/database/app_database.dart' show Bookmark;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/bookmark_sentence.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/practice/sentence_annotation_card.dart';
import 'package:echo_loop/widgets/common/recording_button.dart';

import '../helpers/mock_providers.dart';

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _MockAudioItemDao extends Mock implements AudioItemDao {}

class _WaitingSpyRepeatEngine extends RepeatFlowEngine {
  bool enteredWaitingForUser = false;

  _WaitingSpyRepeatEngine()
    : super(
        onStateChanged: (_) {},
        callbacks: RepeatFlowCallbacks(
          pauseAudio: () {},
          playSentence: (_, _) async {},
          startRecording:
              ({
                required String promptId,
                required String referenceText,
                required Duration maxDuration,
                Duration? referenceDuration,
              }) {},
          cancelRecording: () async {},
          stopAndEvaluate: ({required String referenceText}) async {},
          clearRecording: () {},
          setMaxRecordingDuration: (_) {},
          hasDetectedSpeech: () => false,
        ),
      );

  @override
  void enterWaitingForUser({bool afterCurrentPrompt = false}) {
    enteredWaitingForUser = true;
  }
}

// ========== 测试用 BookmarkDao ==========

class _TestBookmarkDao implements BookmarkDao {
  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => [];

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

// ========== 测试用 BookmarkReview Provider ==========

/// 带预设句子的测试用 BookmarkReview
class _TestBookmarkReview extends BookmarkReview {
  final ReviewDifficultPracticeState _initialState;
  final List<BookmarkSentence> _testSentences;

  _TestBookmarkReview(this._initialState, this._testSentences);

  @override
  ReviewDifficultPracticeState build() {
    return _initialState;
  }

  @override
  BookmarkSentence? get currentBookmarkSentence =>
      _testSentences.isNotEmpty &&
          state.currentSentenceIndex < _testSentences.length
      ? _testSentences[state.currentSentenceIndex]
      : null;

  @override
  Sentence? get currentSentence => currentBookmarkSentence?.sentence;

  @override
  int get currentIndex => state.currentSentenceIndex;

  @override
  RepeatFlowEngine? get repeatEngine {
    if (!state.isAnnotationMode) return null;
    final sentence = currentSentence;
    if (sentence == null) return null;

    final engine = RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async {},
        startRecording:
            ({
              required String promptId,
              required String referenceText,
              required Duration maxDuration,
              Duration? referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required String referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => false,
      ),
    );
    engine.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: 'bookmark-audio',
        getRepeatCount: (_) => 3,
        getIntervalDuration: (_) => const Duration(seconds: 3),
        isManualMode: () => state.isManualMode,
      ),
    );
    return engine;
  }

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(isPlaying: true);
  }

  @override
  void pause() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  @override
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      state = state.copyWith(isPlaying: true, currentPlayCount: 1);
      return;
    }
    state = state.copyWith(isPlaying: true);
  }

  @override
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isTextRevealed: false,
    );
  }

  @override
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  @override
  void enterWaitingForUserInBlindMode() {
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  @override
  Future<void> goToNext() async {
    if (state.currentSentenceIndex < state.totalSentences - 1) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
      );
    }
  }

  @override
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex > 0) {
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex - 1,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
      );
    }
  }

  @override
  BookmarkSentence? removeBookmark() {
    if (_testSentences.isEmpty) return null;
    return _testSentences[state.currentSentenceIndex];
  }

  @override
  Future<void> toggleCurrentBookmark() async {
    if (_testSentences.isEmpty) return;
    final current = _testSentences[state.currentSentenceIndex];
    _testSentences[state.currentSentenceIndex] = current.copyWithBookmark(
      !current.sentence.isBookmarked,
    );
    state = state.copyWith(bookmarkVersion: state.bookmarkVersion + 1);
  }

  @override
  Future<void> replayDuringCountdown() async {
    state = state.copyWith(isPauseBetweenPlays: false, isPlaying: true);
  }

  @override
  void pauseCountdown() {
    state = state.copyWith(isCountdownPaused: true);
  }

  @override
  void resumeCountdown() {
    state = state.copyWith(isCountdownPaused: false);
  }

  @override
  void disposePlayer() {
    state = const ReviewDifficultPracticeState();
  }

  @override
  Future<void> resetToStart() async {
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _testSentences.length,
    );
  }

  void completeSession() {
    state = state.copyWith(stepFinished: true);
  }
}

class _SettingsSpyBookmarkReview extends _TestBookmarkReview {
  final _WaitingSpyRepeatEngine spyEngine;

  _SettingsSpyBookmarkReview(
    super.initialState,
    super.testSentences,
    this.spyEngine,
  );

  @override
  RepeatFlowEngine? get repeatEngine {
    if (!state.isAnnotationMode) return null;
    final sentence = currentSentence;
    if (sentence == null) return null;
    spyEngine.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: 'bookmark-audio',
        getRepeatCount: (_) => 3,
        getIntervalDuration: (_) => const Duration(seconds: 3),
        isManualMode: () => state.isManualMode,
      ),
    );
    return spyEngine;
  }
}

class _BlindWaitingSpyBookmarkReview extends _TestBookmarkReview {
  bool enteredBlindWaitingForUser = false;

  _BlindWaitingSpyBookmarkReview(super.initialState, super.testSentences);

  @override
  void enterWaitingForUserInBlindMode() {
    enteredBlindWaitingForUser = true;
    super.enterWaitingForUserInBlindMode();
  }
}

void main() {
  /// 创建测试用的收藏句子列表
  List<BookmarkSentence> createBookmarkSentences({int count = 5}) {
    return List.generate(count, (i) {
      return BookmarkSentence(
        sentence: Sentence(
          index: i,
          text: 'Bookmark sentence number ${i + 1}.',
          startTime: Duration(seconds: i * 5),
          endTime: Duration(seconds: (i + 1) * 5),
          isBookmarked: true,
        ),
        audioItemId: i < 3 ? 'audio-1' : 'audio-2',
        audioName: i < 3 ? 'Audio One' : 'Audio Two',
        originalSentenceIndex: i,
      );
    });
  }

  /// 创建测试用状态
  ReviewDifficultPracticeState createPlayerState({
    int currentSentenceIndex = 0,
    int totalSentences = 5,
    int currentPlayCount = 1,
    bool isPlaying = true,
    bool isAnnotationMode = false,
    bool isTextRevealed = false,
    bool isPauseBetweenPlays = false,
    bool isPauseBetweenSentences = false,
    Duration pauseRemaining = Duration.zero,
    Duration pauseDuration = Duration.zero,
    bool isCountdownPaused = false,
    bool isCountdownFastForward = false,
  }) {
    final repeatFlowState = isAnnotationMode
        ? RepeatFlowState(
            phase: isPauseBetweenPlays
                ? flow.WaitingInterval(
                    remaining: pauseRemaining == Duration.zero
                        ? const Duration(seconds: 3)
                        : pauseRemaining,
                    total: pauseDuration == Duration.zero
                        ? const Duration(seconds: 3)
                        : pauseDuration,
                    isPaused: isCountdownPaused,
                  )
                : (isPlaying
                      ? const flow.PlayingPrompt()
                      : const flow.WaitingForUser(
                          flow.WaitingReason.userInteraction,
                        )),
            sentenceIndex: currentSentenceIndex,
            totalSentences: totalSentences,
            repeatIndex: currentPlayCount - 1,
            totalRepeats: 3,
            intervalDuration: pauseDuration,
          )
        : null;

    return ReviewDifficultPracticeState(
      currentSentenceIndex: currentSentenceIndex,
      totalSentences: totalSentences,
      currentPlayCount: currentPlayCount,
      isPlaying: isPlaying,
      isAnnotationMode: isAnnotationMode,
      isTextRevealed: isTextRevealed,
      isPauseBetweenPlays: isPauseBetweenPlays,
      isPauseBetweenSentences: isPauseBetweenSentences,
      pauseRemaining: pauseRemaining,
      pauseDuration: pauseDuration,
      isCountdownPaused: isCountdownPaused,
      isCountdownFastForward: isCountdownFastForward,
      repeatFlowState: repeatFlowState,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    ReviewDifficultPracticeState? playerState,
    List<BookmarkSentence>? sentences,
    SpeechRecordingPhase turnPhase = SpeechRecordingPhase.idle,
    bool startAtHome = false,
    BookmarkReview Function(
      ReviewDifficultPracticeState initialState,
      List<BookmarkSentence> sentences,
    )?
    playerFactory,
  }) {
    final testSentences = sentences ?? createBookmarkSentences();
    final initialPlayerState = playerState ?? createPlayerState();
    final audioItemDao = _MockAudioItemDao();
    when(() => audioItemDao.getById(any())).thenAnswer((_) async => null);
    when(
      () => audioItemDao.getWordTimestamps(any()),
    ).thenAnswer((_) async => null);

    final router = GoRouter(
      initialLocation: startAtHome ? '/' : '/bookmark-review',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.push('/bookmark-review'),
                child: const Text('Open player'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/bookmark-review',
          builder: (context, state) => const BookmarkReviewScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        analyticsOverride(),
        ...studyTimeOverrides(),
        ...learningSettingsOverrides(),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        bookmarkReviewProvider.overrideWith(
          () =>
              playerFactory?.call(initialPlayerState, testSentences) ??
              _TestBookmarkReview(initialPlayerState, testSentences),
        ),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
        speechRecordingControllerProvider.overrideWith(
          () => TestSpeechRecordingController(initialPhase: turnPhase),
        ),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
        transcriptionApiClientProvider.overrideWithValue(
          createTestTranscriptionApiClient(),
        ),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: createStubbedMockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
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

  group('BookmarkReviewScreen — 基本渲染', () {
    testWidgets('显示 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bookmark Review'), findsOneWidget);
    });

    testWidgets('显示关闭按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('显示设置按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
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

      expect(find.text('Sentence 3/10'), findsOneWidget);
    });

    testWidgets('显示音频来源名称', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 第一句来自 Audio One
      expect(find.textContaining('Audio One'), findsOneWidget);
    });

    testWidgets('显示进度条', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('BookmarkReviewScreen — 盲听模式', () {
    testWidgets('显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsOneWidget);
      expect(find.text("Unclear"), findsOneWidget);
    });

    testWidgets('盲听模式只显示一套底部播放控制', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('播放中不显示盲听标签（共享 widget 简化）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 共享 PracticeNormalModeView 不再显示盲听标签
      expect(find.byIcon(Icons.headphones), findsNothing);
      expect(find.text('Listening...'), findsNothing);
    });

    testWidgets('偷看切换显示句子文本', skip: true, (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isPlaying: true, isTextRevealed: true),
        ),
      );
      await tester.pumpAndSettle();

      // 统一可点词组件：整句渲染为单个 RichText
      expect(
        find.text('Bookmark sentence number 1.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('偷看切换隐藏句子文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 非 revealed 时显示隐藏占位
      expect(find.byIcon(Icons.hearing), findsOneWidget);
      expect(
        find.text('Bookmark sentence number 1.', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('点击偷看切换文本可见性', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isTextRevealed: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击偷看
      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();

      // 统一可点词组件：整句渲染为单个 RichText
      expect(
        find.text('Bookmark sentence number 1.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('盲听模式打开设置会进入 WaitingForUser', (tester) async {
      final player = _BlindWaitingSpyBookmarkReview(
        createPlayerState(isPlaying: true),
        createBookmarkSentences(),
      );
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isPlaying: true),
          playerFactory: (_, __) => player,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(player.enteredBlindWaitingForUser, isTrue);
    });

    testWidgets('显示收藏标记行', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsAtLeast(1));
    });

    testWidgets('句间停顿显示倒计时', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPauseBetweenPlays: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('BookmarkReviewScreen — 跟读模式', () {
    testWidgets('跟读模式显示 SentenceAnnotationCard', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
    });

    testWidgets('跟读模式不显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsNothing);
      expect(find.text("Unclear"), findsNothing);
    });

    testWidgets('跟读模式显示遍数标签', skip: true, (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play 2/3'), findsOneWidget);
    });

    testWidgets('跟读留白期显示录音面板', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: ReviewDifficultPracticeState(
            currentSentenceIndex: 0,
            totalSentences: 5,
            currentPlayCount: 1,
            isAnnotationMode: true,
            isPlaying: false,
            isPauseBetweenPlays: true,
            repeatFlowState: const RepeatFlowState(
              phase: flow.Recording(promptId: 'bookmark:audio-1:0'),
              sentenceIndex: 0,
              totalSentences: 5,
              repeatIndex: 0,
              totalRepeats: 3,
              intervalDuration: Duration(seconds: 8),
            ),
          ),
          turnPhase: SpeechRecordingPhase.awaitingSpeech,
        ),
      );
      await tester.pump();
      await tester.pump();

      // 跟读留白期显示录音面板（含录音按钮）
      expect(find.byType(RecordingButton), findsOneWidget);
    });

    testWidgets('跟读模式只显示一套底部播放控制', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('打开设置弹窗后进入 WaitingForUser', (tester) async {
      final spyEngine = _WaitingSpyRepeatEngine();
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
          playerFactory: (initialState, sentences) =>
              _SettingsSpyBookmarkReview(initialState, sentences, spyEngine),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(spyEngine.enteredWaitingForUser, isTrue);
    });
  });

  group('BookmarkReviewScreen — 播放控制', () {
    testWidgets('显示播放控制按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      // 播放中显示暂停图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('播放中点击暂停', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('暂停后点击恢复', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 恢复
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('第一句时上一句按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(currentSentenceIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: prevIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(opacity.opacity, 0.15);
    });

    testWidgets('最后一句时显示完成图标且始终可用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 4,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 最后一句显示 check_circle_rounded 而非 skip_next_rounded
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);

      // 按钮始终可用（opacity > 0.15）
      final checkIcon = find.byIcon(Icons.check_circle_rounded);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: checkIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(opacity.opacity, greaterThan(0.15));
    });

    testWidgets('点击听不懂进入跟读模式', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Unclear"));
      await tester.pumpAndSettle();

      // 进入跟读模式后显示 SentenceAnnotationCard
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      expect(find.text('Peek'), findsNothing);
    });
  });

  group('BookmarkReviewScreen — 中文本地化', () {
    testWidgets('中文标题和操作文案', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await tester.pumpAndSettle();

      expect(find.text('收藏复习'), findsOneWidget);
      expect(find.text('偷看字幕'), findsOneWidget);
      expect(find.text('听不太懂'), findsOneWidget);
    });
  });

  group('BookmarkReviewScreen — 完成弹窗', () {
    testWidgets('点完成返回后主界面仍可点击', (tester) async {
      late _TestBookmarkReview player;

      await tester.pumpWidget(
        createTestWidget(
          startAtHome: true,
          playerFactory: (state, sentences) {
            player = _TestBookmarkReview(state, sentences);
            return player;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      player.completeSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Review Complete'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Open player'), findsOneWidget);

      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      expect(find.byType(BookmarkReviewScreen), findsOneWidget);
    });
  });
}
