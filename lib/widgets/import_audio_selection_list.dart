import 'package:flutter/material.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../features/audio_import/audio_import_models.dart';
import '../l10n/app_localizations.dart';
import 'media_type_icon.dart';

/// 音频导入确认列表。
///
/// 本地文件导入与网盘导入共用：只展示将要导入的音频，同名字幕用 CC 徽章标记；
/// 音频文件大小列固定宽度，保证长文件名不会挤乱列表。
class ImportAudioSelectionList extends StatefulWidget {
  const ImportAudioSelectionList({
    super.key,
    required this.items,
    this.maxHeight = 240,
    this.progress,
    this.summary,
    this.onRemove,
    this.onRetryFailed,
  });

  final List<AudioImportSelectionItem> items;
  final double maxHeight;
  final AudioImportSelectionProgress? progress;
  final AudioImportSelectionSummary? summary;
  final ValueChanged<String>? onRemove;
  final ValueChanged<String>? onRetryFailed;

  double get _effectiveMaxHeight => maxHeight.isFinite ? maxHeight : 240;

  @override
  State<ImportAudioSelectionList> createState() =>
      _ImportAudioSelectionListState();
}

class _ImportAudioSelectionListState extends State<ImportAudioSelectionList> {
  late final ScrollController _scrollController;
  String? _hoveredItemId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight;
        final fileList = boundedHeight
            ? _buildListContainer(context, shrinkWrap: false)
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget._effectiveMaxHeight,
                ),
                child: _buildListContainer(context, shrinkWrap: true),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            boundedHeight ? Expanded(child: fileList) : fileList,
            if (widget.progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: widget.progress!.value),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.progress!.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    child: Text(
                      _progressDetailLabel(widget.progress!),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.summary != null) ...[
              const SizedBox(height: 12),
              _ImportSelectionSummaryView(summary: widget.summary!),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalBytes = widget.items.fold<int>(
      0,
      (sum, item) => sum + item.fileSize,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${l10n.filesSelected(widget.items.length)}'
        '  ·  ${formatImportFileSize(totalBytes)}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildListContainer(BuildContext context, {required bool shrinkWrap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          primary: false,
          shrinkWrap: shrinkWrap,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: widget.items.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            indent: 44,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, index) =>
              _buildFileRow(context, widget.items[index], colorScheme),
        ),
      ),
    );
  }

  bool get _showStatusColumn {
    return widget.progress != null ||
        widget.summary != null ||
        widget.items.any(
          (item) => item.status != AudioImportSelectionStatus.pending,
        );
  }

  Widget _buildFileRow(
    BuildContext context,
    AudioImportSelectionItem item,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    final canRemove =
        widget.onRemove != null &&
        item.status == AudioImportSelectionStatus.pending;
    final retryFailed = widget.onRetryFailed;
    final canRetry =
        retryFailed != null && item.status == AudioImportSelectionStatus.failed;
    final showRetry = canRetry && _hoveredItemId == item.id;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItemId = item.id),
      onExit: (_) {
        if (_hoveredItemId == item.id) {
          setState(() => _hoveredItemId = null);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            MediaTypeIcon(
              isVideo: item.isVideo,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_supportingMessageFor(context, item)
                      case final supportingMessage?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        supportingMessage,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              item.status == AudioImportSelectionStatus.failed
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 22,
              child: item.hasSubtitle
                  ? Tooltip(
                      message: AppLocalizations.of(context)!
                          .subtitlePairedBadge,
                      child: SvgActionIcon(
                        assetName: 'assets/icon/closed-captions.svg',
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                formatImportFileSize(item.fileSize),
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_showStatusColumn)
              SizedBox(
                width: 32,
                child: showRetry
                    ? Tooltip(
                        message: AppLocalizations.of(context)!.retryDownload,
                        child: IconButton(
                          onPressed: () => retryFailed(item.id),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                        ),
                      )
                    : _SelectionStatusIcon(status: item.status),
              ),
            if (canRemove) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: AppLocalizations.of(context)!.removeFile,
                child: IconButton(
                  onPressed: () => widget.onRemove!(item.id),
                  icon: const SvgActionIcon(
                    assetName: 'assets/icon/trash-bin.svg',
                    size: 20,
                  ),
                  color: colorScheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _supportingMessageFor(
    BuildContext context,
    AudioImportSelectionItem item,
  ) {
    final duplicateExistingName = item.duplicateExistingName;
    if (item.status == AudioImportSelectionStatus.skipped &&
        duplicateExistingName != null) {
      return AppLocalizations.of(
        context,
      )!.duplicateExistingFileName(duplicateExistingName);
    }
    if (item.status == AudioImportSelectionStatus.failed) {
      return item.failureMessage;
    }
    return null;
  }

  String _progressDetailLabel(AudioImportSelectionProgress progress) {
    final speed = progress.speedBytesPerSecond;
    final percent = progress.progressPercent;
    final parts = <String>[
      _formatImportSpeed(speed == null || speed <= 0 ? 0 : speed),
      if (percent != null) '$percent%',
    ];
    return parts.join(' · ');
  }
}

class _SelectionStatusIcon extends StatelessWidget {
  const _SelectionStatusIcon({required this.status});

  final AudioImportSelectionStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = Colors.orange.shade700;
    return Center(
      child: switch (status) {
        AudioImportSelectionStatus.pending => Icon(
          Icons.schedule,
          size: 18,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        AudioImportSelectionStatus.importing => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
        AudioImportSelectionStatus.added => SvgActionIcon(
          assetName: 'assets/icon/check-circle-3.svg',
          size: 19,
          color: colorScheme.primary,
        ),
        AudioImportSelectionStatus.skipped => Icon(
          Icons.warning_amber_rounded,
          size: 19,
          color: warningColor,
        ),
        AudioImportSelectionStatus.failed => Icon(
          Icons.cancel_rounded,
          size: 19,
          color: colorScheme.error,
        ),
      },
    );
  }
}

class _ImportSelectionSummaryView extends StatelessWidget {
  const _ImportSelectionSummaryView({required this.summary});

  final AudioImportSelectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warningColor = Colors.orange.shade700;
    final successParts = <String>[
      l10n.audioImportedCount(summary.addedCount),
      if (summary.addedCount > 0)
        l10n.audioImportedWithSubtitleCount(summary.subtitleCount),
    ];
    final summaryStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ImportSelectionSummaryRow(
          icon: const SvgActionIcon(
            assetName: 'assets/icon/check-circle-3.svg',
            size: 20,
          ),
          iconColor: colorScheme.primary,
          label: successParts.join(' · '),
          textStyle: summaryStyle,
        ),
        if (summary.skippedCount > 0) ...[
          const SizedBox(height: 4),
          _ImportSelectionSummaryRow(
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            iconColor: warningColor,
            label: l10n.duplicatesSkipped(summary.skippedCount),
            textStyle: summaryStyle,
          ),
        ],
        if (summary.failedCount > 0) ...[
          const SizedBox(height: 4),
          _ImportSelectionSummaryRow(
            icon: const Icon(Icons.cancel_rounded, size: 20),
            iconColor: colorScheme.error,
            label: l10n.importFailedCount(summary.failedCount),
            textStyle: summaryStyle,
          ),
        ],
      ],
    );
  }
}

class _ImportSelectionSummaryRow extends StatelessWidget {
  const _ImportSelectionSummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.textStyle,
  });

  final Widget icon;
  final Color iconColor;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconTheme(
          data: IconThemeData(color: iconColor, size: 20),
          child: icon,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

/// 导入列表共用文件大小格式。
String formatImportFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatImportSpeed(double bytesPerSecond) {
  if (bytesPerSecond < 1024) {
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }
  if (bytesPerSecond < 1024 * 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}
