/// Podcast 搜索与订阅统一页（全屏）。
///
/// 「发现资源」与「创建合集 → 订阅 Podcast」两个入口收敛到本页：
/// - 搜索框为空 → 展示精选 Podcast（[featuredPodcastsProvider]）；
/// - 输入关键词 → Apple iTunes Search（[podcastSearchResultsProvider]，350ms 防抖）。
/// - 粘贴 http/https 链接 → 解析该链接对应的播客并显示为可点 item（[podcastPreviewProvider]），
///   **不直接订阅**，点「+」才订阅。
///
/// 点击 item 进入单集预览页；点「+」订阅后**停留在本页**（item 自动显示对勾和
/// 「已添加」角标），支持连续订阅多个播客。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/collection.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/form_input_style.dart';
import '../../../widgets/common/svg_action_icon.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../providers/featured_podcasts_provider.dart';
import '../podcast_models.dart';
import '../podcast_preview_provider.dart';
import '../podcast_repository.dart';
import '../podcast_search_provider.dart';
import '../widgets/podcast_subscribe_tile.dart';

class PodcastDiscoveryScreen extends ConsumerStatefulWidget {
  const PodcastDiscoveryScreen({super.key});

  @override
  ConsumerState<PodcastDiscoveryScreen> createState() =>
      _PodcastDiscoveryScreenState();
}

