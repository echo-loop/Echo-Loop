import 'dart:math' as math;
import 'dart:typed_data';

import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_waveform_view.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/utils/waveform_peaks.dart';
import 'package:echo_loop/widgets/guide_flow.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';
import 'subtitle_editor_test_support.dart';

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
      // 末词终点竖线在 8s（x≈630）。在竖线上端（顶部文字行之下、远离底部把手）
      // 按下并拖动，整条竖线都应可抓取该边界。
      final endX = rect.left + 630;
      final gesture = await tester.startGesture(Offset(endX, rect.top + 24));
      await tester.pump();
      await gesture.moveTo(Offset(rect.left + 500, rect.top + 24));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(wordAdjusts, isNotEmpty, reason: '线身任意处都应可抓取');
      expect(wordAdjusts.last.$1, 3);
      expect(wordAdjusts.last.$2, BoundaryEdge.end);
    });

    group('顶部单词块与播放头手柄', () {
      // 未缩放：x = 16 + t/10s * 768。句 1 [4s,8s] 的词 aa [4,6]、bb [6,8]，
      // 播放头停在句首 4s（x≈323），与句首边界重合。
      const playheadX = 16 + 768 * .4;
      const laneY = 9.0;
      const bodyY = 50.0;

      late List<Duration> scrubs;
      late List<Duration> scrubEnds;
      late List<int> wordTaps;
      late List<(int, BoundaryEdge, Duration)> adjusts;

      Future<Rect> pumpView(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 240));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        scrubs = [];
        scrubEnds = [];
        wordTaps = [];
        adjusts = [];
        final sentences = _sentences();
        await tester.pumpWidget(
          createTestApp(
            SubtitleWaveformView(
              waveform: _waveform(),
              extractionProgress: 1,
              duration: const Duration(seconds: 10),
              sentences: sentences,
              activeSentence: sentences[1],
              selectionEpoch: 0,
              playbackPosition: const Duration(seconds: 4),
              isPlaying: false,
              zoomScale: 1,
              wordBoundaries: _activeWords,
              onAdjustWord: (i, edge, target) => adjusts.add((i, edge, target)),
              onZoomChanged: (_) {},
              onScrub: scrubs.add,
              onScrubEnd: scrubEnds.add,
              onWordTap: wordTaps.add,
            ),
          ),
        );
        return tester.getRect(find.byType(SubtitleWaveformView));
      }

      testWidgets('轻点单词块试听该词，不定位播放头', (tester) async {
        final rect = await pumpView(tester);
        await tester.tapAt(rect.topLeft + const Offset(16 + 768 * .7, laneY));
        await tester.pump();

        expect(wordTaps, [1]);
        expect(scrubEnds, isEmpty);
      });

      testWidgets('在单词块之外的文字行轻点仍定位播放头', (tester) async {
        final rect = await pumpView(tester);
        await tester.tapAt(rect.topLeft + const Offset(16 + 768 * .9, laneY));
        await tester.pump();

        expect(wordTaps, isEmpty);
        expect(scrubEnds.single.inMilliseconds, closeTo(9000, 60));
      });

      testWidgets('手柄与句首边界重合：从手柄拖动播放头，不动边界', (tester) async {
        final rect = await pumpView(tester);
        final gesture = await tester.startGesture(
          rect.topLeft + const Offset(playheadX, laneY),
        );
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          await gesture.moveBy(const Offset(-10, 0));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();

        expect(adjusts, isEmpty);
        expect(wordTaps, isEmpty);
        expect(scrubs, isNotEmpty);
        expect(scrubEnds.single, lessThan(const Duration(seconds: 4)));
      });

      testWidgets('手柄与句首边界重合：从线身拖动的是边界', (tester) async {
        final rect = await pumpView(tester);
        final gesture = await tester.startGesture(
          rect.topLeft + const Offset(playheadX, bodyY),
        );
        await tester.pump();
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(scrubs, isEmpty);
        expect(adjusts, isNotEmpty);
        expect(adjusts.last.$1, 2);
        expect(adjusts.last.$2, BoundaryEdge.start);
      });

      testWidgets('轻点压在单词块上的手柄（不拖动）= 试听该词', (tester) async {
        final rect = await pumpView(tester);
        await tester.tapAt(rect.topLeft + const Offset(playheadX + 2, laneY));
        await tester.pump();

        expect(wordTaps, [0]);
        expect(scrubs, isEmpty);
        expect(scrubEnds, isEmpty);
      });
    });

    group('整词拖动', () {
      // 未缩放：x = 16 + t/10s * 768。词 aa [4,6]（x 323.2~476.8），线身 y=50。
      const bodyY = 50.0;
      const aaMidX = 16 + 768 * .5; // 5s

      late List<Duration> scrubEnds;
      late List<int> wordTaps;
      late List<(int, Duration)> moves;
      late List<(int, BoundaryEdge, Duration)> adjusts;
      late int adjustEnds;

      Future<Rect> pumpView(
        WidgetTester tester, {
        List<WaveformWordBoundary> words = _activeWords,
      }) async {
        await tester.binding.setSurfaceSize(const Size(800, 240));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        scrubEnds = [];
        wordTaps = [];
        moves = [];
        adjusts = [];
        adjustEnds = 0;
        final sentences = _sentences();
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
              onAdjustWord: (i, edge, target) => adjusts.add((i, edge, target)),
              onMoveWord: (i, target) => moves.add((i, target)),
              onAdjustEnd: () => adjustEnds++,
              onZoomChanged: (_) {},
              onScrub: (_) {},
              onScrubEnd: scrubEnds.add,
              onWordTap: wordTaps.add,
            ),
          ),
        );
        return tester.getRect(find.byType(SubtitleWaveformView));
      }

      MouseCursor cursorOf(WidgetTester tester) => tester
          .widget<MouseRegion>(
            find
                .descendant(
                  of: find.byType(SubtitleWaveformView),
                  matching: find.byType(MouseRegion),
                )
                .first,
          )
          .cursor;

      testWidgets('鼠标悬停在词区间显示抓取手形，边界上仍是左右箭头', (tester) async {
        final rect = await pumpView(tester);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: rect.topLeft + const Offset(700, 50));
        await mouse.moveTo(rect.topLeft + const Offset(aaMidX, bodyY));
        await tester.pump();
        expect(cursorOf(tester), SystemMouseCursors.grab);

        await mouse.moveTo(rect.topLeft + const Offset(16 + 768 * .6, bodyY));
        await tester.pump();
        expect(cursorOf(tester), SystemMouseCursors.resizeLeftRight);
      });

      testWidgets('鼠标按住词区间拖动：整体移动该词，不定位播放头', (tester) async {
        final rect = await pumpView(tester);
        final mouse = await tester.startGesture(
          rect.topLeft + const Offset(aaMidX, bodyY),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        // 向左 76.8px = 1s：词起点 4s → 3s。
        await mouse.moveBy(const Offset(-38.4, 0));
        await tester.pump();
        expect(cursorOf(tester), SystemMouseCursors.grabbing);
        await mouse.moveBy(const Offset(-38.4, 0));
        await tester.pump();
        await mouse.up();
        await tester.pump();

        expect(adjusts, isEmpty);
        expect(scrubEnds, isEmpty);
        expect(moves.last.$1, 2);
        expect(moves.last.$2.inMilliseconds, closeTo(3000, 20));
        expect(adjustEnds, 1);
      });

      for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
        testWidgets('${kind.name} 轻点词区间试听该词，不定位播放头（同点单词块）', (tester) async {
          final rect = await pumpView(tester);
          await tester.tapAt(
            rect.topLeft + const Offset(aaMidX, bodyY),
            kind: kind,
          );
          await tester.pump();

          expect(wordTaps, [0]);
          expect(moves, isEmpty);
          expect(scrubEnds, isEmpty);
        });
      }

      testWidgets('轻点相邻句的词区间仍定位播放头（单词块只对应当前句）', (tester) async {
        final rect = await pumpView(
          tester,
          words: [
            ..._activeWords,
            (
              globalIndex: 4,
              word: const WordTimestamp(
                word: 'cc',
                startTime: Duration(seconds: 8),
                endTime: Duration(seconds: 9),
              ),
              primary: false,
              isSentenceStart: true,
              isSentenceEnd: false,
            ),
          ],
        );
        // 相邻句（句 2）的词 cc [8,9]。
        await tester.tapAt(rect.topLeft + const Offset(16 + 768 * .85, bodyY));
        await tester.pump();

        expect(wordTaps, isEmpty);
        expect(scrubEnds.single.inMilliseconds, closeTo(8500, 20));
      });

      testWidgets('长按顶部单词块后拖动：与长按词区间一样整体移动该词', (tester) async {
        final rect = await pumpView(tester);
        final hold = await tester.startGesture(
          rect.topLeft + const Offset(aaMidX, 9),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await hold.moveBy(const Offset(76.8, 0));
        await tester.pump();
        await hold.up();
        await tester.pump();

        expect(moves.last.$1, 2);
        expect(moves.last.$2.inMilliseconds, closeTo(5000, 20));
        expect(wordTaps, isEmpty);
        expect(scrubEnds, isEmpty);
        expect(adjustEnds, 1);
      });

      testWidgets('触摸直接拖动词区间不移动词；长按后拖动才整体移动', (tester) async {
        final rect = await pumpView(tester);
        final swipe = await tester.startGesture(
          rect.topLeft + const Offset(aaMidX, bodyY),
        );
        await tester.pump();
        await swipe.moveBy(const Offset(-40, 0));
        await tester.pump(kLongPressTimeout);
        await swipe.up();
        await tester.pump();
        expect(moves, isEmpty, reason: '未长按的拖动是平移波形');

        final hold = await tester.startGesture(
          rect.topLeft + const Offset(aaMidX, bodyY),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await hold.moveBy(const Offset(76.8, 0));
        await tester.pump();
        await hold.up();
        await tester.pump();

        expect(moves.last.$1, 2);
        expect(moves.last.$2.inMilliseconds, closeTo(5000, 20));
        expect(scrubEnds, isEmpty);
        expect(adjustEnds, 1);
      });
    });

    testWidgets('试听单词（不跟随）时视图不滚动，播放头出视口才居中', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Widget view(Duration position) => createTestApp(
        SubtitleWaveformView(
          waveform: _waveform(),
          extractionProgress: 1,
          duration: const Duration(seconds: 10),
          sentences: _sentences(),
          activeSentence: null,
          selectionEpoch: 0,
          playbackPosition: position,
          isPlaying: true,
          followsPlayhead: false,
          zoomScale: 4,
          onZoomChanged: (_) {},
          onScrub: (_) {},
          onScrubEnd: (_) {},
        ),
      );

      // zoom=4：可用内容宽 768×4，x = 16 + t/10s * 3072。2s 在 x≈630，仍在视口内。
      await tester.pumpWidget(view(const Duration(seconds: 2)));
      await tester.pump();
      expect(_viewOffset(tester), 0);

      // 3s 在 x≈938，已出视口：居中到 938 - 400。
      await tester.pumpWidget(view(const Duration(seconds: 3)));
      await tester.pump();
      expect(_viewOffset(tester), closeTo(537.6, 1));
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
        // 同一用例内多次 pumpWidget 时保留缩放焦点对应的偏移状态。
        key: const ValueKey('subtitle-waveform-zoom-focus'),
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      // zoom=1 铺满不滚动，焦点 12s 屏幕 x = 16 + 768*0.1 = 92.8。
      expect(_viewOffset(tester), 0);
      expect(_hasPlayhead(tester), isTrue);

      await tester.pumpWidget(build(8));
      await tester.pump();
      // zoom=8 后内容变宽，焦点 12s 屏幕位置保持 92.8 不变。
      // 偏移 = timeToContentX_8(12s) - 92.8 = 630.4 - 92.8 = 537.6。
      expect(_viewOffset(tester), closeTo(537.6, 1));
      expect(_hasPlayhead(tester), isTrue);
    });

    testWidgets('暂停时也显示播放头；轻点空白处定位', (tester) async {
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

      expect(_hasPlayhead(tester), isTrue);

      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      await tester.tapAt(Offset(rect.left + 400, rect.center.dy));
      await tester.pump();

      expect(endedAt, isNotNull);
      expect(_hasPlayhead(tester), isTrue);
    });

    testWidgets('拖动播放头连续定位，松手时结束定位', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scrubs = <Duration>[];
      Duration? endedAt;
      var position = const Duration(seconds: 5);
      late StateSetter setOuter;
      await tester.pumpWidget(
        createTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return SubtitleWaveformView(
                waveform: _waveform(),
                extractionProgress: 1,
                duration: const Duration(seconds: 10),
                sentences: _sentences(),
                activeSentence: null,
                selectionEpoch: 0,
                playbackPosition: position,
                isPlaying: false,
                zoomScale: 1,
                onZoomChanged: (_) {},
                onScrub: (t) {
                  scrubs.add(t);
                  setOuter(() => position = t);
                },
                onScrubEnd: (t) => endedAt = t,
              );
            },
          ),
        ),
      );
      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      // 未缩放时内容区 = 视口 - 左右各 16px 内边距，5s 在正中。
      final playheadX = rect.left + 16 + (rect.width - 32) / 2;

      final gesture = await tester.startGesture(
        Offset(playheadX, rect.top + 50),
      );
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();

      expect(scrubs.length, greaterThanOrEqualTo(5));
      expect(scrubs.last, lessThan(const Duration(seconds: 5)));
      expect(endedAt, scrubs.last);
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

    testWidgets('无音频时显示没有找到音频，不显示失败态和重试', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: null,
            extractionProgress: 0,
            extractionFailed: false,
            audioMissing: true,
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

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.text('No audio found. You can still edit subtitles below.'),
        findsOneWidget,
      );
      expect(
        find.text('Waveform unavailable. You can still edit subtitles below.'),
        findsNothing,
      );
      expect(find.text('Retry'), findsNothing);
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

  group('SubtitleWaveformView 双指 / 滚轮平移', () {
    Future<List<double>> pumpZoomed(
      WidgetTester tester, {
      bool isPlaying = false,
      double zoomScale = 8,
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final zooms = <double>[];
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(),
            extractionProgress: 1,
            duration: const Duration(seconds: 120),
            sentences: _sentences(duration: const Duration(seconds: 120)),
            activeSentence: null,
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: isPlaying,
            zoomScale: zoomScale,
            onZoomChanged: zooms.add,
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onAdjustEnd: () {},
          ),
        ),
      );
      return zooms;
    }

    testWidgets('鼠标右键在词区间上拖动只平移波形；右键轻点不试听、不定位', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scrubbed = <Duration>[];
      final wordTaps = <int>[];
      final moves = <(int, Duration)>[];
      final sentences = _sentences(duration: const Duration(seconds: 120));
      // 放大 8 倍、偏移 0：x=500 ≈ 9.45s，落在当前句的词 [8s, 11s] 内。
      const word = (
        globalIndex: 2,
        word: WordTimestamp(
          word: 'aa',
          startTime: Duration(seconds: 8),
          endTime: Duration(seconds: 11),
        ),
        primary: true,
        isSentenceStart: true,
        isSentenceEnd: true,
      );
      await tester.pumpWidget(
        createTestApp(
          SubtitleWaveformView(
            waveform: _waveform(length: 1200),
            extractionProgress: 1,
            duration: const Duration(seconds: 120),
            sentences: sentences,
            activeSentence: sentences[1],
            selectionEpoch: 0,
            playbackPosition: Duration.zero,
            isPlaying: false,
            zoomScale: 8,
            wordBoundaries: const [word],
            onZoomChanged: (_) {},
            onScrub: scrubbed.add,
            onScrubEnd: scrubbed.add,
            onAdjustEnd: () {},
            onWordTap: wordTaps.add,
            onMoveWord: (i, target) => moves.add((i, target)),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      final start = Offset(rect.left + 500, rect.top + 50);

      final before = _viewOffset(tester);
      final drag = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await drag.moveBy(const Offset(-200, 0));
      await tester.pump();
      await drag.up();
      await tester.pump();
      expect(_viewOffset(tester), closeTo(before + 200, 1));

      await tester.tapAt(
        start,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(moves, isEmpty, reason: '右键不抓词');
      expect(wordTaps, isEmpty, reason: '右键不试听');
      expect(scrubbed, isEmpty, reason: '右键不定位播放头');
    });

    testWidgets('触控板双指左滑平移到更晚的内容，不触发缩放', (tester) async {
      final zooms = await pumpZoomed(tester);
      final before = _viewOffset(tester);
      final center = tester.getCenter(find.byType(SubtitleWaveformView));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(center);
      await tester.pump();
      await gesture.panZoomUpdate(center, pan: const Offset(-150, 0));
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pump();

      expect(_viewOffset(tester), closeTo(before + 150, 1));
      expect(zooms, isEmpty);
    });

    testWidgets('触控板竖向滑动也映射为横向平移', (tester) async {
      await pumpZoomed(tester);
      final center = tester.getCenter(find.byType(SubtitleWaveformView));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(center);
      await tester.pump();
      await gesture.panZoomUpdate(center, pan: const Offset(0, -120));
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pump();

      expect(_viewOffset(tester), closeTo(120, 1));
    });

    testWidgets('鼠标滚轮平移，Ctrl + 滚轮缩放', (tester) async {
      final zooms = await pumpZoomed(tester);
      final center = tester.getCenter(find.byType(SubtitleWaveformView));
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(center));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await tester.pump();
      expect(_viewOffset(tester), closeTo(100, 1));
      expect(zooms, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -240)));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(zooms.single, closeTo(8 * math.e, 0.01));
    });

    testWidgets('触屏双指同向移动时平移波形', (tester) async {
      await pumpZoomed(tester);
      final rect = tester.getRect(find.byType(SubtitleWaveformView));
      final before = _viewOffset(tester);
      final first = await tester.startGesture(
        Offset(rect.left + 300, rect.center.dy - 20),
      );
      final second = await tester.startGesture(
        Offset(rect.left + 400, rect.center.dy + 20),
        pointer: 2,
      );
      await tester.pump();
      await first.moveBy(const Offset(-100, 0));
      await second.moveBy(const Offset(-100, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump();

      // 两指各左移 100：中点左移 100（第一指移动时中点先移 50，第二指再移 50）。
      expect(_viewOffset(tester), closeTo(before + 100, 1));
    });

    testWidgets('播放中由跟随播放头接管，手动平移不生效', (tester) async {
      await pumpZoomed(tester, isPlaying: true);
      final before = _viewOffset(tester);
      final center = tester.getCenter(find.byType(SubtitleWaveformView));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(center);
      await tester.pump();
      await gesture.panZoomUpdate(center, pan: const Offset(-150, 0));
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pump();

      expect(_viewOffset(tester), before);
    });

    testWidgets('未放大时滚轮不接管，交给外层处理', (tester) async {
      await pumpZoomed(tester, zoomScale: 1);
      final center = tester.getCenter(find.byType(SubtitleWaveformView));
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(center));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await tester.pump();
      expect(_viewOffset(tester), 0);
    });
  });

  group('SubtitleSimpleEditorScreen', () {
    setUp(useTemporaryAppDataDirectory);

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
          overrides: dedupeOverrides([
            analyticsServiceProvider.overrideWithValue(analytics),
            ...audioEngine.overrides,
          ]),
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
          overrides: audioEngine.overrides,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('00:01.230 - 00:03.450 · 2.2s'), findsOneWidget);
    });

    testWidgets('句子编号排在播放按钮正下方，不另占横向宽度', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: audioEngine.overrides,
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
      final playRect = tester.getRect(
        find.byKey(const ValueKey('subtitle-sentence-play-0')),
      );
      final numberRect = tester.getRect(
        find.byKey(const ValueKey('subtitle-sentence-number-0')),
      );
      expect(numberRect.center.dx, moreOrLessEquals(playRect.center.dx));
      expect(numberRect.top, greaterThanOrEqualTo(playRect.bottom));
    });

    testWidgets('波形上方工具条显示缩放和速度控制，音频材料不显示画面开关', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: audioEngine.overrides,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('subtitle-waveform-zoom-slider')),
        findsOneWidget,
      );
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.byTooltip('Playback Speed'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('subtitle-editor-toggle-video')),
        findsNothing,
      );
      final toolbarBottom = tester
          .getRect(find.byKey(const ValueKey('subtitle-waveform-zoom-slider')))
          .bottom;
      expect(
        toolbarBottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(SubtitleWaveformView)).top,
        ),
      );

      final sliderFinder = find.byKey(
        const ValueKey('subtitle-waveform-zoom-slider'),
      );
      final before = tester.widget<Slider>(sliderFinder).value;
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(tester.widget<Slider>(sliderFinder).value, greaterThan(before));
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pump();
      expect(
        tester.widget<Slider>(sliderFinder).value,
        moreOrLessEquals(before),
      );

      await tester.tap(find.byTooltip('Playback Speed'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
    });

    testWidgets('缩放滑杆圆点在左右端点时仍可从外侧容易拖动', (tester) async {
      final audioItem = createTestAudioItem(totalDuration: 10);
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: audioItem),
          overrides: audioEngine.overrides,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final sliderFinder = find.byKey(
        const ValueKey('subtitle-waveform-zoom-slider'),
      );
      final sliderRect = tester.getRect(sliderFinder);

      // 圆点在最左端时，从控件左边缘向内 4px 按下也应能拖动。
      final leftGesture = await tester.startGesture(
        Offset(sliderRect.left + 4, sliderRect.center.dy),
      );
      await leftGesture.moveBy(const Offset(80, 0));
      await leftGesture.up();
      await tester.pump();
      expect(tester.widget<Slider>(sliderFinder).value, greaterThan(1.0));

      // 先把圆点移到最右端，再验证右边缘外侧命中区可向内拖动。
      await tester.drag(sliderFinder, const Offset(1000, 0));
      await tester.pump();
      final maxValue = tester.widget<Slider>(sliderFinder).max;
      expect(tester.widget<Slider>(sliderFinder).value, maxValue);

      final rightGesture = await tester.startGesture(
        Offset(sliderRect.right - 4, sliderRect.center.dy),
      );
      await rightGesture.moveBy(const Offset(-80, 0));
      await rightGesture.up();
      await tester.pump();
      expect(tester.widget<Slider>(sliderFinder).value, lessThan(maxValue));
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
          overrides: audioEngine.overrides,
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
    });

    testWidgets('波形和首句左右操作区挂载字幕编辑引导', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: audioEngine.overrides,
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
    });

    testWidgets('选中句拆成单词 label，未选中句保持纯文本', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: audioEngine.overrides,
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
          overrides: audioEngine.overrides,
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
      expect(audioEngine.backend.ranges, hasLength(1));
      // 关键回归（bug1）：点第 2 个 label 必须播放第 2 个词的区间，
      // 而非因 label↔词错位 / 越界钳制播放到别的词。
      final words = notifier.wordsOfSelectedSentence;
      expect(audioEngine.backend.ranges.last, (
        words[1].startTime,
        words[1].endTime,
      ));
      // 选中句即展示其全部单词边界（具体绘制在 SubtitleWaveformView 用例验证）。
      expect(notifier.wordBoundariesForWaveform, isNotEmpty);

      audioEngine.completePlayback();
      await tester.pump();
    });

    testWidgets('点击播放句子后切换下一句会更新行播放态', (tester) async {
      final audioEngine = _ScreenTestAudioEngine(
        duration: const Duration(seconds: 10),
        sentences: _sentences(),
      );

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: createTestAudioItem()),
          overrides: audioEngine.overrides,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-0')));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(audioEngine.backend.ranges.last.$1, _sentences()[0].startTime);

      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(audioEngine.backend.ranges.last.$1, _sentences()[1].startTime);
      expect(audioEngine.backend.ranges, hasLength(2));

      audioEngine.completePlayback();
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsNothing);
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

WaveformPeaks _waveform({int length = 100}) {
  return WaveformPeaks(
    pixelsPerSecond: 10,
    duration: Duration(milliseconds: length * 100),
    minMax: Int16List.fromList([
      for (var i = 0; i < length; i++) ...[-9000 - i * 10, 9000 + i * 10],
    ]),
  );
}

/// 编辑页界面测试的播放与字幕依赖：fake 播放器 + 按句子生成字幕的 DAO。
class _ScreenTestAudioEngine {
  _ScreenTestAudioEngine({required Duration duration, required this.sentences})
    : backend = RangeRecordingBackend(duration);

  final RangeRecordingBackend backend;
  final List<Sentence> sentences;

  List<Override> get overrides => [
    ...subtitleEditorPlaybackOverrides(backend),
    audioItemDaoProvider.overrideWithValue(
      TranscriptAudioItemDao(() => sentences),
    ),
  ];

  void completePlayback() => backend.completePlayback();
}
