// 资源库首页全局搜索测试：覆盖合集与音频的分区结果、空状态，以及退出搜索的路径。
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/screens/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  AudioItem audio(String id, {required String name, String? description}) =>
      AudioItem(
        id: id,
        name: name,
        description: description,
        audioPath: 'audios/$id.m4a',
        addedDate: DateTime(2026, 1, 1),
      );

  Collection collection(String id, String name) =>
      createTestCollection(id: id, name: name);

  final audioItems = [
    audio('a1', name: 'Coffee Talk', description: 'Ordering at a cafe'),
    audio('a2', name: 'Airport', description: 'Check-in and coffee break'),
  ];

  final collections = [
    collection('c1', 'Coffee Corner'),
    collection('c2', 'Music'),
  ];

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      createTestScreen(
        const LibraryScreen(),
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: collections,
                audioIdsMap: {
                  'c1': ['a1'],
                  'c2': ['a2'],
                },
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterSearch(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('library_search_button')));
    await tester.pumpAndSettle();
  }

  Future<void> typeQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  testWidgets('搜索后合集与音频分区展示命中结果', (tester) async {
    await pumpLibrary(tester);
    await enterSearch(tester);

    await typeQuery(tester, 'coffee');

    // 合集名命中、音频标题或描述命中，均展示；未命中的合集隐藏。
    expect(find.text('Collections'), findsOneWidget);
    // 「Coffee Corner」出现两次：合集卡片本身，以及 Coffee Talk 行内的所属合集标签。
    expect(find.text('Coffee Corner'), findsNWidgets(2));
    // 「Music」只剩 Airport 行内的所属合集标签，合集卡片本身未命中。
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Coffee Talk'), findsOneWidget);
    expect(find.text('Airport'), findsOneWidget);
  });

  testWidgets('只命中合集时不展示音频分区', (tester) async {
    await pumpLibrary(tester);
    await enterSearch(tester);

    await typeQuery(tester, 'music');

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Audio'), findsNothing);
    expect(find.text('Coffee Talk'), findsNothing);
  });

  testWidgets('无任何命中时显示空状态', (tester) async {
    await pumpLibrary(tester);
    await enterSearch(tester);

    await typeQuery(tester, 'zzz');

    expect(find.text('No matching collections or audio'), findsOneWidget);
    expect(find.text('Coffee Corner'), findsNothing);
  });

  testWidgets('取消搜索恢复合集列表', (tester) async {
    await pumpLibrary(tester);
    await enterSearch(tester);
    await typeQuery(tester, 'zzz');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Coffee Corner'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
  });

  testWidgets('系统返回键优先退出搜索而不是离开资源库', (tester) async {
    await pumpLibrary(tester);
    await enterSearch(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Music'), findsOneWidget);
  });
}
