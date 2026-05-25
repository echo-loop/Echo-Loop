/// 提醒设置页面
///
/// 独立页面，控制收藏复习提醒（开关 + 时间选择）和
/// 音频复习提醒（开关），通过 [ReminderSettingsNotifier] 持久化。
library;

import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../l10n/app_localizations.dart';
import '../models/reminder_settings.dart';
import '../providers/notification_permission_provider.dart';
import '../providers/reminder_settings_provider.dart';
import '../services/app_logger.dart';
import '../services/notification_permission_reporter.dart';
import '../services/notification_permission_service.dart';
import '../theme/app_theme.dart';

/// 分钟可选值（15 分钟间隔）
const _minuteOptions = [0, 15, 30, 45];

/// 提醒设置页面
class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen>
    with WidgetsBindingObserver {
  /// 当前通知权限状态；null 表示未读取 / 不支持平台。
  ///
  /// 用 [NotificationPermissionState] 抽象（granted / canRequest / blocked），
  /// 真值由 flutter_local_notifications 提供。
  NotificationPermissionState? _notificationState;

  @override
  void initState() {
    super.initState();
    // 用 WidgetsBindingObserver 而不是 AppLifecycleListener：
    // macOS 上窗口焦点切换（如系统设置和 app 并排时）AppLifecycleListener.onResume
    // 不稳定触发，导致 toggle 完通知开关切回 app 后 banner 不刷新。
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.log('NotifPerm', 'settings: lifecycle -> ${state.name}');
    // resumed (app 拿回焦点) / inactive (macOS 窗口部分活跃) 都触发刷新。
    // hidden / paused 不刷新（无意义）。
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      _refreshStatus();
    }
  }

  /// 当前平台是否原生支持通知。Web / Linux 上不显示 banner（永远点不掉无意义）。
  bool get _platformSupportsNotification {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  /// 读取系统通知权限。用户从系统设置回来时（AppLifecycle.resumed）也调一次。
  Future<void> _refreshStatus() async {
    if (!_platformSupportsNotification) {
      AppLogger.log(
        'NotifPerm',
        'settings: platform does not support notifications, skip banner',
      );
      return;
    }
    try {
      final s = await ref
          .read(notificationPermissionServiceProvider)
          .getCurrentState();
      AppLogger.log('NotifPerm', 'settings: _refreshStatus -> ${s.name}');
      if (!mounted) return;
      setState(() => _notificationState = s);
    } catch (e) {
      AppLogger.log('NotifPerm', 'settings: _refreshStatus ERROR: $e');
      // 平台错误时不显示 banner（不误导）
      if (mounted) setState(() => _notificationState = null);
    }
  }

  /// 通知是否真正被系统阻止 → 红色警告横幅 + 跳系统设置
  bool get _isNotificationBlocked =>
      _notificationState == NotificationPermissionState.blocked;

  /// 通知还没请求过 → 蓝色信息横幅 + 主动弹系统授权框
  bool get _isNotificationCanRequest =>
      _notificationState == NotificationPermissionState.canRequest;

  /// 用户在 canRequest banner 上点「开启」：复用 pre-prompt 的 accept 路径，
  /// 走系统授权 API（埋点 + 持久化都一致），权限结果通过 lifecycle resume 刷新。
  Future<void> _onTurnOnNotification() async {
    AppLogger.log('NotifPerm', 'settings: banner CTA tapped (turn on)');
    final granted = await ref
        .read(notificationPermissionServiceProvider)
        .onUserAcceptedPrompt();
    AppLogger.log(
      'NotifPerm',
      'settings: banner CTA result granted=$granted; refreshing status',
    );
    await _refreshStatus();
  }

  Future<void> _onOpenSystemSettings() async {
    AppLogger.log('NotifPerm', 'settings: open-system-settings tapped');
    ref
        .read(analyticsServiceProvider)
        .track(Events.notificationSettingsOpenTapped, const {});
    final reporter = ref.read(notificationPermissionReporterProvider);
    await reporter.openSettings();
    AppLogger.log('NotifPerm', 'settings: openSettings done');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(reminderSettingsNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminderSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        children: [
          // ── 通知权限横幅（按状态分两态） ──
          if (_isNotificationBlocked) ...[
            _NotificationStatusBanner(
              tone: _BannerTone.error,
              icon: Icons.notifications_off_outlined,
              message: l10n.notificationDisabledBanner,
              ctaLabel: l10n.notificationDisabledBannerCta,
              onCta: _onOpenSystemSettings,
            ),
            const SizedBox(height: AppSpacing.m),
          ] else if (_isNotificationCanRequest) ...[
            _NotificationStatusBanner(
              tone: _BannerTone.warning,
              icon: Icons.notifications_active_outlined,
              message: l10n.notificationNotGrantedBanner,
              ctaLabel: l10n.notificationNotGrantedBannerCta,
              onCta: _onTurnOnNotification,
            ),
            const SizedBox(height: AppSpacing.m),
          ],

          // ── 收藏复习提醒 ──
          _SectionHeader(title: l10n.savedReviewReminderSection),
          Card(
            child: Column(
              children: [
                // 开关行
                _SwitchRow(
                  icon: Icons.notifications_active_outlined,
                  iconColor: colorScheme.primary,
                  title: l10n.savedReviewReminderToggle,
                  value: settings.savedReviewReminderEnabled,
                  onChanged: (v) => _update(
                    ref,
                    settings.copyWith(savedReviewReminderEnabled: v),
                  ),
                ),
                // 开关开启时显示时间选择
                if (settings.savedReviewReminderEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  _TimeRow(
                    title: l10n.savedReviewReminderTime,
                    formattedTime: settings.formattedTime,
                    onTap: () => _showTimePickerSheet(context, ref, settings),
                  ),
                ],
              ],
            ),
          ),
          // 说明文字
          _DescriptionText(text: l10n.savedReviewReminderDescription),

          const SizedBox(height: AppSpacing.l),

          // ── 复习到期提醒 ──
          _SectionHeader(title: l10n.audioReviewReminderSection),
          Card(
            child: _SwitchRow(
              icon: Icons.event_repeat_outlined,
              iconColor: colorScheme.primary,
              title: l10n.audioReviewReminderToggle,
              value: settings.perAudioReminderEnabled,
              onChanged: (v) =>
                  _update(ref, settings.copyWith(perAudioReminderEnabled: v)),
            ),
          ),
          _DescriptionText(text: l10n.audioReviewReminderDescription),
        ],
      ),
    );
  }

  void _update(WidgetRef ref, ReminderSettings settings) {
    ref.read(reminderSettingsNotifierProvider.notifier).update(settings);
  }

  /// 底部弹窗时间选择器（双列滚轮：小时 0-23 + 分钟 0/15/30/45）
  Future<void> _showTimePickerSheet(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings settings,
  ) async {
    var selectedHour = settings.savedReviewReminderHour;
    var selectedMinuteIndex = _nearestMinuteIndex(
      settings.savedReviewReminderMinute,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return _TimePickerSheet(
          initialHour: selectedHour,
          initialMinuteIndex: selectedMinuteIndex,
          onChanged: (hour, minuteIndex) {
            selectedHour = hour;
            selectedMinuteIndex = minuteIndex;
          },
        );
      },
    );

    final newMinute = _minuteOptions[selectedMinuteIndex];
    if (selectedHour != settings.savedReviewReminderHour ||
        newMinute != settings.savedReviewReminderMinute) {
      ref
          .read(reminderSettingsNotifierProvider.notifier)
          .update(
            settings.copyWith(
              savedReviewReminderHour: selectedHour,
              savedReviewReminderMinute: newMinute,
            ),
          );
    }
  }

  /// 找到最接近 [minute] 的可选分钟索引
  static int _nearestMinuteIndex(int minute) {
    var bestIndex = 0;
    var bestDiff = 60;
    for (var i = 0; i < _minuteOptions.length; i++) {
      final diff = (minute - _minuteOptions[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}

// ─────────────────────────────────────────────────────────
// 子组件
// ─────────────────────────────────────────────────────────

/// 通知权限提示横幅。
///
/// 两种 tone：
/// - [_BannerTone.error]：系统通知已 denied / restricted → 红色，引导跳设置
/// - [_BannerTone.warning]：尚未请求过通知权限（notDetermined）→ 黄色，引导主动允许
enum _BannerTone { error, warning }

/// 警告色（黄/琥珀），用于"还可以授权但未授权"的轻提醒。
/// Material 3 没有标准 warning role，用 amber.shade700 作为统一警告色。
const Color _kWarnAccent = Color(0xFFFFA000); // Material amber 700

class _NotificationStatusBanner extends StatelessWidget {
  final _BannerTone tone;
  final IconData icon;
  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  const _NotificationStatusBanner({
    required this.tone,
    required this.icon,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = tone == _BannerTone.error ? colorScheme.error : _kWarnAccent;
    return Card(
      color: accent.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.s,
          AppSpacing.s,
          AppSpacing.s,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: onCta,
              child: Text(
                ctaLabel,
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section 标题
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 带图标的开关行
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 时间选择行
class _TimeRow extends StatelessWidget {
  final String title;
  final String formattedTime;
  final VoidCallback onTap;

  const _TimeRow({
    required this.title,
    required this.formattedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 20),
      title: Text(title),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          formattedTime,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Section 下方灰色说明文字
class _DescriptionText extends StatelessWidget {
  final String text;
  const _DescriptionText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m + AppSpacing.xs,
        AppSpacing.s,
        AppSpacing.m,
        0,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 时间选择器底部弹窗
// ─────────────────────────────────────────────────────────

const double _kItemExtent = 40;

/// 双列滚轮时间选择器
class _TimePickerSheet extends StatefulWidget {
  final int initialHour;
  final int initialMinuteIndex;
  final void Function(int hour, int minuteIndex) onChanged;

  const _TimePickerSheet({
    required this.initialHour,
    required this.initialMinuteIndex,
    required this.onChanged,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinuteIndex;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinuteIndex = widget.initialMinuteIndex;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinuteIndex,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽把手
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const SizedBox(height: AppSpacing.s),
            // 滚轮 + 选中行高亮条
            SizedBox(
              height: _kItemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 选中行背景条（横跨整个宽度）
                  Container(
                    height: _kItemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // 滚轮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 小时列
                      SizedBox(
                        width: 90,
                        child: CupertinoPicker.builder(
                          scrollController: _hourController,
                          itemExtent: _kItemExtent,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedHour = index);
                            widget.onChanged(
                              _selectedHour,
                              _selectedMinuteIndex,
                            );
                          },
                          itemBuilder: (_, index) => Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: index == _selectedHour
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: index == _selectedHour
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            ),
                          ),
                          childCount: 24,
                        ),
                      ),
                      // 冒号
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          ':',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // 分钟列
                      SizedBox(
                        width: 90,
                        child: CupertinoPicker.builder(
                          scrollController: _minuteController,
                          itemExtent: _kItemExtent,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedMinuteIndex = index);
                            widget.onChanged(
                              _selectedHour,
                              _selectedMinuteIndex,
                            );
                          },
                          itemBuilder: (_, index) => Center(
                            child: Text(
                              _minuteOptions[index].toString().padLeft(2, '0'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: index == _selectedMinuteIndex
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: index == _selectedMinuteIndex
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            ),
                          ),
                          childCount: _minuteOptions.length,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
