import 'package:echo_loop/services/system_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemProxyEndpoint.fromChannelValue', () {
    test('解析原生侧返回的 host 与 port', () {
      final endpoint = SystemProxyEndpoint.fromChannelValue({
        'host': '127.0.0.1',
        'port': 7897,
      });

      expect(
        endpoint,
        const SystemProxyEndpoint(host: '127.0.0.1', port: 7897),
      );
    });

    test('未启用手动代理（原生侧返回 null）时视为无代理', () {
      expect(SystemProxyEndpoint.fromChannelValue(null), isNull);
    });

    test('缺少地址或端口非法时视为无代理，不把残缺配置当作有效代理', () {
      expect(SystemProxyEndpoint.fromChannelValue({'port': 7897}), isNull);
      expect(
        SystemProxyEndpoint.fromChannelValue({'host': '', 'port': 7897}),
        isNull,
      );
      expect(
        SystemProxyEndpoint.fromChannelValue({'host': '127.0.0.1', 'port': 0}),
        isNull,
      );
      expect(
        SystemProxyEndpoint.fromChannelValue({
          'host': '127.0.0.1',
          'port': 70000,
        }),
        isNull,
      );
    });
  });
}
