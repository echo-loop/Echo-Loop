/// Tab 导航外壳组件
///
/// 从 main.dart 的 MainScreen 提取，使用 StatefulNavigationShell
/// 实现 Tab 切换并保持各 Tab 状态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/tag_provider.dart';
import '../theme/app_theme.dart';

/// 主导航壳组件 — 包含 NavigationRail / NavigationBar + 内容区域
class MainShell extends ConsumerStatefulWidget {
  /// go_router 提供的 StatefulNavigationShell
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioLibraryProvider.notifier).loadLibrary().then((_) {
        ref.read(collectionListProvider.notifier).loadCollections();
        ref.read(tagListProvider.notifier).loadTags();
        ref.read(audioLibraryProvider.notifier).backfillDurations();
        ref.read(audioLibraryProvider.notifier).backfillTranscriptStats();
      });
      ref.read(learningProgressNotifierProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;

        return Scaffold(
          body: Row(
            children: [
              if (isWideScreen)
                NavigationRail(
                  extended: constraints.maxWidth >= 800,
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    widget.navigationShell.goBranch(
                      index,
                      initialLocation:
                          index == widget.navigationShell.currentIndex,
                    );
                  },
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(
                        Icons.library_music,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.library),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(
                        Icons.school,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.study),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.favorite_border),
                      selectedIcon: const Icon(
                        Icons.favorite,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.favorites),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(
                        Icons.person,
                        color: AppTheme.navActiveColor,
                      ),
                      label: Text(l10n.profile),
                    ),
                  ],
                ),
              Expanded(child: widget.navigationShell),
            ],
          ),
          bottomNavigationBar: isWideScreen
              ? null
              : NavigationBar(
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    widget.navigationShell.goBranch(
                      index,
                      initialLocation:
                          index == widget.navigationShell.currentIndex,
                    );
                  },
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(
                        Icons.library_music,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.library,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(
                        Icons.school,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.study,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.favorite_border),
                      selectedIcon: const Icon(
                        Icons.favorite,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.favorites,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(
                        Icons.person,
                        color: AppTheme.navActiveColor,
                      ),
                      label: l10n.profile,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
