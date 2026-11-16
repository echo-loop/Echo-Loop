import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/features/media_trim/widgets/media_trim_timeline.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    double viewWidth = width,
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
              width: viewWidth,
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

  testWidgets('播放头停在起点时：按在外侧把手上抓把手，按在片段内侧抓播放头', (tester) async {
    final rect = await pumpTimeline(
      tester,
      position: const Duration(seconds: 2),
    );
    // 把手画在片段外侧，中心在边界左边半个把手宽处。
    await tester.dragFrom(
      Offset(xAt(rect, 2) - 6, rect.center.dy),
      const Offset(-30, 0),
    );
    await tester.pumpAndSettle();
    expect(drags.last.$1, MediaTrimEdge.start);
    expect(
      drags.first.$2.inMilliseconds,
      lessThan(2000),
      reason: '抓把手时边界不跳到手指下，只随拖动位移变化',
    );
    expect(scrubs, isEmpty);

    drags.clear();
    await tester.dragFrom(
      Offset(xAt(rect, 2) + 3, rect.center.dy),
      const Offset(30, 0),
    );
    await tester.pumpAndSettle();
    expect(scrubs, isNotEmpty);
    expect(drags, isEmpty);
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

  testWidgets('放大后快速滑动松手会继续惯性平移，按下即停住且这次轻点不定位', (tester) async {
    // 放大后从同一位置拖同样距离：慢拖和快甩停下后，同一屏幕位置对应的时间应不同。
    Future<Duration> timeAfter(
      Future<void> Function(Offset from) gesture,
    ) async {
      // 先卸载，保证每次都是全新的缩放和平移状态。
      await tester.pumpWidget(const SizedBox());
      final rect = await pumpTimeline(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('trim-zoom-in')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trim-zoom-in')));
      await tester.pumpAndSettle();
      final from = Offset(rect.left + 600, rect.center.dy);
      await gesture(from);
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(rect.left + 300, rect.center.dy));
      await tester.pumpAndSettle();
      return seeks.isEmpty ? selections.last.$2 : seeks.last;
    }

    final dragged = await timeAfter(
      (from) => tester.timedDragFrom(
        from,
        const Offset(-80, 0),
        const Duration(seconds: 1),
      ),
    );
    final flung = await timeAfter(
      (from) => tester.flingFrom(from, const Offset(-80, 0), 1500),
    );
    expect(flung, greaterThan(dragged));

    // 惯性滑动中按下：只停住，不定位。
    await tester.pumpWidget(const SizedBox());
    final rect = await pumpTimeline(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trim-zoom-in')));
    await tester.pumpAndSettle();
    await tester.flingFrom(
      Offset(rect.left + 600, rect.center.dy),
      const Offset(-80, 0),
      1500,
    );
    await tester.pump(const Duration(milliseconds: 50));
    seeks.clear();
    selections.clear();
    await tester.tapAt(Offset(rect.left + 300, rect.center.dy));
    await tester.pumpAndSettle();
    expect(seeks, isEmpty);
    expect(selections, isEmpty);
  });

  testWidgets('拖动把手靠近其它片段边界时吸附对齐并轻震，拖远后脱开', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final rect = await pumpTimeline(tester);
    // 终点把手中心在 4 秒右侧半个把手宽处；拖到 5.9 秒，距片段 2 起点 6px。
    final handle = Offset(xAt(rect, 4) + 6, rect.center.dy);
    await tester.dragFrom(handle, const Offset(60 * 1.9, 0));
    await tester.pumpAndSettle();
    expect(drags.last, (MediaTrimEdge.end, const Duration(seconds: 6)));
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    drags.clear();
    haptics.clear();
    await tester.dragFrom(handle, const Offset(60 * 1.5, 0));
    await tester.pumpAndSettle();
    expect(drags.last.$2.inMilliseconds, closeTo(5500, 20));
    expect(haptics, isEmpty);
  });

  testWidgets('放大平移后视口宽度变化：左侧对应的时间不变，不会每次向右偏一个留白', (tester) async {
    var rect = await pumpTimeline(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trim-zoom-in')));
    await tester.pumpAndSettle();
    // 在空白处拖动平移，让偏移量大于 0。
    await tester.timedDragFrom(
      Offset(rect.left + 600, rect.center.dy),
      const Offset(-200, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    Future<Duration> timeAtLeft() async {
      seeks.clear();
      selections.clear();
      await tester.tapAt(Offset(rect.left + 14, rect.center.dy));
      await tester.pumpAndSettle();
      return seeks.isEmpty ? selections.last.$2 : seeks.last;
    }

    final before = await timeAtLeft();
    for (final w in [500.0, width, 560.0, width]) {
      rect = await pumpTimeline(tester, viewWidth: w);
      await tester.pumpAndSettle();
    }
    final after = await timeAtLeft();
    expect(after.inMilliseconds, closeTo(before.inMilliseconds, 15));
  });
}
