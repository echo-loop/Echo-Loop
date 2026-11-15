import 'package:echo_loop/widgets/common/media_startup_canvas.dart';
import 'package:echo_loop/widgets/common/media_startup_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  Widget buildSubject(MediaStartupStatus status) {
    return createTestApp(
      Scaffold(
        body: SizedBox(
          width: 320,
          height: 200,
          child: MediaStartupCanvas(status: status),
        ),
      ),
    );
  }

  testWidgets('加载中显示视频加载提示', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        MediaStartupStatus(phase: ManagedMediaPhase.loading, retry: () {}),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading video…'), findsOneWidget);
  });

  testWidgets('失败时显示重试按钮并回调', (tester) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      buildSubject(
        MediaStartupStatus(
          phase: ManagedMediaPhase.failure,
          retry: () => retryCalls += 1,
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(retryCalls, 1);
  });

  testWidgets('加载中点击占位不会穿透到下方视频', (tester) async {
    var underlyingTaps = 0;
    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                key: const ValueKey('underlying-video'),
                onTap: () => underlyingTaps += 1,
                child: const ColoredBox(color: Colors.green),
              ),
              MediaStartupCanvas(
                status: MediaStartupStatus(
                  phase: ManagedMediaPhase.loading,
                  retry: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('media-startup-canvas')));
    await tester.pump();

    expect(underlyingTaps, 0);
  });
}
