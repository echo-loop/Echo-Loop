// 音频列表项组件
//
// 统一的音频列表项，同时用于资源库全局列表和合集详情页。
// 通过 collectionId 参数区分两种上下文，自动调整菜单、路由和显示逻辑。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';
import '../models/audio_item.dart';
import '../models/tag.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/tag_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/transcript_picker.dart';

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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isCurrentlyPlaying
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.transparent,
          child: Icon(
            Icons.audiotrack,
            color: audioItem.isStarred
                ? AppTheme.bookmarkColor
                : theme.colorScheme.primary,
          ),
        ),
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
        ),
        trailing: _buildTrailing(context, ref, l10n, theme, isCurrentlyPlaying),
        onTap: () => _handleTap(context, l10n),
      ),
    );
  }

  /// 获取音频关联的标签数据（名称 + 颜色）
  List<Tag> _getTagData(WidgetRef ref) {
    final tagIds = ref.watch(
      tagListProvider.select(
        (s) => s.audioToTagsMap[audioItem.id],
      ),
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
  Widget _buildSubtitle(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    dynamic progress,
    List<String> collectionNames,
    List<Tag> tagData,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 音频时长
        if (audioItem.totalDuration > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                _formatDuration(audioItem.totalDuration),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        // 字幕图标 + 文字
        if (audioItem.hasTranscript)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.subtitles, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                l10n.transcript,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        // 添加时间
        Text(
          l10n.addedOn(_formatDate(audioItem.addedDate)),
          style: theme.textTheme.bodySmall,
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
  Widget _buildStarButton(WidgetRef ref, AppLocalizations l10n, ThemeData theme) {
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.playing,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
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
          value: 'transcript',
          child: Row(
            children: [
              const Icon(Icons.subtitles_outlined, size: 20),
              const SizedBox(width: 8),
              Text(l10n.uploadTranscript),
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
        } else if (value == 'transcript') {
          uploadTranscriptForAudio(context, ref, audioItem);
        } else if (value == 'manage') {
          onManageCollections?.call();
        } else if (value == 'manageTags') {
          onManageTags?.call();
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

  /// 重命名音频对话框
  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: audioItem.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameAudio),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.audioName),
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              ref
                  .read(audioLibraryProvider.notifier)
                  .updateAudioItem(audioItem.copyWith(name: name));
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(audioLibraryProvider.notifier)
                    .updateAudioItem(audioItem.copyWith(name: name));
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}
