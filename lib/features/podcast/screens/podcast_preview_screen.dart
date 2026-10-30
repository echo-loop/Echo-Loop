/// Podcast 内容预览页（只读单集列表 + 订阅 CTA）。
///
/// 由 [PodcastPreviewArg] 驱动，供精选 Podcast、Apple 搜索结果和用户粘贴链接共用。
/// 本页不写入 audio_items；只有用户明确订阅后才走
/// [PodcastRepository.createAndFetch] 创建本地合集。
///
/// 订阅后**停留在本页**（CTA 翻成「去学习」），与订阅列表页交互一致；
/// 只有点「去学习」才 `context.go` 跳合集详情。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/collection.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../../../widgets/common/transcript_cc_badge.dart';
import '../../../theme/app_theme.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../podcast_info_sheet.dart';
import '../podcast_models.dart';
import '../podcast_preview_provider.dart';
import '../podcast_repository.dart';
import '../widgets/podcast_feed_summary_header.dart';
import '../widgets/podcast_subscribe_tile.dart';

class PodcastPreviewScreen extends ConsumerStatefulWidget {
  final PodcastPreviewArg arg;

  const PodcastPreviewScreen({super.key, required this.arg});

  @override
  ConsumerState<PodcastPreviewScreen> createState() =>
      _PodcastPreviewScreenState();
}

class _PodcastPreviewScreenState extends ConsumerState<PodcastPreviewScreen> {
  bool _subscribing = false;

  /// 错误卡「重试」进行中标志，给按钮一个可见的加载态。
  bool _retrying = false;

  PodcastPreviewArg get _arg => widget.arg;

  String get _inputUrl => _arg.subscriptionInputUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preview = ref.watch(podcastPreviewProvider(_inputUrl));
    final subscribedCollection = _findSubscribedCollection(preview);

