import 'dart:async';

import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_waveform_view.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/widgets/guide_flow.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_waveform/just_waveform.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('SubtitleWaveformView', () {
    testWidgets('轻点空白处定位播放头到该时间', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scrubbed = <Duration>[];
      Duration? endedAt;

      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: _sentences(),
            activeSentence: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            onZoomChanged: (_) {},
            onScrub: scrubbed.add,
            onScrubEnd: (position) => endedAt = position,
            onAdjustEnd: () {},
          ),
        ),
      );

      // zoom==1 不滚动：screen-x==content-x。轻点 x=400 → 时间 (400-16)/768*10≈5s。
      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      await tester.tapAt(Offset(rect.left + 400, rect.center.dy));
      await tester.pump();

      expect(endedAt, isNotNull);
      expect(endedAt!.inMilliseconds, closeTo(5000, 60));
      expect(scrubbed, isNotEmpty);
    });

    testWidgets('放大后拖动空白处平移波形（不触发定位）', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scrubbed = <Duration>[];
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(length: 1200),
            extractionProgress: 1,
            duration: const Duration(seconds: 120),
            sentences: _sentences(duration: const Duration(seconds: 120)),
            activeSentence: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 8, // 可滚动（maxOffset>0）
            onZoomChanged: (_) {},
            onScrub: scrubbed.add,
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );

      final before = _viewOffset(tester);
      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      // 向左拖动 200px → 偏移增大约 200（看见更晚内容），且不触发定位。
      final g = await tester.startGesture(
        Offset(rect.left + 500, rect.center.dy),
      );
      await tester.pump();
      await g.moveTo(Offset(rect.left + 300, rect.center.dy));
      await tester.pump();
      await g.up();
      await tester.pump();

      expect(_viewOffset(tester), closeTo(before + 200, 1));
      expect(scrubbed, isEmpty, reason: '拖动是平移，不应触发播放头定位');
    });

    testWidgets('拖动句末词把手（即句子结束边界）上报 onAdjustWord 而非播放头', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scrubbed = <Duration>[];
      final wordAdjusts = <(int, BoundaryEdge, Duration)>[];
      var adjustEnded = false;

      final sentences = _sentences();
      // 当前句 [4s,8s] 两词；末词终点 8s 即句子结束边界（统一为单词边界）。
      const words = _activeWords;
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: sentences,
            activeSentence: sentences[1],
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            wordBoundaries: words,
            onAdjustWord: (i, edge, target) =>
                wordAdjusts.add((i, edge, target)),
            onZoomChanged: (_) {},
            onScrub: scrubbed.add,
            onScrubEnd: (_) {},
            onAdjustEnd: () => adjustEnded = true,
          ),
        ),
      );

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      // zoom==1 不滚动，screen-x == content-x。末词终点 8s：16 + 768*0.8 = 630.4。
      final endX = rect.left + 630;
      final handleY =
          rect.bottom -
          SubtitleWaveformView.axisHeight -
          SubtitleWaveformView.boundaryHandleAxisGap -
          7;
      final gesture = await tester.startGesture(Offset(endX, handleY));
      await tester.pump();
      // 向左拖到 ≈6.3s。
      await gesture.moveTo(Offset(rect.left + 500, handleY));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(scrubbed, isEmpty, reason: '命中边界把手时不应触发播放头拖动');
      expect(wordAdjusts, isNotEmpty);
      // 命中的是末词（globalIndex 3）的结束边界。
      expect(
        wordAdjusts.every((a) => a.$1 == 3 && a.$2 == BoundaryEdge.end),
        isTrue,
      );
      expect(wordAdjusts.last.$3, lessThan(const Duration(seconds: 8)));
      expect(wordAdjusts.last.$3, greaterThan(const Duration(seconds: 4)));
      expect(adjustEnded, isTrue);
    });

    testWidgets('整条竖线（非底部把手处）也可抓取拖动边界', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final wordAdjusts = <(int, BoundaryEdge, Duration)>[];
      final sentences = _sentences();
      const words = _activeWords;
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: sentences,
            activeSentence: sentences[1], // [4s, 8s]
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            wordBoundaries: words,
            onAdjustWord: (i, edge, target) =>
                wordAdjusts.add((i, edge, target)),
            onZoomChanged: (_) {},
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      // 末词终点竖线在 8s（x≈630）。在竖线上半部分（远离底部把手）按下并拖动，
      // 整条竖线都应可抓取该边界。
      final endX = rect.left + 630;
      final gesture = await tester.startGesture(Offset(endX, rect.top + 8));
      await tester.pump();
      await gesture.moveTo(Offset(rect.left + 500, rect.top + 8));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(wordAdjusts, isNotEmpty, reason: '线身任意处都应可抓取');
      expect(wordAdjusts.last.$1, 3);
      expect(wordAdjusts.last.$2, BoundaryEdge.end);
    });

    testWidgets('播放时让播放头红线钉在视口中线（近首尾退化为扫过）', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final waveform = _waveform(length: 1200);
      final sentences = _sentences(duration: const Duration(seconds: 120));

      // viewport=800, padding=16, usableViewport=768；zoom=8 → contentUsable=6144。
      // viewOffset = clamp(timeToContentX(pos) - 400, 0, 5376)；
      // playheadX = clamp(timeToContentX(pos) - viewOffset, 0, 800)。
      Widget build(Duration position) => createTestApp(
        SubtitleWaveformView(
          waveform: waveform,
          extractionProgress: 1,
          duration: const Duration(seconds: 120),
          sentences: sentences,
          activeSentence: sentences.first,
          selectionEpoch: 0,
          playbackPosition: position,
          isPlaying: true,
          zoomScale: 8,
          onZoomChanged: (_) {},
          onScrub: (_) {},
          onScrubEnd: (_) {},
          onAdjustEnd: () {},
        ),
      );

      // 起始：timeToContentX(0)=16 < 中线，偏移被 clamp 到 0，红线在左侧扫过。
      await tester.pumpWidget(build(Duration.zero));
      await tester.pump();
      expect(_viewOffset(tester), 0);
      expect(_playheadX(tester), closeTo(16, 1));

      // 12s：timeToContentX=16+6144*0.1=630.4，偏移=230.4，红线钉在中线 400。
      await tester.pumpWidget(build(const Duration(seconds: 12)));
      await tester.pump();
      expect(_viewOffset(tester), closeTo(230.4, 1));
      expect(_playheadX(tester), closeTo(400, 1));

      // 18s：偏移=537.6，红线仍钉在中线 400（持续居中跟随）。
      await tester.pumpWidget(build(const Duration(seconds: 18)));
      await tester.pump();
      expect(_viewOffset(tester), closeTo(537.6, 1));
      expect(_playheadX(tester), closeTo(400, 1));
    });

    testWidgets('缩放时保持焦点（播放头）在屏幕上的位置不动', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final waveform = _waveform(length: 1200);
      final sentences = _sentences(duration: const Duration(seconds: 120));

      Widget build(double zoom) => createTestApp(
        SubtitleWaveformView(
          waveform: waveform,
          extractionProgress: 1,
          duration: const Duration(seconds: 120),
          sentences: sentences,
          // 不设当前句，隔离选句居中，仅验证缩放焦点保持。
          activeSentence: null,
          selectionEpoch: 0,
          playbackPosition: const Duration(seconds: 12), // 焦点位置
          isPlaying: false,
          zoomScale: zoom,
          onZoomChanged: (_) {},
          onScrub: (_) {},
          onScrubEnd: (_) {},
          onAdjustEnd: () {},
        ),
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      // zoom=1 铺满不滚动，焦点 12s 屏幕 x = 16 + 768*0.1 = 92.8。
      expect(_viewOffset(tester), 0);
      expect(_hasPlayhead(tester), isFalse);

      await tester.pumpWidget(build(8));
      await tester.pump();
      // zoom=8 后内容变宽，焦点 12s 屏幕位置保持 92.8 不变。
      // 偏移 = timeToContentX_8(12s) - 92.8 = 630.4 - 92.8 = 537.6。
      expect(_viewOffset(tester), closeTo(537.6, 1));
      expect(_hasPlayhead(tester), isFalse);
    });

    testWidgets('暂停和轻点定位时不显示播放头红线', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Duration? endedAt;
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: _sentences(),
            activeSentence: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            onZoomChanged: (_) {},
            onScrub: (_) {},
            onScrubEnd: (position) => endedAt = position,
            onAdjustEnd: () {},
          ),
        ),
      );

      expect(_hasPlayhead(tester), isFalse);

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      await tester.tapAt(Offset(rect.left + 400, rect.center.dy));
      await tester.pump();

      expect(endedAt, isNotNull);
      expect(_hasPlayhead(tester), isFalse);
    });

    testWidgets('双指张开会按指距比例放大波形', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final zooms = <double>[];
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: _sentences(),
            activeSentence: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 2,
            onZoomChanged: zooms.add,
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      final cy = rect.center.dy;
      // 两指初始相距 100，张开到 200（比例 2）。
      final p1 = await tester.startGesture(
        Offset(rect.center.dx - 50, cy),
        pointer: 1,
      );
      await tester.pump();
      final p2 = await tester.startGesture(
        Offset(rect.center.dx + 50, cy),
        pointer: 2,
      );
      await tester.pump();
      await p1.moveTo(Offset(rect.center.dx - 100, cy));
      await tester.pump();
      await p2.moveTo(Offset(rect.center.dx + 100, cy));
      await tester.pump();
      await p1.up();
      await p2.up();
      await tester.pump();

      expect(zooms, isNotEmpty);
      // 基准缩放 2 × 指距比例 2 ≈ 4。
      expect(zooms.last, closeTo(4, 0.3));
    });

    testWidgets('传入单词边界时波形层绘制对应词边界', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final sentences = _sentences();
      const words = <WaveformWordBoundary>[
        (
          globalIndex: 0,
          word: WordTimestamp(
            word: 'First',
            startTime: Duration.zero,
            endTime: Duration(seconds: 2),
            confidence: 0,
          ),
          primary: true,
          isSentenceStart: true,
          isSentenceEnd: false,
        ),
        (
          globalIndex: 1,
          word: WordTimestamp(
            word: 'sentence.',
            startTime: Duration(seconds: 2),
            endTime: Duration(seconds: 4),
            confidence: 0,
          ),
          primary: true,
          isSentenceStart: false,
          isSentenceEnd: true,
        ),
      ];

      // 无选中句：不绘制任何词边界。
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: sentences,
            activeSentence: sentences.first,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            onZoomChanged: (_) {},
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );
      expect(_wordBoundaries(tester), isEmpty);

      // 传入单词边界：波形层拿到对应词边界。
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: sentences,
            activeSentence: sentences.first,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            wordBoundaries: words,
            onZoomChanged: (_) {},
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );
      expect(_wordBoundaries(tester).length, 2);
    });

    testWidgets('拖动内部词边界把手上报 onAdjustWord', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final sentences = _sentences();
      final wordAdjusts = <(int, BoundaryEdge, Duration)>[];
      // 句 0 [0,4s] 内三个词，内部边界在 1s、2.5s。
      const words = <WaveformWordBoundary>[
        (
          globalIndex: 0,
          word: WordTimestamp(
            word: 'one',
            startTime: Duration.zero,
            endTime: Duration(seconds: 1),
            confidence: 0,
          ),
          primary: true,
          isSentenceStart: true,
          isSentenceEnd: false,
        ),
        (
          globalIndex: 1,
          word: WordTimestamp(
            word: 'two',
            startTime: Duration(seconds: 1),
            endTime: Duration(milliseconds: 2500),
            confidence: 0,
          ),
          primary: true,
          isSentenceStart: false,
          isSentenceEnd: false,
        ),
        (
          globalIndex: 2,
          word: WordTimestamp(
            word: 'three',
            startTime: Duration(milliseconds: 2500),
            endTime: Duration(seconds: 4),
            confidence: 0,
          ),
          primary: true,
          isSentenceStart: false,
          isSentenceEnd: true,
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: sentences,
            activeSentence: sentences[0],
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            wordBoundaries: words,
            onAdjustWord: (index, edge, target) =>
                wordAdjusts.add((index, edge, target)),
            onZoomChanged: (_) {},
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      // 内部词边界 1s：screenX = 16 + 768*0.1 = 92.8。
      final x = rect.left + 92.8;
      final handleY =
          rect.bottom -
          SubtitleWaveformView.axisHeight -
          SubtitleWaveformView.boundaryHandleAxisGap -
          7;
      final gesture = await tester.startGesture(Offset(x, handleY));
      await tester.pump();
      await gesture.moveTo(Offset(rect.left + 200, handleY)); // 向右拖
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(wordAdjusts, isNotEmpty, reason: '应上报词边界调整');
      // 向右拖选「开始」边界：命中的是某个词的 start。
      expect(wordAdjusts.last.$2, BoundaryEdge.start);
    });

    testWidgets('提取失败时显示失败态和重试，点击重试回调', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var retried = 0;
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: null,
            extractionProgress: 0,
            extractionFailed: true,
            onRetryExtraction: () => retried++,
            duration: const Duration(seconds: 10),
            sentences: _sentences(),
            activeSentence: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            onZoomChanged: (_) {},
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );

      // 失败态不显示「加载中」进度，而显示失败提示 + 重试按钮。
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.text('Waveform unavailable. You can still edit subtitles below.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('触控板捏合（pan-zoom）按 scale 放大波形', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final zooms = <double>[];
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: _sentences(),
            activeSentence: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 2,
            onZoomChanged: zooms.add,
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );

      final center = tester.getCenter(find.byType(SubtitleWaveformView));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(center);
      await tester.pump();
      await gesture.panZoomUpdate(center, scale: 2);
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pump();

      expect(zooms, isNotEmpty);
      // 基准缩放 2 × scale 2 = 4。
      expect(zooms.last, closeTo(4, 0.01));
    });
  });

  group('SubtitleSimpleEditorScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'guide_v1_subtitle_editor_sentence_actions_seen': true,
      });
    });

    testWidgets('进入页面时记录一次字幕编辑器打开事件', (tester) async {
      final analytics = _MockAnalyticsService();
      when(() => analytics.track(any(), any())).thenAnswer((_) async {});
      final audioItem = createTestAudioItem();
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: audioItem),
          overrides: [
            analyticsServiceProvider.overrideWithValue(analytics),
            audioEngineProvider.overrideWith(() => audioEngine),
          ],
        ),
      );
      await tester.pump();

      verify(
        () => analytics.track(Events.subtitleEditorOpened, {
          EventParams.audioId: audioItem.id,
        }),
      ).called(1);

      await tester.pump();
      verifyNoMoreInteractions(analytics);
      audioEngine.disposeController();
    });

    testWidgets('句子行显示完整起止时间和句长', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: [
          Sentence(
            index: 0,
            text: 'Precise sentence.',
            startTime: const Duration(seconds: 1, milliseconds: 230),
            endTime: const Duration(seconds: 3, milliseconds: 450),
          ),
        ],
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('00:01.230 - 00:03.450 · 2.2s'), findsOneWidget);

      audioEngine.disposeController();
    });

    testWidgets('句子编号复用左侧播放区，不增加布局宽度', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (var i = 0; i < 3; i++) {
        final numberFinder = find.byKey(
          ValueKey('subtitle-sentence-number-$i'),
        );
        expect(numberFinder, findsOneWidget);
        expect(tester.widget<Text>(numberFinder).data, '${i + 1}');
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('subtitle-sentence-play-0')))
            .width,
        52,
      );

      audioEngine.disposeController();
    });

    testWidgets('波形下方显示缩放和速度控制', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.text('Zoom'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(
        find.byKey(const ValueKey('subtitle-waveform-zoom-slider')),
        findsOneWidget,
      );
      expect(find.text('Playback Speed'), findsOneWidget);
      expect(find.byTooltip('Playback Speed'), findsOneWidget);

      await tester.tap(find.byTooltip('Playback Speed'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);

      audioEngine.disposeController();
    });

    testWidgets('保存按钮激活时使用更深的主色背景', (tester) async {
      final audioItem = createTestAudioItem();
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: audioItem),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final saveFinder = find.byKey(
        const ValueKey('subtitle-editor-save-button'),
      );
      FilledButton saveButton = tester.widget(saveFinder);
      final theme = Theme.of(tester.element(saveFinder));

      expect(saveButton.onPressed, isNull);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SubtitleSimpleEditorScreen)),
      );
      // 句0 末词 'sentence.' = 全局词 1，前移其终点使字幕进入已修改态。
      container
          .read(subtitleEditorControllerProvider(audioItem).notifier)
          .adjustWord(1, BoundaryEdge.end, const Duration(seconds: 2));
      await tester.pump();

      saveButton = tester.widget(saveFinder);
      final background = saveButton.style?.backgroundColor?.resolve({
        WidgetState.pressed,
      });
      final foreground = saveButton.style?.foregroundColor?.resolve({
        WidgetState.pressed,
      });

      expect(saveButton.onPressed, isNotNull);
      expect(background, theme.colorScheme.primary);
      expect(foreground, theme.colorScheme.onPrimary);

      audioEngine.disposeController();
    });

    testWidgets('波形和首句左右操作区挂载字幕编辑引导', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final descriptions = tester
          .widget<GuideFlowSequenceHost>(find.byType(GuideFlowSequenceHost))
          .flows
          .single
          .steps
          .map((step) => step.description)
          .toList();
      expect(descriptions, [
        'Tap the play button on the left to play this sentence.',
        'Tap the menu on the right to merge or delete this sentence.',
        "Drag the red or green handles on the waveform to adjust the current sentence's start and end time.",
      ]);

      audioEngine.disposeController();
    });

    testWidgets('选中句拆成单词 label，未选中句保持纯文本', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 默认选中第一句 "First sentence." → 两个单词 label。
      expect(
        find.byKey(const ValueKey('subtitle-word-label-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('subtitle-word-label-1')),
        findsOneWidget,
      );
      expect(find.text('First'), findsOneWidget);
      expect(find.text('sentence.'), findsOneWidget);
      // 未选中句仍是整段纯文本。
      expect(find.text('Second sentence.'), findsOneWidget);
      expect(find.text('Third sentence.'), findsOneWidget);

      audioEngine.disposeController();
    });

    testWidgets('点击单词 label 播放该词并在波形显示词边界', (tester) async {
      final audioItem = createTestAudioItem();
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: audioItem),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('subtitle-word-label-1')));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SubtitleSimpleEditorScreen)),
      );
      final notifier = container.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      final st = container.read(subtitleEditorControllerProvider(audioItem));
      expect(st.focusedWordIndex, 1);
      expect(audioEngine.playRangeOnceCallCount, 1);
      // 关键回归（bug1）：点第 2 个 label 必须播放第 2 个词的区间，
      // 而非因 label↔词错位 / 越界钳制播放到别的词。
      final words = notifier.wordsOfSelectedSentence;
      expect(audioEngine.lastRangeStart, words[1].startTime);
      expect(audioEngine.lastRangeEnd, words[1].endTime);
      // 选中句即展示其全部单词边界（具体绘制在 SubtitleWaveformView 用例验证）。
      expect(notifier.wordBoundariesForWaveform, isNotEmpty);

      audioEngine.completePlayback();
      await tester.pump();
      audioEngine.disposeController();
    });

    testWidgets('点击播放句子后切换下一句会更新行播放态', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-0')));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(audioEngine.lastPlayedSentence?.index, 0);

      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(audioEngine.lastPlayedSentence?.index, 1);
      expect(audioEngine.stopPlaybackCallCount, 1);

      audioEngine.completePlayback();
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      audioEngine.disposeController();
    });
  });
}

