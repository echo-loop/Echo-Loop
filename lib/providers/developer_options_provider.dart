import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_config.dart';

const _devOptionsKey = 'developer_options_enabled';

/// 开发者选项显隐 Provider。
///
/// - Debug / Profile 构建：始终开启（编译期常量 [showDeveloperOptions] = true）
/// - Release 构建：默认关闭，可通过连续点击版本号解锁，状态持久化到 SharedPreferences
/// - `--dart-define=SHOW_DEVELOPER_OPTIONS=true` 可在任何构建中强制开启
final showDeveloperOptionsProvider = NotifierProvider<DeveloperOptions, bool>(
  DeveloperOptions.new,
);

/// 开发者选项状态管理。
class DeveloperOptions extends Notifier<bool> {
  @override
  bool build() {
    // 编译期常量作为初始值（Debug/Profile=true, Release=false）
    // Release 构建下异步加载持久化状态后覆盖
    unawaited(_loadFromPrefs());
    return showDeveloperOptions;
  }

  /// 从 SharedPreferences 加载持久化的解锁状态。
  ///
  /// 从持久化存储加载开发者选项的开关状态。
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_devOptionsKey) ?? false;
    if (saved != state) state = saved;
  }

  /// 设置开发者选项开关并持久化。
  ///
  /// 设置开发者选项开关并持久化到 SharedPreferences。
  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_devOptionsKey, true);
    } else {
      await prefs.remove(_devOptionsKey);
    }
  }
}
