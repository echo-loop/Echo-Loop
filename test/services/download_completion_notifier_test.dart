import 'package:echo_loop/services/download_completion_notifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  late _MockNotificationsPlugin plugin;
  late List<String> calls;

  setUp(() {
    plugin = _MockNotificationsPlugin();
    calls = <String>[];
    when(() => plugin.show(any(), any(), any(), any())).thenAnswer((_) async {
      calls.add('show');
    });
  });

  MacOSDownloadCompletionNotifier buildNotifier({
    required bool isAppInForeground,
  }) {
    return MacOSDownloadCompletionNotifier(
      plugin: plugin,
      ensureInitialized: () async {
        calls.add('initialize');
      },
      isAppInForeground: () => isAppInForeground,
    );
  }

  test('应用在前台时不发送通知，也不初始化插件', () async {
    final notifier = buildNotifier(isAppInForeground: true);

    await notifier.notify(taskId: 'task-1', title: '下载完成', body: '听力素材');

    expect(calls, isEmpty);
    verifyNever(() => plugin.show(any(), any(), any(), any()));
  });

  test('应用不在前台时先初始化，再以 macOS 通知形式展示标题与正文', () async {
    final notifier = buildNotifier(isAppInForeground: false);

    await notifier.notify(taskId: 'task-1', title: '下载完成', body: '听力素材');

    expect(calls, ['initialize', 'show']);
    final captured = verify(
      () => plugin.show(captureAny(), '下载完成', '听力素材', captureAny()),
    ).captured;
    final id = captured[0] as int;
    // 必须落在下载专用区间，不能覆盖复习提醒的通知 ID。
    expect(id, inInclusiveRange(1000000, 1999999));
    final details = captured[1] as NotificationDetails;
    expect(details.macOS?.presentAlert, isTrue);
  });

  test('同一任务的通知 ID 稳定', () async {
    final notifier = buildNotifier(isAppInForeground: false);

    await notifier.notify(taskId: 'task-1', title: 'a', body: 'b');
    await notifier.notify(taskId: 'task-1', title: 'a', body: 'b');

    final ids = verify(() => plugin.show(captureAny(), any(), any(), any()))
        .captured;
    expect(ids[0], ids[1]);
  });

  test('系统拒绝展示时吞掉异常，不影响下载状态处理', () async {
    when(() => plugin.show(any(), any(), any(), any()))
        .thenThrow(PlatformException(code: 'denied'));
    final notifier = buildNotifier(isAppInForeground: false);

    await expectLater(
      notifier.notify(taskId: 'task-1', title: '下载完成', body: '听力素材'),
      completes,
    );
  });
}
