// 字幕文字偏好 Provider 测试
//
// 验证：启动读取已存字号与字重、修改即时生效并持久化，且互不覆盖。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/features/user_preferences/domain/user_preferences_sync_events.dart';
import 'package:echo_loop/providers/subtitle_text_prefs_provider.dart';

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
    final container = await _container({'subtitle_font_size_percent': 130});

    expect(
      container.read(subtitleTextPrefsProvider),
      const SubtitleTextPrefs(fontSizePercent: 130),
    );
  });

  test('修改字号即时生效、吸附档位并持久化', () async {
    final container = await _container({});

    await container
        .read(subtitleTextPrefsProvider.notifier)
        .setFontSizePercent(131);

    expect(container.read(subtitleTextPrefsProvider).fontSizePercent, 130);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('subtitle_font_size_percent'), 130);
  });

  test('修改字重吸附档位并持久化，同时保留字号', () async {
    final container = await _container({'subtitle_font_size_percent': 130});

    await container
        .read(subtitleTextPrefsProvider.notifier)
        .setFontWeightPercent(120);

    expect(
      container.read(subtitleTextPrefsProvider),
      const SubtitleTextPrefs(fontSizePercent: 130, fontWeightPercent: 120),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('subtitle_font_weight_percent'), 120);
  });

  test('修改字号不覆盖已设置的字重百分比', () async {
    final container = await _container({'subtitle_font_weight_percent': 110});

    await container
        .read(subtitleTextPrefsProvider.notifier)
        .setFontSizePercent(120);

    expect(
      container.read(subtitleTextPrefsProvider),
      const SubtitleTextPrefs(fontSizePercent: 120, fontWeightPercent: 110),
    );
  });

  test('未注入 SharedPreferences 时异步加载已存偏好', () async {
    SharedPreferences.setMockInitialValues({'subtitle_font_size_percent': 150});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // autoDispose：保持订阅，模拟页面持续监听。
    final sub = container.listen(subtitleTextPrefsProvider, (_, _) {});
    addTearDown(sub.close);

    expect(sub.read().fontSizePercent, 100);
    await pumpEventQueue();
    expect(sub.read().fontSizePercent, 150);
  });

  test('字号与粗细的本地修改都会触发云端偏好同步事件', () async {
    final container = await _container({});
    var changeCount = 0;
    final subscription = userPreferencesSyncEvents.changes.listen(
      (_) => changeCount++,
    );
    addTearDown(subscription.cancel);

    final notifier = container.read(subtitleTextPrefsProvider.notifier);
    await notifier.setFontSizePercent(120);
    await notifier.setFontWeightPercent(110);

    expect(changeCount, 2);
  });
}
