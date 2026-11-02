// LibraryScreen 测试（原 CollectionScreen）
//
// 测试资源库页面的合集视图渲染和交互。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/screens/library_screen.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  group('LibraryScreen（合集视图）', () {
    group('渲染', () {
      testWidgets('空状态显示提示文案', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.collections_bookmark_outlined),
          findsOneWidget,
        );
        expect(find.text('No collections yet'), findsOneWidget);
      });

      testWidgets('显示我的资源库标题并隐藏旧视图选择组件', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        expect(find.text('My Library'), findsOneWidget);
        expect(find.text('Collections'), findsNothing);
        expect(find.text('Audio'), findsNothing);
      });

      testWidgets('连续点击标题五次后显示全部音频入口', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        final title = find.byKey(const Key('library_title'));
        expect(find.byKey(const Key('library_all_audio_button')), findsNothing);

        for (var i = 0; i < 4; i++) {
          await tester.tap(title);
        }
        await tester.pump();
        expect(find.byKey(const Key('library_all_audio_button')), findsNothing);

        await tester.tap(title);
        await tester.pump();
        expect(find.text('All'), findsOneWidget);
      });

      testWidgets('点击全部后进入原音频列表视图', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        final title = find.byKey(const Key('library_title'));
        for (var i = 0; i < 5; i++) {
          await tester.tap(title);
        }
        await tester.pump();
        await tester.tap(find.byKey(const Key('library_all_audio_button')));
        await tester.pumpAndSettle();

        expect(find.text('No audio files yet'), findsOneWidget);
        expect(find.byIcon(Icons.sort), findsOneWidget);
      });

      testWidgets('全部入口仅保存在当前页面内存中', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('library_title')));
        }
        await tester.pump();
        expect(find.text('All'), findsOneWidget);

        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();
        expect(find.text('All'), findsNothing);
      });

      testWidgets('中文环境显示全部按钮', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const LibraryScreen(), locale: const Locale('zh')),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('library_title')));
        }
        await tester.pump();
        expect(find.text('全部'), findsOneWidget);
      });

      testWidgets('显示创建按钮', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        // AppBar 中的 + 按钮和空状态 CTA 中都有 add 图标
        expect(find.byIcon(Icons.add), findsNWidgets(2));
      });

      testWidgets('显示排序按钮', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.sort), findsOneWidget);
      });

      testWidgets('列表视图模式下合集列表正确显示', (tester) async {
        final updatedAt = DateTime.now().subtract(const Duration(minutes: 5));
        final c1 = createTestCollection(
          id: '1',
          name: 'English Lessons',
          isPinned: true,
          updatedAt: updatedAt,
        );
        final c2 = createTestCollection(
          id: '2',
          name: 'Podcasts',
          isPinned: false,
          updatedAt: updatedAt,
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(
                    rawCollections: [c1, c2],
                    audioIdsMap: {
                      '1': ['a1', 'a2'],
                      '2': ['a3'],
                    },
                  ),
                ),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        // 合集名称
        expect(find.text('English Lessons'), findsOneWidget);
        expect(find.text('Podcasts'), findsOneWidget);
        // 素材数量（列表模式下 audioCount 与日期组合显示）
        expect(find.textContaining('2 items'), findsOneWidget);
        expect(find.textContaining('1 items'), findsOneWidget);
        expect(find.textContaining('Updated 5 minutes ago'), findsNWidgets(2));
        expect(find.textContaining('Added'), findsNothing);
      });

      testWidgets('中国地区本地合集列表使用已保存的中国封面 URL', (tester) async {
        final community =
            createTestCollection(
              id: 'community-cn',
              name: 'Community Lessons',
            ).copyWith(
              source: CollectionSource.community,
              coverUrl: 'https://global.example/cover.jpg',
              coverUrlChina: 'https://china.example/cover.jpg',
            );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              isChinaUserProvider.overrideWithValue(true),
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(rawCollections: [community]),
                ),
              ),
            ]),
          ),
        );

        final cover = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cover.imageUrl, 'https://china.example/cover.jpg');
      });

      testWidgets('每个来源的用户合集都显示对应角标', (tester) async {
        final local = createTestCollection(id: 'local', name: 'Local Lessons');
        final community = createTestCollection(
          id: 'community',
          name: 'Community Lessons',
        ).copyWith(source: CollectionSource.community);
        final podcast = createTestCollection(
          id: 'podcast',
          name: 'Podcast Lessons',
        ).copyWith(source: CollectionSource.podcast);

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(rawCollections: [local, community, podcast]),
                ),
              ),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Local'), findsOneWidget);
        expect(find.text('Shared'), findsOneWidget);
        expect(find.text('Podcast'), findsOneWidget);
      });

      testWidgets('来源角标位于合集 meta 信息下方', (tester) async {
        final collection = createTestCollection(
          id: 'local',
          name: 'Local Lessons',
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(rawCollections: [collection]),
                ),
              ),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        final metaRect = tester.getRect(find.textContaining('0 items'));
        final badgeRect = tester.getRect(find.text('Local'));
        expect(badgeRect.top, greaterThan(metaRect.bottom));
      });

      testWidgets('中文环境显示三种来源角标', (tester) async {
        final collections = [
          createTestCollection(id: 'local', name: '本地课程'),
          createTestCollection(
            id: 'community',
            name: '社区课程',
          ).copyWith(source: CollectionSource.community),
          createTestCollection(
            id: 'podcast',
            name: '播客课程',
          ).copyWith(source: CollectionSource.podcast),
        ];

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            locale: const Locale('zh'),
            overrides: dedupeOverrides([
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(rawCollections: collections),
                ),
              ),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('本地'), findsOneWidget);
        expect(find.text('共享'), findsOneWidget);
        expect(find.text('播客'), findsOneWidget);
      });

      testWidgets('社区合集下架时显示状态角标', (tester) async {
        final deprecated =
            createTestCollection(
              id: 'deprecated-community',
              name: 'Removed Community',
            ).copyWith(
              source: CollectionSource.community,
              deprecatedAt: DateTime(2026, 1, 2),
            );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(rawCollections: [deprecated]),
                ),
              ),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Removed'), findsOneWidget);
        expect(find.text('Shared'), findsNothing);
      });

      testWidgets('置顶合集使用淡背景色标记', (tester) async {
        final c = createTestCollection(
          id: '1',
          name: 'Starred',
          isPinned: true,
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        final card = tester.widget<Card>(find.byType(Card).first);
        expect(card.color, isNotNull);
      });

      testWidgets('加载中显示进度指示器', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () =>
                    TestCollectionList(const CollectionState(isLoading: true)),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击 + 创建新合集', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        // 点击 AppBar 中的创建按钮（第一个 add 图标）
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();

        // 先进入统一底部 sheet 的类型选择页
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(
          find.byKey(const ValueKey('collection-option-local')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('collection-option-podcast')),
          findsOneWidget,
        );
        expect(find.text('New Collection'), findsOneWidget);
        expect(find.text('Add audio or video'), findsOneWidget);
        expect(find.text('Subscribe Podcast'), findsOneWidget);
        expect(find.text('Add with Apple Podcasts or RSS'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('collection-option-local')));
        await tester.pumpAndSettle();

        expect(find.text('Collection Name'), findsOneWidget);
      });

      testWidgets('创建本地合集表单弱化输入提示样式', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('collection-option-local')));
        await tester.pumpAndSettle();

        final localField = tester.widget<TextField>(find.byType(TextField));
        final localContext = tester.element(find.byType(TextField));
        final localTheme = Theme.of(localContext);

        expect(
          localField.style?.fontSize,
          localTheme.textTheme.bodyMedium?.fontSize,
        );
        expect(
          localField.decoration?.hintStyle?.fontSize,
          localTheme.textTheme.bodyMedium?.fontSize,
        );
        expect(
          localField.decoration?.hintStyle?.color,
          localTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
        );
        expect(
          localField.decoration?.labelStyle?.fontSize,
          localTheme.textTheme.bodySmall?.fontSize,
        );
        expect(
          localField.decoration?.floatingLabelStyle?.color,
          localTheme.colorScheme.primary.withValues(alpha: 0.78),
        );
        expect(
          localField.decoration?.contentPadding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      });

      testWidgets('创建合集时空名称时 Add 按钮禁用', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        // 打开创建对话框（AppBar 中的 + 按钮）
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('collection-option-local')));
        await tester.pumpAndSettle();

        // Add 按钮应禁用（空输入）
        final addButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Add'),
        );
        expect(addButton.onPressed, isNull);

        // 输入内容后按钮启用
        await tester.enterText(find.byType(TextField).first, 'My Collection');
        await tester.pump();

        final enabledButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Add'),
        );
        expect(enabledButton.onPressed, isNotNull);
      });

      testWidgets('点击「订阅 Podcast」关闭 sheet 并进入统一订阅页', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('collection-option-podcast')),
        );
        await tester.pumpAndSettle();

        // sheet 关闭并跳转到统一的 Podcast 搜索与订阅页（stub）。
        expect(find.text('Podcast Subscribe'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('collection-option-podcast')),
          findsNothing,
        );
      });

      testWidgets('点击排序按钮显示排序选项', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        // 点击排序按钮
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();

        // 应显示排序选项
        expect(find.text('Name (A-Z)'), findsOneWidget);
        expect(find.text('Name (Z-A)'), findsOneWidget);
        expect(find.text('oldest First'), findsOneWidget);
        expect(find.text('Newest First'), findsOneWidget);
      });

      testWidgets('列表视图菜单内点击置顶切换', (tester) async {
        final c = createTestCollection(
          id: '1',
          name: 'Test Collection',
          isPinned: false,
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.push_pin_outlined), findsNothing);

        await tester.tap(
          find.byKey(const Key('collection_list_menu_hit_area')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pin to Top'), findsOneWidget);

        await tester.tap(find.text('Pin to Top'));
        await tester.pumpAndSettle();

        final card = tester.widget<Card>(find.byType(Card).first);
        expect(card.color, isNotNull);
      });

      testWidgets('删除合集弹窗默认勾选删音频并显示文件数，取消勾选则保留', (tester) async {
        final c = createTestCollection(id: '1', name: 'test');
        final audio = createTestAudioItem(id: 'a1');
        final collectionList = TestCollectionList(
          CollectionState(
            rawCollections: [c],
            audioIdsMap: {
              '1': ['a1'],
            },
          ),
        );
        final audioLib = TestAudioLibrary(
          AudioLibraryState(audioItems: [audio]),
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => audioLib),
              collectionListProvider.overrideWith(() => collectionList),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('collection_list_menu_hit_area')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // 默认勾选：提示一并删除并带文件数，选项文案为纯文本。
        expect(
          find.text('1 audio file(s) in this collection will also be deleted.'),
          findsOneWidget,
        );
        expect(find.text('Also delete audio file(s)?'), findsOneWidget);

        // 取消勾选 → 提示切换为保留。
        await tester.tap(find.text('Also delete audio file(s)?'));
        await tester.pumpAndSettle();
        expect(
          find.text('1 audio file(s) in this collection will be kept.'),
          findsOneWidget,
        );

        // 删除 → 合集删除，音频保留。
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(collectionList.state.rawCollections, isEmpty);
        expect(audioLib.state.audioItems, hasLength(1));
      });

      testWidgets('删除合集默认勾选时一并删除音频文件', (tester) async {
        final c = createTestCollection(id: '1', name: 'test');
        final audio = createTestAudioItem(id: 'a1');
        final collectionList = TestCollectionList(
          CollectionState(
            rawCollections: [c],
            audioIdsMap: {
              '1': ['a1'],
            },
          ),
        );
        final audioLib = TestAudioLibrary(
          AudioLibraryState(audioItems: [audio]),
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => audioLib),
              collectionListProvider.overrideWith(() => collectionList),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('collection_list_menu_hit_area')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // 默认已勾选，直接删除 → 合集与音频均被删除。
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(collectionList.state.rawCollections, isEmpty);
        expect(audioLib.state.audioItems, isEmpty);
      });

      testWidgets('Podcast 合集菜单显示重命名和详情，不显示刷新', (tester) async {
        final c =
            createTestCollection(
              id: 'podcast-1',
              name: 'Podcast Collection',
            ).copyWith(
              source: CollectionSource.podcast,
              podcastFeedUrl: 'https://example.com/feed.xml',
            );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('collection_list_menu_hit_area')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Refresh Feed'), findsNothing);
        expect(find.byType(PopupMenuDivider), findsOneWidget);

        await tester.tap(find.text('Details'));
        await tester.pumpAndSettle();

        expect(find.text('RSS URL'), findsOneWidget);
        expect(find.text('https://example.com/feed.xml'), findsOneWidget);
      });

      testWidgets('Podcast 合集刷新失败时列表显示标记且菜单详情展示失败状态', (tester) async {
        final c =
            createTestCollection(
              id: 'podcast-1',
              name: '6 Minute English',
            ).copyWith(
              source: CollectionSource.podcast,
              podcastFeedUrl: 'https://example.com/feed.xml',
              podcastLastRefreshedAt: DateTime(2026, 6, 15, 11, 52),
              podcastLastRefreshError: 'Exception: rss failed',
            );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: dedupeOverrides([
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Refresh failed'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('collection_list_menu_hit_area')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Details'));
        await tester.pumpAndSettle();

        expect(find.text('Last refreshed: 2026-06-15 11:52'), findsNothing);
        expect(find.text('Failed · 2026-06-15 11:52'), findsOneWidget);
      });
    });
  });
}
