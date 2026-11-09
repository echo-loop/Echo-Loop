/// 统一任务引导页/设置弹窗中的设置项横向布局。
///
/// 约束为左侧标签自适应、右侧值区固定宽度，避免不同页面各自手写 `Row`
/// 后出现左右边距和右侧控件宽度不一致的问题。
library;

import 'package:flutter/material.dart';

/// 通用设置项行。
class SettingLabeledRow extends StatelessWidget {
  const SettingLabeledRow({
    super.key,
    required this.label,
    required this.trailing,
    this.trailingWidth,
    this.spacing = 12,
  });

  /// 左侧标签。
  final Widget label;

  /// 右侧值控件。
  final Widget trailing;

  /// 右侧值区固定宽度；为 null（默认）时按值控件内容自适应，
  /// 大字号下值文字不会被固定宽度截断。
  final double? trailingWidth;

  /// 标签和值区之间的水平间距。
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: label),
        SizedBox(width: spacing),
        if (trailingWidth == null)
          // widthFactor: 1 让值区域只占内容宽度，贴右显示；否则 Align 会占满剩余宽度，值会居中
          Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: trailing,
          )
        else
          SizedBox(
            width: trailingWidth,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
      ],
    );
  }
}
