import 'package:echo_loop/features/profile/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatarInitialFor', () {
    test('取去除首尾空白后的第一个字符并大写', () {
      expect(avatarInitialFor('  ann  '), 'A');
    });

    test('emoji 按码点取值，不截断代理对', () {
      expect(avatarInitialFor('😀bob'), '😀');
    });

    test('昵称为空或仅含空白时返回 null', () {
      expect(avatarInitialFor(null), isNull);
      expect(avatarInitialFor(''), isNull);
      expect(avatarInitialFor('   '), isNull);
    });
  });

  testWidgets('没有头像和昵称时显示默认人像', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UserAvatar(size: 40))),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('没有头像时用昵称首字作为占位', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatar(size: 40, nickname: 'Quiet Otter')),
      ),
    );

    expect(find.text('Q'), findsOneWidget);
  });
}