    return Scaffold(
      appBar: AppBar(title: Text(_arg.title)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPreview,
              child: _buildContent(preview),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: SizedBox(
                width: double.infinity,
                child: _buildCta(subscribedCollection, l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AsyncValue<PodcastPreviewData> preview) {
    return preview.when(
      loading: () => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _PodcastPreviewHeader(arg: _arg),
          const LinearProgressIndicator(),
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _PodcastPreviewHeader(arg: _arg),
          _PodcastPreviewErrorCard(
            message: _formatPreviewError(error),
            retrying: _retrying,
            onRetry: _retryPreview,
          ),
        ],
      ),
      data: (data) {
        // 单集封面兜底：单集无自带头图时用播客封面，优先入参原始封面
        // （与 header 一致，避免 feed 图不可用时退回默认占位图）。
        final cover = (data.meta.imageUrl?.isNotEmpty ?? false)
            ? data.meta.imageUrl
            : _arg.imageUrl;
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.s),
          itemCount: data.episodes.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _PodcastPreviewHeader(arg: _arg);
            }
            final episode = data.episodes[index - 1];
            return _EpisodePreviewTile(
              episode: episode,
              podcastImageUrl: cover,
              onTap: () => showPodcastPreviewEpisodeSheet(
                context,
                episode,
                podcastImageUrl: cover,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshPreview() async {
    try {
      await ref
          .read(podcastPreviewServiceProvider)
          .fetchByUrl(_inputUrl, force: true);
    } catch (_) {
      // 服务层已记录失败原因；保留当前 error state，避免失败后再发一次默认请求。
      return;
    }
    ref.invalidate(podcastPreviewProvider(_inputUrl));
    try {
      await ref.read(podcastPreviewProvider(_inputUrl).future);
    } catch (error, stackTrace) {
      // 强制请求成功后此处应复用刚写入的缓存；若仍失败，保留诊断证据。
      AppLogger.log(
        'PodcastPreview',
        'preview cache publish failed inputUrl=$_inputUrl error=$error',
      );
      AppLogger.log('PodcastPreview', stackTrace.toString());
    }
  }

  Future<void> _retryPreview() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await _refreshPreview();
    if (!mounted) return;
    setState(() => _retrying = false);
  }

  Widget _buildCta(Collection? subscribedCollection, AppLocalizations l10n) {
    if (_subscribing) {
      return FilledButton(
        onPressed: null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(l10n.podcastSubscribing),
          ],
        ),
      );
    }
    if (subscribedCollection != null) {
      return FilledButton(
        onPressed: () =>
            context.go(AppRoutes.collectionDetail(subscribedCollection.id)),
        child: Text(l10n.goLearn),
      );
    }
    return FilledButton(
      onPressed: _subscribe,
      child: Text(l10n.addToMyCollections),
    );
  }

  /// 匹配本地已订阅合集：优先用解析后的 [PodcastFeedMeta.feedUrl]，
  /// 回退到入参已知的 [PodcastPreviewArg.feedUrl]。
  Collection? _findSubscribedCollection(
    AsyncValue<PodcastPreviewData> preview,
  ) {
    final candidates = <String>{
      if ((_arg.feedUrl ?? '').trim().isNotEmpty) _arg.feedUrl!.trim(),
      if (preview.valueOrNull != null) preview.value!.meta.feedUrl.trim(),
    };
    if (candidates.isEmpty) return null;
    final state = ref.watch(collectionListProvider);
    for (final c in state.collections) {
      if (c.isPodcast &&
          c.podcastFeedUrl != null &&
          candidates.contains(c.podcastFeedUrl!.trim())) {
        return c;
      }
    }
    return null;
  }

  Future<void> _subscribe() async {
    final l10n = AppLocalizations.of(context)!;
    final canEnroll = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.communityCollectionSignInRequiredTitle,
      message: l10n.podcastSignInRequiredMessage,
    );
    if (!mounted || !canEnroll) return;

    setState(() => _subscribing = true);
    try {
      final appleUrl = _arg.applePodcastUrl?.trim() ?? '';
      await ref
          .read(podcastRepositoryProvider)
          .createAndFetch(
            appleUrl.isNotEmpty ? appleUrl : _inputUrl,
            knownFeedUrl: _arg.feedUrl,
          );
      if (!mounted) return;
      // 订阅成功后停留在本页：collectionListProvider 更新会使 CTA/单集自动
      // 翻成「去学习」，仅提示成功、不导航。
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enrollSucceeded)));
    } on PodcastAlreadySubscribedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.podcastAlreadySubscribed(e.collectionName)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastPreviewSubscribeFailed)),
      );
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  String _formatPreviewError(Object error) {
    final l10n = AppLocalizations.of(context)!;
    if (error is PodcastPreviewException) {
      return switch (error.kind) {
        PodcastPreviewErrorKind.timeout ||
        PodcastPreviewErrorKind.network => l10n.podcastPreviewNetworkFailed,
        PodcastPreviewErrorKind.appleLookup => l10n.podcastPreviewAppleFailed,
        PodcastPreviewErrorKind.parseFailed => l10n.podcastPreviewParseFailed,
        PodcastPreviewErrorKind.blockedByAntiBot => l10n.podcastFeedBlocked,
        PodcastPreviewErrorKind.emptyFeed => l10n.podcastPreviewEmpty,
        PodcastPreviewErrorKind.rssUnavailable =>
          l10n.podcastPreviewNetworkFailed,
      };
    }
    return l10n.podcastPreviewNetworkFailed;
  }
}

/// 预览页头图卡片。
///
/// meta 统一从 [podcastPreviewProvider] 读取（单一数据源）：feed 加载完成后
/// 内联展示与「详情」弹窗都用 feed 的完整 meta（标题/作者/完整简介/封面），
/// 加载中才回退到精选/搜索/链接参数（[PodcastPreviewArg]）的精简信息，避免同一「详情」
/// 因打开时机不同而时而精简时而完整（时序不一致 bug）。
class _PodcastPreviewHeader extends ConsumerWidget {
  final PodcastPreviewArg arg;

