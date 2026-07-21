// LibraryScreen 测试（原 CollectionScreen）
//
// 测试资源库页面的合集视图渲染和交互。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/official_collections/providers/discover_podcasts_provider.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/screens/library_screen.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';

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

      testWidgets('显示 SegmentedButton 切换', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Collections'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
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
            overrides: [
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
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 合集名称
        expect(find.text('English Lessons'), findsOneWidget);
        expect(find.text('Podcasts'), findsOneWidget);
        // 音频数量（列表模式下 audioCount 与日期组合显示）
        expect(find.textContaining('2 audios'), findsOneWidget);
        expect(find.textContaining('1 audios'), findsOneWidget);
        expect(find.textContaining('Updated 5 minutes ago'), findsNWidgets(2));
        expect(find.textContaining('Added'), findsNothing);
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
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
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
            overrides: [
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
            ],
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
        expect(
          find.text('Add audio or practice materials manually'),
          findsOneWidget,
        );
        expect(find.text('Subscribe Podcast'), findsOneWidget);
        expect(find.text('Add with Apple Podcasts or RSS'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('collection-option-local')));
        await tester.pumpAndSettle();

        expect(find.text('Collection Name'), findsOneWidget);
      });

      testWidgets('创建合集和订阅 Podcast 表单弱化输入提示样式', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            // 精选 catalog 置空，避免订阅面板落到 null → 无限 spinner
            overrides: [
              discoverPodcastsProvider.overrideWith((ref) => const []),
            ],
          ),
        );
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

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('collection-option-podcast')),
        );
        await tester.pumpAndSettle();

        final podcastField = tester.widget<TextField>(find.byType(TextField));
        final podcastContext = tester.element(find.byType(TextField));
        final podcastTheme = Theme.of(podcastContext);

        expect(
          podcastField.style?.fontSize,
          podcastTheme.textTheme.bodyMedium?.fontSize,
        );
        expect(
          podcastField.decoration?.hintStyle?.fontSize,
          podcastTheme.textTheme.bodyMedium?.fontSize,
        );
        expect(
          podcastField.decoration?.hintStyle?.color,
          podcastTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
        );
        expect(
          podcastField.decoration?.floatingLabelStyle?.color,
          podcastTheme.colorScheme.primary.withValues(alpha: 0.78),
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

      testWidgets('订阅 Podcast 使用同一个底部 sheet 表单', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: [
              discoverPodcastsProvider.overrideWith((ref) => const []),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('collection-option-podcast')),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        // 面板改为搜索框：label 为搜索提示，标题仍是「Subscribe Podcast」
        expect(find.text('Search podcasts or paste a link'), findsOneWidget);
        expect(find.text('Subscribe Podcast'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
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
        expect(find.text('Oldest First'), findsOneWidget);
        expect(find.text('Newest First'), findsOneWidget);
      });

      testWidgets('SegmentedButton 切换到音频视图', (tester) async {
        await tester.pumpWidget(createTestScreen(const LibraryScreen()));
        await tester.pumpAndSettle();

        // 切换到音频视图
        await tester.tap(find.text('Audio'));
        await tester.pumpAndSettle();

        // 应显示音频空状态
        expect(find.text('No audio files yet'), findsOneWidget);
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
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
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
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => audioLib),
              collectionListProvider.overrideWith(() => collectionList),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
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
        expect(find.text('Also delete audio files'), findsOneWidget);

        // 取消勾选 → 提示切换为保留。
        await tester.tap(find.text('Also delete audio files'));
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
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => audioLib),
              collectionListProvider.overrideWith(() => collectionList),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
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
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
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
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(CollectionState(rawCollections: [c])),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
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
