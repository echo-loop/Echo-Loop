import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('collectionSortTypeFromName 解析', () {
    test('合法字符串解析为对应枚举', () {
      expect(collectionSortTypeFromName('nameAsc'), CollectionSortType.nameAsc);
      expect(collectionSortTypeFromName('dateAsc'), CollectionSortType.dateAsc);
    });

    test('null（未存过）回退到默认 dateDesc', () {
      expect(collectionSortTypeFromName(null), CollectionSortType.dateDesc);
    });

    test('非法字符串回退到默认 dateDesc', () {
      expect(
        collectionSortTypeFromName('garbage'),
        CollectionSortType.dateDesc,
      );
    });
  });

  group('CollectionList.setSortType 持久化', () {
    test('同步更新状态并写入 prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(collectionListProvider.notifier)
          .setSortType(CollectionSortType.nameDesc);

      expect(
        container.read(collectionListProvider).sortType,
        CollectionSortType.nameDesc,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('collection_sort_type'), 'nameDesc');
    });
  });

  group('CollectionState', () {
    final now = DateTime(2026, 1, 15);

    Collection createCollection({
      required String id,
      required String name,
      DateTime? createdDate,
      bool isPinned = false,
    }) {
      return Collection(
        id: id,
        name: name,
        createdDate: createdDate ?? now,
        isPinned: isPinned,
      );
    }

    group('默认值', () {
      test('所有默认值符合预期', () {
        const state = CollectionState();

        expect(state.rawCollections, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.sortType, CollectionSortType.dateDesc);
        expect(state.isEmpty, isTrue);
      });
    });

    group('isEmpty', () {
      test('有合集时返回 false', () {
        final state = CollectionState(
          rawCollections: [createCollection(id: '1', name: '测试')],
        );
        expect(state.isEmpty, isFalse);
      });
    });

    group('collections getter 排序', () {
      late List<Collection> rawCollections;

      setUp(() {
        rawCollections = [
          createCollection(
            id: '1',
            name: 'B集',
            createdDate: DateTime(2026, 1, 10),
          ),
          createCollection(
            id: '2',
            name: 'A集',
            createdDate: DateTime(2026, 1, 15),
          ),
          createCollection(
            id: '3',
            name: 'C集',
            createdDate: DateTime(2026, 1, 12),
          ),
        ];
      });

      test('nameAsc 按名称升序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.nameAsc,
        );
        final sorted = state.collections;
        expect(sorted[0].name, 'A集');
        expect(sorted[1].name, 'B集');
        expect(sorted[2].name, 'C集');
      });

      test('nameDesc 按名称降序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.nameDesc,
        );
        final sorted = state.collections;
        expect(sorted[0].name, 'C集');
        expect(sorted[1].name, 'B集');
        expect(sorted[2].name, 'A集');
      });

      test('dateAsc 按日期升序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.dateAsc,
        );
        final sorted = state.collections;
        expect(sorted[0].id, '1'); // 1月10日
        expect(sorted[1].id, '3'); // 1月12日
        expect(sorted[2].id, '2'); // 1月15日
      });

      test('dateDesc 按日期降序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.dateDesc,
        );
        final sorted = state.collections;
        expect(sorted[0].id, '2'); // 1月15日
        expect(sorted[1].id, '3'); // 1月12日
        expect(sorted[2].id, '1'); // 1月10日
      });
    });

    group('置顶排序', () {
      test('置顶合集始终排在最前面（dateDesc 排序）', () {
        final state = CollectionState(
          rawCollections: [
            createCollection(
              id: '1',
              name: 'A集',
              createdDate: DateTime(2026, 1, 15),
            ),
            createCollection(
              id: '2',
              name: 'B集',
              createdDate: DateTime(2026, 1, 10),
              isPinned: true,
            ),
            createCollection(
              id: '3',
              name: 'C集',
              createdDate: DateTime(2026, 1, 12),
            ),
          ],
          sortType: CollectionSortType.dateDesc,
        );
        final sorted = state.collections;
        // 置顶项 B集 排第一，其余按日期倒序
        expect(sorted[0].id, '2');
        expect(sorted[1].id, '1');
        expect(sorted[2].id, '3');
      });

      test('置顶合集始终排在最前面（nameAsc 排序）', () {
        final state = CollectionState(
          rawCollections: [
            createCollection(id: '1', name: 'B集'),
            createCollection(id: '2', name: 'A集'),
            createCollection(id: '3', name: 'C集', isPinned: true),
          ],
          sortType: CollectionSortType.nameAsc,
        );
        final sorted = state.collections;
        // 置顶项 C集 排第一，其余按名称升序
        expect(sorted[0].id, '3');
        expect(sorted[1].id, '2');
        expect(sorted[2].id, '1');
      });

      test('多个置顶合集之间保持排序类型的顺序', () {
        final state = CollectionState(
          rawCollections: [
            createCollection(
              id: '1',
              name: 'C集',
              createdDate: DateTime(2026, 1, 15),
              isPinned: true,
            ),
            createCollection(
              id: '2',
              name: 'A集',
              createdDate: DateTime(2026, 1, 10),
              isPinned: true,
            ),
            createCollection(
              id: '3',
              name: 'B集',
              createdDate: DateTime(2026, 1, 12),
            ),
          ],
          sortType: CollectionSortType.nameAsc,
        );
        final sorted = state.collections;
        // 置顶区按名称升序：A集, C集；非置顶区：B集
        expect(sorted[0].id, '2'); // A集
        expect(sorted[1].id, '1'); // C集
        expect(sorted[2].id, '3'); // B集
      });

      test('无置顶时排序行为不变', () {
        final state = CollectionState(
          rawCollections: [
            createCollection(
              id: '1',
              name: 'B集',
              createdDate: DateTime(2026, 1, 10),
            ),
            createCollection(
              id: '2',
              name: 'A集',
              createdDate: DateTime(2026, 1, 15),
            ),
          ],
          sortType: CollectionSortType.nameAsc,
        );
        final sorted = state.collections;
        expect(sorted[0].name, 'A集');
        expect(sorted[1].name, 'B集');
      });
    });

    group('audioIdsMap', () {
      test('getAudioIds 返回对应合集的音频 ID 列表', () {
        final state = CollectionState(
          audioIdsMap: {
            'c1': ['a1', 'a2'],
            'c2': ['a3'],
          },
        );
        expect(state.getAudioIds('c1'), ['a1', 'a2']);
        expect(state.getAudioIds('c2'), ['a3']);
        expect(state.getAudioIds('c3'), isEmpty);
      });

      test('getAudioCount 返回对应合集的音频数量', () {
        final state = CollectionState(
          audioIdsMap: {
            'c1': ['a1', 'a2'],
            'c2': ['a3'],
          },
        );
        expect(state.getAudioCount('c1'), 2);
        expect(state.getAudioCount('c2'), 1);
        expect(state.getAudioCount('c3'), 0);
      });

      test('删除合集时 audioIdsMap 应同步移除对应 key', () {
        // 模拟 deleteCollection 中的状态更新逻辑
        final initialState = CollectionState(
          rawCollections: [
            createCollection(id: 'c1', name: '合集1'),
            createCollection(id: 'c2', name: '合集2'),
          ],
          audioIdsMap: {
            'c1': ['a1', 'a2'],
            'c2': ['a3'],
          },
        );

        // 模拟修复后的 deleteCollection 逻辑
        const deleteId = 'c1';
        final newMap = Map<String, List<String>>.from(initialState.audioIdsMap)
          ..remove(deleteId);
        final newState = initialState.copyWith(
          rawCollections: initialState.rawCollections
              .where((c) => c.id != deleteId)
              .toList(),
          audioIdsMap: newMap,
        );

        expect(newState.rawCollections, hasLength(1));
        expect(newState.rawCollections.first.id, 'c2');
        expect(newState.audioIdsMap.containsKey('c1'), isFalse);
        expect(newState.audioIdsMap['c2'], ['a3']);
      });

      test('删除合集不影响其他合集的音频关联', () {
        final initialState = CollectionState(
          rawCollections: [
            createCollection(id: 'c1', name: '合集1'),
            createCollection(id: 'c2', name: '合集2'),
            createCollection(id: 'c3', name: '合集3'),
          ],
          audioIdsMap: {
            'c1': ['a1', 'a2'],
            'c2': ['a2', 'a3'],
            'c3': ['a4'],
          },
        );

        const deleteId = 'c2';
        final newMap = Map<String, List<String>>.from(initialState.audioIdsMap)
          ..remove(deleteId);
        final newState = initialState.copyWith(
          rawCollections: initialState.rawCollections
              .where((c) => c.id != deleteId)
              .toList(),
          audioIdsMap: newMap,
        );

        expect(newState.rawCollections, hasLength(2));
        expect(newState.audioIdsMap, hasLength(2));
        expect(newState.audioIdsMap['c1'], ['a1', 'a2']);
        expect(newState.audioIdsMap['c3'], ['a4']);
      });
    });

    group('audioToCollectionsMap 反向索引', () {
      test('正确构建 audioId -> collectionIds 映射', () {
        final state = CollectionState(
          audioIdsMap: {
            'c1': ['a1', 'a2'],
            'c2': ['a2', 'a3'],
            'c3': ['a1'],
          },
        );
        final reverseMap = state.audioToCollectionsMap;

        expect(reverseMap['a1'], unorderedEquals(['c1', 'c3']));
        expect(reverseMap['a2'], unorderedEquals(['c1', 'c2']));
        expect(reverseMap['a3'], ['c2']);
      });

      test('空 audioIdsMap 返回空映射', () {
        const state = CollectionState();
        expect(state.audioToCollectionsMap, isEmpty);
      });

      test('音频不在任何合集中时不出现在反向索引', () {
        final state = CollectionState(
          audioIdsMap: {
            'c1': ['a1'],
          },
        );
        final reverseMap = state.audioToCollectionsMap;
        expect(reverseMap.containsKey('a2'), isFalse);
      });
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        const state = CollectionState();
        final copied = state.copyWith(
          isLoading: true,
          sortType: CollectionSortType.nameAsc,
        );

        expect(copied.isLoading, isTrue);
        expect(copied.sortType, CollectionSortType.nameAsc);
      });
    });
  });

  group('CollectionList.unsubscribePodcastCollection', () {
    test('退订清理合集独占的所有单集，保留无关音频并删除合集', () async {
      final podcast = Collection(
        id: 'pc-1',
        name: 'My Podcast',
        createdDate: DateTime(2026, 1, 1),
        source: CollectionSource.podcast,
      );
      final ep1 = createTestAudioItem(id: 'ep-1', name: 'Ep 1');
      final ep2 = createTestAudioItem(id: 'ep-2', name: 'Ep 2');
      final other = createTestAudioItem(id: 'other', name: 'Other');

      final container = ProviderContainer(
        overrides: [
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [podcast],
                audioIdsMap: {
                  'pc-1': ['ep-1', 'ep-2'],
                },
              ),
            ),
          ),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(
              AudioLibraryState(audioItems: [ep1, ep2, other]),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(collectionListProvider.notifier)
          .unsubscribePodcastCollection('pc-1');

      // 合集独占的单集被清理，无关音频保留
      final libIds = container
          .read(audioLibraryProvider)
          .audioItems
          .map((e) => e.id)
          .toList();
      expect(libIds, ['other']);

      // 合集本身被删除
      final cols = container.read(collectionListProvider).rawCollections;
      expect(cols.where((c) => c.id == 'pc-1'), isEmpty);
    });
  });
}
