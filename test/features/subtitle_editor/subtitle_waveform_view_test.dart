import 'dart:async';

import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_waveform_view.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_waveform/just_waveform.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

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
            selectedIndex: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            onZoomChanged: (_) {},
            onScrub: scrubbed.add,
            onScrubEnd: (position) => endedAt = position,
            onAdjustBoundary: (_, _, _) {},
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
            selectedIndex: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 8, // 可滚动（maxOffset>0）
            onZoomChanged: (_) {},
            onScrub: scrubbed.add,
            onScrubEnd: (_) {},
            onAdjustBoundary: (_, _, _) {},
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

    testWidgets('在当前句结束边界把手附近按下拖动会上报边界调整而非播放头', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scrubbed = <Duration>[];
      final adjusts = <(int, BoundaryEdge, Duration)>[];
      var adjustEnded = false;

      final sentences = _sentences();
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: sentences,
            activeSentence: sentences[1], // [4s, 8s]
            selectedIndex: 1,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            onZoomChanged: (_) {},
            onScrub: scrubbed.add,
            onScrubEnd: (_) {},
            onAdjustBoundary: (index, edge, target) =>
                adjusts.add((index, edge, target)),
            onAdjustEnd: () => adjustEnded = true,
          ),
        ),
      );

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      // zoom==1 不滚动，screen-x == content-x。结束边界 8s：16 + 768*0.8 = 630.4。
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
      expect(adjusts, isNotEmpty);
      // 命中的是当前句（index 1）的结束边界。
      expect(
        adjusts.every((a) => a.$1 == 1 && a.$2 == BoundaryEdge.end),
        isTrue,
      );
      expect(adjusts.last.$3, lessThan(const Duration(seconds: 8)));
      expect(adjusts.last.$3, greaterThan(const Duration(seconds: 4)));
      expect(adjustEnded, isTrue);
    });

    testWidgets('顶部边界线不可误触发把手拖动', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adjusts = <(int, BoundaryEdge, Duration)>[];
      final sentences = _sentences();
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 10),
            sentences: sentences,
            activeSentence: sentences[1], // [4s, 8s]
            selectedIndex: 1,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 1,
            onZoomChanged: (_) {},
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustBoundary: (index, edge, target) =>
                adjusts.add((index, edge, target)),
            onAdjustEnd: () {},
          ),
        ),
      );

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      final endX = rect.left + 630;
      final gesture = await tester.startGesture(Offset(endX, rect.top + 8));
      await tester.pump();
      await gesture.moveTo(Offset(rect.left + 500, rect.top + 8));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(adjusts, isEmpty);
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
          selectedIndex: 0,
          selectionEpoch: 0,
          playbackPosition: position,
          isPlaying: true,
          zoomScale: 8,
          onZoomChanged: (_) {},
          onScrub: (_) {},
          onScrubEnd: (_) {},
          onAdjustBoundary: (_, _, _) {},
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
          selectedIndex: null,
          selectionEpoch: 0,
          playbackPosition: const Duration(seconds: 12), // 焦点位置
          isPlaying: false,
          zoomScale: zoom,
          onZoomChanged: (_) {},
          onScrub: (_) {},
          onScrubEnd: (_) {},
          onAdjustBoundary: (_, _, _) {},
          onAdjustEnd: () {},
        ),
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      // zoom=1 铺满不滚动，焦点 12s 屏幕 x = 16 + 768*0.1 = 92.8。
      expect(_viewOffset(tester), 0);
      expect(_playheadX(tester), closeTo(92.8, 1));

      await tester.pumpWidget(build(8));
      await tester.pump();
      // zoom=8 后内容变宽，焦点 12s 屏幕位置保持 92.8 不变。
      // 偏移 = timeToContentX_8(12s) - 92.8 = 630.4 - 92.8 = 537.6。
      expect(_viewOffset(tester), closeTo(537.6, 1));
      expect(_playheadX(tester), closeTo(92.8, 1));
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
            selectedIndex: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 2,
            onZoomChanged: zooms.add,
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustBoundary: (_, _, _) {},
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
            selectedIndex: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 2,
            onZoomChanged: zooms.add,
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustBoundary: (_, _, _) {},
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
    testWidgets('波形下方显示播放、缩放和速度控制', (tester) async {
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

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(
        find.byKey(const ValueKey('subtitle-waveform-zoom-slider')),
        findsOneWidget,
      );
      expect(find.byTooltip('Playback Speed'), findsOneWidget);

      await tester.tap(find.byTooltip('Playback Speed'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);

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

      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(audioEngine.lastPlayedSentence?.index, 0);

      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
      await tester.pump();

      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(audioEngine.lastPlayedSentence?.index, 1);
      expect(audioEngine.stopPlaybackCallCount, 1);

      audioEngine.completePlayback();
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
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
  Future<Duration?> loadAudio(AudioItem item, double speed) async => duration;

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
