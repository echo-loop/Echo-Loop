// 学习内容文字偏好 Provider 测试
//
// 验证：启动读取已存字号、修改即时生效并持久化。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/providers/reading_text_prefs_provider.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('首帧同步读出已存偏好', () async {
    final container = await _container({'reading_font_scale': 1.3});

    expect(
      container.read(readingTextPrefsNotifierProvider),
      const ReadingTextPrefs(fontScale: 1.3),
    );
  });

  test('修改字号即时生效、吸附档位并持久化', () async {
    final container = await _container({});

    await container
        .read(readingTextPrefsNotifierProvider.notifier)
        .setFontScale(1.31);

    expect(container.read(readingTextPrefsNotifierProvider).fontScale, 1.3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('reading_font_scale'), 1.3);
  });

  test('未注入 SharedPreferences 时异步加载已存偏好', () async {
    SharedPreferences.setMockInitialValues({'reading_font_scale': 1.5});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // autoDispose：保持订阅，模拟页面持续监听。
    final sub = container.listen(readingTextPrefsNotifierProvider, (_, _) {});
    addTearDown(sub.close);

    expect(sub.read().fontScale, 1.0);
    await pumpEventQueue();
    expect(sub.read().fontScale, 1.5);
  });
}