/// 读取波形层 painter 的 viewOffset（视图偏移真相源）。
double _viewOffset(WidgetTester tester) {
  for (final cp in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final p = cp.painter;
    if (p != null && p.runtimeType.toString() == '_WaveformLayerPainter') {
      return (p as dynamic).viewOffset as double;
    }
  }
  fail('找不到波形层 painter');
}

/// 读取播放头红线 overlay 当前的视口 x 坐标。
double _playheadX(WidgetTester tester) {
  for (final cp in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final p = cp.painter;
    if (p != null && p.runtimeType.toString() == '_PlayheadLayerPainter') {
      return (p as dynamic).x as double;
    }
  }
  fail('找不到播放头 overlay');
}

bool _hasPlayhead(WidgetTester tester) {
  for (final cp in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final p = cp.painter;
    if (p != null && p.runtimeType.toString() == '_PlayheadLayerPainter') {
      return true;
    }
  }
  return false;
}

/// 读取波形层 painter 当前绘制的词边界列表（点中词 + 左右邻词）。
List<dynamic> _wordBoundaries(WidgetTester tester) {
  for (final cp in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final p = cp.painter;
    if (p != null && p.runtimeType.toString() == '_WaveformLayerPainter') {
      return (p as dynamic).wordBoundaries as List<dynamic>;
    }
  }
  fail('找不到波形层 painter');
}

