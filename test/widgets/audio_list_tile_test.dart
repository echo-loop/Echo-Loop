import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/audio_list_tile.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 包装器：从 Provider 读取第一个音频项，传给 AudioListTile
/// 模拟真实场景中父组件 watch provider → 传 item 给子组件的模式
class _AudioListTileWrapper extends ConsumerWidget {
  const _AudioListTileWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(audioLibraryProvider.select((s) => s.audioItems));
    if (items.isEmpty) return const SizedBox.shrink();
    return AudioListTile(audioItem: items.first);
  }
}

void main() {
  group('AudioListTile 置顶菜单', () {
    final baseItem = createTestAudioItem(id: 'star-1', name: 'Star Audio');

    Widget buildTile(AudioLibraryState libraryState) {
      return createTestApp(
        const _AudioListTileWrapper(),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    Widget buildCompactTile(AudioLibraryState libraryState) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    testWidgets('右侧仅显示一个菜单按钮', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_menu_hit_area')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('已置顶时使用淡背景色标记', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNotNull);
    });

    testWidgets('未置顶时卡片保持默认背景', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNull);
    });

    testWidgets('已置顶时 leading 音频图标颜色不受置顶影响（显示进度状态）', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      // leading 图标现在显示进度状态，不再根据置顶变色
      final audioIcon = tester.widget<Icon>(find.byIcon(Icons.graphic_eq));
      expect(audioIcon.color, isNotNull);
      expect(audioIcon.color, isNot(AppTheme.bookmarkColor));
    });

    testWidgets('菜单内点击置顶触发 togglePin 并更新背景', (tester) async {
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      expect(find.text('Pin to Top'), findsOneWidget);

      await tester.tap(find.text('Pin to Top'));
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNotNull);
    });

    testWidgets('菜单首项根据状态显示 pin 或 unpin', (tester) async {
      await tester.pumpWidget(
        buildTile(
          AudioLibraryState(audioItems: [baseItem.copyWith(isPinned: true)]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Unpin'), findsOneWidget);
    });
  });

  group('AudioListTile 当前播放展示', () {
    final baseItem = createTestAudioItem(
      id: 'playing-1',
      name: 'Playing Audio',
    );

    Widget buildCollectionTile() {
      return createTestApp(
        AudioListTile(audioItem: baseItem, collectionId: 'collection-1'),
        overrides: [
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState()),
          ),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(
            () => TestListeningPractice(
              ListeningPracticeState(currentAudioItem: baseItem),
            ),
          ),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
        ],
      );
    }

    testWidgets('合集上下文当前播放时不显示 Last 标签', (tester) async {
      await tester.pumpWidget(buildCollectionTile());
      await tester.pumpAndSettle();

      expect(find.text('Last'), findsNothing);
      expect(find.text('上次'), findsNothing);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });
}
