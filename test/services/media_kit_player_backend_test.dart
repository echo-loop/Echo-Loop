import 'dart:async';

import 'package:echo_loop/services/media_kit_player_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  /// 构建视频视图并在指定系统文字缩放的 context 中取出 [Video]。
  ///
  /// 视频需要原生纹理，测试环境不挂载 Video 本身，只执行外层 Builder 拿到配置。
  Future<Video> buildVideoWidget(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final backend = MediaKitPlayerBackend(
      player: Player(platformPlayer: _TestPlatformPlayer()),
    );
    final view = backend.buildVideoView(viewportSize: const Size(390, 844));

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return (view as Builder).builder(context) as Video;
  }

  testWidgets('视频随心听进入后台时不自动暂停播放器', (tester) async {
    final video = await buildVideoWidget(tester);

    expect(video.pauseUponEnteringBackgroundMode, isFalse);
  });

  testWidgets('视频字幕跟随系统文字缩放', (tester) async {
    final video = await buildVideoWidget(
      tester,
      textScaler: const TextScaler.linear(1.5),
    );

    expect(video.subtitleViewConfiguration.textScaler?.scale(10), 15);
  });
}

class _TestPlatformPlayer extends PlatformPlayer {
  _TestPlatformPlayer() : super(configuration: const PlayerConfiguration());

  /// 原生句柄永不就绪：VideoController 会挂起而不是报错，测试只关心配置。
  @override
  Future<int> get handle => Completer<int>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
