import 'package:echo_loop/models/video_subtitle_mask.dart';
import 'package:echo_loop/widgets/common/media_visual_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  const maskButton = ValueKey('media-subtitle-mask-button');
  const ccButton = ValueKey('media-subtitle-track-button');
  const fullscreenButton = ValueKey('media-fullscreen-button');
  const hideButton = ValueKey('media-hide-visual-button');

  Future<List<String>> pumpSurface(
    WidgetTester tester, {
    required MediaVisualControls controls,
    required bool isMaskEnabled,
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: SizedBox(
            width: 400,
            height: 240,
            child: MediaVisualSurface(
              state: MediaVisualSurfaceState(
                visible: true,
                expanded: false,
                isPlaying: false,
                subtitleVisible: false,
                subtitleMask: VideoSubtitleMask(enabled: isMaskEnabled),
                videoAspectRatio: 16 / 9,
              ),
              actions: MediaVisualSurfaceActions(
                onShow: () => calls.add('show'),
                onHide: () => calls.add('hide'),
                onPlayPause: () => calls.add('play'),
                onSubtitleToggle: () => calls.add('cc'),
                onFullscreenToggle: () => calls.add('fullscreen'),
                onSubtitleMaskToggle: () => calls.add('mask'),
                onSubtitleMaskRectChanged: (_) {},
              ),
              buildVideoView: (_) => const SizedBox.expand(),
              fillAvailableHeight: true,
              controls: controls,
            ),
          ),
        ),
      ),
    );
    // 点按画面显示悬浮控件。
    await tester.tap(find.byKey(const ValueKey('media-visual-surface')));
    await tester.pump(const Duration(milliseconds: 200));
    return calls;
  }

  testWidgets('默认控件：遮罩、字幕、全屏、隐藏都可用', (tester) async {
    await pumpSurface(
      tester,
      controls: const MediaVisualControls(),
      isMaskEnabled: true,
    );
    expect(find.byKey(maskButton), findsOneWidget);
    expect(find.byKey(ccButton), findsOneWidget);
    expect(find.byKey(fullscreenButton), findsOneWidget);
    expect(find.byKey(hideButton), findsOneWidget);
  });

  const reviewControls = MediaVisualControls(
    showSubtitleTrackButton: false,
    showFullscreenButton: false,
  );

  testWidgets('复习模式：无字幕和全屏按钮，遮罩未开启时可开启', (tester) async {
    final calls = await pumpSurface(
      tester,
      controls: reviewControls,
      isMaskEnabled: false,
    );
    expect(find.byKey(ccButton), findsNothing);
    expect(find.byKey(fullscreenButton), findsNothing);
    expect(find.byKey(hideButton), findsOneWidget);

    await tester.tap(find.byKey(maskButton));
    expect(calls, ['mask']);
  });

  testWidgets('复习模式：遮罩已开启时仍可关闭', (tester) async {
    final calls = await pumpSurface(
      tester,
      controls: reviewControls,
      isMaskEnabled: true,
    );
    await tester.tap(find.byKey(maskButton));
    expect(calls, ['mask']);
  });
}
