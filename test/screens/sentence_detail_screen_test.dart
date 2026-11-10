import 'dart:async';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/word_highlight_binding.dart';
import 'package:echo_loop/models/sense_group_range_playback.dart';
import 'package:echo_loop/models/media_playback_state.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/media_playback/media_playback_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/screens/sentence_detail_screen.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/bookmark_toggle_row.dart';
import 'package:echo_loop/widgets/practice/sentence_explanation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart'
    show PlaybackNavButton, PlaybackToggleIcon, playbackCenterIconKey;
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/misc.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _MockSentenceAiApiClient extends Mock implements SentenceAiApiClient {}

class _RecordingRangePlayback
    implements
        SenseGroupRangePlayback,
        ResumableSentenceRangePlayback,
        LiveSpeedRangePlayback {
  Duration? start;
  final liveSpeeds = <double>[];
  Duration? end;
  @override
  Duration currentPosition = Duration.zero;
  final playStarts = <Duration>[];
  final resumedPositions = <Duration>[];
  int cancelCalls = 0;
  bool holdNextPlay = false;
  Completer<void>? _activePlay;

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    liveSpeeds.add(speed);
  }

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

/// 字幕读取可控失败的 DAO：[fail] 为 true 时读取抛错，模拟数据库异常。
class _FlakyAudioItemDao extends FakeAudioItemDao {
  bool fail = true;

  @override
  Future<String?> getTranscriptSrt(String audioItemId) async {
    if (fail) throw StateError('transcript read failed');
    return super.getTranscriptSrt(audioItemId);
  }
}

class _VideoViewMediaEngine extends MediaEngine {
  @override
  Widget buildVideoView({required Size viewportSize}) {
    return const SizedBox(key: ValueKey('sentence-detail-video-view'));
  }
}

/// 整篇字幕文本：第 0 句为讲解入口，其余为占位句，每句 3 秒。
List<String> _transcriptTexts(String entryText, {int count = 10}) => [
  entryText,
  for (var i = 1; i < count; i++) 'Sentence $i.',
];

/// 生成整篇 SRT；第 i 句时间为 [3i+1, 3i+3] 秒，第 0 句与测试入口的 1000–3000ms 一致。
String _transcriptSrt(List<String> texts) {
  String two(int value) => value.toString().padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < texts.length; i++) {
    final start = i * 3 + 1;
    buffer
      ..writeln(i + 1)
      ..writeln('00:00:${two(start)},000 --> 00:00:${two(start + 2)},000')
      ..writeln(texts[i])
      ..writeln();
  }
  return buffer.toString();
}

SentenceDetailScreen _detailScreen({
  required String sentenceText,
  String audioItemId = 'media-item',
  int sentenceIndex = 0,
  int startTimeMs = 1000,
  int endTimeMs = 3000,
  SenseGroupRangePlayback Function(double Function() playbackSpeed)?
  rangePlaybackBuilder,
}) {
  return SentenceDetailScreen(
    args: SentenceDetailArgs(
      audioItemId: audioItemId,
      audioName: 'Media item',
      sentenceText: sentenceText,
      sentenceIndex: sentenceIndex,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
      rangePlaybackBuilder: rangePlaybackBuilder,
      wordHighlightSource: WordHighlightSource(
        audioItemId: audioItemId,
        positionStream: const Stream<Duration>.empty(),
        currentPosition: Duration.zero,
        playbackStatus: WordHighlightPlaybackStatus.idle,
        playbackStatusStream: const Stream<WordHighlightPlaybackStatus>.empty(),
      ),
    ),
  );
}

