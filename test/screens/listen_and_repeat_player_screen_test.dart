import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/services/speech_permission_service.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/media_learning_startup.dart';
import 'package:echo_loop/models/media_load_result.dart';
import 'package:echo_loop/models/media_engine_state.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_controller.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_phase.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_settings_provider.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_session_state.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_state.dart';
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/screens/listen_and_repeat_player_screen.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';
import 'package:echo_loop/widgets/common/recording_button.dart';
import 'package:echo_loop/widgets/common/bookmark_toggle_row.dart';
import 'package:echo_loop/widgets/practice/sentence_explanation_view.dart';

import '../helpers/mock_providers.dart';

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _MockAudioItemDao extends Mock implements AudioItemDao {}

class _MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

class _VideoViewMediaEngine extends MediaEngine {
  @override
  MediaEngineState build() => const MediaEngineState();

  @override
  Widget buildVideoView({required Size viewportSize}) =>
      const ColoredBox(color: Colors.black);
}

class _FakeSpeechPermissionService implements SpeechPermissionService {
  @override
  bool get isSupported => true;

  @override
  Future<SpeechPracticePermissionState> getStatus() async =>
      const SpeechPracticePermissionState(
        microphone: SpeechPracticePermissionStatus.granted,
        speech: SpeechPracticePermissionStatus.granted,
      );

  @override
  Future<SpeechPracticePermissionState> request({
    required bool onlyMic,
  }) async => const SpeechPracticePermissionState(
    microphone: SpeechPracticePermissionStatus.granted,
    speech: SpeechPracticePermissionStatus.granted,
  );

  @override
  Future<void> openAppSettings() async {}
}

class _TestListenAndRepeatController extends ListenAndRepeatController {
  _TestListenAndRepeatController(
    this._initialState,
    this._sentences, {
    this.startPlayingNoop = false,
    this.sessionPrepared = true,
  });

  final ListenAndRepeatSessionState _initialState;
  final List<Sentence> _sentences;
  final bool startPlayingNoop;
  final bool sessionPrepared;
  int? nextAppliedRepeatCount;
  int applySettingsChangeCallCount = 0;
  bool keepWaitingForUserOnSettingsChange = false;
  int nextSentenceCalls = 0;
  int previousSentenceCalls = 0;
  int goToSentenceCalls = 0;

  @override
  ListenAndRepeatSessionState build() => _initialState;

  @override
  List<Sentence> get sentences => _sentences;

  @override
  bool get isSessionPrepared => sessionPrepared;

  @override
  Sentence? get currentSentence =>
      _sentences.isEmpty ? null : _sentences[state.sentenceIndex];

  @override
  String get currentPromptId =>
      'lar:test-audio:${currentSentence?.index ?? state.sentenceIndex}';

  @override
  Future<void> startPlaying() async {
    if (startPlayingNoop) return;
    state = state.copyWith(phase: const PlayingPrompt());
  }

  @override
  void enterWaitingForUser() {
    state = state.copyWith(
      phase: const WaitingForUser(WaitingReason.userInteraction),
    );
  }

  @override
  void enterWaitingForUserAfterCurrentPrompt() {
    state = state.copyWith(
      phase: const WaitingForUser(WaitingReason.userInteraction),
    );
  }

  @override
  Future<void> replayCurrentSentence() async {
    state = state.copyWith(phase: const PlayingPrompt());
  }

  @override
  Future<void> nextSentence({
    RepeatNavigationSource source = RepeatNavigationSource.nextArrow,
  }) async {
    nextSentenceCalls += 1;
    if (state.sentenceIndex >= _sentences.length - 1) return;
    state = state.copyWith(sentenceIndex: state.sentenceIndex + 1);
  }

  @override
  Future<void> previousSentence({
    RepeatNavigationSource source = RepeatNavigationSource.previousArrow,
  }) async {
    previousSentenceCalls += 1;
    if (state.sentenceIndex <= 0) return;
    state = state.copyWith(sentenceIndex: state.sentenceIndex - 1);
  }

