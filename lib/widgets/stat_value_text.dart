/// 统计数值：大数字 + 小字单位。
///
/// 各统计卡片共用，保证「大数字、小单位」的排版在学习统计与复习统计中一致。
library;

import 'package:flutter/material.dart';

/// 统计值的数字部分与单位部分，由调用方按语言格式化。
class StatValue {
  final String number;
  final String unit;

  const StatValue(this.number, this.unit);
}

/// 单行展示统计值：数字用 [numberStyle]，单位用小字并与数字基线对齐。
class StatValueText extends StatelessWidget {
  final StatValue value;
  final TextStyle? numberStyle;

  const StatValueText({super.key, required this.value, this.numberStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value.number, style: numberStyle),
          // 单位前留一个空格，与数字分开
          TextSpan(
            text: ' ${value.unit}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
