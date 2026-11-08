import 'package:echo_loop/features/profile/domain/user_profile.dart';
import 'package:echo_loop/features/profile/providers/user_profile_provider.dart';
import 'package:echo_loop/features/profile/widgets/profile_edit_section.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 已加载资料但未设置头像，避免测试中发起真实的图片网络请求。
class _LoadedProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async {
    return UserProfile(
      userId: 'user-1',
      nickname: 'Ann',
      avatarUrl: null,
      updatedAt: DateTime.utc(2026, 11, 8),
    );
  }
}

void main() {
  testWidgets('鼠标悬停在头像上时显示相机遮罩，离开后隐藏', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(_LoadedProfileNotifier.new),
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
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);

    await mouse.moveTo(tester.getCenter(find.byType(InkWell).first));
    await tester.pump();
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
  });
}
