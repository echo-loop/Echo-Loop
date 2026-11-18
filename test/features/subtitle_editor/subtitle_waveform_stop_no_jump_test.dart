import 'dart:typed_data';

import 'package:echo_loop/features/subtitle_editor/subtitle_waveform_view.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/utils/waveform_peaks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// 回归：播放结束、停止后，波形不得跳变/闪烁。
///
/// 单一坐标系（[WaveformMetrics] + viewOffset）下，play→stop 只翻转 isPlaying，
/// playbackPosition 被冻结，viewOffset 由「保持」分支取到与播放中完全相同的值。
/// 停止态不再绘制播放头红线，避免蓝线常驻干扰字幕边界编辑。
void main() {
  group('字幕波形：播放停止不跳变/不闪烁', () {
    final waveform = _waveform(length: 1200);
    final sentences = [
      Sentence(
        index: 0,
        text: 'Long first.',
        startTime: const Duration(seconds: 3),
        endTime: const Duration(seconds: 11),
      ),
      Sentence(
        index: 1,
        text: 'Second.',
        startTime: const Duration(seconds: 11),
        endTime: const Duration(seconds: 18),
      ),
    ];

    Widget build({
      required bool isPlaying,
      required Duration position,
      required int selectionEpoch,
    }) => createTestApp(
      SubtitleWaveformView(
        waveform: waveform,
        extractionProgress: 1,
        duration: const Duration(seconds: 60),
        sentences: sentences,
        activeSentence: sentences[0],
        selectionEpoch: selectionEpoch,
        playbackPosition: position,
        isPlaying: isPlaying,
        zoomScale: 8,
        onZoomChanged: (_) {},
        onScrub: (_) {},
        onScrubEnd: (_) {},
        onAdjustEnd: () {},
      ),
      // 同一用例内多次 pumpWidget 时保留波形的持久偏移状态。
      key: const ValueKey('subtitle-waveform-stop-no-jump'),
    );

    testWidgets('播放到句尾后停止：viewOffset 不变且播放头仍在', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 播放中（钉中线，11s 居中）。
      await tester.pumpWidget(
        build(
          isPlaying: true,
          position: const Duration(seconds: 11),
          selectionEpoch: 0,
        ),
      );
      await tester.pump();
      final offsetPlaying = _viewOffset(tester);
      final linePlaying = _playheadX(tester);
      expect(offsetPlaying, greaterThan(0));
      expect(linePlaying, closeTo(400, 1)); // 中线

      // 停止：isPlaying=false，position 不变，epoch 不变。
      await tester.pumpWidget(
        build(
          isPlaying: false,
          position: const Duration(seconds: 11),
          selectionEpoch: 0,
        ),
      );
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // 结构性零跳变：偏移像素级不变；播放头常驻，停在停止位置。
      expect(_viewOffset(tester), closeTo(offsetPlaying, 0.001));
      expect(_hasPlayhead(tester), isTrue);
    });

    testWidgets('用户显式点选（epoch 自增）才把该句居中', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 初始（未播放，已选中句 0，epoch=0）—— 挂载不居中，偏移停在 0。
      await tester.pumpWidget(
        build(
          isPlaying: false,
          position: const Duration(seconds: 3),
          selectionEpoch: 0,
        ),
      );
      await tester.pump();
      expect(_viewOffset(tester), 0);

      // epoch 自增（模拟用户点选句子）→ 把句 0（中点 7s）居中。
      await tester.pumpWidget(
        build(
          isPlaying: false,
          position: const Duration(seconds: 3),
          selectionEpoch: 1,
        ),
      );
      await tester.pump();

      // 句 0 中点 7s：偏移 = timeToContentX(7s) - viewport/2
      //            = (16 + 6144*7/60) - 400 = 732.8 - 400 = 332.8。
      expect(_viewOffset(tester), closeTo(332.8, 1));
    });
  });
}

double _viewOffset(WidgetTester tester) {
  for (final cp in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final p = cp.painter;
    if (p != null && p.runtimeType.toString() == '_WaveformLayerPainter') {
      return (p as dynamic).viewOffset as double;
    }
  }
  fail('找不到波形层 painter');
}

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

WaveformPeaks _waveform({int length = 100}) {
  return WaveformPeaks(
    pixelsPerSecond: 10,
    duration: Duration(milliseconds: length * 100),
    minMax: Int16List.fromList([
      for (var i = 0; i < length; i++) ...[-9000 - i * 10, 9000 + i * 10],
    ]),
  );
}
