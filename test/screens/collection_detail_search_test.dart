import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/screens/collection_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  AudioItem audio(String id, {String? name, String? description}) => AudioItem(
    id: id,
    name: name ?? id,
    description: description,
    audioPath: 'audios/$id.m4a',
    addedDate: DateTime(2026, 1, 1),
  );

  Collection communityCollection() => Collection(
    id: 'c1',
    name: 'Official',
    description: 'Collection intro text',
    createdDate: DateTime(2026, 1, 1),
    source: CollectionSource.community,
    remoteId: 'remote-1',
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<AudioItem> items,
    Collection? collection,
  }) async {
    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'c1'),
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: items)),
          ),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [collection ?? communityCollection()],
                audioIdsMap: {'c1': items.map((e) => e.id).toList()},
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterSearch(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('collection_search_button')));
    await tester.pumpAndSettle();
  }

  double scrollPixels(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  final items = [
    audio('a1', name: 'Coffee Talk', description: 'Ordering at a cafe'),
    audio('a2', name: 'Airport', description: 'Check-in and coffee break'),
    audio('a3', name: 'Weather'),
  ];

  testWidgets('搜索模式隐藏合集介绍并只展示匹配的节目', (tester) async {
    await pumpScreen(tester, items: items);
    expect(find.text('Collection intro text'), findsOneWidget);

    await enterSearch(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Collection intro text'), findsNothing);

    await tester.enterText(find.byType(TextField), 'COFFEE');
    await tester.pump();

    expect(find.text('Coffee Talk'), findsOneWidget);
    expect(find.text('Airport'), findsOneWidget);
    expect(find.text('Weather'), findsNothing);
    // 仅描述命中时，描述正文同样可见（不因标题未命中而隐藏）。
    expect(find.text('Check-in and coffee break'), findsOneWidget);
  });

  testWidgets('无匹配结果时显示空状态文案', (tester) async {
    await pumpScreen(tester, items: items);
    await enterSearch(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    expect(find.text('No matching content'), findsOneWidget);
    expect(find.text('Coffee Talk'), findsNothing);
  });

  testWidgets('清除按钮清空关键词并恢复全部节目，仍保持搜索模式', (tester) async {
    await pumpScreen(tester, items: items);
    await enterSearch(tester);
    await tester.enterText(find.byType(TextField), 'airport');
    await tester.pump();
    expect(find.text('Coffee Talk'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Coffee Talk'), findsOneWidget);
    expect(find.text('Weather'), findsOneWidget);
  });

  testWidgets('取消搜索恢复合集介绍与原列表', (tester) async {
    await pumpScreen(tester, items: items);
    await enterSearch(tester);
    await tester.enterText(find.byType(TextField), 'airport');
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Collection intro text'), findsOneWidget);
    expect(find.text('Coffee Talk'), findsOneWidget);
    expect(find.text('Weather'), findsOneWidget);
  });

  testWidgets('系统返回键优先退出搜索模式而不是离开页面', (tester) async {
    await pumpScreen(tester, items: items);
    await enterSearch(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Collection intro text'), findsOneWidget);
  });

  testWidgets('取消搜索后恢复进入搜索前的滚动位置', (tester) async {
    final manyItems = List.generate(30, (i) => audio('item-$i'));
    await pumpScreen(tester, items: manyItems);

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    final offsetBeforeSearch = scrollPixels(tester);
    expect(offsetBeforeSearch, greaterThan(0));

    await enterSearch(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(scrollPixels(tester), offsetBeforeSearch);
  });
}
