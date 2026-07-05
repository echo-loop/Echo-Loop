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
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_controller.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_phase.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_settings_provider.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_session_state.dart';
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

import '../helpers/mock_providers.dart';

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _MockAudioItemDao extends Mock implements AudioItemDao {}

class _MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

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
  });

  final ListenAndRepeatSessionState _initialState;
  final List<Sentence> _sentences;
  final bool startPlayingNoop;
  int? nextAppliedRepeatCount;
  int applySettingsChangeCallCount = 0;
  bool keepWaitingForUserOnSettingsChange = false;

  @override
  ListenAndRepeatSessionState build() => _initialState;

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
  Future<void> nextSentence() async {
    if (state.sentenceIndex >= _sentences.length - 1) return;
    state = state.copyWith(sentenceIndex: state.sentenceIndex + 1);
  }

  @override
  Future<void> previousSentence() async {
    if (state.sentenceIndex <= 0) return;
    state = state.copyWith(sentenceIndex: state.sentenceIndex - 1);
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
  void pauseStudyTimer() {}

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
}) {
  final audioItemDao = _MockAudioItemDao();
  when(
    () => audioItemDao.getWordTimestamps(any()),
  ).thenAnswer((_) async => null);
  when(() => audioItemDao.getById(any())).thenAnswer((_) async => null);

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
      speechPermissionServiceProvider.overrideWithValue(
        _FakeSpeechPermissionService(),
      ),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
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
      listenAndRepeatControllerProvider.overrideWith(() => controller),
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
    );
  }

  group('ListenAndRepeatPlayerScreen', () {
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

    testWidgets('播放原句阶段显示提示而不显示录音按钮', (tester) async {
      final controller = _TestListenAndRepeatController(
        createState(phase: const PlayingPrompt()),
        createTestSentences(count: 3),
      );

      await tester.pumpWidget(_createTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Listen then repeat'), findsOneWidget);
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
      expect(find.text('Listen then repeat'), findsNothing);
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
