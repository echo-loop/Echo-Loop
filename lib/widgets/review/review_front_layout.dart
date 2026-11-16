/// 收藏复习（句子 / 词汇）正面的共享布局。
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 正面播放入口的视觉状态。
enum ReviewPlaybackTone {
  /// 空闲，可点按重播。
  idle,

  /// 加载或播放中。
  active,

  /// 音频失败，可点按重试。
  error,
}

/// 复习正面：内容直接居中在页面底色上，底部一个翻面主按钮。
///
/// 不再用大色块切分上下两区：内容很少时大色块只会放大空白、显得笨重。
/// 翻面按钮放在背面评分栏的同一位置，拇指不用移动，翻面前后版式连贯。
/// 内容区整块仍可点按重播，保留大点按面积。
class ReviewFrontLayout extends StatelessWidget {
  const ReviewFrontLayout({
    super.key,
    required this.listenZoneKey,
    required this.revealZoneKey,
    required this.listenContent,
    required this.revealLabel,
    required this.onReplay,
    required this.onReveal,
  });

  final Key listenZoneKey;
  final Key revealZoneKey;
  final Widget listenContent;
  final String revealLabel;
  final VoidCallback onReplay;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  AppSpacing.s,
                  AppSpacing.m,
                  0,
                ),
                child: Material(
                  key: listenZoneKey,
                  type: MaterialType.transparency,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onReplay,
                    child: _CenteredContent(child: listenContent),
                  ),
                ),
              ),
            ),
            // 内边距与背面底部操作区一致，按钮落在评分栏的位置。
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.m,
                AppSpacing.m,
                AppSpacing.s,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  key: revealZoneKey,
                  onPressed: onReveal,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(revealLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 正面播放入口：标准色调圆形按钮 + 弱化的状态说明。
///
/// 状态文字只是辅助提示，用次要色，避免盖过需要回忆的内容。
class ReviewPlaybackPrompt extends StatelessWidget {
  const ReviewPlaybackPrompt({
    super.key,
    required this.icon,
    required this.tone,
    required this.status,
    this.detail,
  });

  final IconData icon;
  final ReviewPlaybackTone tone;
  final String status;

  /// 状态下方的补充说明，例如失败原因或听力提示。
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (background, foreground) = switch (tone) {
      ReviewPlaybackTone.idle => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      // 播放中填实，明确表示「正在发声」。
      ReviewPlaybackTone.active => (colorScheme.primary, colorScheme.onPrimary),
      ReviewPlaybackTone.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };
    final detailText = detail;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, size: 32, color: foreground),
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          status,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: tone == ReviewPlaybackTone.error
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
          ),
        ),
        if (detailText != null && detailText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            detailText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: .7),
            ),
          ),
        ],
      ],
    );
  }
}

/// 在区域内居中内容；内容超出高度（矮窗口、大字号）时裁剪而非溢出报错。
class _CenteredContent extends StatelessWidget {
  const _CenteredContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.m),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: (constraints.maxWidth - AppSpacing.m * 2).clamp(
            0,
            double.infinity,
          ),
          minHeight: (constraints.maxHeight - AppSpacing.m * 2).clamp(
            0,
            double.infinity,
          ),
        ),
        child: Center(child: child),
      ),
    ),
  );
}
