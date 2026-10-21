import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/analytics/channels/log_only_channel.dart';
import 'package:echo_loop/services/app_logger.dart';

void main() {
  group('LogOnlyChannel', () {
    late LogOnlyChannel channel;

    setUp(() {
      channel = LogOnlyChannel();
      AppLogger.instance.clear();
    });

    test('initialize 记录日志', () async {
      await channel.initialize();

      final entries = AppLogger.instance.entries;
      expect(entries, isNotEmpty);
      expect(entries.last.tag, 'Analytics');
      expect(entries.last.message, contains('LogOnlyChannel initialized'));
    });

    test('logEvent 记录事件名和参数', () async {
      await channel.logEvent('test_event', {'key': 'value', 'num': 42});

      final entries = AppLogger.instance.entries;
      expect(entries, isNotEmpty);
      expect(entries.last.message, contains('test_event'));
      expect(entries.last.message, contains('key=value'));
      expect(entries.last.message, contains('num=42'));
    });

    test('logEvent 无参数时不显示花括号', () async {
      await channel.logEvent('simple_event', null);

      final entries = AppLogger.instance.entries;
      expect(entries.last.message, 'Event: simple_event');
    });

    test('setUserId 记录日志', () async {
      await channel.setUserId('user-123');

      final entries = AppLogger.instance.entries;
      expect(entries.last.message, 'setUserId: user-123');
    });

    test('setUserProperty 记录日志', () async {
      await channel.setUserProperty('locale', 'zh');

      final entries = AppLogger.instance.entries;
      expect(entries.last.message, 'setUserProperty: locale=zh');
    });

    test('registerSuperProperties 记录所有 key=value', () async {
      await channel.registerSuperProperties({
        'notification_status': 'granted',
        'network_status': 'not_applicable',
      });

      final entries = AppLogger.instance.entries;
      expect(entries.last.message, contains('registerSuperProperties'));
      expect(entries.last.message, contains('notification_status=granted'));
      expect(entries.last.message, contains('network_status=not_applicable'));
    });
  });
}
