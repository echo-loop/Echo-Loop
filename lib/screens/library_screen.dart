// 资源库页面
//
// 包含 SegmentedButton 切换合集/音频双视图，
// 使用 IndexedStack 保持两个视图状态。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/community_collections/widgets/discover_entry_banner.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/collection_provider.dart';
import '../router/app_router.dart';
import '../l10n/app_localizations.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/guide_flow.dart';
import '../widgets/import_audio_sheet.dart';
import 'collection_screen.dart';

// AudioSortButton 已提取到 audio_list_view.dart 中作为公开组件

/// 资源库视图类型
enum LibraryViewType { collections, audio }

/// 资源库页面 — 合集/音频双视图
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryViewType _currentView = LibraryViewType.collections;
  int _libraryTitleTapCount = 0;
  bool _showAllAudioShortcut = false;

  final _keyCreateCollection = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    final stepCreateCollection = GuideStep(
      key: _keyCreateCollection,
      description: l10n.guideLibraryCreateCollectionDescription,
    );

    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.libraryCreateCollection,
          shouldRun:
              _currentView == LibraryViewType.collections &&
              !collectionState.isLoading,
          steps: [stepCreateCollection],
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                key: const Key('library_title'),
                behavior: HitTestBehavior.opaque,
                onTap: _onLibraryTitleTap,
                child: Text(l10n.myLibrary),
              ),
              if (_showAllAudioShortcut) ...[
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('library_all_audio_button'),
                  onPressed: _showAllAudio,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.libraryShowAll),
                ),
              ],
            ],
          ),
          // TODO(资源库 UI 稳定后): 删除以下暂时隐藏的合集/音频选择组件及相关视图切换逻辑。
          // title: SegmentedButton<LibraryViewType>(
          //   segments: [
          //     ButtonSegment(
          //       value: LibraryViewType.collections,
          //       label: Text(l10n.collectionsTab),
          //     ),
          //     ButtonSegment(
          //       value: LibraryViewType.audio,
          //       label: Text(l10n.audioTab),
          //     ),
          //   ],
          //   selected: {_currentView},
          //   onSelectionChanged: (selected) {
          //     setState(() {
          //       _currentView = selected.first;
          //     });
          //   },
          //   showSelectedIcon: false,
          //   style: ButtonStyle(
          //     visualDensity: VisualDensity.compact,
          //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          //   ),
          // ),
          actions: _buildActions(l10n, stepCreateCollection),
        ),
        body: IndexedStack(
          index: _currentView.index,
          children: [
            const _CollectionListBody(),
            AudioListView(
              guideFirstAudioMenu: true,
              guideEnabled: _currentView == LibraryViewType.audio,
            ),
          ],
        ),
      ),
    );
  }

  /// 连续点击标题五次后，在标题旁显示临时的全量音频入口。
  void _onLibraryTitleTap() {
    if (_showAllAudioShortcut) return;
    setState(() {
      if (_libraryTitleTapCount < 5) {
        _libraryTitleTapCount += 1;
      }
      if (_libraryTitleTapCount == 5) {
        _showAllAudioShortcut = true;
      }
    });
  }

  /// 复用旧音频 Tab 的切换行为，保留音频列表及 AppBar 操作入口。
  void _showAllAudio() {
    setState(() {
      _currentView = LibraryViewType.audio;
    });
  }

  /// 根据当前视图构建 AppBar actions
  List<Widget> _buildActions(AppLocalizations l10n, GuideStep createStep) {
    if (_currentView == LibraryViewType.collections) {
      return [
        // 合集排序
        const CollectionSortButton(),
        IconButton(
          tooltip: l10n.textToLessonTitle,
          icon: const Icon(Icons.text_fields),
          onPressed: () => context.push(AppRoutes.textToLesson),
        ),
        // 「发现社区合集」入口已改为列表顶部的 DiscoverEntryBanner，更醒目；
        // AppBar 这里不再放 compass icon，避免重复。
        // 创建合集
        GuideTarget(
          step: createStep,
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showCreateCollectionDialog(context),
          ),
        ),
        const SizedBox(width: 8),
      ];
    } else {
      return [
        // 音频排序
        const AudioSortButton(),
        // 添加音频
        IconButton(
          tooltip: l10n.textToLessonTitle,
          icon: const Icon(Icons.text_fields),
          onPressed: () => context.push(AppRoutes.textToLesson),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => showImportAudioSheet(context),
        ),
        const SizedBox(width: 8),
      ];
    }
  }
}

/// 合集列表视图体（不含 Scaffold/AppBar）
class _CollectionListBody extends ConsumerWidget {
  const _CollectionListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionState = ref.watch(collectionListProvider);
    // Banner 在 loading / empty / data 三态下都显示，让新用户一进来就看到入口。
    return Column(
      children: [
        const DiscoverEntryBanner(),
        Expanded(child: _buildInner(collectionState)),
      ],
    );
  }

  Widget _buildInner(CollectionState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmpty) return const CollectionEmptyState();
    return CollectionListView(collections: state.collections);
  }
}
