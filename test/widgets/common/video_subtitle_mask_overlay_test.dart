import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/widgets/common/video_subtitle_mask_overlay.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(400, 400);
  const contentRect = Rect.fromLTWH(0, 100, 400, 200);
  const initialRect = Rect.fromLTWH(0.25, 0.5, 0.5, 0.25);

  /// 挂载遮罩组件；[isEnabled] 对应字幕遮罩开关。
  Future<List<Rect>> pumpOverlay(
    WidgetTester tester, {
    VoidCallback? onInteractionStart,
    Rect startRect = initialRect,
    Rect content = contentRect,
    bool isEnabled = true,
  }) async {
    final committed = <Rect>[];
    var rect = startRect;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: viewport,
            // 与真实页面一致：外层画面有点按手势参与竞争，提交的位置回写给遮罩。
            child: GestureDetector(
              onTap: () {},
              child: StatefulBuilder(
                builder: (context, setState) => VideoSubtitleMaskOverlay(
                  normalizedRect: rect,
                  contentRect: content,
                  isEnabled: isEnabled,
                  onInteractionStart: onInteractionStart ?? () {},
                  onRectChanged: (next) {
                    committed.add(next);
                    setState(() => rect = next);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return committed;
  }

  /// 点按遮罩，让手柄显示（手柄只在激发态下出现）。
  Future<void> revealFrame(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('video-subtitle-mask')));
    await tester.pump();
  }

  test('videoContentRect 按 contain 计算去黑边后的画面区域', () {
    expect(videoContentRect(viewport, 2), contentRect);
    expect(videoContentRect(viewport, null), Offset.zero & viewport);
  });

  testWidgets('遮罩按画面区域定位，拖动结束只提交一次新位置', (tester) async {
    final committed = await pumpOverlay(tester);
    final mask = find.byKey(const ValueKey('video-subtitle-mask'));
    expect(tester.getRect(mask), const Rect.fromLTWH(100, 200, 200, 50));

    final gesture = await tester.startGesture(tester.getCenter(mask));
    // 首段位移用于越过手势判定阈值，之后的位移完整跟随手指。
    await gesture.moveBy(const Offset(10, 0));
    await gesture.moveBy(const Offset(40, -20));
    await tester.pump();
    expect(committed, isEmpty);
    await gesture.up();
    await tester.pump();

    expect(committed, hasLength(1));
    expect(committed.single.left, closeTo(0.35, 1e-6));
    expect(committed.single.top, closeTo(0.4, 1e-6));
    expect(committed.single.size, initialRect.size);
  });

  testWidgets('小幅拖动也立即跟手，不受默认 36px 判定阈值影响', (tester) async {
    final committed = await pumpOverlay(tester);
    final mask = find.byKey(const ValueKey('video-subtitle-mask'));

    final gesture = await tester.startGesture(tester.getCenter(mask));
    await gesture.moveBy(const Offset(0, -10));
    await gesture.moveBy(const Offset(0, -10));
    await tester.pump();
    // 首段 10px 用于越过判定阈值，之后的位移应完整跟随手指。
    expect(tester.getRect(mask).top, lessThan(200));
    await gesture.up();
    await tester.pump();

    expect(committed.single.top, lessThan(initialRect.top));
  });

  testWidgets('单指拖动中加入第二根手指时遮罩不跳动', (tester) async {
    await pumpOverlay(tester);
    final mask = find.byKey(const ValueKey('video-subtitle-mask'));
    final center = tester.getCenter(mask);

    final first = await tester.startGesture(center);
    await first.moveBy(const Offset(10, 0));
    await first.moveBy(const Offset(10, 0));
    await tester.pump();
    final beforeSecondFinger = tester.getRect(mask);

    final second = await tester.startGesture(center + const Offset(60, 0));
    await tester.pump();
    await second.moveBy(const Offset(0.5, 0));
    await tester.pump();

    final afterSecondFinger = tester.getRect(mask);
    expect(
      (afterSecondFinger.center - beforeSecondFinger.center).distance,
      lessThan(2),
    );
    await first.up();
    await second.up();
  });

  testWidgets('拖动越界时遮罩停在画面边缘', (tester) async {
    final committed = await pumpOverlay(tester);
    final mask = find.byKey(const ValueKey('video-subtitle-mask'));

    await tester.drag(mask, const Offset(0, 300));
    await tester.pump();

    expect(committed.single.bottom, closeTo(1.0, 1e-6));
  });

  Finder grip(String edge) =>
      find.byKey(ValueKey('video-subtitle-mask-grip-$edge'));

  testWidgets('拖动下边手柄只改变高度，上边与左右保持不动', (tester) async {
    final committed = await pumpOverlay(tester);
    await revealFrame(tester);

    await tester.drag(grip('bottom'), const Offset(30, 20));
    await tester.pump();

    final rect = committed.single;
    expect(rect.top, initialRect.top);
    expect(rect.left, initialRect.left);
    expect(rect.right, initialRect.right);
    expect(rect.bottom, closeTo(initialRect.bottom + 0.1, 1e-6));
  });

  testWidgets('拖动左边手柄只改变左边，右边保持不动', (tester) async {
    final committed = await pumpOverlay(tester);
    await revealFrame(tester);

    await tester.drag(grip('left'), const Offset(-40, 15));
    await tester.pump();

    final rect = committed.single;
    expect(rect.left, closeTo(initialRect.left - 0.1, 1e-6));
    expect(rect.right, initialRect.right);
    expect(rect.top, initialRect.top);
    expect(rect.bottom, initialRect.bottom);
  });

  testWidgets('上边手柄不能把遮罩压到小于最小高度', (tester) async {
    final committed = await pumpOverlay(tester);
    await revealFrame(tester);

    await tester.drag(grip('top'), const Offset(0, 300));
    await tester.pump();

    final rect = committed.single;
    expect(rect.bottom, initialRect.bottom);
    expect(rect.height * contentRect.height, greaterThanOrEqualTo(23.9));
  });

  testWidgets('打开视频或窗口重建时，已开启的遮罩不自动弹出手柄', (tester) async {
    // 视频加载完成后遮罩从无到有挂载，布局切换也会重建组件；两者都不是用户操作。
    await pumpOverlay(tester);
    expect(grip('bottom'), findsNothing);
    expect(find.byKey(const ValueKey('video-subtitle-mask')), findsOneWidget);
  });

  testWidgets('遮罩从关闭切换为开启时短暂显示手柄，之后自动收起', (tester) async {
    await pumpOverlay(tester, isEnabled: false);
    expect(find.byKey(const ValueKey('video-subtitle-mask')), findsNothing);

    await pumpOverlay(tester, isEnabled: true);
    expect(grip('bottom'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(grip('bottom'), findsNothing);
  });

  testWidgets('鼠标悬浮在遮罩上显示手柄，移出后收起', (tester) async {
    await pumpOverlay(tester);
    final mask = find.byKey(const ValueKey('video-subtitle-mask'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await tester.pump();
    expect(grip('bottom'), findsNothing);

    await mouse.moveTo(tester.getCenter(mask));
    await tester.pump();
    expect(grip('bottom'), findsOneWidget);

    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    expect(grip('bottom'), findsNothing);
  });

  testWidgets('鼠标从遮罩移到底边手柄上时手柄保持显示', (tester) async {
    await pumpOverlay(tester);
    final mask = find.byKey(const ValueKey('video-subtitle-mask'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(mask));
    await tester.pump();

    // 底边手柄的触控区伸到遮罩外侧，越过遮罩边界后仍应视为悬浮。
    await mouse.moveTo(tester.getRect(mask).bottomCenter + const Offset(0, 12));
    await tester.pump();
    expect(grip('bottom'), findsOneWidget);
  });

  testWidgets('点按遮罩显示手柄并通知收起控件，激发态变化写入日志', (tester) async {
    var interactions = 0;
    final logCountBefore = AppLogger.instance.entries.length;
    await pumpOverlay(tester, onInteractionStart: () => interactions++);
    expect(grip('bottom'), findsNothing);

    await revealFrame(tester);
    expect(grip('bottom'), findsOneWidget);
    expect(interactions, 1);

    await tester.pump(const Duration(seconds: 3));
    expect(grip('bottom'), findsNothing);

    final messages = AppLogger.instance.entries
        .skip(logCountBefore)
        .where((entry) => entry.tag == 'VideoSubtitleMask')
        .map((entry) => entry.message);
    expect(messages, contains('遮罩激发态开启 原因=点按遮罩'));
    expect(messages, contains('遮罩激发态关闭 原因=保持时间结束'));
  });

  testWidgets('遮罩窄于当前画面的像素下限时，拖四边手柄不抛异常且保持有效', (tester) async {
    // 模拟全屏里缩窄、回到小窗口后的竖屏视频：画面仅 100px 宽，
    // 像素下限（56px ≈ 0.56）已大于遮罩当前宽度 0.4（40px）。
    const narrowRect = Rect.fromLTWH(0, 0.5, 0.4, 0.3);
    const smallContent = Rect.fromLTWH(150, 100, 100, 200);
    final committed = await pumpOverlay(
      tester,
      startRect: narrowRect,
      content: smallContent,
    );
    await revealFrame(tester);

    for (final edge in ['left', 'right', 'top', 'bottom']) {
      await tester.drag(grip(edge), const Offset(-30, -30));
      await tester.pump();
      // 手柄在松手后保留 2 秒，连续拖动不需要重新点按。
    }

    expect(tester.takeException(), isNull);
    expect(committed, hasLength(4));
    for (final rect in committed) {
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(1 + 1e-9));
      expect(rect.bottom, lessThanOrEqualTo(1 + 1e-9));
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    }
  });
}
