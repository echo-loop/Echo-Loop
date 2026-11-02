/// 跟读设置「跨音频记忆」端到端测试(provider 层)
///
/// 难句跟读已迁移到按槽位的 [intensiveListenPrefsProvider]。本测试验证桥接:
/// [ListenAndRepeatSettings.update] 把手动改动写穿到偏好(按槽位、只记改动)、
/// initialize 注入完整设置不持久、按「子阶段×轮次」分轮独立。
library;

import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/providers/intensive_listen_prefs_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: dedupeOverrides([
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialIntensiveListenPrefsProvider.overrideWithValue(
          intensiveListenPrefsFromPrefsSync(prefs),
        ),
      ]),
    );
  });
  tearDown(() => container.dispose());

  const slotR2 = 'listenAndRepeat:review2';
  const slotR14 = 'listenAndRepeat:review14';

  ListenAndRepeatSettings settingsNotifier() =>
      container.read(listenAndRepeatSettingsProvider.notifier);
  IntensiveListenPrefsNotifier prefsNotifier() =>
      container.read(intensiveListenPrefsProvider.notifier);

  test('update 把手动改动写穿到偏好 → resolve 回来', () {
    final notifier = settingsNotifier();
    notifier.initialize(const IntensiveListenSettings(repeatCount: 3), slotR2);
    // 用户在播放器内把自动改手动
    notifier.update(
      container
          .read(listenAndRepeatSettingsProvider)
          .copyWith(controlMode: ShadowingControlMode.manual),
    );

    expect(
      prefsNotifier().prefsFor(slotR2).controlMode,
      ShadowingControlMode.manual,
    );
    // 重新进入(新音频同一轮)→ resolve 回手动
    expect(
      prefsNotifier().resolve(slotR2, smartSpeed: 1.0).controlMode,
      ShadowingControlMode.manual,
    );
  });

  test('分轮独立:review2 改动不影响 review14', () {
    final notifier = settingsNotifier();
    notifier.initialize(const IntensiveListenSettings(repeatCount: 3), slotR2);
    notifier.update(
      container
          .read(listenAndRepeatSettingsProvider)
          .copyWith(controlMode: ShadowingControlMode.manual),
    );

    expect(prefsNotifier().prefsFor(slotR14).controlMode, isNull);
    expect(
      prefsNotifier().resolve(slotR14, smartSpeed: 1.0).controlMode,
      ShadowingControlMode.auto,
    );
  });

  test('未手动改动则不记忆(不冻结智能默认)', () {
    final notifier = settingsNotifier();
    // initialize 注入入口选择的速度,但用户没有再 update → 偏好仍为空
    notifier.initialize(
      const IntensiveListenSettings(repeatCount: 3, playbackSpeed: 0.8),
      slotR2,
    );
    expect(prefsNotifier().prefsFor(slotR2).playbackSpeed, isNull);
  });

  test('固定间隔:偏好记录后 resolve 回固定模式', () {
    final prefs = prefsNotifier();
    prefs.setPauseMode(slotR2, PauseMode.fixed);
    prefs.setFixedPauseSeconds(slotR2, 5);

    final s = prefs.resolve(slotR2, smartSpeed: 1.0);
    expect(s.pauseMode, PauseMode.fixed);
    expect(s.fixedPauseSeconds, 5);
  });
}
