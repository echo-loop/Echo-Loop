import 'dart:async';

import 'package:echo_loop/models/media_load_result.dart';
import 'package:echo_loop/widgets/common/managed_media_visual_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  Finder findBlackCanvas() => find.byWidgetPredicate(
    (widget) => widget is ColoredBox && widget.color == Colors.black,
  );

  Widget buildSubject({
    required Object loadKey,
    required Future<MediaLoadResult> Function() load,
    required Future<void> Function() cancel,
    VoidCallback? onReady,
    bool showVideoLoading = true,
  }) {
    return createTestApp(
      Scaffold(
        body: ManagedMediaVisualSurface(
          loadKey: loadKey,
          load: load,
          cancel: cancel,
          onReady: onReady,
          showVideoLoading: showVideoLoading,
          child: const ColoredBox(
            key: ValueKey('ready-child'),
            color: Colors.green,
          ),
        ),
      ),
    );
  }

  testWidgets('挂载后只加载一次，普通 rebuild 不重复加载', (tester) async {
    var loadCalls = 0;
    var readyCalls = 0;
    VoidCallback rebuild = () {};

    await tester.pumpWidget(
      createTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = () => setState(() {});
            return Scaffold(
              body: ManagedMediaVisualSurface(
                loadKey: 'video-1',
                load: () async {
                  loadCalls += 1;
                  return MediaLoadResult.ready;
                },
                cancel: () async {},
                onReady: () => readyCalls += 1,
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    rebuild();
    await tester.pump();

    expect(loadCalls, 1);
    expect(readyCalls, 1);
    expect(find.byKey(const ValueKey('managed-media-loading')), findsNothing);
  });

  testWidgets('加载期间显示动画，成功后显示内容并回调一次', (tester) async {
    final completer = Completer<MediaLoadResult>();
    var readyCalls = 0;

    await tester.pumpWidget(
      buildSubject(
        loadKey: 'video-1',
        load: () => completer.future,
        cancel: () async {},
        onReady: () => readyCalls += 1,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading video…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('managed-media-overlay-canvas')),
      findsOneWidget,
    );

    completer.complete(MediaLoadResult.ready);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ready-child')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(readyCalls, 1);
  });

  testWidgets('音频启动复用托管组件时不显示视频加载文案', (tester) async {
    final completer = Completer<MediaLoadResult>();
    await tester.pumpWidget(
      buildSubject(
        loadKey: 'audio-1',
        load: () => completer.future,
        cancel: () async {},
        showVideoLoading: false,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading video…'), findsNothing);
    expect(findBlackCanvas(), findsNothing);

    completer.complete(MediaLoadResult.ready);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ready-child')), findsOneWidget);
  });

  testWidgets('音频启动失败后可重试且不显示视频画布', (tester) async {
    var loadCalls = 0;

    await tester.pumpWidget(
      buildSubject(
        loadKey: 'audio-1',
        load: () async {
          loadCalls += 1;
          return loadCalls == 1
              ? MediaLoadResult.failure
              : MediaLoadResult.ready;
        },
        cancel: () async {},
        showVideoLoading: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Failed to load video'), findsNothing);
    expect(findBlackCanvas(), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(find.byKey(const ValueKey('ready-child')), findsOneWidget);
    expect(findBlackCanvas(), findsNothing);
  });

  testWidgets('极大系统字号下加载提示跟随缩放且保持在视频画布内', (tester) async {
    final completer = Completer<MediaLoadResult>();
    await tester.pumpWidget(
      createTestApp(
        MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(4)),
          child: ManagedMediaVisualSurface(
            loadKey: 'video-1',
            load: () => completer.future,
            cancel: () async {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final textSize = tester.getSize(find.text('Loading video…'));
    final canvasSize = tester.getSize(
      find.byKey(const ValueKey('managed-media-overlay-canvas')),
    );
    // 文字应按 4 倍放大，且仍落在画布内、不溢出
    expect(textSize.height, greaterThan(30));
    expect(textSize.width, lessThanOrEqualTo(canvasSize.width));
    expect(textSize.height, lessThan(canvasSize.height));
  });

  testWidgets('失败后原地重试并可成功', (tester) async {
    var loadCalls = 0;
    var readyCalls = 0;

    await tester.pumpWidget(
      buildSubject(
        loadKey: 'video-1',
        load: () async {
          loadCalls += 1;
          return loadCalls == 1
              ? MediaLoadResult.failure
              : MediaLoadResult.ready;
        },
        cancel: () async {},
        onReady: () => readyCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load video'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(readyCalls, 1);
    expect(find.text('Failed to load video'), findsNothing);
  });

  testWidgets('切换 loadKey 取消旧任务并忽略迟到结果', (tester) async {
    final oldLoad = Completer<MediaLoadResult>();
    final newLoad = Completer<MediaLoadResult>();
    var key = 'video-1';
    var cancelCalls = 0;
    var readyCalls = 0;
    late StateSetter rebuild;

    Widget subject() => createTestApp(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return Scaffold(
            body: ManagedMediaVisualSurface(
              loadKey: key,
              load: () => key == 'video-1' ? oldLoad.future : newLoad.future,
              cancel: () async => cancelCalls += 1,
              onReady: () => readyCalls += 1,
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(subject());
    await tester.pump();
    rebuild(() => key = 'video-2');
    await tester.pump();
    expect(cancelCalls, 1);

    oldLoad.complete(MediaLoadResult.ready);
    await tester.pump();
    expect(readyCalls, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    newLoad.complete(MediaLoadResult.ready);
    await tester.pumpAndSettle();
    expect(readyCalls, 1);
  });

  testWidgets('加载中销毁会取消且迟到完成不回调', (tester) async {
    final completer = Completer<MediaLoadResult>();
    var cancelCalls = 0;
    var readyCalls = 0;

    await tester.pumpWidget(
      buildSubject(
        loadKey: 'video-1',
        load: () => completer.future,
        cancel: () async => cancelCalls += 1,
        onReady: () => readyCalls += 1,
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancelCalls, 1);

    completer.complete(MediaLoadResult.ready);
    await tester.pump();
    expect(readyCalls, 0);
  });
}
