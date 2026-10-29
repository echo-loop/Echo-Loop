/// 学习内容字号缩放容器
///
/// 词典结果视图的文字大多取自主题 `textTheme`，无法逐个注入样式，
/// 因此在结果区外层统一按学习内容字号偏好缩放主题文字。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reading_text_prefs_provider.dart';

/// 按学习内容字号偏好同比缩放 [child] 子树内的主题文字。
class ReadingTextScale extends ConsumerWidget {
  const ReadingTextScale({super.key, required this.child});

  /// 需要缩放的词典结果子树。
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(readingTextPrefsNotifierProvider);
    return Theme(
      data: theme.copyWith(textTheme: prefs.scaleTextTheme(theme.textTheme)),
      child: child,
    );
  }
}
