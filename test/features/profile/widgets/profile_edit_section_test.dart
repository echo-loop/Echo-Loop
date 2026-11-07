import 'package:echo_loop/features/profile/domain/user_profile.dart';
import 'package:echo_loop/features/profile/providers/user_profile_provider.dart';
import 'package:echo_loop/features/profile/widgets/profile_edit_section.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 模拟资料加载失败（例如后端接口未部署返回 404）。
class _FailingProfileNotifier extends UserProfileNotifier {
  static int buildCount = 0;

  @override
  Future<UserProfile?> build() async {
    buildCount++;
    throw Exception('profile endpoint returned 404');
  }
}

void main() {
  setUp(() {
    _FailingProfileNotifier.buildCount = 0;
  });

  testWidgets('资料加载失败时显示提示，点击昵称入口可重新加载', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(_FailingProfileNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: ProfileEditSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't load your profile. Tap to retry."),
      findsOneWidget,
    );
    expect(_FailingProfileNotifier.buildCount, 1);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(_FailingProfileNotifier.buildCount, 2);
  });
}
