import 'dart:async';

import 'package:echo_loop/providers/learning_settings_provider.dart';

import 'package:echo_loop/features/daily_goal_check_in/data/daily_check_in_share_actions.dart';
import 'package:echo_loop/features/daily_goal_check_in/providers/daily_check_in_share_provider.dart';
import 'package:echo_loop/features/daily_goal_check_in/widgets/daily_check_in_share_dialog.dart';
import 'package:echo_loop/features/user_preferences/data/local_user_preferences_store.dart';
import 'package:echo_loop/features/user_preferences/data/user_preferences_sync_service.dart';
import 'package:echo_loop/features/user_preferences/providers/user_preferences_sync_providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../share_test_support.dart';

class _Sync extends Mock implements UserPreferencesSyncService {}

class _Actions implements DailyShareActions {
  int saves = 0;
  int shares = 0;
  @override
  Future<bool> save(PreparedDailyCheckInShare card) async {
    saves++;
    return true;
  }

  @override
  Future<void> share(PreparedDailyCheckInShare card, Rect origin) async {
    shares++;
  }
}

class _Share extends DailyCheckInShareNotifier {
  _Share(this.initial);
  final DailyCheckInShareState initial;
  int prepareCalls = 0;
  @override
  DailyCheckInShareState build() {
    ref.onDispose(() => initial.card?.image.dispose());
    return initial;
  }

  @override
  Future<void> prepare({bool refresh = false}) async {
    prepareCalls++;
  }

  Completer<bool>? changeOverride;

  @override
  Future<bool> changeCard() => changeOverride?.future ?? super.changeCard();

  void setReady(PreparedDailyCheckInShare card) {
    ref.onDispose(card.image.dispose);
    state = DailyCheckInShareState(status: DailyShareStatus.ready, card: card);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _Sync sync;
  late _Actions actions;
  late ShareTestApi api;
  late ProviderContainer container;
  var userId = 'user-1';
  var visible = true;
  final day = DateTime(2026, 11, 8);

  setUp(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    sync = _Sync();
    actions = _Actions();
    api = ShareTestApi();
    userId = 'user-1';
    visible = true;
    when(() => sync.onSessionChanged(any())).thenAnswer((_) async {});
  });

  Future<PreparedDailyCheckInShare> card(WidgetTester tester) async {
    final image = await tester.runAsync(tinyShareImage);
    return PreparedDailyCheckInShare(
      userId: userId,
      date: day,
      template: api.template,
      image: image!,
    );
  }

  Future<_Share> mount(
    WidgetTester tester, {
    PreparedDailyCheckInShare? ready,
  }) async {
    final share = _Share(
      DailyCheckInShareState(
        status: ready == null
            ? DailyShareStatus.preparing
            : DailyShareStatus.ready,
        card: ready,
      ),
    );
    container = ProviderContainer(
      overrides: [
        dailyShareUserIdProvider.overrideWith(
          (ref) => userId.isEmpty ? null : userId,
        ),
        dailyShareNowProvider.overrideWithValue(() => day),
        sharedPreferencesProvider.overrideWithValue(prefs),
        dailyCheckInShareProvider.overrideWith(() => share),
        userPreferencesSyncServiceProvider.overrideWithValue(sync),
        dailyShareActionsProvider.overrideWithValue(actions),
        shareCardApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showDailyCheckInShareDialog(context, ref),
                    child: const Text('manual'),
                  ),
                  TextButton(
                    onPressed: () => showDailyCheckInShareDialog(
                      context,
                      ref,
                      automatic: true,
                      canPresent: () => visible,
                    ),
                    child: const Text('automatic'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return share;
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets('小屏和横屏完整显示预览与操作：$size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, ready: await card(tester));
      await tester.tap(find.text('manual'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(RawImage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close));
      await drain(tester);
    });
  }

  testWidgets('未就绪自动跳过，手动只 toast，准备完成不会补弹', (tester) async {
    final share = await mount(tester);
    await tester.tap(find.text('automatic'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('manual'));
    await tester.pumpAndSettle();
    expect(find.text('今日卡片正在准备中，请稍后再试'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    share.setReady(await card(tester));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(
      prefs.getString(LocalUserPreferencesStore.dailyShareDateKey),
      isNull,
    );
    await drain(tester);
  });

  testWidgets('完整预览与按钮就绪后才打开，保存分享复用当前图片', (tester) async {
    await mount(tester, ready: await card(tester));
    await tester.tap(find.text('manual'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(RawImage), findsOneWidget);
    await tester.tap(find.text('保存图片'));
    await tester.pumpAndSettle();
    expect(actions.saves, 1);
    await tester.tap(find.text('分享'));
    await tester.pumpAndSettle();
    expect(actions.shares, 1);
    expect(api.shareCalls, 1);
    expect(
      prefs.getString(LocalUserPreferencesStore.dailyShareDateKey),
      '2026-11-08',
    );
    await tester.tap(find.byIcon(Icons.close));
    await drain(tester);
  });

  testWidgets('云端已展示当天不自动弹出，手动仍可打开', (tester) async {
    await prefs.setString(
      LocalUserPreferencesStore.dailyShareDateKey,
      '2026-11-08',
    );
    await mount(tester, ready: await card(tester));
    await tester.tap(find.text('automatic'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('manual'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await drain(tester);
  });

  testWidgets('关闭自动显示不弹窗或写标记，手动仍可打开', (tester) async {
    await mount(tester, ready: await card(tester));
    await container
        .read(learningSettingsProvider.notifier)
        .setAutoShowDailyShare(false);
    await tester.tap(find.text('automatic'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(
      prefs.getString(LocalUserPreferencesStore.dailyShareDateKey),
      isNull,
    );
    await tester.tap(find.text('manual'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await drain(tester);
  });

  testWidgets('换一张进行中显示加载态，完成后恢复换卡图标', (tester) async {
    final share = await mount(tester, ready: await card(tester));
    final change = Completer<bool>();
    share.changeOverride = change;
    await tester.tap(find.text('manual'));
    await tester.pumpAndSettle();
    final shuffleButton = find
        .descendant(of: find.byType(Dialog), matching: find.byType(IconButton))
        .first;
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(shuffleButton);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    change.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await drain(tester);
  });

  testWidgets('慢同步不阻塞自动展示，本地记录立即去重', (tester) async {
    final pending = Completer<void>();
    when(() => sync.onSessionChanged(any())).thenAnswer((_) => pending.future);
    await mount(tester, ready: await card(tester));
    await tester.tap(find.text('automatic'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(pending.isCompleted, isFalse);
    expect(
      prefs.getString(LocalUserPreferencesStore.dailyShareDateKey),
      '2026-11-08',
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('automatic'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    pending.complete();
    await drain(tester);
  });

  testWidgets('已离开首页时不展示或写入展示标记', (tester) async {
    await mount(tester, ready: await card(tester));
    visible = false;
    await tester.tap(find.text('automatic'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(
      prefs.getString(LocalUserPreferencesStore.dailyShareDateKey),
      isNull,
    );
    verifyNever(() => sync.onSessionChanged(any()));
  });

  testWidgets('未登录不打开分享；弹窗中登出会关闭并阻断操作', (tester) async {
    await mount(tester, ready: await card(tester));
    await tester.tap(find.text('manual'));
    await tester.pumpAndSettle();
    userId = '';
    container.invalidate(dailyShareUserIdProvider);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('manual'));
    await tester.pumpAndSettle();
    expect(find.text('请先登录后分享'), findsOneWidget);
    expect(actions.saves, 0);
    expect(actions.shares, 0);
    await drain(tester);
  });
}
