/// Podcast 信息只读展示弹窗
///
/// - [showPodcastFeedInfoSheet]：合集级详情（标题/简介/图片/Apple 链接/link/RSS）
/// - [showPodcastEpisodeInfoSheet]：音频级详情（标题/简介/网页 link/音频下载链接）
library;

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/collection.dart';
import '../../providers/collection_provider.dart';
import '../../theme/app_theme.dart';
import 'podcast_models.dart';
import 'widgets/podcast_subscribe_tile.dart';

/// 展示 podcast 合集的详情（只读）。
void showPodcastFeedInfoSheet(
  BuildContext context,
  Collection collection, {
  String? refreshStatusText,
}) {
  final l10n = AppLocalizations.of(context)!;
  final collectionId = collection.id;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 用 Consumer 监听该合集：打开详情时常伴随自动刷新，刷新写回新描述后弹窗
    // 内容实时更新，无需关闭重开（旧实现是打开瞬间的一次性快照，刷新完不重建）。
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final current = ref.watch(
          collectionListProvider.select(
            (s) => s.rawCollections.firstWhere(
              (c) => c.id == collectionId,
              // 合集已被删除时回退到打开时的快照，避免抛异常。
              orElse: () => collection,
            ),
          ),
        );

        final meta = _decodeMeta(current.podcastMetaJson);
        final title = meta?.title ?? current.name;
        final description = meta?.description ?? current.description;
        final imageUrl = meta?.imageUrl ?? current.coverUrl;
        final websiteUrl = meta?.websiteUrl;

        return _InfoSheet(
          title: l10n.podcastDetails,
          heroTitle: title,
          heroAuthor: meta?.author,
          heroDescription: description,
          imageUrl: imageUrl,
          refreshStatusText: refreshStatusText,
          metadata: _feedMetadata(l10n, meta),
          links: [
            if (_isApplePodcastUrl(current.podcastInputUrl))
              PodcastInfoLink(l10n.podcastAppleLink, current.podcastInputUrl!),
            if (websiteUrl != null && websiteUrl.trim().isNotEmpty)
              PodcastInfoLink(_metadataLabel(l10n, 'Website'), websiteUrl),
            if (_hasText(current.podcastFeedUrl))
              PodcastInfoLink(l10n.podcastFeedUrl, current.podcastFeedUrl!),
          ],
        );
      },
    ),
  );
}

/// 生成 Podcast 合集刷新状态文案，供合集详情页和合集列表菜单共用。
String? podcastRefreshStatusText(
  AppLocalizations l10n,
  Collection collection, {
  DateTime? refreshingAt,
}) {
  final isZh = l10n.localeName.startsWith('zh');
  if (refreshingAt != null) {
    final time = _formatDateTime(refreshingAt);
    return isZh ? '刷新中 · $time' : 'Refreshing · $time';
  }

  final refreshedAt = collection.podcastLastRefreshedAt;
  if (refreshedAt == null) return null;
  if (!podcastHasRefreshError(collection)) return null;
  final time = _formatDateTime(refreshedAt);
  return isZh ? '失败 · $time' : 'Failed · $time';
}

/// Podcast 合集是否存在最近一次刷新错误。
bool podcastHasRefreshError(Collection collection) {
  return collection.podcastLastRefreshError?.trim().isNotEmpty == true;
}

/// Podcast 合集列表上的刷新失败短标记。
String podcastRefreshFailedLabel(AppLocalizations l10n) {
  return l10n.localeName.startsWith('zh') ? '刷新失败' : 'Refresh failed';
}

/// 展示通用 Podcast 信息弹窗。
///
/// 发现页 Podcast 预览和本地已订阅 Podcast 合集共用同一套详情布局，
/// 避免同一类内容在不同入口呈现不一致。
void showPodcastInfoSheet(
  BuildContext context, {
  required String title,
  required String heroTitle,
  required List<PodcastInfoLink> links,
  String? heroAuthor,
  String? heroDescription,
  String? imageUrl,
  String? dateText,
  String? refreshStatusText,
  List<PodcastInfoMeta> metadata = const [],
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: title,
      heroTitle: heroTitle,
      heroAuthor: heroAuthor,
      heroDescription: heroDescription,
      imageUrl: imageUrl,
      dateText: dateText,
      refreshStatusText: refreshStatusText,
      metadata: metadata,
      links: links,
    ),
  );
}