/// 当前句（[_sentences] 的句 1，区间 [4s,8s]）的两词边界：
/// 全局词下标 2/3，末词终点 8s 即句子结束边界。均为主样式。
const List<WaveformWordBoundary> _activeWords = [
  (
    globalIndex: 2,
    word: WordTimestamp(
      word: 'aa',
      startTime: Duration(seconds: 4),
      endTime: Duration(seconds: 6),
      confidence: 0,
    ),
    primary: true,
    isSentenceStart: true,
    isSentenceEnd: false,
  ),
  (
    globalIndex: 3,
    word: WordTimestamp(
      word: 'bb',
      startTime: Duration(seconds: 6),
      endTime: Duration(seconds: 8),
      confidence: 0,
    ),
    primary: true,
    isSentenceStart: false,
    isSentenceEnd: true,
  ),
];

List<Sentence> _sentences({Duration duration = const Duration(seconds: 10)}) {
  return [
    Sentence(
      index: 0,
      text: 'First sentence.',
      startTime: Duration.zero,
      endTime: duration.inSeconds >= 4 ? const Duration(seconds: 4) : duration,
    ),
    Sentence(
      index: 1,
      text: 'Second sentence.',
      startTime: const Duration(seconds: 4),
      endTime: duration.inSeconds >= 8 ? const Duration(seconds: 8) : duration,
    ),
    Sentence(
      index: 2,
      text: 'Third sentence.',
      startTime: const Duration(seconds: 8),
      endTime: duration,
    ),
  ];
}

