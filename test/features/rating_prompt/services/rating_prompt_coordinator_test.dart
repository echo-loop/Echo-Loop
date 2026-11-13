import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/study_statistics_dao.dart';
import 'package:echo_loop/features/rating_prompt/data/rating_prompt_attempt_store.dart';
import 'package:echo_loop/features/rating_prompt/data/rating_prompt_task_completion_store.dart';
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
    database = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() async => database.close());

  /// 写入一天的学习时长并完成当日的每日目标打卡（与线上流程一致：先落库时长，再打卡）。
  Future<void> addCheckInDay(DateTime date) async {
    await database.studyStatisticsDao.applyDelta(
      StudyStatisticsDelta(
        date: date,
        stage: StudyStage.retell,
        studyTimeMilliseconds: 10 * 60 * 1000,
      ),
    );
    await database.studyStatisticsDao.markDailyGoalCheckIn(
      date: date,
      goalMinutes: 10,
    );
  }

  Future<void> addThreeCheckInDays() async {
    await addCheckInDay(DateTime(2026, 10, 20));
    await addCheckInDay(DateTime(2026, 10, 21));
    await addCheckInDay(DateTime(2026, 10, 22));
  }

  /// 在窗口内记录一次正常完成的任务（默认 1 分钟前）。
  Future<void> recordRecentCompletion({
    Duration ago = const Duration(minutes: 1),
  }) =>
      RatingPromptTaskCompletionStore(preferences)
          .recordCompletion(now.subtract(ago));

  PackageInfo packageInfo({DateTime? installedAt}) => PackageInfo(
    appName: 'Echo Loop',
    packageName: 'test.echo.loop',
    version: '1.0.0',
    buildNumber: '1',
    installerStore: 'com.android.vending',
    installTime: installedAt ?? installTime,
  );

  RatingPromptCoordinator coordinatorFor(
    RatingPromptAttemptStore store, {
    required _FakeReviewGateway gateway,
    PackageInfo? packageInfoOverride,
    bool remoteEnabled = true,
    bool storeInstall = true,
    DateTime? clockOverride,
  }) => RatingPromptCoordinator(
    packageInfo: packageInfoOverride ?? packageInfo(),
    studyRecordDao: database.dailyStudyRecordDao,
    attemptStore: store,
    taskCompletionStore: RatingPromptTaskCompletionStore(preferences),
    reviewGateway: gateway,
    isEnabled: () => remoteEnabled,
    storeInstallCheck: () => storeInstall,
    clock: () => clockOverride ?? now,
  );

  test('条件满足时先持久化冷却，再请求系统评分', () async {
    await recordRecentCompletion();
    await addThreeCheckInDays();
    final attemptStore = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {
      expect(attemptStore.readLastAttempt(), now);
    });
    final coordinator = coordinatorFor(attemptStore, gateway: gateway);

    await coordinator.maybeRequest(canPresent: () => true);

    expect(gateway.requestCount, 1);
    expect(attemptStore.readLastAttempt(), now);
  });

  test('条件未满足时不请求也不记录冷却', () async {
    await addCheckInDay(DateTime(2026, 10, 22));
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});

    await coordinatorFor(
      store,
      gateway: gateway,
    ).maybeRequest(canPresent: () => true);

    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), isNull);
  });

  test('检查前页面不可见时不请求', () async {
    await addThreeCheckInDays();
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});

    await coordinatorFor(
      store,
      gateway: gateway,
    ).maybeRequest(canPresent: () => false);

    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), isNull);
  });

  test('统计查询完成前离开页面，不请求且不记录冷却', () async {
    await addThreeCheckInDays();
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});
    final coordinator = coordinatorFor(store, gateway: gateway);
    var visible = true;

    final request = coordinator.maybeRequest(canPresent: () => visible);
    visible = false;
    await request;

    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), isNull);
  });

  for (final previous in <DateTime?>[null, DateTime(2026, 1, 1)]) {
    test('冷却落盘期间离开页面，恢复此前冷却 $previous', () async {
      await recordRecentCompletion();
      await addThreeCheckInDays();
      if (previous != null) {
        await RatingPromptAttemptStore(preferences).recordAttempt(previous);
      }
      final store = _DelayedAttemptStore(preferences);
      final gateway = _FakeReviewGateway(() async {});
      final coordinator = coordinatorFor(store, gateway: gateway);
      var visible = true;

      final request = coordinator.maybeRequest(canPresent: () => visible);
      await store.recorded.future;
      visible = false;
      store.resume.complete();
      await request;

      expect(gateway.requestCount, 0);
      expect(store.readLastAttempt(), previous);
    });
  }

  test('系统调用失败仍保留冷却，之后不会重复请求', () async {
    await recordRecentCompletion();
    await addThreeCheckInDays();
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {
      throw StateError('native review unavailable');
    });
    final coordinator = coordinatorFor(store, gateway: gateway);

    await coordinator.maybeRequest(canPresent: () => true);
    await coordinator.maybeRequest(canPresent: () => true);

    expect(gateway.requestCount, 1);
    expect(store.readLastAttempt(), now);
  });

  test('远程评分开关关闭时不记录冷却也不请求系统评分', () async {
    await addThreeCheckInDays();
    final store = RatingPromptAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});

    await coordinatorFor(
      store,
      gateway: gateway,
      remoteEnabled: false,
    ).maybeRequest(canPresent: () => true);

    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), isNull);
  });

  test('冷却落盘期间远程开关关闭时恢复此前冷却并跳过原生请求', () async {
    await recordRecentCompletion();
    await addThreeCheckInDays();
    final previousAttempt = DateTime(2026, 1, 1);
    await RatingPromptAttemptStore(preferences).recordAttempt(previousAttempt);
    final store = _DelayedAttemptStore(preferences);
    final gateway = _FakeReviewGateway(() async {});
    var enabled = true;
    final coordinator = RatingPromptCoordinator(
      packageInfo: packageInfo(),
      studyRecordDao: database.dailyStudyRecordDao,
      attemptStore: store,
      taskCompletionStore: RatingPromptTaskCompletionStore(preferences),
      reviewGateway: gateway,
      isEnabled: () => enabled,
      storeInstallCheck: () => true,
      clock: () => now,
    );

    final request = coordinator.maybeRequest(canPresent: () => true);
    await store.recorded.future;
    enabled = false;
    store.resume.complete();
    await request;

    expect(gateway.requestCount, 0);
    expect(store.readLastAttempt(), previousAttempt);
  });

  test('距上次请求不足 120 天时不再次请求', () async {
    await addThreeCheckInDays();
    final store = RatingPromptAttemptStore(preferences);
    await store.recordAttempt(now.subtract(const Duration(days: 119)));
    final gateway = _FakeReviewGateway(() async {});

    await coordinatorFor(
      store,
      gateway: gateway,
    ).maybeRequest(canPresent: () => true);

    expect(gateway.requestCount, 0);
  });

  test('上次请求当天的学习记录不计入新的有效学习日周期', () async {
    final store = RatingPromptAttemptStore(preferences);
    await store.recordAttempt(DateTime(2026, 6, 24, 10));
    await addCheckInDay(DateTime(2026, 10, 20));
    await addCheckInDay(DateTime(2026, 10, 21));
    final gateway = _FakeReviewGateway(() async {});

    await coordinatorFor(
      store,
      gateway: gateway,
    ).maybeRequest(canPresent: () => true);

    expect(gateway.requestCount, 0);
  });

  test('夏令时回拨日后从下一个自然日重新累计学习日', () async {
    final store = RatingPromptAttemptStore(preferences);
    await store.recordAttempt(DateTime(2026, 11, 1, 12));
    await addCheckInDay(DateTime(2026, 11, 1));
    await addCheckInDay(DateTime(2026, 11, 2));
    await addCheckInDay(DateTime(2026, 11, 3));
    final gateway = _FakeReviewGateway(() async {});

    await coordinatorFor(
      store,
      gateway: gateway,
      packageInfoOverride: packageInfo(installedAt: DateTime(2026, 10, 1)),
      clockOverride: DateTime(2027, 3, 2, 12),
    ).maybeRequest(canPresent: () => true);

    // 11 月 1 日的记录属于上次请求周期；次日和第三日只有两个有效学习日。
    expect(gateway.requestCount, 0);
  });

  group('inspect', () {
    test('没有任务完成记录时结论为最近没有完成任务', () async {
      await addThreeCheckInDays();

      final status = await coordinatorFor(
        RatingPromptAttemptStore(preferences),
        gateway: _FakeReviewGateway(() async {}),
      ).inspect();

      expect(status.lastTaskCompletedAt, isNull);
      expect(status.blockReason, RatingPromptBlockReason.noRecentTask);
    });

    test('任务完成超过 10 分钟不允许请求，恰好 10 分钟内允许', () async {
      await addThreeCheckInDays();
      final store = RatingPromptAttemptStore(preferences);
      final gateway = _FakeReviewGateway(() async {});

      await recordRecentCompletion(ago: const Duration(minutes: 11));
      final stale = await coordinatorFor(store, gateway: gateway).inspect();
      await recordRecentCompletion(ago: const Duration(minutes: 10));
      final boundary = await coordinatorFor(store, gateway: gateway).inspect();

      expect(stale.blockReason, RatingPromptBlockReason.noRecentTask);
      expect(boundary.blockReason, isNull);
    });

    test('条件全部满足时结论为可请求，且不写冷却', () async {
      await recordRecentCompletion();
      await addThreeCheckInDays();
      final store = RatingPromptAttemptStore(preferences);
      final gateway = _FakeReviewGateway(() async {});

      final status = await coordinatorFor(store, gateway: gateway).inspect();

      expect(status.checkInDays, 3);
      expect(status.cooldownRemaining, isNull);
      expect(status.blockReason, isNull);
      expect(gateway.requestCount, 0);
      expect(store.readLastAttempt(), isNull);
    });

    test('安装未满 7 天时结论为安装时间不足', () async {
      await addThreeCheckInDays();
      final status = await coordinatorFor(
        RatingPromptAttemptStore(preferences),
        gateway: _FakeReviewGateway(() async {}),
        packageInfoOverride: packageInfo(installedAt: DateTime(2026, 10, 16)),
      ).inspect();

      expect(status.installAge!.inDays, 6);
      expect(status.blockReason, RatingPromptBlockReason.installTooRecent);
    });

    test('冷却期内返回剩余时长与冷却结论', () async {
      await addThreeCheckInDays();
      final store = RatingPromptAttemptStore(preferences);
      await store.recordAttempt(DateTime(2026, 10, 20, 12));

      final status = await coordinatorFor(
        store,
        gateway: _FakeReviewGateway(() async {}),
      ).inspect();

      expect(status.cooldownRemaining!.inDays, 118);
      expect(status.blockReason, RatingPromptBlockReason.inCooldown);
    });

    test('远程开关关闭或非商店安装时给出对应结论', () async {
      await addThreeCheckInDays();

      final remoteOff = await coordinatorFor(
        RatingPromptAttemptStore(preferences),
        gateway: _FakeReviewGateway(() async {}),
        remoteEnabled: false,
      ).inspect();
      final notStore = await coordinatorFor(
        RatingPromptAttemptStore(preferences),
        gateway: _FakeReviewGateway(() async {}),
        storeInstall: false,
      ).inspect();

      expect(remoteOff.blockReason, RatingPromptBlockReason.remoteDisabled);
      expect(notStore.blockReason, RatingPromptBlockReason.notStoreInstall);
      expect(notStore.installerStore, 'com.android.vending');
    });

    test('快照结论与实际请求判定一致：打卡天数不足时两者都不请求', () async {
      await addCheckInDay(DateTime(2026, 10, 21));
      await addCheckInDay(DateTime(2026, 10, 22));
      final gateway = _FakeReviewGateway(() async {});
      final coordinator = coordinatorFor(
        RatingPromptAttemptStore(preferences),
        gateway: gateway,
      );

      final status = await coordinator.inspect();
      await coordinator.maybeRequest(canPresent: () => true);

      expect(status.checkInDays, 2);
      expect(status.blockReason, RatingPromptBlockReason.notEnoughCheckInDays);
      expect(gateway.requestCount, 0);
    });
  });
}
