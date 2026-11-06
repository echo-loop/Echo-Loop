/// 开发者 Toast 样式预览页
///
/// 点击任一预设即弹出对应 toast，用于快速调试样式（亮/暗配色、文案长度、语言）。
/// 只在开发者选项中可达，文案为开发者页约定的中文字面量。
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/daily_goal_toast.dart';

/// 预设的主题亮度来源。
enum _ToastBrightness { followTheme, light, dark }

class _ToastPreset {
  const _ToastPreset({
    required this.label,
    required this.buildMessage,
    this.brightness = _ToastBrightness.followTheme,
  });

  final String label;
  final String Function(AppLocalizations l10n) buildMessage;
  final _ToastBrightness brightness;
}

final _presets = <_ToastPreset>[
  _ToastPreset(
    label: '短文案（5 分钟，跟随当前语言）',
    buildMessage: (l10n) => l10n.dailyGoalCompletedToast(5),
  ),
  _ToastPreset(
    label: '长数字（120 分钟，跟随当前语言）',
    buildMessage: (l10n) => l10n.dailyGoalCompletedToast(120),
  ),
  _ToastPreset(
    label: '英文（30 分钟）',
    buildMessage: (_) =>
        lookupAppLocalizations(const Locale('en')).dailyGoalCompletedToast(30),
  ),
  _ToastPreset(
    label: '超长文案（换行与截断）',
    buildMessage: (_) => 'Today\'s 120-minute study goal is complete! 这是一段很长很长的测试文案，用来检查 toast 在窄屏下的换行与截断效果。',
  ),
  _ToastPreset(
    label: '强制亮色配色',
    buildMessage: (l10n) => l10n.dailyGoalCompletedToast(10),
    brightness: _ToastBrightness.light,
  ),
  _ToastPreset(
    label: '强制暗色配色',
    buildMessage: (l10n) => l10n.dailyGoalCompletedToast(10),
    brightness: _ToastBrightness.dark,
  ),
];

class ToastDebugScreen extends StatelessWidget {
  const ToastDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Toast 样式')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('点击预设弹出 toast，3 秒后自动消失，点击 toast 可提前关闭。'),
          ),
          for (final preset in _presets)
            ListTile(
              title: Text(preset.label),
              subtitle: Text(preset.buildMessage(l10n)),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => _show(context, preset),
            ),
        ],
      ),
    );
  }

  void _show(BuildContext context, _ToastPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    showDailyGoalCompletedToast(
      overlayState: Overlay.of(context),
      message: preset.buildMessage(l10n),
      brightness: switch (preset.brightness) {
        _ToastBrightness.followTheme => Theme.of(context).brightness,
        _ToastBrightness.light => Brightness.light,
        _ToastBrightness.dark => Brightness.dark,
      },
    );
  }
}
