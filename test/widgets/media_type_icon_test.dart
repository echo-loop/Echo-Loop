import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/media_type_icon.dart';

void main() {
  testWidgets('音频媒体显示波形 SVG', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MediaTypeIcon(isVideo: false)),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      (svg.bytesLoader as SvgAssetLoader).assetName,
      MediaTypeIcon.audioAsset,
    );
    expect(find.byIcon(Icons.graphic_eq), findsNothing);
  });

  testWidgets('视频媒体显示视频 SVG', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MediaTypeIcon(isVideo: true)),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      (svg.bytesLoader as SvgAssetLoader).assetName,
      MediaTypeIcon.videoAsset,
    );
    expect(find.byIcon(Icons.graphic_eq), findsNothing);
  });
}
