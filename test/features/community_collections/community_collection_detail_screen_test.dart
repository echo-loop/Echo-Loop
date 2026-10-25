import 'package:echo_loop/features/community_collections/models/community_collection_models.dart';
import 'package:echo_loop/features/community_collections/models/community_collection_paging.dart';
import 'package:echo_loop/features/community_collections/providers/community_collection_detail_provider.dart';
import 'package:echo_loop/features/community_collections/providers/discover_community_collections_provider.dart';
import 'package:echo_loop/features/community_collections/screens/community_collection_detail_screen.dart';
import 'package:echo_loop/features/community_collections/widgets/community_collection_header.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

void main() {
  final files = [
    const CommunityCollectionFile(
      id: 'file-1',
      title: 'Track 1',
      description: null,
      mediaType: CommunityMediaType.audio,
      durationSec: 65,
      fileSizeBytes: null,
      difficulty: CommunityDifficulty.b1,
      publishedAt: null,
      sortOrder: 0,
      mediaUrl: 'https://example.com/track-1.m4a',
    ),
    const CommunityCollectionFile(
      id: 'file-2',
      title: 'Track 2',
      description: null,
      mediaType: CommunityMediaType.audio,
      durationSec: null,
      fileSizeBytes: null,
      difficulty: null,
      publishedAt: null,
      sortOrder: 1,
      mediaUrl: 'https://example.com/track-2.m4a',
    ),
  ];

  Future<void> pumpDetail(
    WidgetTester tester, {
    bool subscribed = false,
    _TestCommunityCollectionFiles? detailNotifier,
    ValueNotifier<ThemeData>? themeNotifier,
  }) async {
    Widget screen = const CommunityCollectionDetailScreen(
      remoteId: 'collection-1',
    );
    if (themeNotifier case final notifier?) {
      screen = ValueListenableBuilder<ThemeData>(
        valueListenable: notifier,
        child: screen,
        builder: (context, theme, child) =>
            Theme(data: theme, child: child ?? const SizedBox.shrink()),
      );
    }
    await tester.pumpWidget(
      createTestApp(
        screen,
        overrides: [
          discoverCommunityCollectionsProvider.overrideWith(
            () => _TestDiscoverCommunityCollections(
              PublicCollectionCatalogEntry(
                id: 'collection-1',
                name: 'Community English',
                description: 'A short collection',
                coverUrl: null,
                authorNickname: 'Echo Studio',
                fileCount: files.length,
                publishedAt: DateTime(2026, 9, 22),
                updatedAt: DateTime(2026, 9, 24, 15, 7),
              ),
            ),
          ),
          if (subscribed)
            collectionListProvider.overrideWith(
              () => TestCollectionList(
                CollectionState(
                  rawCollections: [
                    Collection(
                      id: 'local-1',
                      name: 'Stale local name',
                      createdDate: DateTime(2026, 9, 22),
                      source: CollectionSource.community,
                      remoteId: 'collection-1',
                    ),
                  ],
                  audioIdsMap: const {
                    'local-1': ['local-only-file'],
                  },
                ),
              ),
            ),
          communityCollectionFilesProvider('collection-1').overrideWith(
            () => detailNotifier ?? _TestCommunityCollectionFiles(files),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未加入合集详情显示素材数量和可用时长', (tester) async {
    await pumpDetail(tester);

    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Echo Studio'), findsOneWidget);
    expect(find.text('2026-09-24 15:07'), findsOneWidget);
    expect(find.text('9/22/2026'), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(CommunityCollectionHeader),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(CommunityCollectionHeader)).width,
      closeTo(tester.getSize(find.byType(ListView)).width, 1),
    );
    expect(
      tester.getTopLeft(find.byType(CommunityCollectionHeader)).dy,
      closeTo(tester.getBottomLeft(find.byType(AppBar)).dy, 1),
    );
    expect(find.text('Name'), findsNothing);
    expect(find.text('Duration'), findsNothing);
    expect(
      find.byKey(const ValueKey('community-collection-files-start-divider')),
      findsOneWidget,
    );
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('Track 2'), findsOneWidget);
    expect(find.text('Add to My Collections'), findsOneWidget);
    expect(find.text('0s'), findsNothing);
    expect(
      tester.getTopLeft(find.byType(CommunityCollectionHeader)).dy,
      lessThan(tester.getTopLeft(find.text('Track 1')).dy),
    );
  });

  testWidgets('合集详情停留时切换主题会立即更新素材文字颜色', (tester) async {
    final themeNotifier = ValueNotifier(AppTheme.light());
    addTearDown(themeNotifier.dispose);
    final detailNotifier = _TestCommunityCollectionFiles([
      const CommunityCollectionFile(
        id: 'theme-aware-file',
        title: 'Theme aware track',
        description: 'Theme aware description',
        mediaType: CommunityMediaType.audio,
        durationSec: 65,
        fileSizeBytes: null,
        difficulty: null,
        publishedAt: null,
        sortOrder: 0,
        mediaUrl: 'https://example.com/theme-aware-track.m4a',
      ),
    ]);

    await pumpDetail(
      tester,
      detailNotifier: detailNotifier,
      themeNotifier: themeNotifier,
    );

    final titleFinder = find.text('Theme aware track');
    final descriptionFinder = find.byKey(
      const ValueKey('community-collection-file-description-theme-aware-file'),
    );
    expect(
      tester.widget<Text>(titleFinder).style?.color,
      AppTheme.light().colorScheme.onSurface,
    );

    themeNotifier.value = AppTheme.dark();
    await tester.pumpAndSettle();

    final darkTheme = AppTheme.dark();
    expect(
      tester.widget<Text>(titleFinder).style?.color,
      darkTheme.colorScheme.onSurface,
    );
    expect(
      tester.widget<Text>(descriptionFinder).style?.color,
      Color.lerp(
        darkTheme.colorScheme.onSurfaceVariant,
        darkTheme.colorScheme.surface,
        0.22,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('预览素材在名称下方显示简介，空白简介隐藏且长简介限制两行', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longDescription =
        'This material introduces the story, its main characters, and the '
        'language points learners can practice while listening to the full '
        'recording.';
    final detailNotifier = _TestCommunityCollectionFiles([
      const CommunityCollectionFile(
        id: 'file-with-description',
        title: 'Described track',
        description: longDescription,
        mediaType: CommunityMediaType.audio,
        durationSec: 125,
        fileSizeBytes: null,
        difficulty: CommunityDifficulty.b1,
        publishedAt: null,
        sortOrder: 0,
        mediaUrl: 'https://example.com/described-track.m4a',
      ),
      const CommunityCollectionFile(
        id: 'file-with-blank-description',
        title: 'Track without description',
        description: '   ',
        mediaType: CommunityMediaType.audio,
        durationSec: 80,
        fileSizeBytes: null,
        difficulty: null,
        publishedAt: null,
        sortOrder: 1,
        mediaUrl: 'https://example.com/blank-description.m4a',
      ),
      const CommunityCollectionFile(
        id: 'file-with-short-description',
        title:
            'A very long track title that should truncate before the type badge',
        description: 'A short summary.',
        mediaType: CommunityMediaType.video,
        durationSec: null,
        fileSizeBytes: null,
        difficulty: null,
        publishedAt: null,
        sortOrder: 2,
        mediaUrl: 'https://example.com/short-description.m4a',
      ),
    ]);

    await pumpDetail(tester, detailNotifier: detailNotifier);

    final descriptionFinder = find.byKey(
      const ValueKey(
        'community-collection-file-description-file-with-description',
      ),
    );
    final descriptionWidget = tester.widget<Text>(descriptionFinder);
    final titleWidget = tester.widget<Text>(find.text('Described track'));
    expect(find.text('Described track'), findsOneWidget);
    expect(find.text(longDescription), findsOneWidget);
    expect(find.text('Track without description'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'community-collection-file-description-file-with-blank-description',
        ),
      ),
      findsNothing,
    );
    expect(descriptionWidget.maxLines, 2);
    expect(descriptionWidget.overflow, TextOverflow.ellipsis);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('file-with-description')))
          .height,
      greaterThan(
        tester
            .getSize(find.byKey(const ValueKey('file-with-short-description')))
            .height,
      ),
    );
    expect(
      descriptionWidget.style?.fontSize,
      lessThan(titleWidget.style?.fontSize ?? double.infinity),
    );
    expect(descriptionWidget.style?.fontWeight, FontWeight.w400);
    expect(descriptionWidget.style?.color, isNot(titleWidget.style?.color));
    final audioTypeFinder = find.byKey(
      const ValueKey('community-collection-file-type-file-with-description'),
    );
    final videoTypeFinder = find.byKey(
      const ValueKey(
        'community-collection-file-type-file-with-short-description',
      ),
    );
    expect(tester.widget<Semantics>(audioTypeFinder).properties.label, 'Audio');
    expect(tester.widget<Semantics>(videoTypeFinder).properties.label, 'Video');
    expect(tester.getSize(audioTypeFinder), const Size(24, 24));
    expect(tester.getSize(videoTypeFinder), const Size(24, 24));
    expect(
      tester.getTopLeft(audioTypeFinder).dx,
      lessThan(tester.getTopLeft(find.text('Described track')).dx),
    );
    expect(
      tester.getTopLeft(audioTypeFinder).dx,
      closeTo(tester.getTopLeft(descriptionFinder).dx, 1),
    );
    final audioIconFinder = find.descendant(
      of: audioTypeFinder,
      matching: find.byIcon(Icons.graphic_eq),
    );
    expect(
      tester.getTopLeft(audioIconFinder).dx,
      closeTo(tester.getTopLeft(descriptionFinder).dx, 1),
    );
    expect(
      tester.getTopLeft(find.text('Described track')).dx -
          tester.getTopRight(audioIconFinder).dx,
      closeTo(6, 1),
    );
    expect(
      tester.getTopLeft(find.text('Described track')).dx -
          tester.getTopRight(audioTypeFinder).dx,
      closeTo(4, 1),
    );
    expect(audioIconFinder, findsOneWidget);
    expect(
      find.descendant(
        of: videoTypeFinder,
        matching: find.byIcon(Icons.videocam_outlined),
      ),
      findsOneWidget,
    );
    final audioIcon = tester.widget<Icon>(
      find.descendant(
        of: audioTypeFinder,
        matching: find.byIcon(Icons.graphic_eq),
      ),
    );
    final videoIcon = tester.widget<Icon>(
      find.descendant(
        of: videoTypeFinder,
        matching: find.byIcon(Icons.videocam_outlined),
      ),
    );
    final colorScheme = Theme.of(tester.element(audioTypeFinder)).colorScheme;
    expect(audioIcon.color, colorScheme.primary);
    expect(videoIcon.color, AppTheme.videoMediaTypeColor(Brightness.light));
    expect(videoIcon.color, isNot(audioIcon.color));
    expect(find.text('B1'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情接口返回的合集元数据更新信息头部和标题', (tester) async {
    final latest = PublicCollectionCatalogEntry(
      id: 'collection-1',
      name: 'Latest collection name',
      description: 'Latest collection description',
      coverUrl: null,
      authorNickname: 'Latest author',
      fileCount: 9,
      publishedAt: DateTime(2026, 9, 22),
      updatedAt: DateTime(2026, 10, 1, 9, 5),
    );
    await tester.pumpWidget(
      createTestApp(
        const CommunityCollectionDetailScreen(remoteId: 'collection-1'),
        overrides: [
          discoverCommunityCollectionsProvider.overrideWith(
            () => _TestDiscoverCommunityCollections(
              PublicCollectionCatalogEntry(
                id: 'collection-1',
                name: 'Stale collection name',
                description: 'Stale description',
                coverUrl: null,
                authorNickname: 'Old author',
                fileCount: 2,
                publishedAt: DateTime(2026, 8, 1),
              ),
            ),
          ),
          communityCollectionFilesProvider(
            'collection-1',
          ).overrideWith(() => _TestCommunityCollectionFiles(files, latest)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Latest collection name'), findsOneWidget);
    expect(find.text('Latest collection description'), findsOneWidget);
    expect(find.text('Latest author'), findsOneWidget);
    expect(find.text('9 items'), findsOneWidget);
    expect(find.text('2026-10-01 09:05'), findsOneWidget);
    expect(find.text('Stale description'), findsNothing);
  });

  testWidgets('未加入合集时点击预览素材不会触发加入操作', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.text('Track 1'));
    await tester.pumpAndSettle();

    expect(find.text('Add Collection First'), findsNothing);
    expect(find.text('Track 1'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.byKey(const Key('community_difficulty_badge')), findsOneWidget);
  });

  testWidgets('未加入合集详情下拉时强制刷新且缓存内容仍可见', (tester) async {
    final detailNotifier = _TestCommunityCollectionFiles(files);
    await tester.pumpWidget(
      createTestApp(
        const CommunityCollectionDetailScreen(remoteId: 'collection-1'),
        overrides: [
          discoverCommunityCollectionsProvider.overrideWith(
            () => _TestDiscoverCommunityCollections(
              PublicCollectionCatalogEntry(
                id: 'collection-1',
                name: 'Community English',
                description: 'A short collection',
                coverUrl: null,
                authorNickname: 'Echo Studio',
                fileCount: files.length,
                publishedAt: DateTime(2026, 9, 22),
              ),
            ),
          ),
          communityCollectionFilesProvider(
            'collection-1',
          ).overrideWith(() => detailNotifier),
        ],
      ),
    );
    await tester.pumpAndSettle();
    detailNotifier.refreshCalls = 0;
    detailNotifier.forceRefreshCalls = 0;

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(detailNotifier.forceRefreshCalls, 1);
    expect(find.text('Track 1'), findsOneWidget);
  });

  testWidgets('已加入合集详情仍展示公开文件列表，仅底部按钮改为开始学习', (tester) async {
    final detailNotifier = _TestCommunityCollectionFiles(
      files,
      PublicCollectionCatalogEntry(
        id: 'collection-1',
        name: 'Remote public name',
        description: 'Public description',
        coverUrl: null,
        authorNickname: 'Public author',
        fileCount: files.length,
        publishedAt: DateTime(2026, 9, 22),
      ),
    );
    await pumpDetail(tester, subscribed: true, detailNotifier: detailNotifier);

    expect(detailNotifier.buildCalls, greaterThan(0));
    expect(find.text('Remote public name'), findsOneWidget);
    expect(find.text('Stale local name'), findsNothing);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Track 1'), findsOneWidget);
    expect(find.text('Start Practicing'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Track 1'));
    await tester.pumpAndSettle();
    expect(find.text('Add Collection First'), findsNothing);
    expect(find.text('Track 1'), findsOneWidget);
  });
}

class _TestDiscoverCommunityCollections extends DiscoverCommunityCollections {
  final PublicCollectionCatalogEntry catalogEntry;

  _TestDiscoverCommunityCollections(this.catalogEntry);

  @override
  Future<CommunityCollectionPagedState<PublicCollectionCatalogEntry>>
  build() async {
    return CommunityCollectionPagedState.fromFirstPage(
      CommunityCollectionCatalogPage(
        cursor: null,
        items: [catalogEntry],
        nextCursor: null,
      ),
    );
  }
}

class _TestCommunityCollectionFiles extends CommunityCollectionFiles {
  final List<CommunityCollectionFile> files;
  final PublicCollectionCatalogEntry? collection;
  var buildCalls = 0;
  var refreshCalls = 0;
  var forceRefreshCalls = 0;

  _TestCommunityCollectionFiles(this.files, [this.collection]);

  @override
  Future<CommunityCollectionPagedState<CommunityCollectionFile>> build(
    String collectionId,
  ) async {
    buildCalls++;
    return CommunityCollectionPagedState.fromFirstPage(
      CommunityCollectionCatalogPage(
        cursor: null,
        collection: collection,
        items: files,
        nextCursor: null,
      ),
    );
  }

  @override
  Future<void> refresh({bool force = false}) async {
    refreshCalls++;
    if (force) forceRefreshCalls++;
  }
}
