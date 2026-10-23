// 音频列表项组件
//
// 统一的音频列表项，同时用于资源库全局列表和合集详情页。
// 通过 collectionId 参数区分两种上下文，自动调整菜单、路由和显示逻辑。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';
import '../models/audio_item.dart';
import '../utils/time_format.dart';
import '../models/learning_progress.dart';
import '../models/tag.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/tag_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/audio_item_actions.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import 'common/app_popup_menu.dart';
import '../features/community_collections/download/download_progress.dart';
import '../features/community_collections/download/community_download_notifier.dart';
import '../features/community_collections/data/community_collection_api.dart';
import '../features/community_collections/models/community_collection_models.dart';
import '../features/community_collections/widgets/community_difficulty_badge.dart';
import 'guide_flow.dart';
import 'learning_progress_icon.dart';
import '../providers/transcription_task_provider.dart';
import 'dialogs/text_input_dialog.dart';
import '../features/audio_import/audio_import_models.dart';
import '../features/audio_import/audio_import_provider.dart';
import '../features/podcast/podcast_info_sheet.dart';
import '../features/podcast/podcast_models.dart';

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

  /// 是否处于多选模式（合集详情页批量删除）。
  final bool selectionMode;

  /// 多选模式下本项是否被选中。
  final bool selected;

  /// 长按回调 —— 进入多选并选中本项（由外层注入）。
  final VoidCallback? onLongPress;

  /// 多选模式下点击本项切换选中态（由外层注入）。
  final VoidCallback? onSelectToggle;

  const AudioListTile({
    super.key,
    required this.audioItem,
    this.collectionId,
    this.onManageCollections,
    this.onManageTags,
    this.onDelete,
    this.itemStep,
    this.menuStep,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
    this.onSelectToggle,
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
    final communityDifficulty = _isCollectionContext && audioItem.isCommunity
        ? CommunityDifficulty.fromCode(audioItem.communityDifficulty)
        : null;

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
    // 本单项的下载进度（播客单集 / 社区合集音频共用同一套行内进度展示）。
    // double? 语义：null 表示未在下载本项；非 null（含 -1 不定态）表示正在下载。
    final podcastDownloadState = _podcastDownloadState(
      ref.watch(podcastDownloadControllerProvider),
    );
    // 社区下载进度：仅对未就绪社区音频订阅，避免其它 tile 无谓重建。
    final communityDownloadProgress =
        audioItem.remoteAudioId != null && !audioItem.isAudioReady
        ? ref.watch(
            communityDownloadProvider.select(
              (s) => s is DownloadInProgress && s.audioItemId == audioItem.id
                  ? s.progress
                  : null,
            ),
          )
        : null;
    final double? downloadProgress =
        podcastDownloadState?.progress ?? communityDownloadProgress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        // 多选态：选中项高亮（沿用置顶高亮的柔和主色底），未选中保持普通色。
        final selectionHighlightColor = theme.colorScheme.primary.withValues(
          alpha: 0.12,
        );
        final Color? cardColor = selectionMode && selected
            ? selectionHighlightColor
            : (audioItem.isPinned ? pinnedHighlightColor : null);
        final card = Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: selectionMode
                ? onSelectToggle
                : () => _handleTap(context, ref, l10n),
            onLongPress: onLongPress,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      // 右侧留白通常由 trailing 菜单（宽 60）撑起，故默认为 0；
                      // 多选态隐藏了菜单，需补回右内边距以保持左右对称。
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 20 : 16,
                        8,
                        selectionMode ? (isDesktop ? 20 : 16) : 0,
                        8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 左侧进度图标，垂直居中
                          _buildLeading(progress, downloadProgress),
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
                                  downloadProgress,
                                  communityDifficulty,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 多选态：右侧放选中框（替代菜单按钮），垂直居中。
                  if (selectionMode)
                    Padding(
                      padding: EdgeInsets.only(right: isDesktop ? 20 : 16),
                      child: Center(
                        child: Checkbox(
                          value: selected,
                          onChanged: (_) => onSelectToggle?.call(),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    )
                  else
                    _buildTrailing(
                      context,
                      ref,
                      l10n,
                      theme,
                      isDownloading: downloadProgress != null,
                    ),
                ],
              ),
            ),
          ),
        );
        // 置顶项右上角常驻图钉标记，让用户一眼识别已置顶（与背景高亮呼应）。
        final decoratedCard = audioItem.isPinned
            ? Stack(
                children: [
                  card,
                  const Positioned(top: 6, right: 6, child: _PinnedBadge()),
                ],
              )
            : card;
        final guidedCard = itemStep != null
            ? GuideTarget(step: itemStep!, child: decoratedCard)
            : decoratedCard;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: guidedCard,
        );
      },
    );
  }

  /// 构建左侧图标。
  ///
  /// 播客单集 / 社区合集音频在下载到本地前无法学习，因此其「未学习」态的环形进度
  /// 图标是闲置的，此时改用下载态图标承载「未下载 / 下载中」，与已下载音频的学习
  /// 进度环区分（业界 App 的标准做法）；下载完成后自动切回 [LearningProgressIcon]。
  Widget _buildLeading(LearningProgress? progress, double? downloadProgress) {
    if (audioItem.isCommunityUnavailable) {
      return Icon(
        Icons.cloud_off_outlined,
        color: Colors.grey.shade500,
        size: 28,
      );
    }
    // 播客单集 / 社区合集音频未下载：用下载态图标取代闲置的学习进度环。
    final isDownloadable =
        !audioItem.isAudioReady &&
        (audioItem.podcastEnclosureUrl != null ||
            audioItem.remoteAudioId != null);
    if (isDownloadable) {
      return _DownloadLeading(
        downloading: downloadProgress != null,
        progress: downloadProgress,
      );
    }
    return LearningProgressIcon(progress: progress, isVideo: audioItem.isVideo);
  }

  /// 当前卡片对应的 podcast 单集正在通过链接导入下载时，返回下载状态。
  AudioImportDownloading? _podcastDownloadState(AudioImportState state) {
    final enclosureUrl = audioItem.podcastEnclosureUrl;
    if (audioItem.isAudioReady || enclosureUrl == null) return null;
    if (state is! AudioImportDownloading) return null;
    if (state.displayName != enclosureUrl) return null;
    return state;
  }

  /// 构建左侧环形进度图标
  ///
  /// - 未学习：音频图标在浅色圆形背景上
  /// - 进行中：环形进度 + 中心音频图标
  /// - 已完成：满环（绿色）+ 对应的音频或视频图标
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

  /// 构建标题下方的元数据与状态标签区域。
  ///
  /// 第二行显示可用的难度、时长和日期；第三行仅在存在字幕、学习状态或其他标签时显示。
  Widget _buildSubtitle(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    LearningProgress? progress,
    List<String> collectionNames,
    List<Tag> tagData,
    TranscriptionTaskState? transcriptionTask,
    double? downloadProgress,
    CommunityDifficulty? communityDifficulty,
  ) {
    // 是否有进行中的转录任务
    final isTranscribing =
        transcriptionTask is TranscriptionHashing ||
        transcriptionTask is TranscriptionUploading ||
        transcriptionTask is TranscriptionProcessing;

    final metaParts = <InlineSpan>[];
    final accessibleMetaParts = <String>[];
    void addMetaSeparator() {
      if (metaParts.isNotEmpty) {
        metaParts.add(const TextSpan(text: ' · '));
      }
    }

    if (audioItem.totalDuration > 0) {
      final duration = _formatDuration(audioItem.totalDuration);
      addMetaSeparator();
      metaParts.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.schedule_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
      metaParts.add(TextSpan(text: ' $duration'));
      accessibleMetaParts.add(l10n.audioDuration(duration));
    }
    // 日期 meta：
    // - 用户自建普通音频：显示「添加于 X」（addedDate 是 import 时间，有意义）
    // - 社区合集 / podcast 单集：显示「发布于 yyyy/M/d」
    //   （originalDate 为后端运营录入或 RSS pubDate 的原始播出日期）；
    //   originalDate 未录入则跳过
    final isPublishedSource =
        audioItem.remoteAudioId != null || audioItem.podcastEpisodeGuid != null;
    if (!isPublishedSource) {
      final addedDate = _formatDate(context, audioItem.addedDate);
      final addedOn = l10n.addedOn(addedDate);
      addMetaSeparator();
      metaParts.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
      metaParts.add(TextSpan(text: ' $addedDate'));
      accessibleMetaParts.add(addedOn);
    } else if (audioItem.originalDate case final originalDate?) {
      final publishedDate = _formatAbsoluteDate(originalDate);
      addMetaSeparator();
      metaParts.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
      metaParts.add(TextSpan(text: ' $publishedDate'));
      accessibleMetaParts.add(l10n.publishedOn(publishedDate));
    }

    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final metadataText = Text.rich(
      TextSpan(children: metaParts),
      key: const Key('audio_list_tile_metadata_row'),
      style: metaStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
    final contentWarningLabel = _contentWarningLabel(
      l10n,
      audioItem.contentStatus,
    );
    // CC 徽章已下沉到元信息行（与时长/日期同排），不再触发标签行。
    final hasCc = audioItem.hasTranscript && !isTranscribing;
    final hasBadgeRow =
        isTranscribing ||
        contentWarningLabel != null ||
        (progress?.isStarted ?? false) ||
        collectionNames.isNotEmpty ||
        tagData.isNotEmpty ||
        audioItem.isCommunityUnavailable ||
        downloadProgress != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasCc) ...[
              _buildTranscriptBadge(theme, l10n.transcript),
              const SizedBox(width: 8),
            ],
            if (communityDifficulty != null) ...[
              CommunityDifficultyBadge(difficulty: communityDifficulty),
              const SizedBox(width: 8),
            ],
            Flexible(
              // 图标精简视觉文案；屏幕阅读器仍会读出原有完整元信息。
              child: accessibleMetaParts.isEmpty
                  ? metadataText
                  : Semantics(
                      label: accessibleMetaParts.join(' · '),
                      excludeSemantics: true,
                      child: metadataText,
                    ),
            ),
          ],
        ),
        if (hasBadgeRow) ...[
          const SizedBox(height: 4),
          Wrap(
            key: const Key('audio_list_tile_badge_row'),
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 内容异常警告（损坏 / 静音）
              if (contentWarningLabel != null)
                _buildContentWarningBadge(theme, contentWarningLabel),
              if (audioItem.isCommunityUnavailable)
                Text(
                  l10n.communityFileUnavailable,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: progress.isCompleted
                          ? (theme.brightness == Brightness.dark
                                ? const Color(0xFF1D3B27)
                                : AppTheme.successContainer)
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      progress.isCompleted
                          ? l10n.learningCompleted
                          : reviewStageLabel(l10n, progress.currentStage),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: progress.isCompleted
                            ? (theme.brightness == Brightness.dark
                                  ? const Color(0xFF8FE0A8)
                                  : AppTheme.successColor)
                            : theme.colorScheme.onPrimaryContainer,
                        fontSize: 10,
                      ),
                    ),
                  ),
              // 合集标签 chips（仅全局上下文显示）
              ...collectionNames.map(
                (name) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
              if (downloadProgress != null)
                _buildDownloadProgress(theme, l10n, downloadProgress),
            ],
          ),
        ],
      ],
    );
  }

  /// 行内下载进度（播客单集 / 社区合集音频共用），避免只用短暂提示承载状态。
  ///
  /// [progress] 为 0..1；<0（或不定态）时显示无固定进度的进度条。
  Widget _buildDownloadProgress(
    ThemeData theme,
    AppLocalizations l10n,
    double progress,
  ) {
    final value = progress < 0 ? null : progress.clamp(0.0, 1.0);
    final percent = value == null ? null : (value * 100).toStringAsFixed(0);
    return SizedBox(
      key: const Key('audio_list_tile_download_progress'),
      width: 180,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 56, child: LinearProgressIndicator(value: value)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              percent == null
                  ? l10n.audioDownloadInProgress
                  : '${l10n.audioDownloadInProgress} $percent%',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建高辨识度的字幕状态标签。
  /// 内容异常警告徽章（疑似空音频：解码失败或全程静音）。
  Widget _buildContentWarningBadge(ThemeData theme, String label) {
    final color = theme.colorScheme.error;
    return Container(
      key: const Key('audio_list_tile_content_warning_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String? _contentWarningLabel(
    AppLocalizations l10n,
    AudioContentStatus? status,
  ) {
    return switch (status) {
      AudioContentStatus.damaged => l10n.audioContentDamagedWarning,
      AudioContentStatus.silent => l10n.audioContentSilentWarning,
      AudioContentStatus.ok || null => null,
    };
  }

  /// 字幕状态标签 —— 采用国际通用的 CC（Closed Caption）徽章。
  ///
  /// [label] 保留作为语义标签（无障碍朗读），视觉上只呈现「CC」，
  /// 更紧凑、辨识度更高。
  ///
  /// 采用中性灰：CC 是「有无字幕」的静态属性标记，与状态/标签 chip 的
  /// 彩色区分，避免与相邻的学习进度 badge 争夺注意力。
  Widget _buildTranscriptBadge(ThemeData theme, String label) {
    final color = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Container(
        key: const Key('audio_list_tile_transcript_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'CC',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  /// 构建 trailing 区域（单一菜单按钮，居中显示）
  Widget _buildTrailing(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme, {
    required bool isDownloading,
  }) {
    final menu = SizedBox(
      width: _kTrailingButtonSize,
      child: _buildPopupMenu(
        context,
        ref,
        l10n,
        theme,
        isDownloading: isDownloading,
      ),
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

  /// 构建弹出菜单
  Widget _buildPopupMenu(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme, {
    required bool isDownloading,
  }) {
    final progressForMenu = ref.read(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItem.id],
      ),
    );
    final hasProgress = progressForMenu?.isStarted ?? false;
    final isPausedForMenu = progressForMenu?.isPaused ?? false;

    // 社区合集音频：name / 字幕 / 合集归属 / 文件本体都由后端决定并在 sync 时回写，
    // 因此隐藏 rename / manageSubtitles / manage / export / delete 这几项写操作，
    // manageTags 也一并隐藏（社区内容场景下打 tag 诉求极低）。
    // 仅保留 pin（纯本地 UI 偏好）+ resetProgress（学习进度重置）。
    final isCommunity = audioItem.remoteAudioId != null;
    // 播客单集由 RSS feed 统一管理：单集是 feed 的占位行，删除后下次刷新会按
    // guid 去重重新插回（_importEpisodes 只比对活跃音频的 guid，查不到已删行），
    // 造成「删了又回来」。故与社区合集一致隐藏删除项，移除请退订整个播客合集。
    final isPodcastEpisode = audioItem.podcastEpisodeGuid != null;
    return SizedBox.expand(
      child: PopupMenuButton<String>(
        key: _kMenuHitAreaKey,
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        padding: EdgeInsets.zero,
        child: Center(child: _buildMenuIcon(theme)),
        itemBuilder: (context) => [
          if (isDownloading)
            appPopupMenuItem(
              context,
              value: 'cancelDownload',
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: l10n.cancelDownload,
            ),
          appPopupMenuItem(
            context,
            value: 'togglePin',
            icon: _buildPinnedMenuIcon(isPinned: audioItem.isPinned),
            label: audioItem.isPinned ? l10n.unpinAudio : l10n.pinAudio,
          ),
          if (!isCommunity)
            appPopupMenuItem(
              context,
              value: 'rename',
              icon: const Icon(Icons.edit, size: 20),
              label: l10n.renameAudio,
            ),
          if (!isCommunity)
            appPopupMenuItem(
              context,
              value: 'manageSubtitles',
              icon: const Icon(Icons.subtitles_outlined, size: 20),
              label: l10n.manageSubtitles,
            ),
          if (!isCommunity && audioItem.hasTranscript)
            appPopupMenuItem(
              context,
              value: 'editSubtitles',
              icon: const Icon(Icons.edit_note, size: 20),
              label: l10n.editSubtitles,
            ),
          if (isCommunity)
            appPopupMenuItem(
              context,
              value: 'updateCommunitySubtitle',
              icon: const Icon(Icons.sync, size: 20),
              label: l10n.updateCommunitySubtitle,
            ),
          // 播客单集天然属于其 RSS 订阅合集，再加入本地自建合集属低频且易与
          // 「管理订阅」语义混淆，故与社区音频一致隐藏此项。
          if (!isCommunity && !isPodcastEpisode)
            appPopupMenuItem(
              context,
              value: 'manage',
              icon: const Icon(Icons.folder_outlined, size: 20),
              label: l10n.manageCollections,
            ),
          if (!isCommunity)
            appPopupMenuItem(
              context,
              value: 'manageTags',
              icon: const Icon(Icons.label_outline, size: 20),
              label: l10n.manageTags,
            ),
          if (!isCommunity)
            appPopupMenuItem(
              context,
              value: 'export',
              icon: const Icon(Icons.ios_share, size: 20),
              label: audioItem.isVideo ? l10n.exportVideo : l10n.exportAudio,
            ),
          // 学习材料导出 PDF：只读派生内容（字幕+笔记），社区音频也可用，仅要求有字幕
          if (audioItem.hasTranscript)
            appPopupMenuItem(
              context,
              value: 'exportPdf',
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: l10n.exportPdf,
            ),
          // 仅在已开始学习时显示「暂停 / 恢复」与「重置」
          if (hasProgress)
            appPopupMenuItem(
              context,
              value: 'togglePause',
              icon: Icon(
                isPausedForMenu
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                size: 20,
              ),
              label: isPausedForMenu ? l10n.resumeLearning : l10n.pauseLearning,
            ),
          if (hasProgress)
            appPopupMenuItem(
              context,
              value: 'resetProgress',
              icon: Icon(
                Icons.restart_alt,
                size: 20,
                color: theme.colorScheme.error,
              ),
              label: l10n.resetLearningProgress,
              destructive: true,
            ),
          if (!isCommunity && !isPodcastEpisode && hasProgress)
            const PopupMenuDivider(height: 10),
          if (!isCommunity && !isPodcastEpisode && !hasProgress)
            const PopupMenuDivider(height: 10),
          if (!isCommunity && !isPodcastEpisode)
            appPopupMenuItem(
              context,
              value: 'delete',
              icon: Icon(
                Icons.delete,
                size: 20,
                color: theme.colorScheme.error,
              ),
              label: l10n.delete,
              destructive: true,
            ),
          // 社区/播客音频：item 由后端 / RSS 管理不可删除，但已下载的音频文件可回收。
          // 「删除音频」仅删本地音频文件、把 audioPath 置空（列表重现下载按钮），
          // 字幕/进度保留，随时可重新下载。
          if ((isCommunity || isPodcastEpisode) && audioItem.isAudioReady)
            appPopupMenuItem(
              context,
              value: 'deleteDownload',
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              label: l10n.deleteAudio,
              destructive: true,
            ),
          if (audioItem.podcastEpisodeGuid != null)
            appPopupMenuItem(
              context,
              value: 'podcastEpisodeInfo',
              icon: const Icon(Icons.info_outline, size: 20),
              label: l10n.podcastEpisodeMeta,
            ),
        ],
        onSelected: (value) {
          if (value == 'cancelDownload') {
            if (isPodcastEpisode) {
              unawaited(
                ref.read(podcastDownloadControllerProvider.notifier).cancel(),
              );
            } else if (isCommunity) {
              unawaited(ref.read(communityDownloadProvider.notifier).cancel());
            }
          } else if (value == 'togglePin') {
            ref.read(audioLibraryProvider.notifier).togglePin(audioItem.id);
          } else if (value == 'rename') {
            _showRenameDialog(context, ref);
          } else if (value == 'manageSubtitles') {
            showManageSubtitlesSheet(context, ref, audioItem);
          } else if (value == 'editSubtitles') {
            context.push(
              AppRoutes.subtitleEditor(audioItem.id),
              extra: audioItem,
            );
          } else if (value == 'updateCommunitySubtitle') {
            unawaited(_handleUpdateCommunitySubtitle(context, ref, l10n));
          } else if (value == 'manage') {
            onManageCollections?.call();
          } else if (value == 'manageTags') {
            onManageTags?.call();
          } else if (value == 'export') {
            exportAudioItem(context, ref, audioItem);
          } else if (value == 'exportPdf') {
            AppRoutes.pushNested(
              context,
              AppRoutes.pdfPreviewSegment,
              extra: _latestAudioItem(ref),
            );
          } else if (value == 'togglePause') {
            _handleTogglePause(context, ref, isPausedForMenu);
          } else if (value == 'resetProgress') {
            _showResetProgressDialog(context, ref);
          } else if (value == 'delete') {
            onDelete?.call();
          } else if (value == 'deleteDownload') {
            // 无需二次确认：item 仍在、可随时重新下载。
            ref
                .read(audioLibraryProvider.notifier)
                .deleteDownloadedAudio(audioItem.id);
          } else if (value == 'podcastEpisodeInfo') {
            showPodcastEpisodeInfoSheet(
              context,
              _latestAudioItem(ref),
              podcastImageUrl: _podcastFeedImageUrl(ref),
            );
          }
        },
      ),
    );
  }

  String? _podcastFeedImageUrl(WidgetRef ref) {
    final state = ref.read(collectionListProvider);
    final candidateIds = <String>[
      if (collectionId case final id?) id,
      ...?state.audioToCollectionsMap[audioItem.id],
    ];
    for (final id in candidateIds) {
      final collection = state.rawCollections
          .where((c) => c.id == id && c.isPodcast)
          .firstOrNull;
      if (collection == null) continue;
      final meta = _decodePodcastMeta(collection.podcastMetaJson);
      final imageUrl = meta?.imageUrl ?? collection.coverUrl;
      if (imageUrl != null && imageUrl.trim().isNotEmpty) return imageUrl;
    }
    return null;
  }

  PodcastFeedMeta? _decodePodcastMeta(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PodcastFeedMeta.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 从 provider 读取当前最新 AudioItem，避免下载完成后 widget 仍持有旧对象。
  AudioItem _latestAudioItem(WidgetRef ref) {
    return ref.read(audioLibraryProvider.notifier).getItemById(audioItem.id) ??
        audioItem;
  }

  /// 处理点击 — 验证文件后导航
  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final currentItem = _latestAudioItem(ref);
    if (currentItem.isCommunityUnavailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.communityFileUnavailable)));
      return;
    }
    // 音频未就绪（audioPath=null）= 未下载 → 走按需下载流程
    if (!currentItem.isAudioReady) {
      // podcast 合集：用 enclosure URL 懒下载
      if (currentItem.podcastEpisodeGuid != null &&
          currentItem.podcastEnclosureUrl != null) {
        await _handlePodcastDownloadTap(context, ref, l10n, currentItem);
      } else {
        await _handleCommunityDownloadTap(context, ref, l10n);
      }
      return;
    }

    // 验证音频文件是否存在
    final fullAudioPath = await currentItem.getFullAudioPath();
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
    // 懒检测内容状态：用户实际打开音频时才检（仅未检测过的），避免启动全库扫描。
    maybeCheckAudioContent(ref, currentItem);
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

  /// 社区合集未下载音频的点击行为（与播客一致：行内进度，无弹窗）：
  /// - 若该音频已在下载 → 不重复触发，进度已在行内展示
  /// - 若已有别的下载任务在跑 → snackbar 提示
  /// - 否则启动下载，等待完成后跳转学习计划页
  Future<void> _handleCommunityDownloadTap(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final notifier = ref.read(communityDownloadProvider.notifier);
    final progress = ref.read(communityDownloadProvider);

    // 已在下载该音频：行内进度条已展示，无需重复触发或弹窗
    if (progress is DownloadInProgress &&
        progress.audioItemId == audioItem.id) {
      return;
    }

    final result = await notifier.start(
      audioItemId: audioItem.id,
      displayName: audioItem.name,
    );
    if (!context.mounted) return;
    switch (result) {
      case StartResult.started:
        // 行内进度条承载下载状态；下载成功后跳转学习计划页（与播客一致）
        final ok = await notifier.awaitCompletion();
        if (ok && context.mounted) _pushPlan(context);
      case StartResult.busy:
        final activeName =
            (ref.read(communityDownloadProvider) as DownloadInProgress?)
                ?.displayName ??
            '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.downloadInProgressSnackbar(activeName))),
        );
      case StartResult.alreadyDownloaded:
        // 极端情况：点击间隙被其它路径标记为已下载；按已下载走常规路径
        _pushPlan(context);
      case StartResult.notCommunity:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.downloadFailed(audioItem.name))),
        );
      case StartResult.unavailable:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.communityFileUnavailable)));
    }
  }

  Future<void> _handleUpdateCommunitySubtitle(
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
        title: Text(l10n.updateCommunitySubtitleConfirm),
        content: Text(l10n.updateCommunitySubtitleWarning),
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
            child: Text(l10n.updateCommunitySubtitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref
          .read(communityDownloadProvider.notifier)
          .updateTranscript(audioItemId: audioItem.id);
      if (!context.mounted) return;
      switch (result) {
        case SubtitleUpdateResult.updated:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.communitySubtitleUpdated)),
          );
        case SubtitleUpdateResult.notFound:
        case SubtitleUpdateResult.notCommunity:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.communitySubtitleUpdateFailed)),
          );
      }
    } on CommunitySubtitleUnavailable {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noTranscript)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.communitySubtitleUpdateFailed)),
      );
    }
  }

  /// 用户自建音频：相对时间（如「8 分钟前」）。
  String _formatDate(BuildContext context, DateTime date) {
    return formatTimeAgo(context, date);
  }

  /// 社区音频原始发布日期：绝对日期 `yyyy/M/d`（历史日期相对时间没意义）。
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
          .resetProgress(audioItem.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.resetLearningProgressDone)));
      }
    }
  }

  /// Podcast episode 懒下载：下载 enclosure 到沙盒并就地更新现有占位条目
  /// （保留 podcast 元字段），不新建条目。下载进度由行内进度条
  /// （[_podcastDownloadState] / [_buildPodcastDownloadProgress]）承载，
  /// 这里只负责发起下载、按结果跳转或提示失败。
  Future<void> _handlePodcastDownloadTap(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AudioItem currentItem,
  ) async {
    final ok = await ref
        .read(podcastDownloadControllerProvider.notifier)
        .downloadPodcastEpisode(currentItem);

    if (!context.mounted) return;
    if (ok) {
      _pushPlan(context);
      return;
    }
    // 仅在确实失败时提示；并发占用（另一单集正在下载）静默忽略，
    // 不误报"下载失败"。
    final state = ref.read(podcastDownloadControllerProvider);
    if (state is! AudioImportFailed) return;
    final detail = _downloadFailureDetail(l10n, state.error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.downloadFailed(audioItem.name)}\n$detail'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _downloadFailureDetail(
    AppLocalizations l10n,
    AudioImportException error,
  ) {
    return switch (error.code) {
      AudioImportFailureCode.invalidUrl => l10n.audioUrlUnsupported,
      AudioImportFailureCode.unsupportedScheme => l10n.audioUrlUnsupported,
      AudioImportFailureCode.unsupportedFormat => l10n.audioUrlUnsupported,
      AudioImportFailureCode.notAudio => l10n.audioUrlUnsupported,
      AudioImportFailureCode.network => l10n.downloadErrorNetwork,
      AudioImportFailureCode.storage => l10n.downloadErrorStorage,
      AudioImportFailureCode.duplicate => error.message,
      AudioImportFailureCode.canceled => l10n.cancel,
      AudioImportFailureCode.unknown =>
        error.message.isEmpty ? l10n.audioDownloadFailed : error.message,
    };
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

/// 置顶标记徽章 —— 卡片右上角常驻图钉，直观表达该音频已置顶。
///
/// 采用与菜单内图钉一致的倾斜角度与 [AppTheme.pinColor]，视觉语言统一。
class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      key: const Key('audio_list_tile_pinned_badge'),
      angle: 0.52,
      child: const Icon(Icons.push_pin, size: 14, color: AppTheme.pinColor),
    );
  }
}

