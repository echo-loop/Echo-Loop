/// 逐句精听「停顿设置持久化」端到端数据流测试
///
/// 锁住本次修复:用户在入口弹窗选「固定 5 秒」后——
/// (a) 关闭弹窗重开,预填回显固定 5s;
/// (b) 进入播放器,运行设置(resolve 后)为固定 5s。
/// 不依赖覆盖表/有损通道——验证「单一偏好 store」这条唯一通道。
///
/// 直接驱动屏幕用到的纯函数与 Notifier(intensivePrefsRecorder /
/// intensivePauseChoiceFromSettings / resolve),覆盖按计划与自由练习两入口共用的
/// 同一套逻辑。
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/stage_settings_overrides.dart'
    show BriefingPauseChoice, StageSettingsSlots, stageSlotKey;
import 'package:echo_loop/providers/intensive_listen_prefs_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/screens/learning_plan_screen.dart'
    show intensivePauseChoiceFromSettings, intensivePrefsRecorder;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final slot = stageSlotKey(
    StageSettingsSlots.intensiveListen,
    LearningStage.firstLearn,
  );

  ProviderContainer makeContainer(SharedPreferences prefs) => ProviderContainer(
    overrides: dedupeOverrides([
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialIntensiveListenPrefsProvider.overrideWithValue(
        intensiveListenPrefsFromPrefsSync(prefs),
      ),
    ]),
  );

  /// 模拟一次「入口弹窗:把停顿改成固定 5 秒」的用户操作(走 onSelectionChanged)。
  void pickFixed5(ProviderContainer container) {
    final notifier = container.read(intensiveListenPrefsProvider.notifier);
    final defaults = notifier.resolve(slot, smartSpeed: 1.0);
    final record = intensivePrefsRecorder(notifier, slot, defaults);
    // 速度不动(传当前值),停顿改为固定 5 秒。
    record(defaults.playbackSpeed, const BriefingPauseChoice.fixed(5));
  }

  test('选固定5秒 → 重开弹窗预填回显固定5s(改完即记)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);
    addTearDown(container.dispose);

    pickFixed5(container);

    // 重开弹窗:预填来自 resolve,停顿应显示固定 5s。
    final reopened = container
        .read(intensiveListenPrefsProvider.notifier)
        .resolve(slot, smartSpeed: 1.0);
    expect(
      intensivePauseChoiceFromSettings(reopened),
      const BriefingPauseChoice.fixed(5),
    );
  });

  test('选固定5秒 → 进入播放器的运行设置为固定5s,且速度未冻结', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);
    addTearDown(container.dispose);

    pickFixed5(container);

    // 进入播放器:enterIntensiveListenMode 传入的 settings = resolve 结果。
    final running = container
        .read(intensiveListenPrefsProvider.notifier)
        .resolve(slot, smartSpeed: 0.8);
    expect(running.pauseMode, PauseMode.fixed);
    expect(running.fixedPauseSeconds, 5);
    // 速度未碰 → 仍按传入的智能默认(0.8),没被冻结。
    expect(running.playbackSpeed, 0.8);
  });

  test('跨实例持久:重启后(从 SP 重读)仍为固定5s', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);
    addTearDown(container.dispose);

    pickFixed5(container);

    // 模拟重启:用同一 SP 新建 container(走 fromPrefsSync 注入)。
    final restarted = makeContainer(prefs);
    addTearDown(restarted.dispose);
    final reopened = restarted
        .read(intensiveListenPrefsProvider.notifier)
        .resolve(slot, smartSpeed: 1.0);
    expect(reopened.pauseMode, PauseMode.fixed);
    expect(reopened.fixedPauseSeconds, 5);
  });

  test('只改停顿不影响速度记忆(speed 仍 null)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);
    addTearDown(container.dispose);

    pickFixed5(container);

    expect(
      container
          .read(intensiveListenPrefsProvider.notifier)
          .prefsFor(slot)
          .playbackSpeed,
      isNull,
    );
  });
}
