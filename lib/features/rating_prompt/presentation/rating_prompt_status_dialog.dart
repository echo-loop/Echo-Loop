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
/// 只展示条件满足情况与本次启动的评估记录，不会触发评价或写入冷却。
class RatingPromptStatusDialog extends ConsumerWidget {
  /// 创建评价提醒状态弹窗。
  const RatingPromptStatusDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(ratingPromptStatusProvider);
    return AlertDialog(
      title: const Text('评价提醒状态'),
      content: SingleChildScrollView(
        child: statusAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('读取失败：$error'),
          data: (status) => _StatusBody(status: status),
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

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.status});

  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static const _maxLogLines = 20;

  final RatingPromptStatus status;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('仅用于查看，不会触发评价。', style: style),
        const SizedBox(height: 12),
        const _SectionTitle('当前满足情况'),
        _ConditionRow(
          ok: status.isRemoteEnabled,
          text: '远程开关：${status.isRemoteEnabled ? '已开启' : '已关闭'}',
        ),
        _ConditionRow(
          ok: status.isStoreInstall,
          text:
              '商店安装：${status.isStoreInstall ? '是' : '否'}'
              '（安装来源：${status.installerStore ?? '未知'}）',
        ),
        for (final (index, group) in status.policy.groups.indexed) ...[
          if (status.policy.groups.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('规则组 ${index + 1}', style: style),
            ),
          _installAgeRow(group),
          _effectiveDaysRow(group),
        ],
        _ConditionRow(
          ok: status.cooldownRemaining == null,
          text: _cooldownText(),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('完成练习时是否会请求'),
        for (final event in RatingPromptEvent.values)
          _ConditionRow(
            ok: status.allowsEvent(event),
            text:
                '${_eventLabel(event)}完成：'
                '${status.allowsEvent(event) ? '会请求' : '不会请求'}',
          ),
        const SizedBox(height: 12),
        const _SectionTitle('自动触发记录（本次启动）'),
        ..._logLines(),
      ],
    );
  }

  Widget _installAgeRow(RatingPromptRuleGroup group) {
    final installAge = status.installAge;
    if (installAge == null) {
      return const _ConditionRow(ok: null, text: '安装时长：未知（平台未提供安装时间）');
    }
    return _ConditionRow(
      ok: installAge >= group.minimumInstallAge,
      text:
          '安装时长：${installAge.inDays} 天 / '
          '要求 ${group.minimumInstallAge.inDays} 天',
    );
  }

  Widget _effectiveDaysRow(RatingPromptRuleGroup group) {
    return _ConditionRow(
      ok: status.effectiveStudyDays >= group.minimumEffectiveStudyDays,
      text:
          '有效学习天数：${status.effectiveStudyDays} / '
          '要求 ${group.minimumEffectiveStudyDays}'
          '（统计起始：${_dateOnlyText(status.countedFrom)}）',
    );
  }

  String _cooldownText() {
    final lastAttempt = status.lastAttempt;
    final cooldownRemaining = status.cooldownRemaining;
    if (lastAttempt == null) return '冷却：从未请求过系统评分';
    final lastText = _dateTimeFormat.format(lastAttempt);
    if (cooldownRemaining == null) return '冷却：已结束（上次请求 $lastText）';
    // 剩余不足一天也应显示为 1 天，避免显示“剩余 0 天”造成误解。
    final remainingDays = (cooldownRemaining.inHours / 24).ceil();
    return '冷却：剩余 $remainingDays 天（上次请求 $lastText）';
  }

  List<Widget> _logLines() {
    final entries = AppLogger.instance.entries
        .where((entry) => entry.tag == RatingPromptCoordinator.logTag)
        .toList()
        .reversed
        .take(_maxLogLines);
    if (entries.isEmpty) {
      return const [Text('本次启动尚无评估记录')];
    }
    return [
      for (final entry in entries)
        Text(
          '${_timeText(entry.time)}  ${entry.message}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
    ];
  }

  static String _eventLabel(RatingPromptEvent event) => switch (event) {
    RatingPromptEvent.shadowingCompleted => '跟读',
    RatingPromptEvent.retellCompleted => '复述',
  };

  static String _dateOnlyText(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  static String _timeText(DateTime time) => DateFormat('HH:mm:ss').format(time);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  /// [ok] 为 `null` 表示无法判定（如安装时间未知）。
  const _ConditionRow({required this.ok, required this.text});

  final bool? ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final mark = switch (ok) {
      true => '✅',
      false => '❌',
      null => '❔',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$mark $text'),
    );
  }
}