/// 未下载音频（播客单集 / 社区合集音频）的左侧图标，承载「未下载 / 下载中」两态。
///
/// 尺寸与 [LearningProgressIcon] 默认值保持一致，确保切换时不抖动。
class _DownloadLeading extends StatelessWidget {
  const _DownloadLeading({required this.downloading, this.progress});

  /// 是否正在下载：true 显示进度环，false 显示静态下载图标。
  final bool downloading;

  /// 下载进度 0..1；null 或 <0 表示不定态（旋转动画）。
  final double? progress;

  static const double _size = 40;
  static const double _iconSize = 20;
  static const double _strokeWidth = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 下载中：进度环 + 中心下载图标（不定进度时环为旋转动画）。
    if (downloading) {
      final p = progress;
      final value = (p == null || p < 0) ? null : p.clamp(0.0, 1.0);
      return SizedBox(
        key: const Key('audio_list_tile_downloading_icon'),
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: _size,
              height: _size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: _strokeWidth,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            Icon(
              Icons.download_rounded,
              size: _iconSize - 4,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      );
    }

    // 未下载：可点击的下载图标（点击行即触发下载）。
    return Container(
      key: const Key('audio_list_tile_download_icon'),
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
      ),
      child: Icon(
        Icons.download_rounded,
        size: _iconSize,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
