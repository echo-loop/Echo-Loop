import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/audio_item.dart';
import '../media_trim_clip.dart';
import '../media_trim_editor_controller.dart';
import 'media_trim_clip_colors.dart';
import 'media_trim_format.dart';

/// 线条图标统一渲染为 20px：Material 线条图标在 20px 时线宽约 1.67px，
/// 自绘 SVG 也按这个线宽绘制，保证同屏图标粗细一致。
const double _lineIconSize = 20;

/// 片段列表的 sliver 组：标题栏 + 空状态或片段行。当前片段就地展开起止编辑。
class MediaTrimClipSlivers extends ConsumerWidget {
  const MediaTrimClipSlivers({
    super.key,
    required this.source,
    required this.onAutoSplit,
    required this.onAddClip,
    required this.onRename,
    required this.onEditTime,
    this.showTitle = true,
  });

  final AudioItem source;

  /// 标签页里已显示「片段 · N」，此时只保留操作按钮。
  final bool showTitle;
  final VoidCallback onAutoSplit;
  final VoidCallback onAddClip;
  final ValueChanged<MediaTrimClip> onRename;
  final ValueChanged<MediaTrimEdge> onEditTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaTrimEditorProvider(source);
    final (clips, selectedId, hasSentences) = ref.watch(
      provider.select(
        (s) => (s.clips, s.selectedClipId, s.boundaries?.hasSentences ?? false),
      ),
    );
    final l10n = AppLocalizations.of(context)!;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _ClipHeader(
            title: showTitle
                ? (clips.isEmpty
                      ? l10n.mediaTrimClips
                      : '${l10n.mediaTrimClips} · ${clips.length}')
                : null,
            onAutoSplit: onAutoSplit,
            onAdd: onAddClip,
          ),
        ),
        if (clips.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyClips(
              message: hasSentences
                  ? l10n.mediaTrimEmptyBodySentences
                  : l10n.mediaTrimEmptyBodyFree,
            ),
          )
        else
          SliverList.builder(
            itemCount: clips.length,
            itemBuilder: (context, index) => _ClipRow(
              key: ValueKey('trim-clip-${clips[index].id}'),
              source: source,
              clip: clips[index],
              number: index + 1,
              isSelected: clips[index].id == selectedId,
              hasSentences: hasSentences,
              onRename: () => onRename(clips[index]),
              onEditTime: onEditTime,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _ClipHeader extends StatelessWidget {
  const _ClipHeader({
    required this.title,
    required this.onAutoSplit,
    required this.onAdd,
  });

  final String? title;
  final VoidCallback onAutoSplit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 两个按钮统一字号与高度，避免主题默认样式让「新片段」显得更大。
    final buttonStyle = ButtonStyle(
      textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge),
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Wrap(
        alignment: title == null
            ? WrapAlignment.end
            : WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 8,
        children: [
          if (title != null)
            Text(
              title!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                key: const ValueKey('trim-auto-split'),
                style: buttonStyle,
                onPressed: onAutoSplit,
                icon: const Icon(Icons.view_week_outlined, size: _lineIconSize),
                label: Text(l10n.mediaTrimAutoSplit),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: l10n.mediaTrimAddClipTooltip,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('trim-add'),
                  style: buttonStyle,
                  onPressed: onAdd,
                  icon: SvgPicture.asset(
                    'assets/icon/split.svg',
                    width: _lineIconSize,
                    height: _lineIconSize,
                    colorFilter: ColorFilter.mode(
                      theme.colorScheme.onSecondaryContainer,
                      BlendMode.srcIn,
                    ),
                  ),
                  label: Text(l10n.mediaTrimAddClip),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyClips extends StatelessWidget {
  const _EmptyClips({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          SvgActionIcon(
            assetName: 'assets/icon/scissor.svg',
            color: scheme.primary,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.mediaTrimEmptyTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipRow extends ConsumerWidget {
  const _ClipRow({
    super.key,
    required this.source,
    required this.clip,
    required this.number,
    required this.isSelected,
    required this.hasSentences,
    required this.onRename,
    required this.onEditTime,
  });

  final AudioItem source;
  final MediaTrimClip clip;
  final int number;
  final bool isSelected;
  final bool hasSentences;
  final VoidCallback onRename;
  final ValueChanged<MediaTrimEdge> onEditTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaTrimEditorProvider(source);
    final controller = ref.read(provider.notifier);
    // 显示的就是保存时用的名称，与重命名弹窗一致。
    final (title, sourceName) = ref.watch(
      provider.select((s) => (s.clipName(clip), s.sourceName)),
    );
    final sentenceCount = ref.watch(
      provider.select(
        (s) => clip.sentencesWithin(s.boundaries?.sentences ?? const []).length,
      ),
    );
    final isPreviewing = ref.watch(
      provider.select((s) {
        final preview = s.preview;
        return s.isPlaying &&
            preview is MediaTrimClipPreview &&
            preview.clipId == clip.id;
      }),
    );
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = [
      '${formatTrimClock(clip.start)} – ${formatTrimClock(clip.end)}',
      formatTrimDuration(clip.duration),
      if (hasSentences) l10n.mediaTrimSentenceCount(sentenceCount),
    ].join(' · ');
    final color = MediaTrimClipColor.of(number - 1, scheme.brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? Color.alphaBlend(
                color.base.withValues(alpha: 0.1),
                scheme.surfaceContainer,
              )
            : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? color.base : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => controller.selectClip(clip.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    _NumberBadge(
                      number: number,
                      color: color,
                      isSelected: isSelected,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClipTitle(
                            name: title,
                            sourceName: sourceName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            details,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('trim-preview-${clip.id}'),
                      tooltip: isPreviewing
                          ? l10n.mediaTrimStopPreview
                          : l10n.mediaTrimPreviewClip,
                      onPressed: () => controller.toggleClipPreview(clip.id),
                      icon: Icon(
                        isPreviewing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: ValueKey('trim-clip-menu-${clip.id}'),
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) => value == 'rename'
                          ? onRename()
                          : controller.removeClip(clip.id),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: ListTile(
                            leading: const SvgActionIcon(
                              assetName: 'assets/icon/edit.svg',
                              size: _lineIconSize,
                            ),
                            title: Text(l10n.mediaTrimRename),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              size: _lineIconSize,
                              color: scheme.error,
                            ),
                            title: Text(
                              l10n.mediaTrimDelete,
                              style: TextStyle(color: scheme.error),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _EdgeEditor(
                              edge: MediaTrimEdge.start,
                              time: clip.start,
                              controller: controller,
                              onEditTime: () => onEditTime(MediaTrimEdge.start),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _EdgeEditor(
                              edge: MediaTrimEdge.end,
                              time: clip.end,
                              controller: controller,
                              onEditTime: () => onEditTime(MediaTrimEdge.end),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// 片段名称。默认名「原名 · 01」过长时只省略原名部分、保留序号，否则各片段截断后
/// 看起来一模一样；自定义名称整体省略。
class _ClipTitle extends StatelessWidget {
  const _ClipTitle({
    required this.name,
    required this.sourceName,
    required this.style,
  });

  final String name;
  final String sourceName;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final prefix = '$sourceName · ';
    if (sourceName.isEmpty || !name.startsWith(prefix)) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Text(name.substring(sourceName.length), maxLines: 1, style: style),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({
    required this.number,
    required this.color,
    required this.isSelected,
  });

  final int number;
  final MediaTrimClipColor color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: isSelected
            ? color.base
            : color.base.withValues(
                alpha: scheme.brightness == Brightness.dark ? 0.24 : 0.16,
              ),
        shape: const StadiumBorder(),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isSelected ? color.onBase : color.base,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 一端的编辑块：小标题 + 「提前 / 时间（点按可输入）/ 推后」胶囊。起止左右并排。
class _EdgeEditor extends StatelessWidget {
  const _EdgeEditor({
    required this.edge,
    required this.time,
    required this.controller,
    required this.onEditTime,
  });

  final MediaTrimEdge edge;
  final Duration time;
  final MediaTrimEditorController controller;
  final VoidCallback onEditTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isStart = edge == MediaTrimEdge.start;
    final name = isStart ? 'start' : 'end';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            isStart ? l10n.mediaTrimStart : l10n.mediaTrimEnd,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Material(
          color: scheme.surface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                _StepButton(
                  key: ValueKey('trim-$name-earlier'),
                  icon: Icons.chevron_left_rounded,
                  tooltip: l10n.mediaTrimEarlier,
                  onStep: ({required isRepeating}) =>
                      controller.stepEdge(edge, -1, isRepeating: isRepeating),
                  onRepeatEnd: () => controller.endEdgeRepeat(edge),
                ),
                Expanded(
                  child: Tooltip(
                    message: l10n.mediaTrimEditTime,
                    child: InkWell(
                      key: ValueKey('trim-$name-time'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: onEditTime,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatTrimTime(time),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  key: ValueKey('trim-$name-later'),
                  icon: Icons.chevron_right_rounded,
                  tooltip: l10n.mediaTrimLater,
                  onStep: ({required isRepeating}) =>
                      controller.stepEdge(edge, 1, isRepeating: isRepeating),
                  onRepeatEnd: () => controller.endEdgeRepeat(edge),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 微调按钮：点按走一步；长按后连续微调，松手时统一记录日志并把播放头停到该端。
class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onStep,
    required this.onRepeatEnd,
  });

  final IconData icon;
  final String tooltip;
  final void Function({required bool isRepeating}) onStep;
  final VoidCallback onRepeatEnd;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  static const Duration _repeatInterval = Duration(milliseconds: 90);

  Timer? _repeatTimer;

  void _startRepeat() {
    widget.onStep(isRepeating: true);
    _repeatTimer = Timer.periodic(
      _repeatInterval,
      (_) => widget.onStep(isRepeating: true),
    );
  }

  void _stopRepeat() {
    final timer = _repeatTimer;
    if (timer == null) return;
    timer.cancel();
    _repeatTimer = null;
    widget.onRepeatEnd();
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 触屏上 Tooltip 也靠长按触发，会抢走连续微调的长按，因此只在桌面端显示。
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    return GestureDetector(
      onLongPressStart: (_) => _startRepeat(),
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: IconButton(
        tooltip: isDesktop ? widget.tooltip : null,
        visualDensity: VisualDensity.compact,
        onPressed: () => widget.onStep(isRepeating: false),
        icon: Icon(widget.icon, size: _lineIconSize),
      ),
    );
  }
}
