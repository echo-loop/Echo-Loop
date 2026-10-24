import 'dart:async';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/word_highlight_binding.dart';
import 'package:echo_loop/models/sense_group_range_playback.dart';
import 'package:echo_loop/models/media_playback_state.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/media_playback/media_playback_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/screens/sentence_detail_screen.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/bookmark_toggle_row.dart';
import 'package:echo_loop/widgets/practice/sentence_explanation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _MockSentenceAiApiClient extends Mock implements SentenceAiApiClient {}

class _RecordingRangePlayback
    implements SenseGroupRangePlayback, ResumableSentenceRangePlayback {
  Duration? start;
  Duration? end;
  @override
  Duration currentPosition = Duration.zero;
  final playStarts = <Duration>[];
  final resumedPositions = <Duration>[];
  int cancelCalls = 0;
  bool holdNextPlay = false;
  Completer<void>? _activePlay;

  @override
  Future<void> cancel() async {
    cancelCalls++;
    final activePlay = _activePlay;
    _activePlay = null;
    if (activePlay != null && !activePlay.isCompleted) {
      activePlay.complete();
    }
  }

  @override
  Future<void> play(String audioItemId, Duration start, Duration end) {
    playStarts.add(start);
    return _recordPlay(start, end);
  }

  @override
  Future<void> playFromPosition(
    String audioItemId,
    Duration start,
    Duration end,
    Duration position,
  ) {
    resumedPositions.add(position);
    return _recordPlay(position, end);
  }

  Future<void> _recordPlay(Duration start, Duration end) {
    this.start = start;
    this.end = end;
    if (!holdNextPlay) return Future<void>.value();
    holdNextPlay = false;
    final activePlay = Completer<void>();
    _activePlay = activePlay;
    return activePlay.future;
  }
}

class _TestMediaPlayback extends MediaPlayback {
  bool? visible;
  bool? subtitleVisible;

  @override
  MediaPlaybackState build() => const MediaPlaybackState();

  @override
  Future<void> setVisualTrackVisible(bool value) async {
    visible = value;
  }

  @override
  Future<void> setVideoSubtitleVisible(bool value) async {
    subtitleVisible = value;
  }
}

class _VideoViewMediaEngine extends MediaEngine {
  @override
  Widget buildVideoView({required Size viewportSize}) {
    return const SizedBox(key: ValueKey('sentence-detail-video-view'));
  }
}