/// 展示 RSS feed 元信息详情。搜索预览和本地合集详情共用该入口的数据口径。
void showPodcastFeedMetaInfoSheet(
  BuildContext context, {
  required PodcastFeedMeta meta,
  String? applePodcastUrl,
  String? fallbackImageUrl,
}) {
  final l10n = AppLocalizations.of(context)!;
  final appleUrl = applePodcastUrl?.trim() ?? '';
  final imageUrl = _hasText(meta.imageUrl) ? meta.imageUrl : fallbackImageUrl;
  final websiteUrl = meta.websiteUrl;
  showPodcastInfoSheet(
    context,
    title: l10n.podcastDetails,
    heroTitle: meta.title,
    heroAuthor: meta.author,
    heroDescription: meta.description,
    imageUrl: imageUrl,
    metadata: _feedMetadata(l10n, meta),
    links: [
      if (appleUrl.isNotEmpty) PodcastInfoLink(l10n.podcastAppleLink, appleUrl),
      if (websiteUrl != null && websiteUrl.trim().isNotEmpty)
        PodcastInfoLink(_metadataLabel(l10n, 'Website'), websiteUrl),
      PodcastInfoLink(l10n.podcastFeedUrl, meta.feedUrl),
    ],
  );
}

/// 展示 podcast episode 的详情（只读）。
void showPodcastEpisodeInfoSheet(
  BuildContext context,
  AudioItem item, {
  String? podcastImageUrl,
}) {
  final l10n = AppLocalizations.of(context)!;
  final episodeLink = _episodeLink(item);
  // meta 行：发布日期 · 时长，二者都可能缺省。
  final metaParts = <String>[
    if (item.originalDate != null)
      l10n.publishedOn(_formatDate(item.originalDate!)),
    if (item.totalDuration > 0)
      l10n.audioDuration(_formatDuration(item.totalDuration)),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: l10n.podcastEpisodeMeta,
      heroTitle: item.name,
      heroDescription: item.description,
      dateText: metaParts.isEmpty ? null : metaParts.join(' · '),
      // 单集封面优先用 episode 自带图，缺省时 _PodcastArtwork 会显示占位图标。
      imageUrl: _hasText(item.podcastImageUrl)
          ? item.podcastImageUrl
          : podcastImageUrl,
      links: [
        if (_hasText(episodeLink))
          PodcastInfoLink(l10n.podcastOriginalLink, episodeLink!),
        if (_hasText(item.podcastEnclosureUrl))
          PodcastInfoLink(l10n.podcastEnclosureUrl, item.podcastEnclosureUrl!),
      ],
    ),
  );
}

/// 展示预览态 podcast 单集（[PodcastEpisode]）的详情（只读）。
///
/// 与已入库的 [showPodcastEpisodeInfoSheet] 布局一致，但数据来自 RSS 预览而非
/// 本地 [AudioItem]，用于订阅前在预览页查看单集标题/摘要/发布时间/下载链接。
/// [podcastImageUrl] 作为单集无自带封面时的兜底头图。
void showPodcastPreviewEpisodeSheet(
  BuildContext context,
  PodcastEpisode episode, {
  String? podcastImageUrl,
}) {
  final l10n = AppLocalizations.of(context)!;
  final metaParts = <String>[
    if (episode.pubDate != null)
      l10n.publishedOn(_formatDate(episode.pubDate!)),
    if (episode.durationSeconds != null && episode.durationSeconds! > 0)
      l10n.audioDuration(_formatDuration(episode.durationSeconds!)),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: l10n.podcastEpisodeMeta,
      heroTitle: episode.title,
      heroDescription: episode.description,
      dateText: metaParts.isEmpty ? null : metaParts.join(' · '),
      imageUrl: _hasText(episode.imageUrl) ? episode.imageUrl : podcastImageUrl,
      links: [
        if (_hasText(episode.link))
          PodcastInfoLink(l10n.podcastOriginalLink, episode.link!),
        if (_hasText(episode.enclosureUrl))
          PodcastInfoLink(l10n.podcastEnclosureUrl, episode.enclosureUrl),
      ],
    ),
  );
}

