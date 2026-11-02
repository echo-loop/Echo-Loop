import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:echo_loop/services/notification_tap_router_bridge.dart';
import 'package:echo_loop/services/review_reminder_service.dart';
import 'package:echo_loop/services/review_reminder_texts.dart';
import 'package:echo_loop/services/review_reminder_time_calculator.dart';

// --- Mocks ---

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockReviewReminderTimeCalculator extends Mock
    implements ReviewReminderTimeCalculator {}

class FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}

class FakeTZDateTime extends Fake implements tz.TZDateTime {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(FakeTZDateTime());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late NotificationTapRouterBridge bridge;
  late MockReviewReminderTimeCalculator mockTimeCalc;

  /// 创建 service 并 stub plugin（含指定的 launch payload）
  ReviewReminderService createService({
    String? launchPayload,
    DateTime Function()? systemNow,
    ReviewReminderTexts Function()? resolveTexts,
  }) {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    bridge = NotificationTapRouterBridge();
    mockTimeCalc = MockReviewReminderTimeCalculator();

    // Stub init / permissions
    when(
      () => mockPlugin.initialize(
        any(),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
        onDidReceiveBackgroundNotificationResponse: any(
          named: 'onDidReceiveBackgroundNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);

    // Stub launch details
    when(() => mockPlugin.getNotificationAppLaunchDetails()).thenAnswer(
      (_) async => launchPayload != null
          ? NotificationAppLaunchDetails(
              true,
              notificationResponse: NotificationResponse(
                notificationResponseType:
                    NotificationResponseType.selectedNotification,
                payload: launchPayload,
              ),
            )
          : null,
    );

    when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
    when(
      () => mockPlugin.pendingNotificationRequests(),
    ).thenAnswer((_) async => <PendingNotificationRequest>[]);
    when(
      () => mockPlugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
    when(
      () => mockPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
    when(
      () => mockPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);

    // Stub FlutterTimezone
    const channel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getLocalTimezone') return 'America/New_York';
          return null;
        });

    return ReviewReminderService(
      plugin: mockPlugin,
      bridge: bridge,
      timeCalculator: mockTimeCalc,
      supportsSystemNotificationOverride: true, // 强制启用通知支持（CI 在 Ubuntu 上运行）
      systemNow: systemNow,
      resolveTexts: resolveTexts,
    );
  }

  group('本地化文案', () {
    ReviewReminderTexts frenchTexts() => ReviewReminderTexts(
      savedBodies: List.filled(10, 'Saved body'),
      perAudioBody: (audioName, round) => 'FR $audioName round $round',
      localeTag: 'fr',
    );

    PerAudioReminderInfo oneReminder() => PerAudioReminderInfo(
      audioId: 'audio-1',
      audioName: 'Test Audio 1',
      triggerAt: DateTime.now().add(const Duration(hours: 6)),
      reviewRound: 1,
    );

    /// 读取最近一次 zonedSchedule 的正文参数
    List<String> scheduledBodies(int count) {
      final captured = verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          captureAny(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).captured;
      expect(captured, hasLength(count));
      return captured.cast<String>();
    }

    test('单条复习提醒正文使用注入的语言文案', () async {
      final service = createService(resolveTexts: frenchTexts);

      await service.syncPerAudioReminders([oneReminder()]);

      expect(scheduledBodies(1), ['FR Test Audio 1 round 1']);
    });

    test('收藏复习提醒正文使用注入的语言文案', () async {
      final service = createService(resolveTexts: frenchTexts);
      when(() => mockTimeCalc.nextTriggerAt(any()))
          .thenReturn(DateTime(2026, 3, 22, 20, 0));

      await service.syncSavedReviewReminder(hasSavedContent: true);

      expect(scheduledBodies(15), everyElement('Saved body'));
    });

    test('文案解析失败时回退英文且仍然调度（不抛异常）', () async {
      final service = createService(
        resolveTexts: () => throw StateError('unsupported locale'),
      );

      await service.syncPerAudioReminders([oneReminder()]);

      expect(scheduledBodies(1).single, contains('Review round 1'));
    });

    test('语言变化时即使提醒列表不变也会重新调度', () async {
      var texts = ReviewReminderTexts(
        savedBodies: List.filled(10, 'Saved body'),
        perAudioBody: (audioName, round) => 'EN $audioName',
        localeTag: 'en',
      );
      final service = createService(resolveTexts: () => texts);
      final reminders = [oneReminder()];

      await service.syncPerAudioReminders(reminders);
      texts = frenchTexts();
      await service.syncPerAudioReminders(reminders);

      expect(scheduledBodies(2), [
        'EN Test Audio 1',
        'FR Test Audio 1 round 1',
      ]);
    });
  });

  group('syncPerAudioReminders', () {
    test('调度通知数量等于传入 reminders 数', () async {
      final service = createService();
      final reminders = [
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test Audio 1',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
        PerAudioReminderInfo(
          audioId: 'audio-2',
          audioName: 'Test Audio 2',
          triggerAt: DateTime.now().add(const Duration(days: 1)),
          reviewRound: 2,
        ),
      ];

      await service.syncPerAudioReminders(reminders);

      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).called(2);
    });

    test('使用非精确 Android 调度，避免复习提醒依赖 exact alarm 权限', () async {
      final service = createService();

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test Audio',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);

      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('跳过对真实系统时间已过期的单条提醒', () async {
      final service = createService();

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'expired-audio',
          audioName: 'Expired Audio',
          triggerAt: DateTime.now().subtract(const Duration(minutes: 1)),
          reviewRound: 1,
        ),
      ]);

      verifyNever(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('过期提醒被过滤为空时仍清理残留 per-audio 通知', () async {
      final service = createService();

      when(() => mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          const PendingNotificationRequest(
            5000,
            'Echo Loop',
            'old',
            'old_payload',
          ),
        ],
      );

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'expired-audio',
          audioName: 'Expired Audio',
          triggerAt: DateTime.now().subtract(const Duration(minutes: 1)),
          reviewRound: 1,
        ),
      ]);

      verifyNever(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      );
      verify(() => mockPlugin.cancel(5000)).called(1);
    });

    test('调度前再次跳过异步等待期间过期的单条提醒', () async {
      var tick = 0;
      final baseTime = DateTime(2026, 6, 9, 12);
      final service = createService(
        systemNow: () {
          tick += 1;
          return tick == 1
              ? baseTime
              : baseTime.add(const Duration(minutes: 2));
        },
      );

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'late-expired-audio',
          audioName: 'Late Expired Audio',
          triggerAt: baseTime.add(const Duration(minutes: 1)),
          reviewRound: 1,
        ),
      ]);

      verifyNever(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('保留 iOS 通知详情，避免 Android 调度调整影响 iOS', () async {
      final service = createService();

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-ios',
          audioName: 'iOS Audio',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);

      final captured = verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          captureAny(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).captured;
      final details = captured.single as NotificationDetails;
      expect(details.iOS, isA<DarwinNotificationDetails>());
      expect(details.macOS, isA<DarwinNotificationDetails>());
    });

    test('快照不变时跳过调度', () async {
      final service = createService();
      final triggerAt = DateTime.now().add(const Duration(hours: 6));
      final reminders = [
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test Audio 1',
          triggerAt: triggerAt,
          reviewRound: 1,
        ),
      ];

      await service.syncPerAudioReminders(reminders);
      clearInteractions(mockPlugin);

      // 重新 stub（clearInteractions 清除 stub）
      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
      when(
        () => mockPlugin.pendingNotificationRequests(),
      ).thenAnswer((_) async => <PendingNotificationRequest>[]);
      when(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      // 相同 reminders 再次同步
      await service.syncPerAudioReminders(reminders);

      verifyNever(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('快照变化时先 cancel 旧通知再调度新通知', () async {
      final service = createService();

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test 1',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);
      clearInteractions(mockPlugin);
      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
      when(
        () => mockPlugin.pendingNotificationRequests(),
      ).thenAnswer((_) async => <PendingNotificationRequest>[]);
      when(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-2',
          audioName: 'Test 2',
          triggerAt: DateTime.now().add(const Duration(days: 1)),
          reviewRound: 2,
        ),
      ]);

      // cancel 旧的 audio-1 通知 ID
      verify(() => mockPlugin.cancel(any())).called(1);
      // 调度新的 audio-2
      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('payload 包含 open_audio: 前缀和 audioId', () async {
      final service = createService();
      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'my-audio-123',
          audioName: 'Test',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);

      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: 'open_audio:my-audio-123',
        ),
      ).called(1);
    });

    test('空列表清除旧通知', () async {
      final service = createService();
      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);
      clearInteractions(mockPlugin);
      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
      when(
        () => mockPlugin.pendingNotificationRequests(),
      ).thenAnswer((_) async => <PendingNotificationRequest>[]);

      await service.syncPerAudioReminders([]);

      verify(() => mockPlugin.cancel(any())).called(1);
    });

