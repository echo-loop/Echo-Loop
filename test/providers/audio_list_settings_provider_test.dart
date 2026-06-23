// 音频列表排序设置 Provider 测试
//
// 验证排序方式的持久化：字符串解析回退、setSortType 写入。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/providers/audio_list_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('audioSortTypeFromName 解析', () {
    test('合法字符串解析为对应枚举', () {
      expect(audioSortTypeFromName('nameAsc'), AudioSortType.nameAsc);
      expect(
        audioSortTypeFromName('originalDateAsc'),
        AudioSortType.originalDateAsc,
      );
    });

    test('null（未存过）回退到默认 dateDesc', () {
      expect(audioSortTypeFromName(null), AudioSortType.dateDesc);
    });

    test('非法字符串回退到默认 dateDesc', () {
      expect(audioSortTypeFromName('garbage'), AudioSortType.dateDesc);
    });
  });

  group('AudioListSettings.setSortType 持久化', () {
    test('同步更新状态并写入 prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(audioListSettingsProvider.notifier)
          .setSortType(AudioSortType.originalDateAsc);

      expect(
        container.read(audioListSettingsProvider).sortType,
        AudioSortType.originalDateAsc,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('audio_list_sort_type'), 'originalDateAsc');
    });
  });
}
