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
  final PlaybackToggleIcon centerIcon;

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

  /// 可选：当前播放速度，与 [onPlaybackSpeedChanged] 同时提供时显示速度按钮。
  final double? playbackSpeed;

  /// 可选：选定新速度后的回调。
  final ValueChanged<double>? onPlaybackSpeedChanged;

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
    this.playbackSpeed,
    this.onPlaybackSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // 播放按钮和遍数标签都属于底部固定控制区，必须整体避让 Android 导航栏和
    // iOS Home Indicator。SafeArea 的 minimum 保留桌面端及无 inset 时的原有留白。
    return SafeArea(
      top: false,
      bottom: true,
      maintainBottomViewPadding: true,
      minimum: EdgeInsets.only(bottom: isMobile ? AppSpacing.s : AppSpacing.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
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
              playbackSpeed: playbackSpeed,
              onPlaybackSpeedChanged: onPlaybackSpeedChanged,
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
      ),
    );
  }
}
