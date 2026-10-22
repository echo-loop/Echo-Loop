import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/study_statistics_dao.dart';
import 'package:echo_loop/features/rating_prompt/data/rating_prompt_attempt_store.dart';
import 'package:echo_loop/features/rating_prompt/domain/rating_prompt_policy.dart';
import 'package:echo_loop/features/rating_prompt/services/in_app_review_gateway.dart';
import 'package:echo_loop/features/rating_prompt/services/rating_prompt_coordinator.dart';
import 'package:echo_loop/models/study_stage.dart';

class _FakeReviewGateway implements InAppReviewGateway {
  _FakeReviewGateway(this.onRequest);

  final Future<void> Function() onRequest;
  int requestCount = 0;

  @override
  Future<void> requestReview() async {
    requestCount++;
    await onRequest();
  }
}

/// 精确停在冷却落盘后，模拟用户在平台调用前离开页面。
class _DelayedAttemptStore extends RatingPromptAttemptStore {
  _DelayedAttemptStore(super.preferences);

  final recorded = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<bool> recordAttempt(DateTime time) async {
    final result = await super.recordAttempt(time);
    recorded.complete();
    await resume.future;
    return result;
  }
}

void main() {
  late AppDatabase database;
  late SharedPreferences preferences;

  final now = DateTime(2026, 10, 22, 12);
  final installTime = DateTime(2026, 10, 15, 11, 59);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() async => database.close());

  Future<void> addEffectiveDay(DateTime date) =>
      database.studyStatisticsDao.applyDelta(
        StudyStatisticsDelta(
          date: date,
          stage: StudyStage.retell,
          studyTimeMilliseconds: 10 * 60 * 1000,
        ),
      );

  PackageInfo packageInfo({DateTime? installedAt}) => PackageInfo(
    appName: 'Echo Loop',
    packageName: 'test.echo.loop',
    version: '1.0.0',
    buildNumber: '1',
    installerStore: 'com.android.vending',
    installTime: installedAt ?? installTime,
  );

  test('记录三个有效学习日后先持久化尝试时间，再请求系统评分', () async {
    await addEffectiveDay(DateTime(2026, 10, 20));
    await addEffectiveDay(DateTime(2026, 10, 21));
    await addEffectiveDay(DateTime(2026, 10, 22));
    final attemptStore = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {
      expect(attemptStore.readLastAttempt(), now);
    });
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: attemptStore,
      reviewGateway: gateway,
      isEnabled: () => true,
      storeInstallCheck: () => true,
      clock: () => now,
    );

    await coordinator.maybeRequest(
      RatingPromptEvent.retellCompleted,
      canPresent: () => true,
    );

    expect(gateway.requestCount, 1);
    expect(attemptStore.readLastAttempt(), now);
  });

  test('统计查询完成前离开页面，不请求且不记录冷却', () async {
    await addEffectiveDay(DateTime(2026, 10, 20));
    await addEffectiveDay(DateTime(2026, 10, 21));
    await addEffectiveDay(DateTime(2026, 10, 22));
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: store,
      reviewGateway: gateway,
      isEnabled: () => true,
      storeInstallCheck: () => true,
      clock: () => now,
    );
    var visible = true;
    final request = coordinator.maybeRequest(
      RatingPromptEvent.retellCompleted,
      canPresent: () => visible,
    );
    visible = false;
    await request;
    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), isNull);
  });

  for (final previous in <DateTime?>[null, DateTime(2026, 1, 1)]) {
    test('冷却落盘期间离开页面，恢复此前冷却 $previous', () async {
      await addEffectiveDay(DateTime(2026, 10, 20));
      await addEffectiveDay(DateTime(2026, 10, 21));
      await addEffectiveDay(DateTime(2026, 10, 22));
      if (previous != null) {
        await RatingPromptAttemptStore(preferences).recordAttempt(previous);
      }
      final store = _DelayedAttemptStore(preferences);
      final gateway = _FakeReviewGateway(() async {});
      final coordinator = RatingPromptCoordinator(
        packageInfo: packageInfo(),
        studyRecordDao: database.dailyStudyRecordDao,
        attemptStore: store,
        reviewGateway: gateway,
        isEnabled: () => true,
        storeInstallCheck: () => true,
        clock: () => now,
      );
      var visible = true;
      final request = coordinator.maybeRequest(
        RatingPromptEvent.retellCompleted,
        canPresent: () => visible,
      );
      await store.recorded.future;
      visible = false;
      store.resume.complete();
      await request;
      expect(gateway.requestCount, 0);
      expect(store.readLastAttempt(), previous);
    });
  }

  test('系统调用失败仍保留冷却，后续完成不会重复请求', () async {
    await addEffectiveDay(DateTime(2026, 10, 20));
    await addEffectiveDay(DateTime(2026, 10, 21));
    await addEffectiveDay(DateTime(2026, 10, 22));
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {
      throw StateError('native review unavailable');
    });
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: store,
      reviewGateway: gateway,
      isEnabled: () => true,
      storeInstallCheck: () => true,
      clock: () => now,
    );
    await coordinator.maybeRequest(
      RatingPromptEvent.retellCompleted,
      canPresent: () => true,
    );
    await coordinator.maybeRequest(
      RatingPromptEvent.shadowingCompleted,
      canPresent: () => true,
    );
    expect(gateway.requestCount, 1);
    expect(store.readLastAttempt(), now);
  });

  test('远程评分开关关闭时不记录冷却也不请求系统评分', () async {
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: store,
      reviewGateway: gateway,
      isEnabled: () => false,
      storeInstallCheck: () => true,
      clock: () => now,
    );

    await coordinator.maybeRequest(
      RatingPromptEvent.retellCompleted,
      canPresent: () => true,
    );

    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), isNull);
  });

  test('冷却落盘期间远程开关关闭时恢复此前冷却并跳过原生请求', () async {
    await addEffectiveDay(DateTime(2026, 10, 20));
    await addEffectiveDay(DateTime(2026, 10, 21));
    await addEffectiveDay(DateTime(2026, 10, 22));
    final previousAttempt = DateTime(2026, 1, 1);
    final baseStore = RatingPromptAttemptStore(preferences);
    await baseStore.recordAttempt(previousAttempt);
    final store = _DelayedAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});
    var enabled = true;
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: store,
      reviewGateway: gateway,
      isEnabled: () => enabled,
      storeInstallCheck: () => true,
      clock: () => now,
    );

    final request = coordinator.maybeRequest(
      RatingPromptEvent.retellCompleted,
      canPresent: () => true,
    );
    await store.recorded.future;
    enabled = false;
    store.resume.complete();
    await request;

    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), previousAttempt);
  });

  test('距上次请求不足 120 天时不再次调用系统评分', () async {
    final attemptStore = RatingPromptAttemptStore(preferences);
    await attemptStore.recordAttempt(now.subtract(const Duration(days: 119)));
    final gateway = _FakeReviewGateway(() async {});
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: attemptStore,
      reviewGateway: gateway,
      isEnabled: () => true,
      storeInstallCheck: () => true,
      clock: () => now,
    );

    await coordinator.maybeRequest(
      RatingPromptEvent.shadowingCompleted,
      canPresent: () => true,
    );

    expect(gateway.requestCount, 0);
  });

  test('上次请求当天的学习记录不计入新的有效学习日周期', () async {
    final attemptStore = RatingPromptAttemptStore(preferences);
    await attemptStore.recordAttempt(DateTime(2026, 6, 24, 10));
    await addEffectiveDay(DateTime(2026, 10, 20));
    await addEffectiveDay(DateTime(2026, 10, 21));
    final gateway = _FakeReviewGateway(() async {});
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: attemptStore,
      reviewGateway: gateway,
      isEnabled: () => true,
      storeInstallCheck: () => true,
      clock: () => now,
    );

    await coordinator.maybeRequest(
      RatingPromptEvent.retellCompleted,
      canPresent: () => true,
    );

    expect(gateway.requestCount, 0);
  });

  test('夏令时回拨日后从下一个自然日重新累计学习日', () async {
    final attemptStore = RatingPromptAttemptStore(preferences);
    await attemptStore.recordAttempt(DateTime(2026, 11, 1, 12));
    await addEffectiveDay(DateTime(2026, 11, 1));
    await addEffectiveDay(DateTime(2026, 11, 2));
    await addEffectiveDay(DateTime(2026, 11, 3));
    final gateway = _FakeReviewGateway(() async {});
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(installedAt: DateTime(2026, 10, 1)),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: attemptStore,
      reviewGateway: gateway,
      isEnabled: () => true,
      storeInstallCheck: () => true,
      clock: () => DateTime(2027, 3, 2, 12),
    );

    await coordinator.maybeRequest(
      RatingPromptEvent.retellCompleted,
      canPresent: () => true,
    );

    // 11 月 1 日的记录属于上次请求周期；次日和第三日只有两个有效学习日。
    expect(gateway.requestCount, 0);
  });
}
