import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/screens/collection_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 记录批量「从合集移除」调用的 CollectionList 替身（不访问 DAO）。
class _SpyCollectionList extends TestCollectionList {
  _SpyCollectionList(super.initialState);

  final List<(String, Set<String>)> removeFromCollectionCalls = [];

  @override
  Future<void> removeAudiosFromCollection(
    String collectionId,
    Set<String> audioIds,
  ) async {
    removeFromCollectionCalls.add((collectionId, audioIds));
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[collectionId] ?? [])
      ..removeWhere(audioIds.contains);
    newMap[collectionId] = ids;
    state = state.copyWith(audioIdsMap: newMap);
  }
}

/// 记录彻底删除调用的 AudioLibrary 替身。
class _SpyAudioLibrary extends TestAudioLibrary {
  _SpyAudioLibrary(super.initialState);

  final List<Set<String>> removeItemsCalls = [];

  @override
  Future<void> removeAudioItems(Set<String> ids) async {
    removeItemsCalls.add(ids);
    await super.removeAudioItems(ids);
  }
}

void main() {
  AudioItem audio(String id) => AudioItem(
    id: id,
    name: id,
    audioPath: 'audios/$id.m4a',
    addedDate: DateTime(2026, 1, 1),
  );

  Collection userCollection() => Collection(
    id: 'c1',
    name: 'My Collection',
    createdDate: DateTime(2026, 1, 1),
  );

  Collection officialCollection() => Collection(
    id: 'c1',
    name: 'Official',
    createdDate: DateTime(2026, 1, 1),
    source: CollectionSource.official,
    remoteId: 'remote-1',
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Collection collection,
    required List<AudioItem> items,
    _SpyCollectionList? collectionList,
    _SpyAudioLibrary? audioLibrary,
  }) async {
    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'c1'),
        overrides: [
          audioLibraryProvider.overrideWith(
            () =>
                audioLibrary ??
                _SpyAudioLibrary(AudioLibraryState(audioItems: items)),
          ),
          collectionListProvider.overrideWith(
            () =>
                collectionList ??
                _SpyCollectionList(
                  CollectionState(
                    rawCollections: [collection],
                    audioIdsMap: {'c1': items.map((e) => e.id).toList()},
                  ),
                ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('长按进入多选并选中该项，全选后可再取消全选', (tester) async {
    await pumpScreen(
      tester,
      collection: userCollection(),
      items: [audio('a1'), audio('a2')],
    );

    // 初始无多选工具栏
    expect(find.text('Select All'), findsNothing);

    await tester.longPress(find.text('a1'));
    await tester.pumpAndSettle();

    // 进入多选：工具栏 + 已选 1 项 + 出现复选框
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    // 全选
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Deselect All'), findsOneWidget);

    // 取消全选
    await tester.tap(find.text('Deselect All'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('多选后彻底删除调用 removeAudioItems', (tester) async {
    final lib = _SpyAudioLibrary(
      AudioLibraryState(audioItems: [audio('a1'), audio('a2')]),
    );
    await pumpScreen(
      tester,
      collection: userCollection(),
      items: [audio('a1'), audio('a2')],
      audioLibrary: lib,
    );

    await tester.longPress(find.text('a1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // 默认勾选「彻底删除」，主按钮为 Delete，直接确认
    expect(find.text('Permanently delete 2 audio'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(lib.removeItemsCalls, [
      {'a1', 'a2'},
    ]);
    // 删除后退出多选
    expect(find.text('Select All'), findsNothing);
  });

  testWidgets('多选后仅从合集移除调用 removeAudiosFromCollection', (tester) async {
    final list = _SpyCollectionList(
      CollectionState(
        rawCollections: [userCollection()],
        audioIdsMap: const {
          'c1': ['a1', 'a2'],
        },
      ),
    );
    await pumpScreen(
      tester,
      collection: userCollection(),
      items: [audio('a1'), audio('a2')],
      collectionList: list,
    );

    await tester.longPress(find.text('a2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // 取消勾选「彻底删除」后主按钮切换为「从合集移除」，再确认
    await tester.tap(find.text('Permanently delete 1 audio'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Remove 1 from collection'),
    );
    await tester.pumpAndSettle();

    expect(list.removeFromCollectionCalls, hasLength(1));
    expect(list.removeFromCollectionCalls.single.$1, 'c1');
    expect(list.removeFromCollectionCalls.single.$2, {'a2'});
    expect(find.text('Select All'), findsNothing);
  });

  testWidgets('官方合集不启用多选（长按无效）', (tester) async {
    await pumpScreen(
      tester,
      collection: officialCollection(),
      items: [audio('a1')],
    );

    await tester.longPress(find.text('a1'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Select All'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}
