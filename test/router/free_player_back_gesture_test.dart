import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/media_load_result.dart';
import 'package:echo_loop/models/media_playback_state.dart';
import 'package:echo_loop/providers/media_playback/media_playback_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/router/main_shell.dart';
import 'package:echo_loop/screens/media_playback_screen.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _GatedMediaPlayback extends MediaPlayback {
  final finishCompleter = Completer<void>();

  @override
  int beginStudyPage() => 1;

  @override
  MediaPlaybackState build() => const MediaPlaybackState();

  @override
  Future<MediaLoadResult> load(AudioItem item) async => MediaLoadResult.ready;

  @override
  Future<void> finishStudyPage({int? generation}) => finishCompleter.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS 边缘右滑退出音频随心听不等待媒体收尾', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final player = _GatedMediaPlayback();
    await pumpFullAppWithAudio(
      tester,
      audioItem: createTestAudioItem(id: 'audio-1'),
      overrides: dedupeOverrides([
        ...fullAppRouteTestStartupOverrides(),
        mediaPlaybackProvider.overrideWith(() => player),
      ]),
    );
    await tester.pump();

    final router = GoRouter.of(tester.element(find.byType(MainShell)));
    unawaited(router.push<void>(AppRoutes.audioPlayer('audio-1')));
    // 播放页包含 indeterminate loading indicator，按路由转场时长推进帧即可；
    // pumpAndSettle 会一直等待该指示器停止动画。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MediaPlaybackScreen), findsOneWidget);
    expect(find.byType(CupertinoPageTransition), findsAtLeastNWidgets(1));

    await tester.flingFrom(const Offset(1, 400), const Offset(520, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.study);
    expect(player.finishCompleter.isCompleted, isFalse);

    player.finishCompleter.complete();
    debugDefaultTargetPlatformOverride = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 显式卸载路由树并推进 dispose 排入的异步收尾，避免测试框架在测试结束
    // 时才执行页面兜底释放，遗留 fake-async Timer。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