class _PodcastDiscoveryScreenState
    extends ConsumerState<PodcastDiscoveryScreen> {
  static const _loadMoreThreshold = 200.0;

  final _searchController = TextEditingController();
  final _featuredScrollController = ScrollController();

  /// 防抖后的查询词（已 trim）；驱动精选、搜索和链接模式切换。
  String _query = '';
  Timer? _debounce;
  bool _hasLoggedLoadMoreThreshold = false;

  /// 正在订阅中的列表项标识集合（PodcastSearchResult.id /
  /// 链接模式的 feedUrl），驱动对应 tile 的 loading 态，防竞态。
  final Set<String> _subscribingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _featuredScrollController.addListener(_handleFeaturedScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(featuredPodcastsProvider.notifier).refreshFirstPage());
    });
  }

  @override
  void dispose() {
    _featuredScrollController
      ..removeListener(_handleFeaturedScroll)
      ..dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleFeaturedScroll() {
    if (_query.isNotEmpty || !_featuredScrollController.hasClients) {
      _hasLoggedLoadMoreThreshold = false;
      return;
    }
    final position = _featuredScrollController.position;
    if (position.extentAfter >= _loadMoreThreshold) {
      _hasLoggedLoadMoreThreshold = false;
      return;
    }

    if (!_hasLoggedLoadMoreThreshold) {
      _hasLoggedLoadMoreThreshold = true;
      AppLogger.log(
        'FeaturedPodcast',
        'pagination threshold reached pixels=${position.pixels.toStringAsFixed(0)} '
            'extentAfter=${position.extentAfter.toStringAsFixed(0)} '
            'scrollDirection=${position.userScrollDirection.name} '
            'isScrolling=${position.isScrollingNotifier.value}',
      );
    }
    unawaited(ref.read(featuredPodcastsProvider.notifier).loadMore());
  }

  void _onSearchChanged(String value) {
    // 立即 setState 更新清除按钮显隐；防抖 350ms 后再落到 _query。
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  /// 点击搜索框外部时释放焦点，让移动端用户可以直接收起键盘。
  void _dismissKeyboardOnTapOutside(PointerDownEvent event) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 输入是 http/https 且 host 非空 → 返回可订阅的链接，否则 null。
  Uri? _asLink(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  /// 本地已订阅播客：feedUrl → collection，用于判定「去学习」。
  Map<String, Collection> _subscribedByFeed() {
    final state = ref.watch(collectionListProvider);
    return {
      for (final c in state.collections)
        if (c.isPodcast && c.podcastFeedUrl != null) c.podcastFeedUrl!: c,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final rawText = _searchController.text;
    final link = _asLink(_query);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscribePodcast)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 外观与资源库搜索框（SearchAppBar）一致：浅色圆角底、无描边、小号搜索图标。
              Container(
                height: 40,
                padding: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        style: compactFormTextStyle(context),
                        // 搜索词通常包含空格；RSS 链接仍可直接粘贴并由下方逻辑识别。
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          // 纯占位提示：输入后即消失，不使用浮动 label（搜索框惯用法）。
                          hintText: l10n.podcastSearchHint,
                          prefixIcon: SvgActionIcon(
                            assetName: 'assets/icon/search.svg',
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
                        ),
                        onTapOutside: _dismissKeyboardOnTapOutside,
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (rawText.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        tooltip: l10n.collectionSearchClearTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _debounce?.cancel();
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Expanded(
                child: link != null
                    ? _buildLinkMode(l10n, link.toString())
                    : _query.isEmpty
                    ? _buildFeatured(l10n)
                    : _buildSearch(l10n, _query),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 链接模式：解析链接对应的播客并展示为可点 item（非直接订阅）。
  Widget _buildLinkMode(AppLocalizations l10n, String url) {
    final async = ref.watch(podcastPreviewProvider(url));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          _PodcastListMessage(message: _previewErrorMessage(l10n, error)),
      data: (data) {
        final meta = data.meta;
        final local = _subscribedByFeed()[meta.feedUrl];
        return ListView(
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            PodcastSubscribeTile(
              imageUrl: meta.imageUrl,
              title: meta.title,
              subtitle: meta.author,
              subscribed: local != null,
              subscribing: _subscribingIds.contains(meta.feedUrl),
              onOpen: () => _openPreview(
                PodcastPreviewArg(
                  title: meta.title,
                  imageUrl: meta.imageUrl,
                  description: meta.description,
                  author: meta.author,
                  feedUrl: meta.feedUrl,
                ),
              ),
              onSubscribe: () => _subscribe(
                inputUrl: url,
                id: meta.feedUrl,
                knownFeedUrl: meta.feedUrl,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 展示缓存/网络加载状态；请求和分页状态由精选 Podcast provider 管理。
  Widget _buildFeatured(AppLocalizations l10n) {
    return ref
        .watch(featuredPodcastsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _PodcastListMessage(
            message: l10n.podcastRefreshFailed(error.toString()),
            actionLabel: l10n.retry,
            onAction: () => unawaited(
              ref.read(featuredPodcastsProvider.notifier).refreshFirstPage(),
            ),
          ),
          data: (state) {
            final snapshot = state.snapshot;
            if (snapshot == null) {
              if (state.firstPageError != null) {
                return _PodcastListMessage(
                  message: l10n.podcastRefreshFailed(
                    state.firstPageError.toString(),
                  ),
                  actionLabel: l10n.retry,
                  onAction: () => unawaited(
                    ref
                        .read(featuredPodcastsProvider.notifier)
                        .refreshFirstPage(),
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }

            final podcasts = snapshot.podcasts;
            if (podcasts.isEmpty) {
              if (state.isRefreshingFirstPage) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.firstPageError != null) {
                return _PodcastListMessage(
                  message: l10n.podcastRefreshFailed(
                    state.firstPageError.toString(),
                  ),
                  actionLabel: l10n.retry,
                  onAction: () => unawaited(
                    ref
                        .read(featuredPodcastsProvider.notifier)
                        .refreshFirstPage(),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref
                    .read(featuredPodcastsProvider.notifier)
                    .refreshFirstPage(),
                child: ListView(
                  controller: _featuredScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .6,
                      child: _PodcastListMessage(
                        message: l10n.discoverPodcastEmpty,
                      ),
                    ),
                  ],
                ),
              );
            }

            final subscribed = _subscribedByFeed();
            return RefreshIndicator(
              onRefresh: () => ref
                  .read(featuredPodcastsProvider.notifier)
                  .refreshFirstPage(),
              child: ListView.builder(
                controller: _featuredScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount:
                    podcasts.length + (snapshot.nextCursor == null ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == podcasts.length) {
                    if (state.isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }
                    if (state.loadMoreError != null) {
                      return Center(
                        child: TextButton(
                          onPressed: () => unawaited(
                            ref
                                .read(featuredPodcastsProvider.notifier)
                                .loadMore(),
                          ),
                          child: Text(l10n.retry),
                        ),
                      );
                    }
                    return const SizedBox(height: 12);
                  }
                  final podcast = podcasts[index];
                  final local = subscribed[podcast.rssUrl];
                  return PodcastSubscribeTile(
                    imageUrl: podcast.imageUrl,
                    title: podcast.title,
                    subtitle: podcast.description,
                    subscribed: local != null,
                    subscribing: _subscribingIds.contains(podcast.id),
                    onOpen: () => _openPreview(
                      PodcastPreviewArg(
                        title: podcast.title,
                        imageUrl: podcast.imageUrl,
                        description: podcast.description,
                        feedUrl: podcast.rssUrl,
                        applePodcastUrl: podcast.applePodcastUrl,
                      ),
                    ),
                    onSubscribe: () => _subscribe(
                      inputUrl: podcast.subscriptionInputUrl,
                      id: podcast.id,
                      knownFeedUrl: podcast.rssUrl,
                    ),
                  );
                },
              ),
            );
          },
        );
  }

  /// Apple 搜索结果：loading/error/data(空态) 三态。
  Widget _buildSearch(AppLocalizations l10n, String term) {
    final async = ref.watch(podcastSearchResultsProvider(term));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _PodcastListMessage(message: l10n.podcastSearchFailed),
      data: (results) {
        if (results.isEmpty) {
          return _PodcastListMessage(message: l10n.podcastSearchEmpty);
        }
        final subscribed = _subscribedByFeed();
        return ListView.builder(
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: results.length,
          itemBuilder: (context, index) {
            final r = results[index];
            final local = subscribed[r.feedUrl];
            return PodcastSubscribeTile(
              imageUrl: r.artworkUrl,
              title: r.title,
              subtitle: r.author,
              subscribed: local != null,
              subscribing: _subscribingIds.contains(r.id),
              onOpen: () => _openPreview(
                PodcastPreviewArg(
                  title: r.title,
                  imageUrl: r.artworkUrl,
                  author: r.author,
                  feedUrl: r.feedUrl,
                  applePodcastUrl: r.applePodcastUrl,
                ),
              ),
              onSubscribe: () {
                final appleUrl = r.applePodcastUrl?.trim() ?? '';
                _subscribe(
                  inputUrl: appleUrl.isNotEmpty ? appleUrl : r.feedUrl,
                  id: r.id,
                  knownFeedUrl: r.feedUrl,
                );
              },
            );
          },
        );
      },
    );
  }

  /// 打开单集预览页（子路由，descriptor 经 extra 传入，§7.17）。
  void _openPreview(PodcastPreviewArg arg) {
    AppRoutes.pushNested<void>(
      context,
      AppRoutes.podcastPreviewSegment,
      extra: arg,
    );
  }

  /// 订阅列表项：登录校验 → createAndFetch，成功后**停留在本页**。
  ///
  /// collectionListProvider 更新会使 tile 自动翻成「去学习」，故不导航。
  /// 用 [id] 驱动对应 tile 的 loading，防竞态。
  Future<void> _subscribe({
    required String inputUrl,
    required String id,
    String? knownFeedUrl,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (_subscribingIds.contains(id)) return;

    final canEnroll = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.communityCollectionSignInRequiredTitle,
      message: l10n.podcastSignInRequiredMessage,
    );
    if (!mounted || !canEnroll) return;

    setState(() => _subscribingIds.add(id));
    try {
      await ref
          .read(podcastRepositoryProvider)
          .createAndFetch(inputUrl, knownFeedUrl: knownFeedUrl);
      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatSubscribeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _subscribingIds.remove(id));
    }
  }

  String _formatSubscribeError(AppLocalizations l10n, Object error) {
    if (error is PodcastAlreadySubscribedException) {
      return l10n.podcastAlreadySubscribed(error.collectionName);
    }
    if (error is PodcastFeedBlockedException) {
      return l10n.podcastFeedBlocked;
    }
    final raw = error.toString();
    final message = raw
        .replaceFirst('PodcastResolveException: ', '')
        .replaceFirst('PodcastParseException: ', '')
        .replaceFirst(RegExp(r'DioException \[[^\]]+\]:\s*'), '')
        .trim();
    return l10n.podcastSubscribeFailed(message.isEmpty ? raw : message);
  }

  /// 链接模式预览失败文案映射。
  String _previewErrorMessage(AppLocalizations l10n, Object error) {
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

/// 列表区居中提示（空态 / 错误态）。
class _PodcastListMessage extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PodcastListMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.podcasts_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}
