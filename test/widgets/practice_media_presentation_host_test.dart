import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/widgets/common/practice_media_presentation_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/mock_providers.dart';

class _VideoViewMediaEngine extends MediaEngine {
  @override
  Widget buildVideoView({required Size viewportSize}) {
    return const SizedBox(key: ValueKey('practice-host-video-view'));
  }
}

void main() {
  testWidgets('按目标状态进入和退出全屏', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      createTestApp(
        PracticeMediaPresentationHost(
          enabled: true,
          audioItemId: 'video-item',
          isPlaying: false,
          onPlayPause: () {},
          builder: (context, presentation, visualSurface) => Scaffold(
            body: Column(
              children: [
                Text('expanded=${presentation.expanded}'),
                SizedBox(height: 260, child: visualSurface),
              ],
            ),
          ),
        ),
        overrides: dedupeOverrides([
          mediaEngineProvider.overrideWith(_VideoViewMediaEngine.new),
        ]),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('media-visual-surface')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('media-fullscreen-button')));
    await tester.pump();

    expect(find.text('expanded=true'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('media-fullscreen-button')));
    await tester.pump();

    debugDefaultTargetPlatformOverride = null;
    expect(find.text('expanded=false'), findsOneWidget);
  });
}
