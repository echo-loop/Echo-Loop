import 'dart:async';
import 'dart:typed_data';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/daily_check_in_share_image.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:echo_loop/features/daily_goal_check_in/providers/daily_check_in_share_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/features/profile/domain/user_profile.dart';
import 'package:echo_loop/features/profile/providers/user_profile_provider.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show Locale;
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
  final renderedSeconds = <int>[];

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
    renderedSeconds.clear();
    when(() => service.studySessionRecorded)
        .thenAnswer((_) => const Stream.empty());
    when(() => service.isDailyGoalCheckedIn(any()))
        .thenAnswer((_) async => true);
  });
  tearDown(() {
    container.dispose();
  });

  void start({String? userId = 'user-1', bool pendingProfile = false}) {
    currentUserId = userId;
    container = ProviderContainer(
      overrides: [
        dailyShareUserIdProvider.overrideWith((ref) => currentUserId),
        dailyShareNowProvider.overrideWithValue(() => now),
        shareCardApiProvider.overrideWithValue(api),
        dailyShareBackgroundStoreProvider.overrideWithValue(
          ShareTestBackgroundStore(),
        ),
        studyTimeServiceProvider.overrideWithValue(service),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appSettingsProvider.overrideWith(ShareTestSettings.new),
        studyStatsProvider.overrideWith(ShareTestStats.new),
        userProfileProvider.overrideWith(
          pendingProfile ? _PendingProfile.new : ShareTestProfile.new,
        ),
        isChinaUserProvider.overrideWithValue(true),
        dailyShareImageGeneratorProvider.overrideWithValue(({
          required template,
          required data,
          required assets,
        }) async {
          renderCalls++;
          renderedSeconds.add(data.totalSeconds);
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

  test('准备期间登出不发布旧卡，公开背景可完成缓存', () async {
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
    expect(api.downloadCalls, 1);
    expect(renderCalls, 0);
    expect(container.read(dailyCheckInShareProvider).card, isNull);
  });

  test('无视觉变化复用成品，不重新渲染', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    await notifier.prepare(refresh: true);
    expect(api.todayCalls, 1);
    expect(api.downloadCalls, 1);
    expect(renderCalls, 1);
    expect(notifier.hasCurrentCard, isTrue);
  });

  test('刷新渲染期间及失败后保留可用成品', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    final first = container.read(dailyCheckInShareProvider).card;
    rendering = Completer<GeneratedDailyCheckInShareImage>();
    container.read(studyStatsProvider.notifier).state = const AsyncData(
      StudyStats(isTodayCheckedIn: true, todaySeconds: 3600, streak: 128),
    );
    await _until(() => renderCalls == 2);
    expect(notifier.hasCurrentCard, isTrue);
    expect(container.read(dailyCheckInShareProvider).card, same(first));
    rendering!.completeError(StateError('failed refresh'));
    await _until(
      () => container.read(dailyCheckInShareProvider).failure != null,
    );
    expect(notifier.hasCurrentCard, isTrue);
    expect(container.read(dailyCheckInShareProvider).card, same(first));
  });

  test('切换语言只重新合成，不请求今日模板、背景或已加载头像', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    container.read(userProfileProvider.notifier).state = AsyncData(
      UserProfile(
        userId: 'user-1',
        nickname: 'Tester',
        avatarUrl: 'https://example.com/avatar.png',
        updatedAt: now,
      ),
    );
    await _until(
      () =>
          api.downloadCalls == 2 &&
          renderCalls >= 2 &&
          notifier.hasCurrentCard &&
          !container.read(dailyCheckInShareProvider).isRefreshing,
    );
    final before = renderCalls;
    container.read(appSettingsProvider.notifier).state = const AppSettingsState(
      locale: Locale('en'),
    );
    await _until(() => renderCalls > before && notifier.hasCurrentCard);
    expect(api.todayCalls, 1);
    expect(api.downloadCalls, 2);
  });

  test('资料请求未完成也能生成首张卡片', () async {
    start(pendingProfile: true);
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare().timeout(const Duration(seconds: 2));
    expect(notifier.hasCurrentCard, isTrue);
    expect(renderCalls, 1);
  });

  test('显示分钟不变时跳过生成，跨分钟才生成', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    container.read(studyStatsProvider.notifier).state = const AsyncData(
      StudyStats(
        isTodayCheckedIn: true,
        todaySeconds: 1919,
        todayInputSeconds: 1200,
        todayOutputSeconds: 720,
        streak: 128,
      ),
    );
    await notifier.prepare(refresh: true);
    expect(renderCalls, 1);
    container.read(studyStatsProvider.notifier).state = const AsyncData(
      StudyStats(
        isTodayCheckedIn: true,
        todaySeconds: 1921,
        todayInputSeconds: 1200,
        todayOutputSeconds: 720,
        streak: 128,
      ),
    );
    await _until(() => renderCalls == 2);
  });

  test('连续变化只追加最新输入，丢弃生成中的过期结果', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    final oldCard = container.read(dailyCheckInShareProvider).card;
    rendering = Completer<GeneratedDailyCheckInShareImage>();
    container.read(studyStatsProvider.notifier).state = const AsyncData(
      StudyStats(isTodayCheckedIn: true, todaySeconds: 3600),
    );
    await _until(() => renderCalls == 2);
    container.read(studyStatsProvider.notifier).state = const AsyncData(
      StudyStats(isTodayCheckedIn: true, todaySeconds: 4000),
    );
    container.read(studyStatsProvider.notifier).state = const AsyncData(
      StudyStats(isTodayCheckedIn: true, todaySeconds: 5000),
    );
    final pending = rendering!;
    rendering = null;
    pending.complete(await tinyShareImage());
    expect(container.read(dailyCheckInShareProvider).card, same(oldCard));
    await _until(
      () =>
          renderCalls == 3 &&
          !container.read(dailyCheckInShareProvider).isRefreshing,
    );
    expect(renderedSeconds, [1920, 3600, 5000]);
  });

  test('渲染期间不影响显示的统计变化不会丢弃成品或追加生成', () async {
    rendering = Completer<GeneratedDailyCheckInShareImage>();
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    final pending = notifier.prepare();
    await _until(() => renderCalls == 1);
    container.read(studyStatsProvider.notifier).state = const AsyncData(
      StudyStats(
        isTodayCheckedIn: true,
        todaySeconds: 1919,
        todayInputSeconds: 1200,
        todayOutputSeconds: 720,
        streak: 128,
      ),
    );
    rendering!.complete(await tinyShareImage());
    await pending;
    expect(notifier.hasCurrentCard, isTrue);
    expect(renderCalls, 1);
  });

  test('头像下载不阻塞，占位成品可用，重复资料不重复下载', () async {
    start();
    final notifier = container.read(dailyCheckInShareProvider.notifier);
    await notifier.prepare();
    const url = 'https://example.com/avatar.png';
    final avatar = Completer<Uint8List>();
    api.pendingAvatar = avatar;
    final profile = UserProfile(
      userId: 'user-1',
      nickname: 'Tester',
      avatarUrl: url,
      updatedAt: now,
    );
    container.read(userProfileProvider.notifier).state = AsyncData(profile);
    await _until(() => api.downloadCalls == 2);
    await notifier.prepare(refresh: true);
    expect(notifier.hasCurrentCard, isTrue);
    await notifier.prepare(refresh: true);
    expect(api.downloadCalls, 2);
    avatar.complete(shareTestPng);
    await _until(() => renderCalls >= 3);
    await notifier.prepare(refresh: true);
    expect(api.downloadCalls, 2);
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
    expect(api.downloadCalls, 1);
    expect(renderCalls, 0);
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

class _PendingProfile extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() => Completer<UserProfile?>().future;
}
