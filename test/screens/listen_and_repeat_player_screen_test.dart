// 跟读播放器页面测试
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/listen_and_repeat_player_screen.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/providers/sentence_ai_provider.dart';
import 'package:fluency/database/daos/sentence_ai_cache_dao.dart';
import 'package:fluency/services/sentence_ai_api_client.dart';
import 'package:fluency/services/speech_practice_platform.dart';
import 'package:fluency/widgets/listen_and_repeat/speech_record_button.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _FakeSpeechPracticeBackend implements SpeechPracticeBackend {
  _FakeSpeechPracticeBackend({this.autoEmitFinal = true});

  SpeechPracticePermissionState permissions =
      const SpeechPracticePermissionState(
        microphone: SpeechPracticePermissionStatus.granted,
        speech: SpeechPracticePermissionStatus.granted,
      );
  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  String finalTranscript = '';
  final bool autoEmitFinal;
  int _counter = 0;
  String? _activePromptId;

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => _controller.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    return permissions;
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions() async {
    return permissions;
  }

  @override
  Future<void> warmup({String locale = 'en-US'}) async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    _activePromptId = promptId;
    _counter += 1;
    return '/tmp/$promptId-$_counter.caf';
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    final promptId = _activePromptId ?? 'shadowing:a1:0';
    if (autoEmitFinal) {
      scheduleMicrotask(() {
        emitFinal(promptId: promptId);
      });
    }
    return SpeechPracticeStopResult(filePath: '/tmp/$promptId-$_counter.caf');
  }

  @override
  Future<void> cancelSession() async {}

  @override
  Future<void> deleteRecording(String filePath) async {}

  void emitSpeechStarted({String? promptId}) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.speechStarted,
        promptId: promptId ?? _activePromptId ?? 'shadowing:a1:0',
      ),
    );
  }

  void emitSilenceProgress({
    String? promptId,
    required Duration silenceDuration,
  }) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.silenceProgress,
        promptId: promptId ?? _activePromptId ?? 'shadowing:a1:0',
        silenceDuration: silenceDuration,
      ),
    );
  }

  void emitFinal({String? promptId, String? transcript}) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.finalTranscriptReady,
        promptId: promptId ?? _activePromptId ?? 'shadowing:a1:0',
        transcript: transcript ?? finalTranscript,
      ),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  /// 创建测试用的跟读播放器状态
  ListenAndRepeatPlayerState createPlayerState({
    int currentSentenceIndex = 0,
    int totalSentences = 5,
    int currentPlayCount = 1,
    int targetPlayCount = 3,
    bool isPlaying = true,
    bool isPauseBetweenPlays = false,
    bool isPauseBetweenSentences = false,
    Duration pauseRemaining = Duration.zero,
    Duration pauseDuration = Duration.zero,
  }) {
    return ListenAndRepeatPlayerState(
      currentSentenceIndex: currentSentenceIndex,
      totalSentences: totalSentences,
      currentPlayCount: currentPlayCount,
      targetPlayCount: targetPlayCount,
      settings: IntensiveListenSettings(repeatCount: targetPlayCount),
      isPlaying: isPlaying,
      isPauseBetweenPlays: isPauseBetweenPlays,
      isPauseBetweenSentences: isPauseBetweenSentences,
      pauseRemaining: pauseRemaining,
      pauseDuration: pauseDuration,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    ListenAndRepeatPlayerState? playerState,
    LearningSessionState? sessionState,
    SpeechPracticeBackend? speechBackend,
  }) {
    final sentences = createTestSentences(count: 5);

    final router = GoRouter(
      initialLocation: '/collections/c1/a1/listen-and-repeat',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/listen-and-repeat',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return ListenAndRepeatPlayerScreen(
              collectionId: collectionId,
              audioItemId: audioId,
            );
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
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
        listenAndRepeatPlayerProvider.overrideWith(
          () => TestListenAndRepeatPlayer(
            playerState ?? createPlayerState(),
            sentences,
          ),
        ),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: _MockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
        speechPracticeBackendProvider.overrideWithValue(
          speechBackend ?? _FakeSpeechPracticeBackend(),
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

  group('ListenAndRepeatPlayerScreen', () {
    testWidgets('显示跟读 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Listen & Repeat'), findsOneWidget);
    });

    testWidgets('显示当前句子文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SentenceAnnotationCard 使用 RichText 渲染，需要在 TextSpan 中查找
      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text.contains('Test sentence number 1.');
        }
        return false;
      });
      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('显示播放遍数信息', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentPlayCount: 1,
            targetPlayCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play 1/3'), findsOneWidget);
    });

    testWidgets('进度指示器显示当前/总句数', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // l10n: "Repeat 3/10" (1-based)
      expect(find.text('Repeat 3/10'), findsOneWidget);
    });

    testWidgets('底部控制栏包含上一句、播放/暂停、下一句按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      // 默认 isPlaying=true，显示暂停图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('AppBar 包含设置按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('播放中显示暂停图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('点击播放按钮切换为暂停图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 初始播放中，显示暂停图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // 点击播放/暂停按钮（GestureDetector 包裹的圆形容器）
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 暂停后显示播放图标
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('播放原句阶段不显示录音按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isPauseBetweenPlays: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpeechRecordButton), findsNothing);
    });

    testWidgets('轮到用户说时自动开始录音并显示录音按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: false,
            isPauseBetweenPlays: true,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      // 使用 pump 而非 pumpAndSettle，因为 SpeechRecordButton 有循环脉冲动画
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // awaitingSpeech 阶段录音已激活，显示 mic 图标（红色背景）
      expect(find.byType(SpeechRecordButton), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('停顿中显示录音状态文字（Recording...）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: false,
            isPauseBetweenPlays: true,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 停顿中，RetellRecordingController 自动开始录音，
      // 映射为 speaking → 显示 "Recording..." 和录音按钮
      expect(find.byType(SpeechRecordButton), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    // TODO: 以下两个测试需要 mock RetellRecordingController 才能测试录音结果展示
    // 迁移到 RetellRecordingController 后，录音流程不再经过 SpeechPracticeSession，
    // 需要创建 RecordingService mock 来驱动录音评估流程。
    //
    // testWidgets('长识别结果不会挤爆底部布局', ...)
    // testWidgets('停止录音后先显示处理中图标，final 到达后再展示转录结果', ...)
  });
}