void main() {
  List<Override> detailOverrides() => [
    audioItemDaoProvider.overrideWithValue(FakeAudioItemDao()),
    bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
    sentenceAiNotifierProvider.overrideWithValue(
      SentenceAiNotifier(
        cacheDao: createStubbedMockCacheDao(),
        apiClient: _MockSentenceAiApiClient(),
      ),
    ),
  ];

  testWidgets('媒体讲解页将句子与意群播放委托给注入的媒体会话', (tester) async {
    final rangePlayback = _RecordingRangePlayback();
    await tester.pumpWidget(
      createTestApp(
        SentenceDetailScreen(
          args: SentenceDetailArgs(
            audioItemId: 'media-item',
            audioName: 'Media item',
            sentenceText: 'A sentence for media playback.',
            sentenceIndex: 0,
            totalSentenceCount: 10,
            startTimeMs: 1000,
            endTimeMs: 3000,
            rangePlayback: rangePlayback,
            wordHighlightSource: const WordHighlightSource(
              audioItemId: 'media-item',
              positionStream: Stream<Duration>.empty(),
              currentPosition: Duration.zero,
              playbackStatus: WordHighlightPlaybackStatus.idle,
              playbackStatusStream: Stream<WordHighlightPlaybackStatus>.empty(),
            ),
          ),
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('media-visual-surface')), findsNothing);
    final annotation = tester.widget<SentenceExplanationView>(
      find.byType(SentenceExplanationView),
    );
    expect(annotation.senseGroupRangePlayback, same(rangePlayback));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(rangePlayback.start, const Duration(seconds: 1));
    expect(rangePlayback.end, const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(rangePlayback.playStarts, [
      const Duration(seconds: 1),
      const Duration(seconds: 1),
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('句子讲解页暂停后从准确位置继续', (tester) async {
    final rangePlayback = _RecordingRangePlayback()..holdNextPlay = true;
    await tester.pumpWidget(
      createTestApp(
        SentenceDetailScreen(
          args: SentenceDetailArgs(
            audioItemId: 'media-item',
            audioName: 'Media item',
            sentenceText: 'A sentence for media playback.',
            sentenceIndex: 0,
            startTimeMs: 1000,
            endTimeMs: 3000,
            rangePlayback: rangePlayback,
            wordHighlightSource: const WordHighlightSource(
              audioItemId: 'media-item',
              positionStream: Stream<Duration>.empty(),
              currentPosition: Duration.zero,
              playbackStatus: WordHighlightPlaybackStatus.idle,
              playbackStatusStream: Stream<WordHighlightPlaybackStatus>.empty(),
            ),
          ),
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(rangePlayback.start, const Duration(seconds: 1));

    rangePlayback.currentPosition = const Duration(milliseconds: 1840);
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    expect(rangePlayback.cancelCalls, 1);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(rangePlayback.resumedPositions, [
      const Duration(milliseconds: 1840),
    ]);
    expect(rangePlayback.start, const Duration(milliseconds: 1840));
    expect(rangePlayback.end, const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('纯音频详情页使用调用方注入的高亮播放源', (tester) async {
    final source = WordHighlightSource(
      audioItemId: 'audio-item',
      positionStream: const Stream<Duration>.empty(),
      currentPosition: const Duration(milliseconds: 1500),
      playbackStatus: WordHighlightPlaybackStatus.playing,
      playbackStatusStream: const Stream<WordHighlightPlaybackStatus>.empty(),
    );
    await tester.pumpWidget(
      createTestApp(
        SentenceDetailScreen(
          args: SentenceDetailArgs(
            audioItemId: 'audio-item',
            audioName: 'Audio item',
            sentenceText: 'A sentence for audio playback.',
            sentenceIndex: 0,
            startTimeMs: 1000,
            endTimeMs: 3000,
            wordHighlightSource: source,
          ),
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('media-visual-surface')), findsNothing);
    final annotation = tester.widget<SentenceExplanationView>(
      find.byType(SentenceExplanationView),
    );
    expect(annotation.wordHighlightSource, same(source));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('详情页顶部信息行与讲解区使用相同水平边距', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        SentenceDetailScreen(
          args: const SentenceDetailArgs(
            audioItemId: 'media-item',
            audioName: 'Media item',
            sentenceText: 'A sentence for alignment.',
            sentenceIndex: 0,
            totalSentenceCount: 10,
            startTimeMs: 1000,
            endTimeMs: 3000,
            wordHighlightSource: WordHighlightSource(
              audioItemId: 'media-item',
              positionStream: Stream<Duration>.empty(),
              currentPosition: Duration.zero,
              playbackStatus: WordHighlightPlaybackStatus.idle,
              playbackStatusStream: Stream<WordHighlightPlaybackStatus>.empty(),
            ),
          ),
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    final progress = find.textContaining('第 1/10 句');
    final annotation = find.byType(SentenceExplanationView);
    expect(progress, findsOneWidget);
    expect(annotation, findsOneWidget);
    expect(tester.getRect(annotation).left, closeTo(AppSpacing.m, 1));
    expect(tester.getRect(progress).left, closeTo(AppSpacing.m, 1));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('sentence-detail-explanation-gap')),
          )
          .height,
      6,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('详情页收藏行贴齐信息区右侧内边距', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        SentenceDetailScreen(
          args: const SentenceDetailArgs(
            audioItemId: 'audio-item',
            audioName: 'Audio item',
            sentenceText: 'A sentence for alignment.',
            sentenceIndex: 0,
            totalSentenceCount: 10,
            startTimeMs: 1000,
            endTimeMs: 3000,
            wordHighlightSource: WordHighlightSource(
              audioItemId: 'audio-item',
              positionStream: Stream<Duration>.empty(),
              currentPosition: Duration.zero,
              playbackStatus: WordHighlightPlaybackStatus.idle,
              playbackStatusStream: Stream<WordHighlightPlaybackStatus>.empty(),
            ),
          ),
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final bookmark = find.byType(BookmarkToggleRow);
    expect(bookmark, findsOneWidget);
    final bookmarkIcon = find.byIcon(Icons.bookmark_border);
    expect(bookmarkIcon, findsOneWidget);
    final annotation = find.byType(SentenceExplanationView);
    expect(
      tester.getRect(bookmarkIcon).right,
      closeTo(tester.getRect(annotation).right, 1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('视频讲解页复用 media_kit 画面并提供完整统一控制', (tester) async {
    final rangePlayback = _RecordingRangePlayback();
    final mediaPlayback = _TestMediaPlayback();
    var fullscreen = false;
    await tester.pumpWidget(
      createTestApp(
        SentenceDetailScreen(
          args: SentenceDetailArgs(
            audioItemId: 'media-item',
            audioName: 'Media item',
            sentenceText: 'A sentence for media playback.',
            sentenceIndex: 0,
            totalSentenceCount: 10,
            startTimeMs: 1000,
            endTimeMs: 3000,
            rangePlayback: rangePlayback,
            wordHighlightSource: const WordHighlightSource(
              audioItemId: 'media-item',
              positionStream: Stream<Duration>.empty(),
              currentPosition: Duration.zero,
              playbackStatus: WordHighlightPlaybackStatus.idle,
              playbackStatusStream: Stream<WordHighlightPlaybackStatus>.empty(),
            ),
            mediaSession: SentenceDetailMediaSession(
              readState: () => const MediaPlaybackState(),
              setVisible: mediaPlayback.setVisualTrackVisible,
              setSubtitleVisible: mediaPlayback.setVideoSubtitleVisible,
              setFullscreen: (expanded) async => fullscreen = expanded,
              buildVideoView: (size) =>
                  _VideoViewMediaEngine().buildVideoView(viewportSize: size),
            ),
          ),
        ),
        overrides: [
          ...detailOverrides(),
          mediaPlaybackProvider.overrideWith(() => mediaPlayback),
          mediaEngineProvider.overrideWith(_VideoViewMediaEngine.new),
        ],
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('sentence-detail-video-view')),
      findsOneWidget,
    );
    expect(find.textContaining('第 1/10 句 · 2.0'), findsOneWidget);
    expect(find.text('00:01 - 00:03'), findsNothing);
    final timeTop = tester.getTopLeft(find.textContaining('第 1/10 句 · 2.0')).dy;
    final videoBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('media-visual-surface')))
        .dy;
    expect(videoBottom, lessThanOrEqualTo(timeTop));

    await tester.tap(find.byKey(const ValueKey('media-visual-surface')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('media-visual-play-pause-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('media-subtitle-track-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('media-fullscreen-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('media-subtitle-track-button')));
    await tester.pump();
    expect(mediaPlayback.subtitleVisible, isTrue);

    await tester.tap(find.byKey(const ValueKey('media-fullscreen-button')));
    await tester.pump();
    expect(fullscreen, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('media-visual-play-pause-button')),
    );
    await tester.pump();
    expect(rangePlayback.start, const Duration(seconds: 1));
    expect(rangePlayback.end, const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('普通音频讲解页不创建视频画面', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        SentenceDetailScreen(
          args: const SentenceDetailArgs(
            audioItemId: 'audio-item',
            audioName: 'Audio item',
            sentenceText: 'Audio sentence.',
            sentenceIndex: 0,
            startTimeMs: 1000,
            endTimeMs: 3000,
            wordHighlightSource: WordHighlightSource(
              audioItemId: 'audio-item',
              positionStream: Stream<Duration>.empty(),
              currentPosition: Duration.zero,
              playbackStatus: WordHighlightPlaybackStatus.idle,
              playbackStatusStream: Stream<WordHighlightPlaybackStatus>.empty(),
            ),
          ),
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('media-visual-surface')), findsNothing);
    expect(find.textContaining('第 1 句 · 2.0'), findsOneWidget);
    expect(find.text('00:01 - 00:03'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
