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

  static const double _spacing = 8;

  /// 按钮高度上限：窄屏按宽高比自然得到的高度约 80，宽屏若继续按比例
  /// 放大，按钮会变成大块空白卡片并挤占正文区域。
  static const double _maxTileHeight = 80;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = actions.length == 4 && constraints.maxWidth < 440
            ? 2
            : actions.length.clamp(1, 4);
        final tileWidth =
            (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        final aspectRatio = columns == 2 ? 2.1 : 1.45;
        final tileHeight = (tileWidth / aspectRatio).clamp(0.0, _maxTileHeight);
        return GridView(
          key: const Key('flashcard-rating-action-bar'),
          // 固定评分栏的系统安全区由页面底部容器统一处理，禁止 GridView
          // 自动继承 MediaQuery padding，避免按钮下方重复出现安全区留白。
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: tileHeight,
          ),
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

/// 单个评分按钮的配色：浅底 + 同色细边框 + 深色文字。
///
/// 颜色只用来区分「困难 → 熟练」的语义，保持低饱和度，避免复习区喧宾夺主；
/// 深色模式单独取低亮度底色和提亮文字，不直接沿用浅色值。
final class _RatingPalette {
  const _RatingPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static _RatingPalette of(MemoryRating rating, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (rating) {
      MemoryRating.again => isDark ? _againDark : _againLight,
      MemoryRating.hard => isDark ? _hardDark : _hardLight,
      MemoryRating.good => isDark ? _goodDark : _goodLight,
      MemoryRating.easy => isDark ? _easyDark : _easyLight,
    };
  }

  // 「听不懂」用暖橙而非红色：传达「需要多练」而不是「答错」，避免用户
  // 回避如实自评，导致间隔复习排期失真。
  static const _againLight = _RatingPalette(
    background: Color(0xFFFDEEE3),
    foreground: Color(0xFFB0602A),
    border: Color(0xFFF0CDB2),
  );
  static const _againDark = _RatingPalette(
    background: Color(0xFF3A2A1F),
    foreground: Color(0xFFF0B07F),
    border: Color(0xFF5A3F2B),
  );
  // 四档模式的「困难」取偏黄土金，与暖橙拉开色相。
  static const _hardLight = _RatingPalette(
    background: Color(0xFFFBF4DC),
    foreground: Color(0xFF8A6D12),
    border: Color(0xFFEADB9F),
  );
  static const _hardDark = _RatingPalette(
    background: Color(0xFF353019),
    foreground: Color(0xFFE3CF7A),
    border: Color(0xFF524A27),
  );
  static const _goodLight = _RatingPalette(
    background: Color(0xFFEAF3FD),
    foreground: Color(0xFF386DA5),
    border: Color(0xFFC3D8EF),
  );
  static const _goodDark = _RatingPalette(
    background: Color(0xFF1F2C3B),
    foreground: Color(0xFF9CC3EE),
    border: Color(0xFF30465F),
  );
  static const _easyLight = _RatingPalette(
    background: Color(0xFFE7F4EC),
    foreground: Color(0xFF327B50),
    border: Color(0xFFBFDDCA),
  );
  static const _easyDark = _RatingPalette(
    background: Color(0xFF1F3328),
    foreground: Color(0xFF94CFA9),
    border: Color(0xFF2F4D3B),
  );
}

class _RatingActionButton extends StatefulWidget {
  const _RatingActionButton({
    required this.action,
    required this.enabled,
    required this.onPressed,
  });

  final FlashcardRatingAction action;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_RatingActionButton> createState() => _RatingActionButtonState();
}

class _RatingActionButtonState extends State<_RatingActionButton> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed) return;
    setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final enabled = widget.enabled;
    final detail = action.detail;
    final theme = Theme.of(context);
    final palette = _RatingPalette.of(action.rating, theme.brightness);
    // 禁用（评分预测未就绪或提交中）时整体降低不透明度，保留语义配色。
    final opacity = enabled ? 1.0 : 0.5;
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      child: Listener(
        onPointerDown: enabled ? (_) => _setPressed(true) : null,
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 100),
          child: OutlinedButton(
            key: Key('flashcard-rating-${action.rating.name}'),
            onPressed: enabled ? widget.onPressed : null,
            style: ButtonStyle(
              // 评分按钮需要紧凑布局，统一使用 6 dp 内边距。
              padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
              backgroundColor: WidgetStatePropertyAll(
                palette.background.withValues(alpha: opacity),
              ),
              foregroundColor: WidgetStatePropertyAll(
                palette.foreground.withValues(alpha: opacity),
              ),
              // 按下 / 悬停时用同色叠加加深底色，作为点击反馈。
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? palette.foreground.withValues(alpha: 0.14)
                    : states.contains(WidgetState.hovered)
                    ? palette.foreground.withValues(alpha: 0.06)
                    : null,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: palette.border.withValues(alpha: opacity)),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 表情只做辅助识别，缩小后让文字成为视觉焦点。
                  Text(
                    action.emoji,
                    style: TextStyle(fontSize: detail == null ? 24 : 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.foreground.withValues(alpha: opacity),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.foreground.withValues(
                          alpha: 0.75 * opacity,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