PodcastFeedMeta? _decodeMeta(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return PodcastFeedMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _episodeLink(AudioItem item) {
  if (_hasText(item.podcastLink)) return item.podcastLink;
  final guid = item.podcastEpisodeGuid;
  if (!_hasText(guid)) return null;
  final uri = Uri.tryParse(guid!);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  return switch (uri.scheme) {
    'http' || 'https' => guid,
    _ => null,
  };
}

bool _isApplePodcastUrl(String? value) {
  if (!_hasText(value)) return false;
  final url = value!;
  final uri = Uri.tryParse(url);
  final host = uri?.host.toLowerCase();
  return host == 'podcasts.apple.com' || host == 'itunes.apple.com';
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}

/// 日期 + 时分（yyyy-MM-dd HH:mm），用于「上次刷新」展示。
String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// 时长（秒 → mm:ss 或 h:mm:ss）。
String _formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

class PodcastInfoLink {
  final String label;
  final String url;

  const PodcastInfoLink(this.label, this.url);
}

class PodcastInfoMeta {
  final String label;
  final String value;

  const PodcastInfoMeta(this.label, this.value);
}

List<PodcastInfoMeta> _feedMetadata(
  AppLocalizations l10n,
  PodcastFeedMeta? meta,
) {
  if (meta == null) return const [];
  final language = meta.language;
  return [
    if (meta.categories.isNotEmpty)
      PodcastInfoMeta(
        _metadataLabel(l10n, 'Categories'),
        meta.categories.join(' · '),
      ),
    if (language != null && language.trim().isNotEmpty)
      PodcastInfoMeta(_metadataLabel(l10n, 'Language'), language),
  ];
}

String _metadataLabel(AppLocalizations l10n, String en) {
  if (!l10n.localeName.startsWith('zh')) return en;
  return switch (en) {
    'Categories' => '类别',
    'Language' => '语言',
    'Website' => '官网',
    _ => en,
  };
}

/// 匹配正文中的 http/https 链接（到空白为止）。
final _urlPattern = RegExp(r'https?://[^\s]+');

/// 用外部浏览器打开链接，失败时提示。
Future<void> _openExternalUrl(BuildContext context, String value) async {
  final l10n = AppLocalizations.of(context)!;
  final uri = Uri.tryParse(value);
  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.podcastOpenLinkFailed)));
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.podcastOpenLinkFailed)));
  }
}