void main() {
  /// [entryText] 为字幕第 0 句；页面入口句需与之一致才会按序号定位。
  List<Override> detailOverrides({
    String entryText = 'A sentence for media playback.',
    bool showPlaybackSpeedButton = false,
    FakeAudioItemDao? audioItemDao,
  }) {
    audioItemDao ??= FakeAudioItemDao();
    final srt = _transcriptSrt(_transcriptTexts(entryText));
    for (final audioItemId in const ['media-item', 'audio-item']) {
      audioItemDao.transcriptSrtStore[audioItemId] = srt;
    }
    return [
      audioItemDaoProvider.overrideWithValue(audioItemDao),
      bookmarkDaoProvider.overrideWithValue(TestBookmarkDao()),
      sentenceAiNotifierProvider.overrideWithValue(
        SentenceAiNotifier(
          cacheDao: createStubbedMockCacheDao(),
          apiClient: _MockSentenceAiApiClient(),
        ),
      ),
      ...learningSettingsOverrides(
        showPlaybackSpeedButton: showPlaybackSpeedButton,
      ),
    ];
  }

  testWidgets('媒体讲解页将句子与意群播放委托给注入的媒体会话', (tester) async {
    final rangePlayback = _RecordingRangePlayback();
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(
          sentenceText: 'A sentence for media playback.',
          rangePlaybackBuilder: (_) => rangePlayback,
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

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();

    expect(rangePlayback.start, const Duration(seconds: 1));
    expect(rangePlayback.end, const Duration(seconds: 3));

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
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
        _detailScreen(
          sentenceText: 'A sentence for media playback.',
          rangePlaybackBuilder: (_) => rangePlayback,
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(rangePlayback.start, const Duration(seconds: 1));

    rangePlayback.currentPosition = const Duration(milliseconds: 1840);
    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.pause)));
    await tester.pump();
    expect(rangePlayback.cancelCalls, 1);

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(rangePlayback.resumedPositions, [
      const Duration(milliseconds: 1840),
    ]);
    expect(rangePlayback.start, const Duration(milliseconds: 1840));
    expect(rangePlayback.end, const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('开启暂停后从句首继续时，句子讲解页暂停后从句首重新播放', (tester) async {
    final rangePlayback = _RecordingRangePlayback()..holdNextPlay = true;
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(
          sentenceText: 'A sentence for media playback.',
          rangePlaybackBuilder: (_) => rangePlayback,
        ),
        overrides: [
          ...detailOverrides(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(
              const AppSettingsState(resumeFromSentenceStartEnabled: true),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();

    rangePlayback.currentPosition = const Duration(milliseconds: 1840);
    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.pause)));
    await tester.pump();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(rangePlayback.start, const Duration(seconds: 1));
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
        overrides: detailOverrides(entryText: 'A sentence for audio playback.'),
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
        _detailScreen(sentenceText: 'A sentence for alignment.'),
        overrides: detailOverrides(entryText: 'A sentence for alignment.'),
      ),
    );
    await tester.pump();

    final progress = find.text('第 1/10 句');
    final annotation = find.byType(SentenceExplanationView);
    expect(progress, findsOneWidget);
    expect(annotation, findsOneWidget);
    expect(tester.getRect(annotation).left, closeTo(AppSpacing.m, 1));
    expect(tester.getRect(progress).left, closeTo(AppSpacing.m, 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('详情页收藏行贴齐信息区右侧内边距', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(
          audioItemId: 'audio-item',
          sentenceText: 'A sentence for alignment.',
        ),
        overrides: detailOverrides(entryText: 'A sentence for alignment.'),
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
            startTimeMs: 1000,
            endTimeMs: 3000,
            rangePlaybackBuilder: (_) => rangePlayback,
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
        overrides: dedupeOverrides([
          ...detailOverrides(),
          mediaPlaybackProvider.overrideWith(() => mediaPlayback),
          mediaEngineProvider.overrideWith(_VideoViewMediaEngine.new),
        ]),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('sentence-detail-video-view')),
      findsOneWidget,
    );
    expect(find.text('第 1/10 句'), findsOneWidget);
    expect(find.text('00:01 - 00:03'), findsNothing);
    final timeTop = tester.getTopLeft(find.text('第 1/10 句')).dy;
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
        _detailScreen(
          audioItemId: 'audio-item',
          sentenceText: 'Audio sentence.',
        ),
        overrides: detailOverrides(entryText: 'Audio sentence.'),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('media-visual-surface')), findsNothing);
    expect(find.text('第 1/10 句'), findsOneWidget);
    expect(find.text('00:01 - 00:03'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('讲解页点下一句切到相邻句并停止当前播放', (tester) async {
    final rangePlayback = _RecordingRangePlayback()..holdNextPlay = true;
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(
          sentenceText: 'A sentence for media playback.',
          rangePlaybackBuilder: (_) => rangePlayback,
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(rangePlayback.cancelCalls, 0);

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pumpAndSettle();

    expect(find.text('第 2/10 句'), findsOneWidget);
    // 切句会取消当前播放；旧句讲解视图被回收时也会再取消一次，因此只断言至少一次
    expect(rangePlayback.cancelCalls, greaterThanOrEqualTo(1));
    // 切句后不自动播放：仍显示播放图标，且没有新的区间开始
    expect(
      find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)),
      findsOneWidget,
    );
    expect(rangePlayback.playStarts, [const Duration(seconds: 1)]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('讲解页首句禁用上一句，末句禁用下一句', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(sentenceText: 'A sentence for media playback.'),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();
    expect(tester.widget<PlaybackNavButton>(find.byType(PlaybackNavButton).first).enabled, isFalse);
    expect(tester.widget<PlaybackNavButton>(find.byType(PlaybackNavButton).last).enabled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(
          sentenceIndex: 9,
          sentenceText: 'Sentence 9.',
          startTimeMs: 28000,
          endTimeMs: 30000,
        ),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();
    expect(tester.widget<PlaybackNavButton>(find.byType(PlaybackNavButton).first).enabled, isTrue);
    expect(tester.widget<PlaybackNavButton>(find.byType(PlaybackNavButton).last).enabled, isFalse);
    expect(find.text('第 10/10 句'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('讲解页进度条松手后跳到目标句', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(sentenceText: 'A sentence for media playback.'),
        overrides: detailOverrides(),
      ),
    );
    await tester.pump();

    // 滑块取值为 1 起算的句序，松手回调与进度条一致
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(4);
    await tester.pumpAndSettle();

    expect(find.text('第 4/10 句'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('入口句不在字幕中时退化为单句讲解', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(sentenceText: 'A sentence for media playback.'),
        overrides: detailOverrides(entryText: 'Edited subtitle.'),
      ),
    );
    await tester.pump();

    expect(find.text('第 1/1 句'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(tester.widget<PlaybackNavButton>(find.byType(PlaybackNavButton).first).enabled, isFalse);
    expect(tester.widget<PlaybackNavButton>(find.byType(PlaybackNavButton).last).enabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('讲解页速度默认 1.0x，开启设置后显示速度按钮并应用到本页播放', (tester) async {
    double Function()? speedOfPage;
    final rangePlayback = _RecordingRangePlayback();
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(
          sentenceText: 'A sentence for media playback.',
          rangePlaybackBuilder: (playbackSpeed) {
            speedOfPage = playbackSpeed;
            return rangePlayback;
          },
        ),
        overrides: detailOverrides(showPlaybackSpeedButton: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(speedOfPage!(), 1.0);
    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.2x'));
    await tester.pumpAndSettle();

    expect(speedOfPage!(), 1.2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('讲解页播放中调整速度立即作用于当前句', (tester) async {
    final rangePlayback = _RecordingRangePlayback()..holdNextPlay = true;
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(
          sentenceText: 'A sentence for media playback.',
          rangePlaybackBuilder: (_) => rangePlayback,
        ),
        overrides: detailOverrides(showPlaybackSpeedButton: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(rangePlayback.liveSpeeds, isEmpty);

    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.2x'));
    await tester.pumpAndSettle();

    expect(rangePlayback.liveSpeeds, [1.2]);
    // 只改速度，仍处于播放中
    expect(
      find.byKey(playbackCenterIconKey(PlaybackToggleIcon.pause)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('字幕读取失败时展示错误并可重试', (tester) async {
    final dao = _FlakyAudioItemDao();
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(sentenceText: 'A sentence for media playback.'),
        overrides: detailOverrides(audioItemDao: dao),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SentenceDetailScreen)),
    )!;
    expect(find.text(l10n.sentenceDetailLoadFailed), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    dao.fail = false;
    await tester.tap(find.text(l10n.sentenceDetailRetry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.sentenceDetailLoadFailed), findsNothing);
    expect(find.text('第 1/10 句'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('默认不显示讲解页速度按钮', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        _detailScreen(sentenceText: 'A sentence for media playback.'),
        overrides: detailOverrides(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.0x'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
