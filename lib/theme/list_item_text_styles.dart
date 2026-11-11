import 'package:flutter/material.dart';

// 资源库相关页面的名称样式。合集名与音频名各只定义一份，
// 资源库、发现合集、合集详情 AppBar、学习页卡片等入口都从这里取值，改动会同步到所有入口。
// 两者都基于 titleMedium 并取消字间距（Material 默认 letterSpacing 为 0.15），避免名称显得更宽。

/// 合集名称样式（资源库合集列表项、合集详情 AppBar、发现合集卡片、社区合集详情 AppBar）。
TextStyle? collectionTitleStyle(ThemeData theme) {
  return theme.textTheme.titleMedium?.copyWith(fontSize: 15, letterSpacing: 0);
}

/// 音频名称样式（音频列表项、学习页卡片、社区合集的音频文件行）。
TextStyle? audioTitleStyle(ThemeData theme) {
  return theme.textTheme.titleMedium?.copyWith(fontSize: 14, letterSpacing: 0);
}