/// 可选中的正文文本，其中的 http/https 链接渲染为可点击（点击外部打开）。
///
/// 末尾常见标点（`.,;:!?)]}` 与全角句读）不并入链接，避免把句号带进 URL。
class _LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _LinkifiedText({required this.text, this.style});

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style;
    final linkStyle = baseStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    // 按段落拆分：parser 已把块级标签（p / div / li / br）统一转成单个 `\n`，
    // 因此每个换行都是一个段落边界。逐段渲染成独立的 SelectableText，段落之间
    // 补一个固定间距，避免所有段落挤在一起（段内行距由 baseStyle.height 控制）。
    final paragraphs = widget.text
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    final children = <Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      if (i > 0) children.add(const SizedBox(height: AppSpacing.s));
      children.add(
        SelectableText.rich(
          TextSpan(
            style: baseStyle,
            children: _buildSpans(context, paragraphs[i], linkStyle),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 把单段文本切成普通文本 span 与可点击链接 span。
  ///
  /// 结尾常见标点不并入链接，避免把句号带进 URL；生成的 recognizer 登记到
  /// [_recognizers]，由 [dispose] 统一释放。
  List<InlineSpan> _buildSpans(
    BuildContext context,
    String text,
    TextStyle? linkStyle,
  ) {
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      var url = match.group(0)!;
      var trailing = '';
      // 把结尾标点从链接里剥出来，避免污染目标 URL。
      while (url.isNotEmpty && '.,;:!?)]}）】。，、'.contains(url[url.length - 1])) {
        trailing = url[url.length - 1] + trailing;
        url = url.substring(0, url.length - 1);
      }
      final target = url;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openExternalUrl(context, target);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: url, style: linkStyle, recognizer: recognizer));
      if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return spans;
  }
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final String heroTitle;
  final String? heroAuthor;
  final String? heroDescription;
  final String? imageUrl;
  final String? dateText;
  final String? refreshStatusText;
  final List<PodcastInfoMeta> metadata;
  final List<PodcastInfoLink> links;

  const _InfoSheet({
    required this.title,
    required this.heroTitle,
    required this.links,
    this.heroAuthor,
    this.heroDescription,
    this.imageUrl,
    this.dateText,
    this.refreshStatusText,
    this.metadata = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.32,
        maxChildSize: 0.88,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.xl + bottom,
            ),
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.l),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.l),
              _InfoHero(
                title: heroTitle,
                author: heroAuthor,
                description: heroDescription,
                imageUrl: imageUrl,
                dateText: dateText,
                refreshStatusText: refreshStatusText,
                metadata: metadata,
              ),
              if (links.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.l),
                for (final link in links) _LinkRow(link: link),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoHero extends StatelessWidget {
  final String title;
  final String? author;
  final String? description;
  final String? imageUrl;
  final String? dateText;
  final String? refreshStatusText;
  final List<PodcastInfoMeta> metadata;

  const _InfoHero({
    required this.title,
    this.author,
    this.description,
    this.imageUrl,
    this.dateText,
    this.refreshStatusText,
    this.metadata = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 封面只与标题/作者/日期并排；简介移到整行下方占满宽度，
    // 避免文字比封面高时封面下方左侧出现大片空白。
    final headColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(title, style: theme.textTheme.titleLarge),
        if (_hasText(author)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            author!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasText(dateText)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasText(refreshStatusText)) ...[
          const SizedBox(height: AppSpacing.xs),
          _RefreshStatusLine(text: refreshStatusText!),
        ],
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          _MetadataList(metadata: metadata),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastCover(imageUrl: imageUrl, size: 88),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: headColumn),
          ],
        ),
        if (_hasText(description)) ...[
          const SizedBox(height: AppSpacing.m),
          _LinkifiedText(
            text: description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetadataList extends StatelessWidget {
  final List<PodcastInfoMeta> metadata;

  const _MetadataList({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.25,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in metadata)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('${item.label}: ${item.value}', style: style),
          ),
      ],
    );
  }
}

class _RefreshStatusLine extends StatelessWidget {
  final String text;

  const _RefreshStatusLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = text.contains('失败') || text.contains('Failed')
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final PodcastInfoLink link;

  const _LinkRow({required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 主点击打开链接；桌面右键（onSecondaryTapDown）/ 移动端长按
    // （onLongPressStart）在指针处弹出「复制」菜单，不常驻复制图标。
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: GestureDetector(
        onSecondaryTapDown: (d) => _showCopyMenu(context, d.globalPosition),
        onLongPressStart: (d) => _showCopyMenu(context, d.globalPosition),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openExternalUrl(context, link.url),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSpacing.s,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        link.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 在 [position]（全局坐标）弹出仅含「复制」的上下文菜单。
  Future<void> _showCopyMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.copy_rounded, size: 18),
              const SizedBox(width: AppSpacing.s),
              Text(l10n.copy),
            ],
          ),
        ),
      ],
    );
    if (selected == 'copy' && context.mounted) {
      await Clipboard.setData(ClipboardData(text: link.url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
    }
  }
}
