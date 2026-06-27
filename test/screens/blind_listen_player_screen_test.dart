// 全文盲听播放器页面 Widget 测试
//
// 验证共享段落骨架已经接入，页面底部只有一套播放控制，
// 且文本显隐开关位于句子列表下方。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/blind_listen_settings.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/screens/blind_listen_player_screen.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';
import 'package:echo_loop/widgets/practice/practice_progress_section.dart';

import '../helpers/mock_providers.dart';

class _StaticBlindListenPlayer extends TestBlindListenPlayer {
  _StaticBlindListenPlayer(super.initialState);

  @override
  Future<void> startPlaying() async {}
}

class _MutableBlindListenPlayer extends _StaticBlindListenPlayer {
  _MutableBlindListenPlayer(super.initialState);

  void emit(BlindListenPlayerState nextState) {
    state = nextState;
  }
}

class _MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

class _TrackingBlindListenPlayer extends _StaticBlindListenPlayer {
  _TrackingBlindListenPlayer(super.initialState, this.paragraphs);

  final List<List<Sentence>> paragraphs;

  int bookmarkCalls = 0;
  int? lastBookmarkedSentenceIndex;

  @override
  List<Sentence> get currentParagraphSentences =>
      paragraphs[state.currentParagraphIndex];

  @override
  Future<void> toggleBookmark(String audioItemId, Sentence sentence) async {
    bookmarkCalls += 1;
    lastBookmarkedSentenceIndex = sentence.index;
    await super.toggleBookmark(audioItemId, sentence);
  }
}

List<List<Sentence>> _testParagraphs() {
  final sentences = createTestSentences(count: 4);
  return [
    [sentences[0], sentences[1]],
    [sentences[2], sentences[3]],
  ];
}

void main() {
  Widget createTestWidget({
    Locale locale = const Locale('en'),
    BlindListenPlayerState? playerState,
    List<Override> extraOverrides = const [],
    TestBlindListenPlayer Function(BlindListenPlayerState initialState)?
    playerFactory,
  }) {
    final sentences = createTestSentences(count: 4);
    final initialState =
        playerState ??
        const BlindListenPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: 2,
          currentRepeatCount: 1,
          displayMode: BlindListenDisplayMode.hideAll,
        );

    final router = GoRouter(
      initialLocation: '/collections/c1/a1/blind-listen',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/blind-listen',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return BlindListenPlayerScreen(
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
        learningSessionProvider.overrideWith(() => TestLearningSession()),
        blindListenPlayerProvider.overrideWith(
          () => (playerFactory ?? TestBlindListenPlayer.new)(initialState),
        ),
        ...studyTimeOverrides(),
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

  group('BlindListenPlayerScreen', () {
    testWidgets('只渲染一套底部播放控制', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(PlaybackControls), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('底部状态标签显示当前播放速度', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            settings: BlindListenSettings(playbackSpeed: 1.3),
          ),
          playerFactory: _StaticBlindListenPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Auto · Round 1/1 · 1.3x'), findsOneWidget);
    });

    testWidgets('文本显隐开关位于句子列表下方', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            displayMode: BlindListenDisplayMode.hideAll,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sentenceCard = find.byType(Card).first;
      final toggleText = find.text('Peek');

      expect(toggleText, findsOneWidget);
      expect(
        tester.getRect(toggleText).top,
        greaterThanOrEqualTo(tester.getRect(sentenceCard).bottom - 1),
      );
    });

    testWidgets('倒计时阶段复用共享骨架并显示进度条', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            isPauseCountdown: true,
            pauseRemaining: Duration(seconds: 2),
            pauseDuration: Duration(seconds: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 多段模式进度条按段落驱动，且可拖动跳段（共享骨架的进度区域）
      expect(find.byType(PracticeProgressSection), findsOneWidget);
      expect(find.text('Try to recall what you just heard'), findsOneWidget);
      expect(find.byType(PlaybackControls), findsOneWidget);
    });

    testWidgets('手动模式播放前显示先听再回忆提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            settings: BlindListenSettings(
              controlMode: ShadowingControlMode.manual,
            ),
          ),
          playerFactory: _StaticBlindListenPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Listen first, then recall'), findsOneWidget);
      expect(find.text('Try to recall what you just heard'), findsNothing);
    });

    testWidgets('WaitingForUser 态即使 isPlaying 为 true 也显示播放图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            isPlaying: true,
            isWaitingForUser: true,
          ),
          playerFactory: _StaticBlindListenPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('手动模式播放完成后显示回忆提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            hasCompletedCurrentParagraphPlayback: true,
            settings: BlindListenSettings(
              controlMode: ShadowingControlMode.manual,
            ),
          ),
          playerFactory: _StaticBlindListenPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Try to recall what you just heard'), findsOneWidget);
      expect(find.text('Listen first, then recall'), findsNothing);
    });

    testWidgets('手动停止播放后显示先听再回忆提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            isPlaying: false,
            hasCompletedCurrentParagraphPlayback: false,
          ),
          playerFactory: _StaticBlindListenPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Listen first, then recall'), findsOneWidget);
      expect(find.text('Try to recall what you just heard'), findsNothing);
    });

    testWidgets('waiting for user 状态显示先听再回忆提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 2,
            currentRepeatCount: 1,
            isWaitingForUser: true,
            hasCompletedCurrentParagraphPlayback: true,
          ),
          playerFactory: _StaticBlindListenPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Listen first, then recall'), findsOneWidget);
      expect(find.text('Listen carefully...'), findsNothing);
      expect(find.text('Try to recall what you just heard'), findsNothing);
    });

    testWidgets('完成后不再检查学习版通知提示', (tester) async {
      final notificationService = _MockNotificationPermissionService();
      when(
        () => notificationService.canShowPrompt(),
      ).thenAnswer((_) async => true);

      final player = _MutableBlindListenPlayer(
        const BlindListenPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: 2,
          currentRepeatCount: 1,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          playerFactory: (_) => player,
          extraOverrides: [
            notificationPermissionServiceProvider.overrideWithValue(
              notificationService,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      player.emit(player.state.copyWith(stepFinished: true, isPlaying: false));
      await tester.pumpAndSettle();

      verifyNever(() => notificationService.canShowPrompt());
    });

    // 盲听页面不再支持点词查词（已移除 onWordTap）
    // 点编号→seekToSentence 的链路由 Provider 单测 + Widget 单测 + 复述 Screen 单测 共同覆盖：
    // - Provider 单测验证 seekToSentence 行为
    // - Widget 单测（masked_sentence_tile_test）验证 tile 编号区→onPlayFromTap 分发
    // - 复述 Screen 单测验证 onPlayFromTap → player.seekToSentence 的接线
    // 盲听 Screen 接入是同款代码（_handleSentencePlayFrom + onSentencePlayFrom 透传），不重复测。

    testWidgets('点击右侧收藏按钮直接切换收藏，不进入讲解页', (tester) async {
      final trackingPlayer = _TrackingBlindListenPlayer(
        const BlindListenPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: 2,
          currentRepeatCount: 1,
          displayMode: BlindListenDisplayMode.hideAll,
        ),
        _testParagraphs(),
      );

      await tester.pumpWidget(
        createTestWidget(playerFactory: (_) => trackingPlayer),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('$kMaskedSentenceBookmarkHitAreaKeyPrefix-0'),
        ),
      );
      await tester.pump();

      expect(trackingPlayer.bookmarkCalls, 1);
      expect(trackingPlayer.lastBookmarkedSentenceIndex, 0);
      expect(find.text('Sentence Detail'), findsNothing);
    });
  });
}