Waveform _waveform({int length = 100}) {
  return Waveform(
    version: 1,
    flags: 0,
    sampleRate: 1000,
    samplesPerPixel: 100,
    length: length,
    data: [
      for (var i = 0; i < length; i++) ...[-9000 - i * 10, 9000 + i * 10],
    ],
  );
}

class _ScreenTestAudioEngine extends AudioEngine {
  _ScreenTestAudioEngine({required this.duration, required this.sentences});

  final Duration duration;
  final List<Sentence> sentences;
  final _positionController = StreamController<Duration>.broadcast();
  final _playbackCompleters = <Completer<void>>[];
  int _sessionId = 0;
  int stopPlaybackCallCount = 0;
  Sentence? lastPlayedSentence;
  int playRangeOnceCallCount = 0;
  Duration? lastRangeStart;
  Duration? lastRangeEnd;

  @override
  AudioEngineState build() => AudioEngineState(totalDuration: duration);

  @override
  Stream<Duration> get absolutePositionStream => _positionController.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<Duration?> loadAudio(
    AudioItem item,
    double speed, {
    String? subtitle,
  }) async => duration;

  @override
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async => sentences;

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCallCount += 1;
    completePlayback();
  }

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    lastPlayedSentence = sentence;
    final completer = Completer<void>();
    _playbackCompleters.add(completer);
    await completer.future;
  }

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    playRangeOnceCallCount += 1;
    lastRangeStart = start;
    lastRangeEnd = end;
    final completer = Completer<void>();
    _playbackCompleters.add(completer);
    await completer.future;
  }

  @override
  Future<void> clearClip() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> seekToAbsolute(Duration absolute) async {}

  void completePlayback() {
    for (final completer in _playbackCompleters) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _playbackCompleters.clear();
  }

  void disposeController() {
    completePlayback();
    unawaited(_positionController.close());
  }
}
