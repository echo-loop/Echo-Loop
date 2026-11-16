import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/features/media_trim/widgets/media_trim_timeline.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 628.0; // 可用宽度 600px，对应 10 秒，每秒 60px。
  const clips = [
    MediaTrimClip(
      id: 1,
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
    ),
    MediaTrimClip(
      id: 2,
      start: Duration(seconds: 6),
      end: Duration(seconds: 8),
    ),
  ];

  late List<(MediaTrimEdge, Duration)> drags;
  late List<Duration> seeks;
  late List<Duration> scrubs;
  late List<(int, Duration)> selections;
  late List<MediaTrimEdge> dragEnds;
  late int scrubEnds;
  late int clears;

  Future<Rect> pumpTimeline(
    WidgetTester tester, {
    Duration position = Duration.zero,
  }) async {
    drags = [];
    seeks = [];
    scrubs = [];
    selections = [];
    dragEnds = [];
    scrubEnds = 0;
    clears = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: MediaTrimTimeline(
                waveform: null,
                waveformProgress: 0.5,
                isWaveformFailed: false,
                onRetryWaveform: () {},
                total: const Duration(seconds: 10),
                spans: const [],
                clips: clips,
                selectedClipId: 1,
                revealSerial: 0,
                position: position,
                isPlaying: false,
                onSeek: seeks.add,
                onScrub: scrubs.add,
                onScrubEnd: () => scrubEnds++,
                onSelectClip: (id, at) => selections.add((id, at)),
                onClearSelection: () => clears++,
                onEdgeDrag: (edge, time) => drags.add((edge, time)),
                onEdgeDragEnd: dragEnds.add,
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getRect(find.byType(GestureDetector).first);
  }

  double xAt(Rect rect, double seconds) => rect.left + 14 + 60 * seconds;

  testWidgets('从把手按下拖动：调整对应一端，而不是平移', (tester) async {
    final rect = await pumpTimeline(tester);
    await tester.dragFrom(
      Offset(xAt(rect, 4), rect.center.dy),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    expect(drags, isNotEmpty);
    expect(drags.last.$1, MediaTrimEdge.end);
    expect(
      drags.last.$2.inMilliseconds,
      closeTo(5000, 50),
      reason: '拖动 60px 对应 1 秒',
    );
    expect(dragEnds, [MediaTrimEdge.end]);
    expect(seeks, isEmpty);
    expect(scrubs, isEmpty);
  });

  testWidgets('鼠标拖动起点把手同样生效', (tester) async {
    final rect = await pumpTimeline(tester);
    await tester.dragFrom(
      Offset(xAt(rect, 2), rect.center.dy),
      const Offset(-60, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(drags.last.$1, MediaTrimEdge.start);
    expect(drags.last.$2.inMilliseconds, closeTo(1000, 50));
  });

  testWidgets('点按其它片段：选中该片段并定位到点按处', (tester) async {
    final rect = await pumpTimeline(tester);
    await tester.tapAt(Offset(xAt(rect, 7), rect.center.dy));
    await tester.pumpAndSettle();
    expect(selections.single.$1, 2);
    expect(selections.single.$2.inMilliseconds, closeTo(7000, 20));
    expect(seeks, isEmpty);
    expect(clears, 0);
    expect(drags, isEmpty);
  });

  testWidgets('点按所有片段之外：取消选中并自由定位', (tester) async {
    final rect = await pumpTimeline(tester);
    await tester.tapAt(Offset(xAt(rect, 5), rect.center.dy));
    await tester.pumpAndSettle();
    expect(clears, 1);
    expect(selections, isEmpty);
    expect(seeks.single.inMilliseconds, closeTo(5000, 20));
  });

  testWidgets('抓住播放头拖动：连续定位，不平移也不改片段', (tester) async {
    final rect = await pumpTimeline(
      tester,
      position: const Duration(seconds: 3),
    );
    await tester.dragFrom(
      Offset(xAt(rect, 3), rect.top + 6),
      const Offset(30, 0),
    );
    await tester.pumpAndSettle();
    expect(scrubs, isNotEmpty);
    expect(scrubs.last.inMilliseconds, closeTo(3500, 50));
    expect(scrubEnds, 1);
    expect(drags, isEmpty);
  });

  testWidgets('播放头与把手重叠时，在波形区按下抓把手', (tester) async {
    final rect = await pumpTimeline(
      tester,
      position: const Duration(seconds: 2),
    );
    await tester.dragFrom(
      Offset(xAt(rect, 2), rect.center.dy),
      const Offset(-30, 0),
    );
    await tester.pumpAndSettle();
    expect(drags.last.$1, MediaTrimEdge.start);
    expect(scrubs, isEmpty);
  });

  testWidgets('未放大时在空白处拖动：从按下处开始拖动播放头', (tester) async {
    final rect = await pumpTimeline(tester);
    await tester.dragFrom(
      Offset(xAt(rect, 5), rect.center.dy),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    expect(scrubs.first.inMilliseconds, closeTo(5000, 20));
    expect(scrubs.last.inMilliseconds, closeTo(6000, 50));
    expect(drags, isEmpty);
  });
}
