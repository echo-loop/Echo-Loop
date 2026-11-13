import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../services/app_logger.dart';
import '../domain/rating_prompt_policy.dart';
import '../domain/rating_prompt_status.dart';
import '../rating_prompt_providers.dart';
import '../services/rating_prompt_coordinator.dart';

/// 开发者选项中的评价提醒状态弹窗。
///
/// 顶部给出结论，下方逐项列出条件；只用于查看，不会触发评价或写入冷却。
/// Debug 构建额外提供强制请求入口，用于真机验证系统弹窗能否展示。
class RatingPromptStatusDialog extends ConsumerWidget {
  /// 创建评价提醒状态弹窗。
  const RatingPromptStatusDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(ratingPromptStatusProvider);
    return AlertDialog(
      title: const Text('评价提醒状态'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: statusAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('读取失败：$error'),
            data: (status) => _StatusBody(
              status: status,
              onForceRequest: () => _forceRequestSystemReview(context, ref),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 调试用：绕过资格判断与冷却直接调用系统评分，用于验证弹窗能否展示。
///
/// 不经过协调器，因此不写入冷却。完成后刷新快照，使记录区域立即显示本次操作。
Future<void> _forceRequestSystemReview(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    await ref.read(inAppReviewGatewayProvider).requestReview();
    AppLogger.log(RatingPromptCoordinator.logTag, 'debug force request called');
  } catch (error, stackTrace) {
    AppLogger.log(
      RatingPromptCoordinator.logTag,
      'debug force request failed error=$error\n$stackTrace',
    );
  }
  if (context.mounted) ref.invalidate(ratingPromptStatusProvider);
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.status, required this.onForceRequest});

  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _timeFormat = DateFormat('HH:mm');
  static const _maxLogLines = 20;

  final RatingPromptStatus status;
  final VoidCallback onForceRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blockReason = status.blockReason;
    final logEntries = _ratingLogEntries();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _VerdictBanner(
          isReady: blockReason == null,
          message: _verdictText(blockReason),
        ),
        const SizedBox(height: 4),
        Text(
          '仅用于查看，不会触发评价。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const _SectionTitle('条件'),
        _ConditionTile(
          ok: status.isRemoteEnabled,
          label: '远程开关',
          value: status.isRemoteEnabled ? '已开启' : '已关闭',
        ),
        _ConditionTile(
          ok: status.isStoreInstall,
          label: '商店安装',
          value: status.isStoreInstall ? '是' : '否',
          caption: '安装来源：${status.installerStore ?? '未知'}',
        ),
        _installAgeTile(),
        _checkInDaysTile(),
        _recentTaskTile(),
        _cooldownTile(),
        const _SectionTitle('触发时机'),
        Text(
          '回到学习或收藏首页时检查一次；学习过程中不会弹出。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Theme(
          // 去掉 ExpansionTile 默认的分割线，保持与其他分区一致。
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text('本次启动记录（${logEntries.length}）'),
            initiallyExpanded: logEntries.isNotEmpty,
            children: _logLines(logEntries),
          ),
        ),
        if (kDebugMode) ...[
          const Divider(height: 24),
          Text(
            '调试工具',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onForceRequest,
              icon: const Icon(Icons.bug_report_outlined, size: 18),
              label: const Text('强制请求系统评分'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '仅 Debug 构建可见；绕过全部条件与冷却，不写入冷却。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  /// 结论文案与 [RatingPromptBlockReason] 一一对应，检查顺序与判定一致。
  String _verdictText(RatingPromptBlockReason? reason) {
    final rules = status.rules;
    return switch (reason) {
      null => '条件已满足，回到学习或收藏首页时会请求系统评分',
      RatingPromptBlockReason.remoteDisabled => '远程开关未开启，不会请求',
      RatingPromptBlockReason.notStoreInstall => '非商店安装，不会请求',
      RatingPromptBlockReason.installTimeUnknown => '平台未提供安装时间，不会请求',
      RatingPromptBlockReason.installTooRecent =>
        '安装未满 ${rules.minimumInstallAge.inDays} 天，暂不会请求',
      RatingPromptBlockReason.inCooldown =>
        '冷却中，还需等待 ${_remainingDays(status.cooldownRemaining ?? Duration.zero)} 天',
      RatingPromptBlockReason.notEnoughCheckInDays =>
        '每日目标打卡未满 ${rules.minimumCheckInDays} 天，暂不会请求',
      RatingPromptBlockReason.noRecentTask =>
        '最近 ${rules.recentTaskWindow.inMinutes} 分钟内没有完成任务，暂不会请求',
    };
  }

  Widget _installAgeTile() {
    final installAge = status.installAge;
    final minimum = status.rules.minimumInstallAge.inDays;
    if (installAge == null) {
      return const _ConditionTile(
        ok: null,
        label: '安装时长',
        value: '未知',
        caption: '平台未提供安装时间',
      );
    }
    return _ConditionTile(
      ok: installAge >= status.rules.minimumInstallAge,
      label: '安装时长',
      value: '${installAge.inDays} 天',
      caption: '需 $minimum 天及以上',
    );
  }

  Widget _recentTaskTile() {
    final completedAt = status.lastTaskCompletedAt;
    if (completedAt == null) {
      return const _ConditionTile(ok: false, label: '最近完成任务', value: '无记录');
    }
    final isRecent = isRecentTaskCompletion(
      rules: status.rules,
      now: status.now,
      completedAt: completedAt,
    );
    return _ConditionTile(
      ok: isRecent,
      label: '最近完成任务',
      value: _timeFormat.format(completedAt),
    );
  }

  Widget _checkInDaysTile() {
    final minimum = status.rules.minimumCheckInDays;
    return _ConditionTile(
      ok: status.checkInDays >= minimum,
      label: '每日目标打卡天数',
      value: '${status.checkInDays} 天',
      caption: '需 $minimum 天及以上，统计自 ${_dateFormat.format(status.countedFrom)}',
    );
  }

  Widget _cooldownTile() {
    final lastAttempt = status.lastAttempt;
    final cooldown = status.cooldownRemaining;
    if (lastAttempt == null) {
      return const _ConditionTile(ok: true, label: '冷却', value: '从未请求');
    }
    final lastText = _dateTimeFormat.format(lastAttempt);
    if (cooldown == null) {
      return _ConditionTile(
        ok: true,
        label: '冷却',
        value: '已结束',
        caption: '上次请求 $lastText',
      );
    }
    return _ConditionTile(
      ok: false,
      label: '冷却',
      value: '剩余 ${_remainingDays(cooldown)} 天',
      caption: '上次请求 $lastText',
    );
  }

  /// 最新的记录在前，便于开发者直接看到刚发生的操作。
  List<LogEntry> _ratingLogEntries() {
    return AppLogger.instance.entries
        .where((entry) => entry.tag == RatingPromptCoordinator.logTag)
        .toList()
        .reversed
        .toList();
  }

  List<Widget> _logLines(List<LogEntry> entries) {
    if (entries.isEmpty) {
      return const [Text('本次启动尚无评估记录')];
    }
    return [
      for (final entry in entries.take(_maxLogLines))
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '${_timeText(entry.time)}  ${entry.message}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
    ];
  }

  /// 剩余不足一天也显示为 1 天，避免显示“剩余 0 天”造成误解。
  static int _remainingDays(Duration remaining) =>
      (remaining.inHours / 24).ceil();

  static String _timeText(DateTime time) => DateFormat('HH:mm:ss').format(time);
}

/// 顶部结论横幅：可请求时用主色提示，否则用中性底色说明原因。
class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.isReady, required this.message});

  final bool isReady;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isReady
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReady
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.info_outline,
            size: 20,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 单个条件行：左侧状态图标与名称，右侧当前值，可选说明放在名称下方。
class _ConditionTile extends StatelessWidget {
  /// [ok] 为 `null` 表示无法判定（如安装时间未知）。
  const _ConditionTile({
    required this.ok,
    required this.label,
    required this.value,
    this.caption,
  });

  final bool? ok;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = switch (ok) {
      true => (Icons.check_circle, scheme.primary),
      false => (Icons.cancel, scheme.error),
      null => (Icons.help_outline, scheme.outline),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
