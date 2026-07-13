// 精听播放器页面测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/screens/intensive_listen_player_screen.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/database/app_database.dart' show AudioItem, Bookmark;
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/practice/sentence_annotation_card.dart';

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

/// 启动后定位到最后一句（等用户点"下一句"触发完成弹窗）
class _AutoCompleteIntensiveListenPlayer extends TestIntensiveListenPlayer {
  _AutoCompleteIntensiveListenPlayer(super.initialState, super.testSentences);

  @override
  Future<void> startPlaying() async {
    state = state.copyWith(
      currentSentenceIndex: state.totalSentences - 1,
      isPlaying: false,
    );
  }
}

class _RecordingIntensiveListenPlayer extends TestIntensiveListenPlayer {
  _RecordingIntensiveListenPlayer(super.initialState, super.testSentences);

  int pauseCalls = 0;
  int resumeCalls = 0;
  int replayInDetailsCalls = 0;
  int replayDuringCountdownCalls = 0;
  int goToNextCalls = 0;
  int goToPreviousCalls = 0;

  @override
  Future<void> startPlaying() async {}

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
}

class _MutableIntensiveListenPlayer extends TestIntensiveListenPlayer {
  _MutableIntensiveListenPlayer(super.initialState, super.testSentences);

  void emit(IntensiveListenState nextState) {
    state = nextState;
  }
}

class _MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

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
    );
  }

  Bookmark createBookmark({required int id, required int sentenceIndex}) {
    final now = DateTime(2026, 2, 25);
    return Bookmark(
      id: id,
      audioItemId: 'test-1',
      sentenceIndex: sentenceIndex,
      sentenceText: 'Sentence $sentenceIndex',
      startTime: sentenceIndex.toDouble(),
      endTime: sentenceIndex.toDouble() + 1,
      createdAt: now,
      updatedAt: now,
      syncStatus: 0,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    IntensiveListenState? playerState,
    LearningSessionState? sessionState,
    _TestBookmarkDao? bookmarkDao,
    List<Override> extraOverrides = const [],
    bool startAtHome = false,
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
    testWidgets('显示精听 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Intensive Listening'), findsOneWidget);
    });

    testWidgets('AppBar 显示设置按钮', (tester) async {
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

      // "Sentence 3/10" (1-based)
      expect(find.text('Sentence 3/10'), findsOneWidget);
    });

    testWidgets('普通模式显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsOneWidget);
      expect(find.text('Unclear'), findsOneWidget);
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

    testWidgets('详情模式显示继续按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
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
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('3s'), findsNothing);
      expect(find.text('Replaying with subtitles...'), findsNothing);
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
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Replaying with subtitles...'), findsOneWidget);
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
      expect(find.text('Continue'), findsNothing);
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

    testWidgets('中文本地化正确显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          locale: const Locale('zh'),
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('逐句精听'), findsOneWidget);
      expect(find.text('偷看字幕'), findsOneWidget);
      expect(find.text('听不太懂'), findsOneWidget);
    });

    testWidgets('完成统计使用数据库难句总数而非本次会话数量', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            totalSentences: 5,
            difficultSentences: {0},
          ),
          playerFactory: (state, sentences) =>
              _AutoCompleteIntensiveListenPlayer(state, sentences),
          bookmarkDao: _TestBookmarkDao(
            bookmarks: [
              createBookmark(id: 1, sentenceIndex: 0),
              createBookmark(id: 2, sentenceIndex: 3),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 最后一句显示完成按钮（check_circle_rounded），点击触发完成弹窗
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      // 难句统计 chip 显示数据库难句总数 2（而非本次会话的 1），标签为 Difficult
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Difficult'), findsOneWidget);
    });

    testWidgets('完成后仍会检查并弹出学习版通知提示', (tester) async {
      final notificationService = _MockNotificationPermissionService();
      when(
        () => notificationService.canShowPrompt(),
      ).thenAnswer((_) async => true);
      when(
        () => notificationService.onUserAcceptedPrompt(),
      ).thenAnswer((_) async => true);
      when(
        () => notificationService.onUserDismissedPrompt(),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            totalSentences: 5,
            difficultSentences: {0},
          ),
          playerFactory: (state, sentences) =>
              _AutoCompleteIntensiveListenPlayer(state, sentences),
          extraOverrides: [
            notificationPermissionServiceProvider.overrideWithValue(
              notificationService,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      verify(() => notificationService.canShowPrompt()).called(1);
      expect(find.text('Review while it\'s fresh'), findsOneWidget);
    });

    testWidgets('点完成返回后不触发退出确认且主界面仍可点击', (tester) async {
      final notificationService = _MockNotificationPermissionService();
      when(
        () => notificationService.canShowPrompt(),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        createTestWidget(
          startAtHome: true,
          playerState: createPlayerState(totalSentences: 5),
          playerFactory: (state, sentences) =>
              _AutoCompleteIntensiveListenPlayer(state, sentences),
          extraOverrides: [
            notificationPermissionServiceProvider.overrideWithValue(
              notificationService,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Exit Intensive Listening?'), findsNothing);
      expect(find.text('Open player'), findsOneWidget);

      await tester.tap(find.text('Open player'));
      await tester.pumpAndSettle();

      expect(find.byType(IntensiveListenPlayerScreen), findsOneWidget);
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
      expect(find.text('Marked difficult, tap to undo'), findsOneWidget);
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
      expect(find.text('Tap to mark as difficult'), findsOneWidget);
    });

    testWidgets('正常模式下点击标记行可取消标记', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            difficultSentences: {0},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击标记行取消难句
      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      // 取消后变为空心星标 + 灰色文案
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.text('Tap to mark as difficult'), findsOneWidget);
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
      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();

      // 统一可点词组件：整句渲染为单个 RichText
      expect(
        find.textContaining('sentence', findRichText: true),
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
      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sentence', findRichText: true),
        findsOneWidget,
      );

      // 第二次点击隐藏（文案已变为 Hide）
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sentence', findRichText: true), findsNothing);
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

      // 标注模式下（非 annotationReplay），导航按钮仍可用
      // _NavButton 使用 AnimatedOpacity，可用态 opacity=0.6
      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final nextIcon = find.byIcon(Icons.skip_next_rounded);
      expect(prevIcon, findsOneWidget);
      expect(nextIcon, findsOneWidget);

      final prevOpacity = tester.widget<Opacity>(
        find.ancestor(of: prevIcon, matching: find.byType(Opacity)).first,
      );
      final nextOpacity = tester.widget<Opacity>(
        find.ancestor(of: nextIcon, matching: find.byType(Opacity)).first,
      );
      expect(prevOpacity.opacity, 0.6);
      expect(nextOpacity.opacity, 0.6);
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
      expect(find.text('Replaying with subtitles...'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
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