  @override
  Future<void> goToSentence(
    int index, {
    RepeatNavigationSource source = RepeatNavigationSource.explicit,
  }) async {
    goToSentenceCalls += 1;
    if (index < 0 || index >= _sentences.length) return;
    state = state.copyWith(sentenceIndex: index);
  }

  @override
  Future<void> toggleCurrentBookmark() async {
    final sentence = currentSentence;
    if (sentence == null) return;
    _sentences[state.sentenceIndex] = sentence.copyWith(
      isBookmarked: !sentence.isBookmarked,
    );
    state = state.copyWith(currentSentenceBookmarked: !sentence.isBookmarked);
  }

  @override
  Future<void> incrementPassCount() async {}

  @override
  Future<void> clearBreakpoint({required bool isFreePlay}) async {}

  @override
  Future<void> completeSubStage() async {}

  @override
  Future<void> exitLearningMode() async {}

  @override
  Future<void> applySettingsChange() async {
    applySettingsChangeCallCount += 1;
    if (nextAppliedRepeatCount != null) {
      state = state.copyWith(
        repeatIndex: 0,
        totalRepeats: nextAppliedRepeatCount,
        phase: keepWaitingForUserOnSettingsChange
            ? const WaitingForUser(WaitingReason.userInteraction)
            : const PlayingPrompt(),
      );
    }
  }

  void completeSession() {
    state = state.copyWith(phase: const SessionCompleted());
  }
}

