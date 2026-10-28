import 'package:echo_loop/features/user_region/user_region_override.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/features/user_region/widgets/user_region_override_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('选择中国区后保存覆盖值并提示重启生效', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isChinaUserProvider.overrideWithValue(false)],
        child: const MaterialApp(
          home: Scaffold(
            body: UserRegionOverrideTile(leading: Icon(Icons.public)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本次启动：全球区'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中国区').last);
    await tester.pumpAndSettle();

    expect(
      await const UserRegionOverrideStore().load(),
      UserRegionOverride.china,
    );
    expect(find.textContaining('重启 App 后生效'), findsOneWidget);
    // 已保存值刷新到行尾，本次启动的生效地区不变。
    expect(find.text('中国区'), findsOneWidget);
    expect(find.text('本次启动：全球区'), findsOneWidget);
  });
}
