/// 自由练习完成通用对话框
///
/// 合并了盲听、精听、跟读、难句补练等多个页面的自由练习完成对话框。
/// 简单的两按钮布局：「完成」和「再来一遍」。
///
/// 使用 [showDialog] + `useRootNavigator: true` 显示弹窗，
/// 弹窗挂到 root Navigator，与 GoRouter 路由栈隔离。
/// `barrierDismissible: true`，点击外部或右上角关闭按钮返回 null。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 显示自由练习完成对话框
///
/// 返回 `true` 表示完成退出，`false` 表示再来一遍，`null` 表示关闭/dismiss。
///
/// [title] 对话框标题。
/// [message] 完成消息（可选，如句数统计）。
/// [replayLabel] 自定义"再来一遍"按钮文本（默认使用 l10n.listenAgain）。
/// [doneLabel] 自定义"完成"按钮文本（默认使用 l10n.done）。
Future<bool?> showFreePlayCompleteDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? replayLabel,
  String? doneLabel,
}) {
  debugPrint(
    '[FreePlayDialog] showFreePlayCompleteDialog called, title=$title',
  );
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) {
      debugPrint('[FreePlayDialog] builder invoked, building dialog widget');
      return FreePlayCompleteDialog(
        onResult: (result) {
          debugPrint('[FreePlayDialog] onResult called, result=$result');
          Navigator.of(dialogContext).pop(result);
          debugPrint('[FreePlayDialog] Navigator.pop($result) done');
        },
        title: title,
        message: message,
        replayLabel: replayLabel,
        doneLabel: doneLabel,
      );
    },
  );
}

/// 显示自由练习完成弹窗并处理结果
///
/// - `null`（关闭/dismiss）→ 留在页面，不做任何操作
/// - `false`（再来一遍）→ 调用 [onStudyAgain]
/// - `true`（完成退出）→ 调用 [onExit]
Future<void> handleFreePlayComplete({
  required BuildContext context,
  required String title,
  String? message,
  String? replayLabel,
  String? doneLabel,
  required Future<void> Function() onStudyAgain,
  required Future<void> Function() onExit,
}) async {
  debugPrint('[FreePlayDialog] handleFreePlayComplete START');
  final result = await showFreePlayCompleteDialog(
    context: context,
    title: title,
    message: message,
    replayLabel: replayLabel,
    doneLabel: doneLabel,
  );
  debugPrint(
    '[FreePlayDialog] showDialog returned, result=$result, mounted=${context.mounted}',
  );
  if (!context.mounted || result == null) {
    debugPrint(
      '[FreePlayDialog] early return: mounted=${context.mounted}, result=$result',
    );
    return;
  }
  if (result == false) {
    debugPrint('[FreePlayDialog] calling onStudyAgain...');
    await onStudyAgain();
    debugPrint('[FreePlayDialog] onStudyAgain done');
  } else {
    debugPrint('[FreePlayDialog] calling onExit...');
    await onExit();
    debugPrint('[FreePlayDialog] onExit done');
  }
  debugPrint('[FreePlayDialog] handleFreePlayComplete END');
}

/// 自由练习完成对话框组件
class FreePlayCompleteDialog extends StatelessWidget {
  /// 对话框标题
  final String title;

  /// 完成消息（可选）
  final String? message;

  /// 自定义"再来一遍"按钮文本
  final String? replayLabel;

  /// 自定义"完成"按钮文本
  final String? doneLabel;

  /// 结果回调，替代 Navigator.pop 传递结果
  final void Function(bool?) onResult;

  const FreePlayCompleteDialog({
    super.key,
    required this.onResult,
    required this.title,
    this.message,
    this.replayLabel,
    this.doneLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 主体内容
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题行
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Flexible(
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                // 消息
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.l),
                // 按钮行
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onResult(true),
                        child: Text(doneLabel ?? l10n.done),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onResult(false),
                        child: Text(replayLabel ?? l10n.listenAgain),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右上角关闭按钮
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              onPressed: () {
                debugPrint('[FreePlayDialog] close button tapped');
                onResult(null);
              },
              icon: const Icon(Icons.close, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
