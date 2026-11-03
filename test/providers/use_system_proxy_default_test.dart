import 'package:echo_loop/providers/developer_options_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('下载使用系统代理的默认值', () {
    test('从未保存过设置时默认开启', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await readUseSystemProxyForDownloads(), isTrue);
    });

    test('用户关闭后保持关闭，不会被默认值覆盖', () async {
      SharedPreferences.setMockInitialValues({
        'developer_use_system_proxy': false,
      });

      expect(await readUseSystemProxyForDownloads(), isFalse);
    });

    test('开关在首帧即显示默认开启', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(useSystemProxyForDownloadsProvider), isTrue);
    });
  });
}
