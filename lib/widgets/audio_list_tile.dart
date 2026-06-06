// 音频列表项组件
//
// 统一的音频列表项，同时用于资源库全局列表和合集详情页。
// 通过 collectionId 参数区分两种上下文，自动调整菜单、路由和显示逻辑。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';
import '../models/audio_item.dart';
import '../utils/time_format.dart';
import '../models/learning_progress.dart';
import '../models/tag.dart';
import '../database/providers.dart';
import '../utils/app_data_dir.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/tag_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../features/official_collections/download/download_progress.dart';
import '../features/official_collections/download/official_download_notifier.dart';
import '../features/official_collections/data/official_collection_api.dart';
import '../features/official_collections/widgets/prepare_learning_dialog.dart';
import 'guide_flow.dart';
import 'learning_progress_icon.dart';
import '../providers/transcription_task_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../services/audio_export_service.dart';
import 'dialogs/export_audio_dialog.dart';
import 'dialogs/text_input_dialog.dart';
import 'manage_subtitles_sheet.dart';

/// 音频列表项 — 资源库全局列表和合集详情页共用
///
/// [collectionId] 非 null 时为合集上下文：
/// - 不显示合集标签 chips 和"管理合集"菜单
/// - 显示"正在播放"标记
/// - 导航到 learningPlan(collectionId, audioId)
///
/// [collectionId] 为 null 时为全局上下文：
/// - 显示合集标签 chips 和"管理合集"菜单
/// - 导航到 audioLearningPlan(audioId)
class AudioListTile extends ConsumerWidget {
  static const double _kTrailingButtonSize = 60;
  static const Key _kMenuHitAreaKey = Key('audio_list_tile_menu_hit_area');

  /// 音频项数据
  final AudioItem audioItem;

  /// 合集 ID — 非 null 表示在合集上下文中
  final String? collectionId;

  /// 管理合集回调（仅全局列表使用）
  final VoidCallback? onManageCollections;

  /// 管理标签回调
  final VoidCallback? onManageTags;

  /// 删除音频回调
  final VoidCallback? onDelete;

  /// 当前音频卡片作为列表区域引导 target 时的 step（由外层注入）。
  final GuideStep? itemStep;

  /// 当前音频菜单作为引导 target 时的 step（由外层注入）。
  final GuideStep? menuStep;

  const AudioListTile({
    super.key,
    required this.audioItem,
    this.collectionId,
    this.onManageCollections,
    this.onManageTags,
    this.onDelete,
    this.itemStep,
    this.menuStep,
  });

  /// 是否在合集上下文中
  bool get _isCollectionContext => collectionId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pinnedHighlightColor = theme.colorScheme.primary.withValues(
      alpha: 0.06,
    );

