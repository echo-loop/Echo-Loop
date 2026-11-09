import 'dart:async';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/daily_check_in_share_image.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:echo_loop/features/daily_goal_check_in/providers/daily_check_in_share_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/features/profile/providers/user_profile_provider.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../share_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShareTestApi api;
  late ShareTestService service;
  late ProviderContainer container;
  late SharedPreferences prefs;
  var now = DateTime(2026, 11, 8, 12);
  Completer<GeneratedDailyCheckInShareImage>? rendering;
  Object? renderFailure;
  var renderCalls = 0;
  String? currentUserId = 'user-1';

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 8, 12);
    api = ShareTestApi();
    service = ShareTestService();
    rendering = null;
    renderFailure = null;
    renderCalls = 0;
    when(() => service.studySessionRecorded)
        .thenAnswer((_) => const Stream.empty());
    when(() => service.isDailyGoalCheckedIn(any()))
        .thenAnswer((_) async => true);
  });
  tearDown(() {
    container.dispose();
  });

  void start({String? userId = 'user-1'}) {
    currentUserId = userId;
    container = ProviderContainer(
      overrides: [
        dailyShareUserIdProvider.overrideWith((ref) => currentUserId),
        dailyShareNowProvider.overrideWithValue(() => now),
        shareCardApiProvider.overrideWithValue(api),
        studyTimeServiceProvider.overrideWithValue(service),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appSettingsProvider.overrideWith(ShareTestSettings.new),
        studyStatsProvider.overrideWith(ShareTestStats.new),
        userProfileProvider.overrideWith(ShareTestProfile.new),
        isChinaUserProvider.overrideWithValue(true),
        dailyShareImageGeneratorProvider.overrideWithValue(({
          required template,
          required data,
          required assets,
        }) async {
          renderCalls++;
          final error = renderFailure;
          if (error != null) throw error;
          return rendering?.future ?? tinyShareImage();
        }),
      ],
    );
    container.listen(dailyCheckInShareProvider, (_, _) {});
  }

  test('未登录不请求模板或图片', () async {
    start(userId: null);
    await container.read(dailyCheckInShareProvider.notifier).prepare();
    expect(api.todayCalls, 0);
    expect(renderCalls, 0);
  });

  test('下载后仍需等待渲染成功，重复调用共用准备任务', () async {
    rendering = Completer<GeneratedDailyCheckInShareImage>();
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    final first = notifier.prepare();
    final second = notifier.prepare();
    await _until(() => renderCalls == 1);
    expect(api.downloadCalls, 1);
    expect(notifier.hasCurrentCard, isFalse);
    rendering!.complete(await tinyShareImage());
    await Future.wait([first, second]);
    expect(notifier.hasCurrentCard, isTrue);
    expect(api.todayCalls, 1);
  });

  test('渲染失败不进入就绪状态，可以显式重试', () async {
    renderFailure = StateError('render failed');
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    expect(notifier.hasCurrentCard, isFalse);
    expect(
      container.read(dailyCheckInShareProvider).status,
      DailyShareStatus.failed,
    );
    renderFailure = null;
    await notifier.prepare();
    expect(notifier.hasCurrentCard, isTrue);
  });

  test('换卡失败保留原图，成功后替换整张图片', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    final first = container.read(dailyCheckInShareProvider).card;
    api.randomFailure = StateError('offline');
    await expectLater(notifier.changeCard(), throwsStateError);
    expect(container.read(dailyCheckInShareProvider).card, same(first));
    api.randomFailure = null;
    expect(await notifier.changeCard(), isTrue);
    expect(
      container.read(dailyCheckInShareProvider).card!.template.id,
      isNot(first!.template.id),
    );
  });

  test('准备期间登出，丢弃旧响应且不再下载用户图片', () async {
    api.pendingTemplate = Completer<ShareCardTemplate>();
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    final pending = notifier.prepare();
    await _until(() => api.todayCalls == 1);
    currentUserId = null;
    container.invalidate(dailyShareUserIdProvider);
    container.read(dailyCheckInShareProvider);
    api.pendingTemplate!.complete(api.template);
    await pending;
    expect(api.downloadCalls, 0);
    expect(container.read(dailyCheckInShareProvider).card, isNull);
  });

  test('更新统计时复用当日背景，只重新渲染', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    await notifier.prepare(refresh: true);
    expect(api.todayCalls, 1);
    expect(api.downloadCalls, 1);
    expect(renderCalls, 2);
    expect(notifier.hasCurrentCard, isTrue);
  });

  test('准备期间跨日或清理缓存，不接受过期响应', () async {
    api.pendingTemplate = Completer<ShareCardTemplate>();
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    final pending = notifier.prepare();
    await _until(() => api.todayCalls == 1);
    now = DateTime(2026, 11, 9);
    notifier.clear();
    api.pendingTemplate!.complete(api.template);
    await pending;
    expect(api.downloadCalls, 0);
    expect(notifier.hasCurrentCard, isFalse);
    expect(container.read(dailyCheckInShareProvider).card, isNull);
  });
}

Future<void> _until(bool Function() predicate) async {
  for (var i = 0; i < 100 && !predicate(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(predicate(), isTrue);
}