    test('清除系统中残留的 per-audio 通知（跨重启场景）', () async {
      final service = createService();

      // 模拟系统中已有一个 per-audio 范围内的 pending 通知（上次启动遗留）
      when(() => mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          const PendingNotificationRequest(
            5000,
            'Echo Loop',
            'old',
            'old_payload',
          ),
        ],
      );

      // 同步空列表——应该 cancel 掉残留的 ID 5000
      await service.syncPerAudioReminders([]);

      verify(() => mockPlugin.cancel(5000)).called(1);
    });

    test('不误删 per-audio 范围外的通知', () async {
      final service = createService();

      // 模拟系统中有 daily reminder（ID 1001，范围外）
      when(() => mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          const PendingNotificationRequest(
            1001,
            'Echo Loop',
            'daily',
            'open_study_tasks',
          ),
        ],
      );

      await service.syncPerAudioReminders([]);

      // 不应 cancel ID 1001
      verifyNever(() => mockPlugin.cancel(1001));
    });
  });

  group('cancelAllPerAudioReminders', () {
    test('取消系统中所有 per-audio 范围内的通知', () async {
      final service = createService();

      // 模拟系统中有 per-audio 通知
      when(() => mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          const PendingNotificationRequest(
            3000,
            'Echo Loop',
            'a',
            'open_audio:a',
          ),
          const PendingNotificationRequest(
            4000,
            'Echo Loop',
            'b',
            'open_audio:b',
          ),
          const PendingNotificationRequest(
            1001,
            'Echo Loop',
            'daily',
            'open_study_tasks',
          ),
        ],
      );

      await service.cancelAllPerAudioReminders();

      // 应 cancel per-audio 范围内的 3000 和 4000，不 cancel 1001
      verify(() => mockPlugin.cancel(3000)).called(1);
      verify(() => mockPlugin.cancel(4000)).called(1);
      verifyNever(() => mockPlugin.cancel(1001));
    });

    test('cancel 后快照重置，下次 syncPerAudioReminders 可重新调度', () async {
      final service = createService();
      final reminders = [
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ];

      // 首次调度
      await service.syncPerAudioReminders(reminders);
      clearInteractions(mockPlugin);

      // 重新 stub
      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
      when(
        () => mockPlugin.pendingNotificationRequests(),
      ).thenAnswer((_) async => <PendingNotificationRequest>[]);
      when(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      // cancelAll 重置快照
      await service.cancelAllPerAudioReminders();
      clearInteractions(mockPlugin);

      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
      when(
        () => mockPlugin.pendingNotificationRequests(),
      ).thenAnswer((_) async => <PendingNotificationRequest>[]);
      when(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      // 相同 reminders 再次同步——应该正常调度（快照已清空）
      await service.syncPerAudioReminders(reminders);

      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });
  });

  group('updateTimeCalculator', () {
    test('更新后 syncSavedReviewReminder 使用新的时间计算器', () async {
      final service = createService();

      // 初始 timeCalc
      when(
        () => mockTimeCalc.nextTriggerAt(any()),
      ).thenReturn(DateTime(2026, 3, 22, 20, 0));

      await service.syncSavedReviewReminder(hasSavedContent: true);

      // 更换为新的计算器
      final newCalc = FixedTimeReminderCalculator(hour: 8, minute: 30);
      service.updateTimeCalculator(newCalc);

      await service.syncSavedReviewReminder(hasSavedContent: true);

      // 15 天 × 2 次 = 30 次 zonedSchedule
      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).called(30);
    });
  });

  group('syncSavedReviewReminder', () {
    test('收藏复习提醒使用非精确 Android 调度', () async {
      final service = createService();
      when(
        () => mockTimeCalc.nextTriggerAt(any()),
      ).thenReturn(DateTime(2026, 3, 22, 20, 0));

      await service.syncSavedReviewReminder(hasSavedContent: true);

      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: any(named: 'payload'),
        ),
      ).called(15);
    });

    test('收藏复习提醒保留 iOS 通知详情', () async {
      final service = createService();
      when(
        () => mockTimeCalc.nextTriggerAt(any()),
      ).thenReturn(DateTime(2026, 3, 22, 20, 0));

      await service.syncSavedReviewReminder(hasSavedContent: true);

      final captured = verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          captureAny(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).captured;
      final details = captured.first as NotificationDetails;
      expect(details.iOS, isA<DarwinNotificationDetails>());
      expect(details.macOS, isA<DarwinNotificationDetails>());
    });
  });

  group('NotificationIntent payload 解析（通过 launch payload）', () {
    test('open_favorites payload 产生 OpenFavorites', () async {
      final service = createService(launchPayload: 'open_favorites');

      // 先注册监听，再 init（init 内 _handlePayload 同步发射）
      final intents = <NotificationIntent>[];
      bridge.intents.listen(intents.add);

      await service.initPlugin();

      // init 可能因为 FlutterTimezone 失败而 catch——检查 pending intent 作为备选
      if (intents.isEmpty) {
        final pending = bridge.takePendingIntent();
        expect(pending, isA<OpenFavorites>());
      } else {
        expect(intents, hasLength(1));
        expect(intents.first, isA<OpenFavorites>());
      }
    });

    test('旧版 open_study_tasks payload 兼容为 OpenFavorites', () async {
      final service = createService(launchPayload: 'open_study_tasks');

      final intents = <NotificationIntent>[];
      bridge.intents.listen(intents.add);

      await service.initPlugin();

      if (intents.isEmpty) {
        final pending = bridge.takePendingIntent();
        expect(pending, isA<OpenFavorites>());
      } else {
        expect(intents, hasLength(1));
        expect(intents.first, isA<OpenFavorites>());
      }
    });

    test('open_audio:<id> payload 产生 OpenAudioLearningPlan', () async {
      final service = createService(launchPayload: 'open_audio:abc-123');

      final intents = <NotificationIntent>[];
      bridge.intents.listen(intents.add);

      await service.initPlugin();

      if (intents.isEmpty) {
        final pending = bridge.takePendingIntent();
        expect(pending, isA<OpenAudioLearningPlan>());
        expect((pending! as OpenAudioLearningPlan).audioId, equals('abc-123'));
      } else {
        expect(intents, hasLength(1));
        expect(intents.first, isA<OpenAudioLearningPlan>());
        expect(
          (intents.first as OpenAudioLearningPlan).audioId,
          equals('abc-123'),
        );
      }
    });

    test('null payload 不产生任何意图', () async {
      final service = createService(launchPayload: null);

      final intents = <NotificationIntent>[];
      bridge.intents.listen(intents.add);

      await service.initPlugin();

      expect(intents, isEmpty);
      expect(bridge.takePendingIntent(), isNull);
    });
  });

  group('initPlugin 不触发权限请求', () {
    test('initPlugin 不去 resolve 平台实现以请求权限', () async {
      final service = createService();

      await service.initPlugin();

      // 行为契约：initPlugin 必须保持 silent，不应主动 resolve 出 plugin
      // 来调任何 request*。mock 默认 stub 返回 null，可用作回归保护。
      verifyNever(
        () => mockPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >(),
      );
      verifyNever(
        () => mockPlugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >(),
      );
      verifyNever(
        () => mockPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      );
    });

    test('initPlugin 使用 Darwin request* 全 false 的 settings', () async {
      final service = createService();

      await service.initPlugin();

      // 捕获实际传给 initialize 的 settings
      final captured = verify(
        () => mockPlugin.initialize(
          captureAny(),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
          onDidReceiveBackgroundNotificationResponse: any(
            named: 'onDidReceiveBackgroundNotificationResponse',
          ),
        ),
      ).captured;
      expect(captured, isNotEmpty);
      final settings = captured.single as InitializationSettings;
      final ios = settings.iOS;
      final macos = settings.macOS;
      expect(ios?.requestAlertPermission, isFalse);
      expect(ios?.requestBadgePermission, isFalse);
      expect(ios?.requestSoundPermission, isFalse);
      expect(macos?.requestAlertPermission, isFalse);
      expect(macos?.requestBadgePermission, isFalse);
      expect(macos?.requestSoundPermission, isFalse);
    });
  });
}
