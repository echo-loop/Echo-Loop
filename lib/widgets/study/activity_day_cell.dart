import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/monthly_study_records_provider.dart';

/// 活动日历的自定义日期单元格
///
/// 本月日期统一黑色、统一字重，仅通过圆形背景色深浅区分学习强度。
/// 非本月日期显示为浅灰色。今天额外加红色圆环标识。
///
/// 背景色使用 GitHub 风格纯正绿，12 档固定阈值（分钟）：
/// 0–5–10–20–35–55–80–110–145–185–230–280+
/// 颜色越深表示学习时长越长，level ≥ 7 时文字改白色。
class ActivityDayCell extends StatelessWidget {
  /// 当前日期
  final DateTime day;

  /// 当天学习数据（可为 null 表示无活动）
  final MonthDayRecord? record;

  /// 是否为今天
  final bool isToday;

  /// 是否被选中
  final bool isSelected;

  /// 是否属于当前月份
  final bool isOutside;

  const ActivityDayCell({
    super.key,
    required this.day,
    this.record,
    this.isToday = false,
    this.isSelected = false,
    this.isOutside = false,
  });

  /// 12 档分钟阈值（递增），超过最后一档按最深色处理
  static const _thresholds = [5, 10, 20, 35, 55, 80, 110, 145, 185, 230, 280];

  /// 12 级绿色（亮色主题），从极浅到极深
  static const _lightColors = [
    Color(0xFFE8F5E9), // level 1  ≤5min
    Color(0xFFD7F5DD), // level 2  ≤10min
    Color(0xFFC0EDCA), // level 3  ≤20min
    Color(0xFF9BE9A8), // level 4  ≤35min
    Color(0xFF6DDC80), // level 5  ≤55min
    Color(0xFF4FCC6A), // level 6  ≤80min
    Color(0xFF40C463), // level 7  ≤110min
    Color(0xFF30A14E), // level 8  ≤145min
    Color(0xFF278C41), // level 9  ≤185min
    Color(0xFF216E39), // level 10 ≤230min
    Color(0xFF1A5E30), // level 11 ≤280min
    Color(0xFF155C2B), // level 12 >280min
  ];

  /// 12 级绿色（暗色主题）
  static const _darkColors = [
    Color(0xFF071E0B), // level 1
    Color(0xFF0A3018), // level 2
    Color(0xFF0C3A1E), // level 3
    Color(0xFF0E4429), // level 4
    Color(0xFF065525), // level 5
    Color(0xFF006D32), // level 6
    Color(0xFF0E8A3E), // level 7
    Color(0xFF26A641), // level 8
    Color(0xFF2DBF4E), // level 9
    Color(0xFF39D353), // level 10
    Color(0xFF48DA62), // level 11
    Color(0xFF56E067), // level 12
  ];

  /// 按固定阈值将学习时长（秒）映射到 1–12 档
  ///
  /// 阈值（分钟）：5–10–20–35–55–80–110–145–185–230–280
  /// 直接归类，无需 log 或归一化。
  static int _toLevel(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes <= 0) return 0;
    for (int i = 0; i < _thresholds.length; i++) {
      if (minutes <= _thresholds[i]) return i + 1;
    }
    return 12;
  }

  /// 根据学习时长返回圆形背景色
  static Color intensityColor(int seconds, Brightness brightness) {
    final level = _toLevel(seconds);
    if (level == 0) return Colors.transparent;
    final colors = brightness == Brightness.dark ? _darkColors : _lightColors;
    return colors[level - 1];
  }

  /// level >= 7 时背景较深，文字需要用白色保证可读性
  static bool _needsLightText(int seconds) => _toLevel(seconds) >= 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 非本月日期：浅灰色，无背景
    if (isOutside) {
      return Center(
        child: Text(
          '${day.day}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
        ),
      );
    }

    final hasActivity = record?.hasActivity ?? false;
    final seconds = record?.studyTimeSeconds ?? 0;
    final semanticLabel = _buildSemanticLabel(l10n, hasActivity);

    // 圆形背景色：有活动按强度着色，无活动透明
    final bgColor = hasActivity
        ? intensityColor(seconds, theme.brightness)
        : Colors.transparent;

    // 深色背景用白色文字，其余用黑色
    final textColor = (hasActivity && _needsLightText(seconds))
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Semantics(
      label: semanticLabel,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: Colors.red, width: 1.5)
                : isSelected
                ? Border.all(color: Colors.orange, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建无障碍标签
  String _buildSemanticLabel(AppLocalizations l10n, bool hasActivity) {
    final isZh = l10n.localeName == 'zh';
    final dateStr = isZh
        ? '${day.month}月${day.day}日'
        : '${_monthShort(day.month)} ${day.day}';
    if (!hasActivity) {
      return '$dateStr, ${isZh ? "无学习记录" : "no activity"}';
    }
    final minutes = (record!.studyTimeSeconds / 60).ceil();
    return '$dateStr, ${isZh ? "学习$minutes分钟" : "studied $minutes minutes"}';
  }

  String _monthShort(int m) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];
}
