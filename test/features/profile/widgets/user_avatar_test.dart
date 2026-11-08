import 'package:echo_loop/features/profile/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未设置头像时显示与设置页一致的默认人像 SVG', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UserAvatar(size: 40))),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
