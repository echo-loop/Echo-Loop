/// 练习页面共享底部控制区
///
/// 统一渲染上一句/播放/下一句和遍数标签。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../guide_flow.dart';
import '../practice/practice_play_count_label.dart';
import 'playback_controls.dart';

const kPracticePlaybackFooterLabelKey = ValueKey(
  'practice-playback-footer-label',
);

/// 练习页面共享底部控制区
class PracticePlaybackFooter extends StatelessWidget {
  /// 是否可以返回上一句
  final bool canGoPrev;

  /// 是否为最后一句
  final bool isLast;

  /// 中间按钮图标
  final IconData centerIcon;

  /// 上一句回调
  final VoidCallback onPrevious;

  /// 下一句回调
  final VoidCallback onNext;

  /// 播放/暂停回调
  final VoidCallback onCenter;

  /// 是否为手动模式
  final bool isManualMode;

  /// 预格式化的遍数文本
  final String playCountText;

  /// 可选状态后缀（如盲听播放速度）
  final String? statusSuffixText;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  /// 可选：中间播放/暂停按钮的新手引导步骤
  final GuideStep? centerGuideStep;

  const PracticePlaybackFooter({
    super.key,
    required this.canGoPrev,
    required this.isLast,
    required this.centerIcon,
    required this.onPrevious,
    required this.onNext,
    required this.onCenter,
    required this.isManualMode,
    required this.playCountText,
    this.statusSuffixText,
    required this.l10n,
    required this.theme,
    this.centerGuideStep,
  });

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomInset = mediaPadding.bottom > viewPadding.bottom
        ? mediaPadding.bottom
        : viewPadding.bottom;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final bottomPadding = isMobile
        ? (bottomInset * 0.5).clamp(AppSpacing.s, AppSpacing.m).toDouble()
        : AppSpacing.m;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        bottom: bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlaybackControls(
            canGoPrev: canGoPrev,
            isLast: isLast,
            centerIcon: centerIcon,
            onPrevious: onPrevious,
            onNext: onNext,
            onCenter: onCenter,
            centerGuideStep: centerGuideStep,
          ),
          const SizedBox(height: AppSpacing.s),
          PracticePlayCountLabel(
            key: kPracticePlaybackFooterLabelKey,
            isManualMode: isManualMode,
            playCountText: playCountText,
            statusSuffixText: statusSuffixText,
            l10n: l10n,
            theme: theme,
          ),
        ],
      ),
    );
  }
}
