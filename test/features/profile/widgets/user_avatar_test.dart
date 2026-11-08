import 'package:echo_loop/features/profile/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未设置头像时显示默认人像', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UserAvatar(size: 40))),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
