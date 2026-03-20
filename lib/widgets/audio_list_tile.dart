// 音频列表项组件
//
// 统一的音频列表项，同时用于资源库全局列表和合集详情页。
// 通过 collectionId 参数区分两种上下文，自动调整菜单、路由和显示逻辑。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';
import '../models/audio_item.dart';
import '../models/learning_progress.dart';
import '../models/tag.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/tag_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import 'learning_progress_icon.dart';
import '../providers/transcription_task_provider.dart';
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

  const AudioListTile({
    super.key,
    required this.audioItem,
    this.collectionId,
    this.onManageCollections,
    this.onManageTags,
    this.onDelete,
  });

  /// 是否在合集上下文中
  bool get _isCollectionContext => collectionId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 精确订阅学习进度
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItem.id],
      ),
    );

    // 合集上下文：监听当前播放状态以显示"正在播放"标记
    final isCurrentlyPlaying = _isCollectionContext
        ? ref.watch(
            listeningPracticeProvider.select(
              (s) => s.currentAudioItem?.id == audioItem.id,
            ),
          )
        : false;

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
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isCurrentlyPlaying
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: ListTile(
            contentPadding: isDesktop
                ? const EdgeInsets.symmetric(horizontal: 20, vertical: 4)
                : null,
            leading: LearningProgressIcon(progress: progress),
            title: Text(
              audioItem.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: _buildSubtitle(
              context,
              l10n,
              theme,
              progress,
              collectionNames,
              tagData,
              transcriptionTask,
            ),
            trailing: _buildTrailing(
              context,
              ref,
              l10n,
              theme,
              isCurrentlyPlaying,
            ),
            onTap: () => _handleTap(context, l10n),
          ),
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
    metaParts.add(l10n.addedOn(_formatDate(audioItem.addedDate)));

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
        if (progress != null && progress.isStarted)
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
                  : progress.currentStage.label,
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

  /// 构建星标按钮
  Widget _buildStarButton(
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return IconButton(
      icon: Icon(
        audioItem.isStarred ? Icons.star : Icons.star_border,
        color: audioItem.isStarred
            ? AppTheme.bookmarkColor
            : theme.colorScheme.onSurfaceVariant,
      ),
      tooltip: audioItem.isStarred ? l10n.unstarAudio : l10n.starAudio,
      onPressed: () {
        ref.read(audioLibraryProvider.notifier).toggleStar(audioItem.id);
      },
    );
  }

  /// 构建 trailing 区域（星标 + 正在播放标记 + 弹出菜单）
  Widget _buildTrailing(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
    bool isCurrentlyPlaying,
  ) {
    if (!isCurrentlyPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStarButton(ref, l10n, theme),
          _buildPopupMenu(context, ref, l10n, theme),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStarButton(ref, l10n, theme),
        _buildPopupMenu(context, ref, l10n, theme),
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
    final hasProgress = ref.read(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItem.id]?.isStarted ?? false,
      ),
    );

    return PopupMenuButton<String>(
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              const Icon(Icons.edit, size: 20),
              const SizedBox(width: 8),
              Text(l10n.renameAudio),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'manageSubtitles',
          child: Row(
            children: [
              const Icon(Icons.subtitles_outlined, size: 20),
              const SizedBox(width: 8),
              Text(l10n.manageSubtitles),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'manage',
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 20),
              const SizedBox(width: 8),
              Text(l10n.manageCollections),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'manageTags',
          child: Row(
            children: [
              const Icon(Icons.label_outline, size: 20),
              const SizedBox(width: 8),
              Text(l10n.manageTags),
            ],
          ),
        ),
        // 仅在有学习进度时显示重置选项
        if (hasProgress)
          PopupMenuItem(
            value: 'resetProgress',
            child: Row(
              children: [
                Icon(
                  Icons.restart_alt,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(l10n.resetLearningProgress),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(l10n.delete),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'rename') {
          _showRenameDialog(context, ref);
        } else if (value == 'manageSubtitles') {
          _showManageSubtitlesSheet(context);
        } else if (value == 'manage') {
          onManageCollections?.call();
        } else if (value == 'manageTags') {
          onManageTags?.call();
        } else if (value == 'resetProgress') {
          _showResetProgressDialog(context, ref);
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
    );
  }

  /// 处理点击 — 验证文件后导航
  Future<void> _handleTap(BuildContext context, AppLocalizations l10n) async {
    // 验证音频文件是否存在
    final fullAudioPath = await audioItem.getFullAudioPath();
    final audioFile = File(fullAudioPath);
    if (!await audioFile.exists()) {
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

    // 根据上下文选择路由
    if (_isCollectionContext) {
      context.push(AppRoutes.learningPlan(collectionId!, audioItem.id));
    } else {
      context.push(AppRoutes.audioLearningPlan(audioItem.id));
    }
  }

  /// 格式化添加日期为 M/d/yyyy
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
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
