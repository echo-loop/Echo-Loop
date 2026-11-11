// 资源库全局搜索结果：按名称 / 描述 / 作者分别过滤合集与音频，两组分区展示。
//
// 合集与音频均已全量加载在内存中，直接过滤即可，不访问数据库。
// 音频列表复用 AudioListView 保留排序、菜单与点击行为；合集区作为列表头部嵌入。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../utils/audio_search.dart';
import '../widgets/audio_list_view.dart';
import 'collection_screen.dart';

class LibrarySearchResults extends ConsumerWidget {
  /// 原始搜索输入；调用方保证非空白，过滤时再去除首尾空格。
  final String query;

  const LibrarySearchResults({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    final audioItems = ref.watch(
      audioLibraryProvider.select((state) => state.audioItems),
    );

    if (collectionState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // collections 已按用户排序并置顶，过滤保持该顺序。
    final matchedCollections = filterCollectionsByKeyword(
      collectionState.collections,
      query,
    );
    final matchedAudios = filterAudioItemsByKeyword(audioItems, query);

    if (matchedCollections.isEmpty && matchedAudios.isEmpty) {
      return Center(
        child: Text(l10n.librarySearchEmpty, textAlign: TextAlign.center),
      );
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matchedCollections.isNotEmpty) ...[
          _SectionTitle(title: l10n.collectionsTab),
          // 合集区嵌入外层滚动，不单独滚动，避免嵌套滚动冲突。
          CollectionListView(
            collections: matchedCollections,
            searchQuery: query,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ],
        if (matchedAudios.isNotEmpty) _SectionTitle(title: l10n.audioTab),
      ],
    );

    // 无匹配音频时不渲染 AudioListView：它的空状态会占用固定高度的空白区域。
    if (matchedAudios.isEmpty) {
      return ListView(children: [header]);
    }
    return AudioListView(
      items: matchedAudios,
      searchQuery: query,
      header: header,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
