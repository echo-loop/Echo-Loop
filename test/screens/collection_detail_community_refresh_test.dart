import 'package:echo_loop/features/community_collections/data/community_sync_service.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/screens/collection_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _MockCommunitySyncService extends Mock implements CommunitySyncService {}

void main() {
  final collection = Collection(
    id: 'community-local-1',
    name: 'Community English',
    createdDate: DateTime(2026, 6, 12),
    source: CollectionSource.community,
    remoteId: 'community-remote-1',
  );

  AudioItem audioItem() => AudioItem(
    id: 'audio-1',
    name: 'Short lesson',
    audioPath: null,
    addedDate: DateTime(2026, 6, 12),
  );

  CommunitySyncCompleted completed({
    int failedCollections = 0,
    int failedFiles = 0,
  }) => CommunitySyncCompleted(
    collectionsScanned: 1,
    collectionsDeprecated: 0,
    collectionsUndeprecated: 0,
    filesAdded: 0,
    filesRemoved: 0,
    failedCollections: failedCollections,
    failedFiles: failedFiles,
  );

  Future<_MockCommunitySyncService> pumpScreen(
    WidgetTester tester, {
    required List<AudioItem> audioItems,
    required CommunitySyncOutcome outcome,
  }) async {
    final syncService = _MockCommunitySyncService();
    when(
      () => syncService.syncCollection('community-local-1'),
    ).thenAnswer((_) async => outcome);

    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'community-local-1'),
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: {
                  'community-local-1': audioItems
                      .map((item) => item.id)
                      .toList(),
                },
              ),
            ),
          ),
          communitySyncServiceProvider.overrideWithValue(syncService),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    return syncService;
  }

  testWidgets('短社区合集列表下拉强制同步当前合集', (tester) async {
    final syncService = await pumpScreen(
      tester,
      audioItems: [audioItem()],
      outcome: completed(failedFiles: 1),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();

    verify(() => syncService.syncCollection('community-local-1')).called(1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('空社区合集也可以下拉强制同步当前合集', (tester) async {
    final syncService = await pumpScreen(
      tester,
      audioItems: const [],
      outcome: completed(),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();

    verify(() => syncService.syncCollection('community-local-1')).called(1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('同步完全失败时显示错误反馈', (tester) async {
    final syncService = await pumpScreen(
      tester,
      audioItems: [audioItem()],
      outcome: const CommunitySyncFailed('network unavailable'),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();

    verify(() => syncService.syncCollection('community-local-1')).called(1);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
