/// 段落练习页共享骨架
///
/// 统一渲染顶部进度、段落内容区、可选中部控制区和底部播放控制。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../practice/practice_progress_section.dart';
import 'playback_controls.dart';
import 'practice_playback_footer.dart';

/// 段落练习页共享骨架
class ParagraphPracticeScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  /// 当前段落序号（1-based）
  final int current;

  /// 总段落数
  final int total;

  /// 进度文本（如 "段落 3/5"），由调用方通过 l10n 生成
  final String progressText;

  /// 段落时长文本（如 "32s"）
  final String? durationText;

  /// 整篇音频时间轴上的当前已播放与剩余时长。
  final Duration? elapsed;
  final Duration? remaining;

  /// 进度条拖动跳转回调（0-based 句索引）；非 null 时进度条可拖动
  final void Function(int targetIndex)? onSeekToIndex;

  final Widget paragraphContent;

  /// 视频段落任务的画面插槽；音频任务保持 null。
  final Widget? topContent;

  /// 包装页面 body 的可选宿主，例如视频加载状态托管层。
  final Widget Function(Widget child)? bodyWrapper;

  /// 全屏时替换普通段落内容的 body；传入后同时隐藏 AppBar。
  final Widget? fullscreenBody;
  final Widget? contentControls;
  final Widget? practiceControls;
  final bool canGoPrev;
  final bool isLast;
  final PlaybackToggleIcon centerIcon;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCenter;
  final bool isManualMode;
  final String playCountText;
  final String? statusSuffixText;

  /// 可选：当前播放速度，与 [onPlaybackSpeedChanged] 同时提供时显示速度按钮。
  final double? playbackSpeed;

  /// 可选：选定新速度后的回调。
  final ValueChanged<double>? onPlaybackSpeedChanged;

  final AppLocalizations l10n;
  final ThemeData theme;

  const ParagraphPracticeScaffold({
    super.key,
    required this.title,
    required this.onClose,
    required this.onOpenSettings,
    required this.current,
    required this.total,
    required this.progressText,
    this.durationText,
    this.elapsed,
    this.remaining,
    this.onSeekToIndex,
    required this.paragraphContent,
    this.topContent,
    this.bodyWrapper,
    this.fullscreenBody,
    this.contentControls,
    this.practiceControls,
    required this.canGoPrev,
    required this.isLast,
    required this.centerIcon,
    required this.onPrevious,
    required this.onNext,
    required this.onCenter,
    required this.isManualMode,
    required this.playCountText,
    this.statusSuffixText,
    this.playbackSpeed,
    this.onPlaybackSpeedChanged,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (topContent != null) topContent!,
        PracticeProgressBar(
          current: current,
          total: total,
          onSeek: onSeekToIndex,
          elapsed: elapsed,
          remaining: remaining,
        ),
        PracticeSentenceInfoRow(
          progressText: progressText,
          durationText: durationText,
        ),
        Expanded(child: paragraphContent),
        if (contentControls != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.m,
              right: AppSpacing.m,
              top: AppSpacing.s,
            ),
            child: contentControls!,
          ),
        if (practiceControls != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: practiceControls!,
          ),
        const SizedBox(height: AppSpacing.m),
        PracticePlaybackFooter(
          canGoPrev: canGoPrev,
          isLast: isLast,
          centerIcon: centerIcon,
          onPrevious: onPrevious,
          onNext: onNext,
          onCenter: onCenter,
          isManualMode: isManualMode,
          playCountText: playCountText,
          statusSuffixText: statusSuffixText,
          playbackSpeed: playbackSpeed,
          onPlaybackSpeedChanged: onPlaybackSpeedChanged,
          l10n: l10n,
          theme: theme,
        ),
      ],
    );
    final isFullscreen = fullscreenBody != null;
    final pageBody = fullscreenBody ?? body;
    return Scaffold(
      appBar: isFullscreen
          ? null
          : AppBar(
              actionsPadding: const EdgeInsets.only(right: AppSpacing.s),
              title: Text(title),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
      body: bodyWrapper?.call(pageBody) ?? pageBody,
    );
  }
}