    // 精确订阅学习进度
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItem.id],
      ),
    );

    // 全局上下文：精确订阅所属合集名称
    final collectionNames = _isCollectionContext
        ? const <String>[]
        : _getCollectionNames(ref);

    // 获取音频关联的标签数据
    final tagData = _getTagData(ref);

    // 监听后台转录任务状态
    final transcriptionTask = ref.watch(
      transcriptionTaskManagerProvider.select((map) => map[audioItem.id]),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final card = Card(
          margin: EdgeInsets.zero,
          color: audioItem.isPinned ? pinnedHighlightColor : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _handleTap(context, ref, l10n),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: isDesktop
                          ? const EdgeInsets.fromLTRB(20, 8, 0, 8)
                          : const EdgeInsets.fromLTRB(16, 8, 0, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 左侧进度图标，垂直居中
                          LearningProgressIcon(progress: progress),
                          const SizedBox(width: 16),
                          // 中间标题 + 副标题
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  audioItem.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildSubtitle(
                                  context,
                                  l10n,
                                  theme,
                                  progress,
                                  collectionNames,
                                  tagData,
                                  transcriptionTask,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildTrailing(context, ref, l10n, theme),
                ],
              ),
            ),
          ),
        );
        final guidedCard = itemStep != null
            ? GuideTarget(step: itemStep!, child: card)
            : card;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: guidedCard,
        );
      },
    );
  }

  /// 构建左侧环形进度图标
  ///
  /// - 未学习：音频图标在浅色圆形背景上
  /// - 进行中：环形进度 + 中心音频图标
  /// - 已完成：满环（绿色）+ 勾号图标
  /// 获取音频关联的标签数据（名称 + 颜色）
  List<Tag> _getTagData(WidgetRef ref) {
    final tagIds = ref.watch(
      tagListProvider.select((s) => s.audioToTagsMap[audioItem.id]),
    );
    if (tagIds == null) return const [];

    final tagState = ref.watch(tagListProvider);
    final result = <Tag>[];
    for (final tId in tagIds) {
      final tag = tagState.tags.where((t) => t.id == tId).firstOrNull;
      if (tag != null) result.add(tag);
    }
    return result;
  }

  /// 获取音频所属合集名称列表（仅全局上下文使用）
  List<String> _getCollectionNames(WidgetRef ref) {
    final collectionIds = ref.watch(
      collectionListProvider.select(
        (s) => s.audioToCollectionsMap[audioItem.id],
      ),
    );
    if (collectionIds == null) return const [];

    final collectionState = ref.watch(collectionListProvider);
    final names = <String>[];
    for (final cId in collectionIds) {
      final c = collectionState.rawCollections
          .where((c) => c.id == cId)
          .firstOrNull;
      if (c != null) names.add(c.name);
    }
    return names;
  }

  /// 构建副标题 Wrap 区域
  ///
  /// 元数据用 `·` 分隔符合并为单行文本，减少 icon 噪音。
  /// 转录进度、学习 badge、合集 chips、标签 chips 仍为独立 widget。
  Widget _buildSubtitle(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    LearningProgress? progress,
    List<String> collectionNames,
    List<Tag> tagData,
    TranscriptionTaskState? transcriptionTask,
  ) {
    // 是否有进行中的转录任务
    final isTranscribing =
        transcriptionTask is TranscriptionHashing ||
        transcriptionTask is TranscriptionUploading ||
        transcriptionTask is TranscriptionProcessing;

    // 构建元数据文本片段，用 · 分隔
    final metaParts = <String>[];
    if (audioItem.totalDuration > 0) {
      metaParts.add(_formatDuration(audioItem.totalDuration));
    }
    if (audioItem.hasTranscript && !isTranscribing) {
      metaParts.add(l10n.transcript);
    }
    // 日期 meta：
    // - 用户自建音频：显示「添加于 X」（addedDate 是 import 时间，有意义）
    // - 官方合集音频：显示「发布于 yyyy/M/d」（originalDate 是后端运营录入的原始播出日期）；
    //   originalDate 未录入则跳过
    if (audioItem.remoteAudioId == null) {
      metaParts.add(l10n.addedOn(_formatDate(context, audioItem.addedDate)));
    } else if (audioItem.originalDate != null) {
      metaParts.add(
        l10n.publishedOn(_formatAbsoluteDate(audioItem.originalDate!)),
      );
    }

    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 合并的元数据文本行
        Text(metaParts.join(' · '), style: metaStyle),
        // 后台转录进度指示（带 spinner，需独立显示）
        if (isTranscribing)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                l10n.transcriptionProcessing,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        // 学习进度 badge
        // 暂停态优先级最高：替换轮次 chip 为「已暂停」灰色 chip。
        if (progress != null && progress.isStarted)
          if (progress.isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.pausedChipLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: progress.isCompleted
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                progress.isCompleted
                    ? l10n.learningCompleted
                    : reviewStageLabel(l10n, progress.currentStage),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: progress.isCompleted
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                  fontSize: 10,
                ),
              ),
            ),
        // 合集标签 chips（仅全局上下文显示）
        ...collectionNames.map(
          (name) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
        ),
        // 标签 chips（彩色）
        ...tagData.map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tag.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tag.color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建 trailing 区域（单一菜单按钮，居中显示）
  Widget _buildTrailing(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final menu = SizedBox(
      width: _kTrailingButtonSize,
      child: _buildPopupMenu(context, ref, l10n, theme),
    );
    if (menuStep == null) return menu;
    return GuideTarget(step: menuStep!, child: menu);
  }

  /// 构建菜单按钮图标
  Widget _buildMenuIcon(ThemeData theme) {
    return Icon(
      Icons.more_horiz,
      size: 18,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
  }

  /// 构建菜单内图钉图标，保持与旧设计一致的倾斜角度。
  Widget _buildPinnedMenuIcon({required bool isPinned}) {
    return Transform.rotate(
      angle: 0.52,
      child: Icon(
        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        size: 20,
        color: isPinned ? AppTheme.pinColor : null,
      ),
    );
  }

  /// 构建菜单项行，避免英文文案在窄菜单中溢出。
  Widget _buildMenuItemRow(Widget icon, String label) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  /// 构建弹出菜单
  Widget _buildPopupMenu(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final progressForMenu = ref.read(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItem.id],
      ),
    );
    final hasProgress = progressForMenu?.isStarted ?? false;
    final isPausedForMenu = progressForMenu?.isPaused ?? false;

    // 官方合集音频：name / 字幕 / 合集归属 / 文件本体都由后端决定并在 sync 时回写，
    // 因此隐藏 rename / manageSubtitles / manage / export / delete 这几项写操作，
    // manageTags 也一并隐藏（官方内容场景下打 tag 诉求极低）。
    // 仅保留 pin（纯本地 UI 偏好）+ resetProgress（学习进度重置）。
    final isOfficial = audioItem.remoteAudioId != null;
    return SizedBox.expand(
      child: PopupMenuButton<String>(
        key: _kMenuHitAreaKey,
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        padding: EdgeInsets.zero,
        child: Center(child: _buildMenuIcon(theme)),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'togglePin',
            child: _buildMenuItemRow(
              _buildPinnedMenuIcon(isPinned: audioItem.isPinned),
              audioItem.isPinned ? l10n.unpinAudio : l10n.pinAudio,
            ),
          ),
          if (!isOfficial)
            PopupMenuItem(
              value: 'rename',
              child: _buildMenuItemRow(
                const Icon(Icons.edit, size: 20),
                l10n.renameAudio,
              ),
            ),
          if (!isOfficial)
            PopupMenuItem(
              value: 'manageSubtitles',
              child: _buildMenuItemRow(
                const Icon(Icons.subtitles_outlined, size: 20),
                l10n.manageSubtitles,
              ),
            ),
          if (!isOfficial && audioItem.hasTranscript)
            PopupMenuItem(
              value: 'editSubtitles',
              child: _buildMenuItemRow(
                const Icon(Icons.edit_note, size: 20),
                l10n.editSubtitles,
              ),
            ),
          if (isOfficial)
            PopupMenuItem(
              value: 'updateOfficialSubtitle',
              child: _buildMenuItemRow(
                const Icon(Icons.sync, size: 20),
                l10n.updateOfficialSubtitle,
              ),
            ),
          if (!isOfficial)
            PopupMenuItem(
              value: 'manage',
              child: _buildMenuItemRow(
                const Icon(Icons.folder_outlined, size: 20),
                l10n.manageCollections,
              ),
            ),
          if (!isOfficial)
            PopupMenuItem(
              value: 'manageTags',
              child: _buildMenuItemRow(
                const Icon(Icons.label_outline, size: 20),
                l10n.manageTags,
              ),
            ),
          if (!isOfficial)
            PopupMenuItem(
              value: 'export',
              child: _buildMenuItemRow(
                const Icon(Icons.ios_share, size: 20),
                l10n.exportAudio,
              ),
            ),
          // 仅在已开始学习时显示「暂停 / 恢复」与「重置」
          if (hasProgress)
            PopupMenuItem(
              value: 'togglePause',
              child: _buildMenuItemRow(
                Icon(
                  isPausedForMenu
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 20,
                ),
                isPausedForMenu ? l10n.resumeLearning : l10n.pauseLearning,
              ),
            ),
          if (hasProgress)
            PopupMenuItem(
              value: 'resetProgress',
              child: _buildMenuItemRow(
                Icon(
                  Icons.restart_alt,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                l10n.resetLearningProgress,
              ),
            ),
          if (!isOfficial)
            PopupMenuItem(
              value: 'delete',
              child: _buildMenuItemRow(
                Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
                l10n.delete,
              ),
            ),
        ],
        onSelected: (value) {
          if (value == 'togglePin') {
            ref.read(audioLibraryProvider.notifier).togglePin(audioItem.id);
          } else if (value == 'rename') {
            _showRenameDialog(context, ref);
          } else if (value == 'manageSubtitles') {
            _showManageSubtitlesSheet(context);
          } else if (value == 'editSubtitles') {
            context.push(
              AppRoutes.subtitleEditor(audioItem.id),
              extra: audioItem,
            );
          } else if (value == 'updateOfficialSubtitle') {
            unawaited(_handleUpdateOfficialSubtitle(context, ref, l10n));
          } else if (value == 'manage') {
            onManageCollections?.call();
          } else if (value == 'manageTags') {
            onManageTags?.call();
          } else if (value == 'export') {
            _handleExport(context, ref);
          } else if (value == 'togglePause') {
            _handleTogglePause(context, ref, isPausedForMenu);
          } else if (value == 'resetProgress') {
            _showResetProgressDialog(context, ref);
          } else if (value == 'delete') {
            onDelete?.call();
          }
        },
      ),
    );
  }

  /// 处理点击 — 验证文件后导航
  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    // 音频未就绪（audioPath=null）= 官方合集未下载 → 走按需下载流程
    if (!audioItem.isAudioReady) {
      await _handleOfficialDownloadTap(context, ref, l10n);
      return;
    }

    // 验证音频文件是否存在
    final fullAudioPath = await audioItem.getFullAudioPath();
    if (fullAudioPath == null || !await File(fullAudioPath).exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.audioFileNotFound),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    _pushPlan(context);
  }

  /// 跳转 plan 页（合集上下文 vs 独立音频上下文）
  void _pushPlan(BuildContext context) {
    if (_isCollectionContext) {
      context.push(AppRoutes.learningPlan(collectionId!, audioItem.id));
    } else {
      context.push(AppRoutes.audioLearningPlan(audioItem.id));
    }
  }

  /// 官方合集未下载音频的点击行为：
  /// - 若已有别的下载任务在跑 → snackbar 提示
  /// - 若该音频已是"下载中" → 重新打开对话框显示当前进度
  /// - 否则启动下载 + 打开对话框
  Future<void> _handleOfficialDownloadTap(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final notifier = ref.read(officialDownloadProvider.notifier);
    final progress = ref.read(officialDownloadProvider);

    // 已在下载该音频 → 直接打开对话框；只有弹窗在前台期间自然完成才跳转
    if (progress is DownloadInProgress &&
        progress.audioItemId == audioItem.id) {
      final completedInForeground = await _showDownloadDialog(
        context,
        audioItem.id,
      );
      if (!context.mounted || completedInForeground != true) return;
      _pushPlan(context);
      return;
    }

    final result = await notifier.start(
      audioItemId: audioItem.id,
      displayName: audioItem.name,
    );
    if (!context.mounted) return;
    switch (result) {
      case StartResult.started:
        final completedInForeground = await _showDownloadDialog(
          context,
          audioItem.id,
        );
        if (!context.mounted || completedInForeground != true) return;
        _pushPlan(context);
      case StartResult.busy:
        final activeName =
            (ref.read(officialDownloadProvider) as DownloadInProgress?)
                ?.displayName ??
            '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.downloadInProgressSnackbar(activeName))),
        );
      case StartResult.alreadyDownloaded:
        // 极端情况：点击间隙被其它路径标记为已下载；按已下载走常规路径
        _pushPlan(context);
    }
  }

  /// 返回值：见 [PrepareLearningDialog] 的 pop 结果约定。
  /// - `true`  → 弹窗前台期间下载自然完成（应跳转学习计划页）
  /// - `false` → 用户点取消按钮
  /// - `null`  → 用户关 × / 点弹窗外（后台仍在下载）
  Future<bool?> _showDownloadDialog(BuildContext context, String audioItemId) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PrepareLearningDialog(audioItemId: audioItemId),
    );
  }

  Future<void> _handleUpdateOfficialSubtitle(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
        ),
        title: Text(l10n.updateOfficialSubtitleConfirm),
        content: Text(l10n.updateOfficialSubtitleWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.updateOfficialSubtitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref
          .read(officialDownloadProvider.notifier)
          .updateTranscript(audioItemId: audioItem.id);
      if (!context.mounted) return;
      switch (result) {
        case SubtitleUpdateResult.updated:
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.officialSubtitleUpdated)));
        case SubtitleUpdateResult.notFound:
        case SubtitleUpdateResult.notOfficial:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.officialSubtitleUpdateFailed)),
          );
      }
    } on AudioTranscriptUnavailable {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noTranscript)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.officialSubtitleUpdateFailed)),
      );
    }
  }

  /// 用户自建音频：相对时间（如「8 分钟前」）。
  String _formatDate(BuildContext context, DateTime date) {
    return formatTimeAgo(context, date);
  }

  /// 官方音频原始发布日期：绝对日期 `yyyy/M/d`（历史日期相对时间没意义）。
  String _formatAbsoluteDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  /// 格式化音频时长（秒 → mm:ss 或 h:mm:ss）
  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 打开管理字幕底部弹窗
  void _showManageSubtitlesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ManageSubtitlesSheet(audioItem: audioItem),
    );
  }

  /// 切换暂停学习状态：
  /// - 暂停（false→true）：弹确认弹窗，用户确认后写库 + 调度跳过该音频
  /// - 恢复（true→false）：直接生效，无弹窗（非破坏性，可再次暂停）
  Future<void> _handleTogglePause(
    BuildContext context,
    WidgetRef ref,
    bool isPaused,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(learningProgressNotifierProvider.notifier);

    if (isPaused) {
      await notifier.resumeProgress(audioItem.id);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pauseLearningConfirmTitle),
        content: Text(l10n.pauseLearningConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.pauseLearning),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await notifier.pauseProgress(audioItem.id);
    }
  }

  /// 重置学习进度确认对话框
  Future<void> _showResetProgressDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetLearningProgressConfirmTitle),
        content: Text(l10n.resetLearningProgressConfirmMessage(audioItem.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .deleteProgress(audioItem.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.resetLearningProgressDone)));
      }
    }
  }

  /// 重命名音频对话框
  /// 处理导出操作
  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    // 1. 弹出导出选项对话框
    final selection = await showExportAudioDialog(
      context: context,
      hasTranscript: audioItem.hasTranscript,
    );
    if (selection == null || !context.mounted) return;

    try {
      // 2. 解析文件绝对路径
      final audioPath = await audioItem.getFullAudioPath();
      if (audioPath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.audioFileNotFound)));
        }
        return;
      }
      // 字幕内容存 DB 列：导出需要文件，故把列内容落临时 SRT 供打包。
      // 旧行（transcriptPath 非 null）仍直接用遗留文件。
      String? transcriptPath = await audioItem.getFullTranscriptPath();
      File? tempTranscriptFile;
      if (selection.includeTranscript && transcriptPath == null) {
        final srt = await ref
            .read(audioItemDaoProvider)
            .getTranscriptSrt(audioItem.id);
        if (srt != null && srt.isNotEmpty) {
          final dataDir = await getAppDataDirectory();
          final tmpDir = Directory(p.join(dataDir.path, 'tmp', 'export'));
          await tmpDir.create(recursive: true);
          tempTranscriptFile = File(
            p.join(tmpDir.path, '${audioItem.id}_export.srt'),
          );
          await tempTranscriptFile.writeAsString(srt);
          transcriptPath = tempTranscriptFile.path;
        }
      }

      // 3. 调用导出服务生成临时文件
      final service = AudioExportService();
      final String exportPath;
      try {
        exportPath = await service.exportAudioItem(
          displayName: audioItem.name,
          audioPath: audioPath,
          transcriptPath: transcriptPath,
          includeAudio: selection.includeAudio,
          includeTranscript: selection.includeTranscript,
        );
      } finally {
        // 清理临时字幕文件（导出服务已把内容打包）
        if (tempTranscriptFile != null) {
          try {
            await tempTranscriptFile.delete();
          } catch (_) {}
        }
      }

      if (!context.mounted) return;

      // 4. 平台分发保存
      if (Platform.isIOS || Platform.isAndroid) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(exportPath)],
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : Rect.zero,
        );
      } else {
        final ext = p.extension(exportPath).replaceFirst('.', '');
        final fileName = p.basename(exportPath);
        final home = Platform.environment['HOME'];
        final downloadsDir = home != null ? '$home/Downloads' : null;

        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.exportAudio,
          fileName: fileName,
          initialDirectory: downloadsDir,
          type: FileType.custom,
          allowedExtensions: [ext],
        );
        if (savePath != null) {
          await File(exportPath).copy(savePath);
          if (context.mounted) {
            final savedName = p.basename(savePath);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l10n.exportSuccess}: $savedName')),
            );
          }
        }
      }

      // 5. 清理临时文件
      try {
        await File(exportPath).delete();
      } catch (_) {}
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.exportAudio}: $e')));
    }
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showTextInputDialog(
      context: context,
      title: l10n.renameAudio,
      labelText: l10n.audioName,
      initialValue: audioItem.name,
      confirmLabel: l10n.ok,
      cancelLabel: l10n.cancel,
    );
    if (name != null) {
      ref
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(audioItem.copyWith(name: name));
    }
  }
}
