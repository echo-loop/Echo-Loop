import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';

void main() {
  testWidgets('主播放按钮图标按 centerIconSize 渲染，不被按钮内边距压缩', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: PlaybackControls.controlButtonSize,
              child: PlaybackCenterButton(
                onPressed: () {},
                icon: playbackToggleGlyph(
                  PlaybackToggleIcon.play,
                  color: Colors.blue,
                  size: PlaybackControls.centerIconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final iconSize = tester.getSize(
      find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)),
    );
    expect(iconSize, Size.square(PlaybackControls.centerIconSize));
  });
}
