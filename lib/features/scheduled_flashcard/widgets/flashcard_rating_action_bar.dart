/// 可配置的 Flashcard 评分动作栏。
library;

import 'package:flutter/material.dart';

import '../../memory_scheduler/domain/memory_rating.dart';

/// 一个可展示、可映射到调度评分的底部动作。
///
/// 页面按当前学习策略提供动作列表；因此三档简化模式和经典四档模式共用
/// 同一布局及回调契约，不需要在业务页面中固化按钮数量。
final class FlashcardRatingAction {
  /// 创建评分动作。
  const FlashcardRatingAction({
    required this.rating,
    required this.emoji,
    required this.label,
    this.detail,
  });

  /// 后续调度提交使用的标准评分值。
  final MemoryRating rating;

  /// 位于文字上方的视觉提示。
  final String emoji;

  /// 位于 emoji 下方的用户可见文案。
  final String label;

  /// 可选的评分结果说明，例如预测的下次复习时间。
  final String? detail;
}

/// 根据动作数和可用宽度自适应排布的固定评分栏。
class FlashcardRatingActionBar extends StatelessWidget {
  /// 创建评分栏。
  const FlashcardRatingActionBar({
    super.key,
    required this.actions,
    required this.onSelected,
    this.enabled = true,
  });

  final List<FlashcardRatingAction> actions;
  final ValueChanged<FlashcardRatingAction> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = actions.length == 4 && constraints.maxWidth < 440
            ? 2
            : actions.length.clamp(1, 4);
        return GridView.count(
          key: const Key('flashcard-rating-action-bar'),
          // 固定评分栏的系统安全区由页面底部容器统一处理，禁止 GridView
          // 自动继承 MediaQuery padding，避免按钮下方重复出现安全区留白。
          padding: EdgeInsets.zero,
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: columns == 2 ? 2.1 : 1.45,
          children: [
            for (final action in actions)
              _RatingActionButton(
                action: action,
                enabled: enabled,
                onPressed: () => onSelected(action),
              ),
          ],
        );
      },
    );
  }
}

class _RatingActionButton extends StatelessWidget {
  const _RatingActionButton({
    required this.action,
    required this.enabled,
    required this.onPressed,
  });

  final FlashcardRatingAction action;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final detail = action.detail;
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      child: OutlinedButton(
        key: Key('flashcard-rating-${action.rating.name}'),
        onPressed: enabled ? onPressed : null,
        // 评分按钮需要紧凑布局，三档评分统一使用 6 dp 内边距。
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(6)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                action.emoji,
                style: TextStyle(fontSize: detail == null ? 30 : 22),
              ),
              const SizedBox(height: 2),
              Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (detail != null)
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