  const _PodcastPreviewHeader({required this.arg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final meta = ref
        .watch(podcastPreviewProvider(arg.subscriptionInputUrl))
        .valueOrNull
        ?.meta;
    final description = meta?.description ?? arg.description;
    // RSS 加载完成后优先使用 feed 图，避免详情页和已订阅合集继续停在
    // 精选/搜索结果占位图；RSS 缺图时再回退到入参图。
    final imageUrl = (meta?.imageUrl?.isNotEmpty ?? false)
        ? meta?.imageUrl
        : arg.imageUrl;
    return PodcastFeedSummaryHeader(
      imageUrl: imageUrl,
      description: description,
      moreLabel: l10n.podcastShowMore,
      onTap: () => _showPodcastInfo(context, meta),
    );
  }

  void _showPodcastInfo(BuildContext context, PodcastFeedMeta? meta) {
    final l10n = AppLocalizations.of(context)!;
    if (meta != null) {
      showPodcastFeedMetaInfoSheet(
        context,
        meta: meta,
        applePodcastUrl: arg.applePodcastUrl,
        fallbackImageUrl: arg.imageUrl,
      );
      return;
    }
    final applePodcastUrl = arg.applePodcastUrl?.trim() ?? '';
    final feedUrl = arg.feedUrl?.trim() ?? '';
    final fallbackMeta = feedUrl.isEmpty
        ? null
        : PodcastFeedMeta(
            title: arg.title,
            feedUrl: feedUrl,
            author: arg.author,
            description: arg.description,
            imageUrl: arg.imageUrl,
          );
    if (fallbackMeta != null) {
      showPodcastFeedMetaInfoSheet(
        context,
        meta: fallbackMeta,
        applePodcastUrl: arg.applePodcastUrl,
        fallbackImageUrl: arg.imageUrl,
      );
      return;
    }
    showPodcastInfoSheet(
      context,
      title: l10n.podcastDetails,
      heroTitle: arg.title,
      heroAuthor: arg.author,
      heroDescription: arg.description,
      imageUrl: arg.imageUrl,
      links: [
        if (applePodcastUrl.isNotEmpty)
          PodcastInfoLink(l10n.podcastAppleLink, applePodcastUrl),
        if (feedUrl.isNotEmpty) PodcastInfoLink(l10n.podcastFeedUrl, feedUrl),
      ],
    );
  }
}

/// 单集卡片：与资源库/合集列表卡片风格一致（圆角封面 + 标题 + 元信息 + 摘要）。
///
/// 点击打开单集详情弹窗（标题/摘要/发布时间/时长/下载链接）。封面优先用单集
/// 自带头图，缺省时回退到 [podcastImageUrl]（播客封面）。
class _EpisodePreviewTile extends StatelessWidget {
  final PodcastEpisode episode;
  final String? podcastImageUrl;
  final VoidCallback onTap;

  const _EpisodePreviewTile({
    required this.episode,
    required this.onTap,
    this.podcastImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasTranscript = episode.transcriptUrl != null;
    final meta = <String>[
      if (episode.pubDate != null) _formatDate(episode.pubDate!),
      if (episode.durationSeconds != null && episode.durationSeconds! > 0)
        _formatDuration(episode.durationSeconds!),
    ].join(' · ');
    final cover = (episode.imageUrl?.isNotEmpty ?? false)
        ? episode.imageUrl
        : podcastImageUrl;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PodcastCover(imageUrl: cover, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (meta.isNotEmpty || hasTranscript)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (meta.isNotEmpty)
                              Flexible(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (meta.isNotEmpty && hasTranscript)
                              const SizedBox(width: 6),
                            if (hasTranscript)
                              TranscriptCcBadge(label: l10n.transcript),
                          ],
                        ),
                      ),
                    // 有字幕时以 CC 标记代替描述：RSS 描述常是「附逐句字幕」之类的长说明。
                    if (!hasTranscript &&
                        (episode.description ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          episode.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }
}

class _PodcastPreviewErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool retrying;

  const _PodcastPreviewErrorCard({
    required this.message,
    required this.onRetry,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: retrying ? null : onRetry,
                child: retrying
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      )
                    : Text(l10n.discoverRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