Widget _createTestWidget({
  required _TestListenAndRepeatController controller,
  SpeechRecordingState recordingState = const SpeechRecordingState(),
  List<Override> extraOverrides = const [],
  bool startAtHome = false,
  bool listenAndRepeatRatingEnabled = true,
  MediaLearningStartup? mediaStartup,
}) {
  var usePassedController = true;
  final audioItemDao = _MockAudioItemDao();
  when(
    () => audioItemDao.getWordTimestamps(any()),
  ).thenAnswer((_) async => null);
  when(() => audioItemDao.getById(any())).thenAnswer((_) async => null);
  when(
    () => audioItemDao.getTranscriptSrt(any()),
  ).thenAnswer((_) async => null);

  final router = GoRouter(
    initialLocation: startAtHome ? '/' : '/collections/c1/a1/listen-and-repeat',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  context.push('/collections/c1/a1/listen-and-repeat'),
              child: const Text('Open player'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/collections/:collectionId/:audioId/listen-and-repeat',
        builder: (context, state) {
          return ListenAndRepeatPlayerScreen(
            collectionId: state.pathParameters['collectionId'],
            audioItemId: state.pathParameters['audioId']!,
            mediaStartup: mediaStartup,
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      analyticsOverride(),
      guideEnabledProvider.overrideWith(() => _DisabledGuideEnabledNotifier()),
      ...studyTimeOverrides(),
      ...learningSettingsOverrides(
        listenAndRepeatRatingEnabled: listenAndRepeatRatingEnabled,
      ),
      speechPermissionServiceProvider.overrideWithValue(
        _FakeSpeechPermissionService(),
      ),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      mediaEngineProvider.overrideWith(_VideoViewMediaEngine.new),
      learningProgressNotifierProvider.overrideWith(
        () => TestLearningProgressNotifier(),
      ),
      learningSessionProvider.overrideWith(
        () => TestLearningSession(
          const LearningSessionState(
            learningMode: LearningMode.listenAndRepeat,
            audioItemId: 'a1',
          ),
        ),
      ),
      listenAndRepeatControllerProvider.overrideWith(() {
        if (usePassedController) {
          usePassedController = false;
          return controller;
        }
        return _TestListenAndRepeatController(
          controller._initialState,
          controller._sentences,
          startPlayingNoop: true,
        );
      }),
      speechRecordingControllerProvider.overrideWith(
        () => _StaticSpeechRecordingController(recordingState),
      ),
      sentenceAiNotifierProvider.overrideWithValue(
        SentenceAiNotifier(
          cacheDao: createStubbedMockCacheDao(),
          apiClient: _MockApiClient(),
        ),
      ),
      transcriptionApiClientProvider.overrideWithValue(
        createTestTranscriptionApiClient(),
      ),
      audioItemDaoProvider.overrideWithValue(audioItemDao),
      ...extraOverrides,
    ],
    child: MaterialApp.router(
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

class _DisabledGuideEnabledNotifier extends GuideEnabledNotifier {
  @override
  bool build() => false;

  @override
  Future<void> setEnabled(bool enabled) async {
    state = false;
  }
}

class _StaticSpeechRecordingController extends SpeechRecordingController {
  _StaticSpeechRecordingController(this._initialState);

  final SpeechRecordingState _initialState;

  @override
  SpeechRecordingState build() => _initialState;

  @override
  Future<void> clearRecording() async {
    state = const SpeechRecordingState();
  }

  @override
  Future<void> fullReset() async {
    state = const SpeechRecordingState();
  }

  @override
  Future<void> cancelActiveRecording() async {}

  @override
  void setRecordingCompletionHandler(
    void Function(Duration duration)? handler,
  ) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ListenAndRepeatSessionState createState({
    RepeatFlowPhase phase = const WaitingForUser(WaitingReason.userInteraction),
    int sentenceIndex = 0,
    int totalSentences = 5,
    int repeatIndex = 0,
    int totalRepeats = 3,
    bool isReviewPlaybackActive = false,
    bool hasVideo = false,
    bool isFreePlay = false,
  }) {
    return ListenAndRepeatSessionState(
      phase: phase,
      sentenceIndex: sentenceIndex,
      totalSentences: totalSentences,
      repeatIndex: repeatIndex,
      totalRepeats: totalRepeats,
      isReviewPlaybackActive: isReviewPlaybackActive,
      flowToken: 1,
      currentSentenceBookmarked: true,
      hasVideo: hasVideo,
      isFreePlay: isFreePlay,
    );
  }

  group('ListenAndRepeatPlayerScreen', () {
    testWidgets('恢复路由缺少启动任务和已初始化会话时返回入口页', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(),
        createTestSentences(count: 5),
        startPlayingNoop: true,
        sessionPrepared: false,
      );

      await tester.pumpWidget(
        _createTestWidget(controller: controller, startAtHome: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      expect(find.text('Open player'), findsOneWidget);
      expect(find.byType(ListenAndRepeatPlayerScreen), findsNothing);
    });

    testWidgets('视频启动任务未完成时显示加载态，完成后显示共享画面', (tester) async {
      final load = Completer<MediaLoadResult>();
      final controller = _TestListenAndRepeatController(
        createState(hasVideo: true),
        createTestSentences(count: 5),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(
        _createTestWidget(
          controller: controller,
          mediaStartup: MediaLearningStartup(
            loadKey: 'video-1',
            load: () => load.future,
            cancel: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading video…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsNothing);

      load.complete(MediaLoadResult.ready);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('media-video-canvas')), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('音频启动期间显示普通加载态，不显示视频画布', (tester) async {
      final load = Completer<MediaLoadResult>();
      final controller = _TestListenAndRepeatController(
        createState(),
        createTestSentences(count: 5),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(
        _createTestWidget(
          controller: controller,
          mediaStartup: MediaLearningStartup(
            loadKey: 'audio-1',
            load: () => load.future,
            cancel: () async {},
            showVideoLoading: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == Colors.black,
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('media-video-canvas')), findsNothing);

      load.complete(MediaLoadResult.ready);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('media-video-canvas')), findsNothing);
    });

    testWidgets('视频画面位于进度条上方', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(hasVideo: true),
        createTestSentences(count: 5),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final videoTop = tester.getTopLeft(
        find.byKey(const ValueKey('media-visual-surface')),
      );
      final progressTop = tester.getTopLeft(find.text('Sentence 1/5'));
      expect(videoTop.dy, lessThan(progressTop.dy));
    });

    testWidgets('正文左滑和右滑分别切换下一句与上一句', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(sentenceIndex: 2),
        createTestSentences(count: 5),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final pager = find.byKey(
        const ValueKey('listen-and-repeat-sentence-page-view'),
      );
      final pagerRect = tester.getRect(pager);
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(pagerRect.left, greaterThanOrEqualTo(AppSpacing.m));
      expect(pagerRect.right, lessThanOrEqualTo(screenWidth - AppSpacing.m));
      final progressTextRect = tester.getRect(find.text('Sentence 3/5'));
      expect(pagerRect.left, closeTo(progressTextRect.left, 1));
      final explanationRect = tester.getRect(
        find.byType(SentenceExplanationView).first,
      );
      expect(explanationRect.left, closeTo(pagerRect.left, 1));
      expect(explanationRect.right, closeTo(pagerRect.right, 1));

      await tester.fling(pager, const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(controller.goToSentenceCalls, 1);
      expect(controller.state.sentenceIndex, 3);
      expect(find.text('Sentence 4/5'), findsOneWidget);

      await tester.fling(pager, const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(controller.goToSentenceCalls, 2);
      expect(controller.state.sentenceIndex, 2);
      expect(find.text('Sentence 3/5'), findsOneWidget);
    });

    testWidgets('显示标题、进度和句子文本', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(sentenceIndex: 1, totalSentences: 5),
        createTestSentences(count: 5),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Listen & Repeat'), findsOneWidget);
      expect(find.text('Sentence 2/5'), findsOneWidget);
    });

    testWidgets('收藏按钮与进度信息显示在同一行', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(sentenceIndex: 1, totalSentences: 5),
        createTestSentences(count: 5),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final progressY = tester.getCenter(find.text('Sentence 2/5')).dy;
      expect(find.byType(BookmarkToggleRow), findsOneWidget);
      expect(
        tester.getCenter(find.byType(BookmarkToggleRow)).dy,
        closeTo(progressY, 3),
      );
      expect(
        tester.getTopRight(find.byType(BookmarkToggleRow)).dx,
        closeTo(tester.getSize(find.byType(Scaffold)).width - AppSpacing.m, 1),
      );
    });

    testWidgets('显示底部控制按钮', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(sentenceIndex: 1, totalSentences: 3),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('上一句下一句按钮点击区域与播放按钮一样大', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证 PlaybackNavButton 的 SizedBox 尺寸正确
      final navButtons = find.byType(PlaybackNavButton);
      expect(navButtons, findsNWidgets(2));

      // 每个 PlaybackNavButton 内部有一个 56x56 的 SizedBox
      final controlSizedBoxes = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == PlaybackControls.controlButtonSize &&
            widget.height == PlaybackControls.controlButtonSize,
      );
      expect(controlSizedBoxes, findsAtLeast(2));
    });

    testWidgets('停顿态显示录音按钮', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(phase: const WaitingForUser(WaitingReason.userInteraction)),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(RecordingButton), findsOneWidget);
      expect(find.text('Tap to record'), findsNothing);
      expect(find.text('Recording...'), findsNothing);
    });

    testWidgets('停止录音后 idle 态不应继续显示红色录音按钮', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(phase: const WaitingForUser(WaitingReason.userInteraction)),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      const recordingState = SpeechRecordingState(
        phase: SpeechRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(
          promptId: 'lar:test-audio:0',
          filePath: '/tmp/test.m4a',
        ),
      );

      await tester.pumpWidget(
        _createTestWidget(
          controller: controller,
          recordingState: recordingState,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Tap to record'), findsNothing);
      expect(find.text('Recording...'), findsNothing);
    });

    testWidgets('关闭评级后仍显示录音回放 badge', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(phase: const WaitingForUser(WaitingReason.userInteraction)),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );
      const recordingState = SpeechRecordingState(
        currentAttempt: SpeechPracticeAttempt(
          promptId: 'lar:test-audio:0',
          filePath: '/tmp/test.m4a',
          status: SpeechPracticeAttemptStatus.passed,
          score: 0.8,
        ),
      );

      await tester.pumpWidget(
        _createTestWidget(
          controller: controller,
          recordingState: recordingState,
          listenAndRepeatRatingEnabled: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recording'), findsOneWidget);
    });

    testWidgets('播放原句阶段显示提示而不显示录音按钮', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(phase: const PlayingPrompt()),
        createTestSentences(count: 3),
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Listen, then repeat'), findsOneWidget);
      expect(find.byType(RecordingButton), findsNothing);
    });

    testWidgets('会话完成后弹出完成对话框', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      controller.completeSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Listen & Repeat Complete'), findsOneWidget);
    });

    testWidgets('完成弹窗显示期间进入等待用户接管并保留末句', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(sentenceIndex: 2, totalSentences: 3),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      controller.completeSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Listen & Repeat Complete'), findsOneWidget);
      expect(controller.state.phase, isA<WaitingForUser>());
      expect(find.text('Sentence 3/3'), findsOneWidget);
      expect(find.byType(RecordingButton), findsOneWidget);
    });

    testWidgets('自由练习末句完成弹窗期间进入等待用户接管', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(sentenceIndex: 2, totalSentences: 3, isFreePlay: true),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Listen & Repeat Complete'), findsOneWidget);
      expect(controller.state.phase, isA<WaitingForUser>());
      expect(find.byType(RecordingButton), findsOneWidget);
    });

    testWidgets('完成后不再检查学习版通知提示', (tester) async {
      final notificationService = _MockNotificationPermissionService();
      when(
        () => notificationService.canShowPrompt(),
      ).thenAnswer((_) async => true);

      final controller = _TestListenAndRepeatController(
        createState(),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(
        _createTestWidget(
          controller: controller,
          extraOverrides: [
            notificationPermissionServiceProvider.overrideWithValue(
              notificationService,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      controller.completeSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Listen & Repeat Complete'), findsOneWidget);
      verifyNever(() => notificationService.canShowPrompt());
    });

    testWidgets('点完成返回后不触发退出确认且主界面仍可点击', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      );

      await tester.pumpWidget(
        _createTestWidget(controller: controller, startAtHome: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      controller.completeSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Exit Listen & Repeat?'), findsNothing);
      expect(find.text('Open player'), findsOneWidget);

      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      expect(find.byType(ListenAndRepeatPlayerScreen), findsOneWidget);
    });

    testWidgets('修改重复次数后当前句遍数标签立即刷新', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(totalRepeats: 3),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      )..nextAppliedRepeatCount = 5;

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Round 1/3'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ListenAndRepeatPlayerScreen)),
      );
      container
          .read(listenAndRepeatSettingsProvider.notifier)
          .update(const IntensiveListenSettings(repeatCount: 5));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.applySettingsChangeCallCount, 1);
      expect(find.textContaining('Round 1/5'), findsOneWidget);
    });

    testWidgets('WaitingForUser 态修改设置后应保持等待态', (tester) async {
      final controller =
          _TestListenAndRepeatController(
              createState(
                phase: const WaitingForUser(WaitingReason.userInteraction),
              ),
              createTestSentences(count: 3),
              startPlayingNoop: true,
            )
            ..nextAppliedRepeatCount = 5
            ..keepWaitingForUserOnSettingsChange = true;

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Tap to record'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ListenAndRepeatPlayerScreen)),
      );
      container
          .read(listenAndRepeatSettingsProvider.notifier)
          .update(const IntensiveListenSettings(repeatCount: 5));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.applySettingsChangeCallCount, 1);
      expect(find.text('Tap to record'), findsNothing);
      expect(find.text('Listen, then repeat'), findsNothing);
      expect(find.textContaining('Round 1/5'), findsOneWidget);
    });

    testWidgets('切换手动模式后底部标签立即更新', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(),
        createTestSentences(count: 3),
        startPlayingNoop: true,
      )..nextAppliedRepeatCount = 3;

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Round 1/3'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ListenAndRepeatPlayerScreen)),
      );
      container
          .read(listenAndRepeatSettingsProvider.notifier)
          .update(
            const IntensiveListenSettings(
              controlMode: ShadowingControlMode.manual,
            ),
          );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Manual'), findsOneWidget);
      expect(find.text('Round 1/3'), findsNothing);
    });
  });
}
