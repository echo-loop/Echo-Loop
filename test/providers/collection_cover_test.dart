import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' hide Collection;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/collection_cover/collection_cover_edit.dart';
import 'package:echo_loop/features/collection_cover/collection_cover_store.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

final _coverA = Uint8List.fromList([0xFF, 0xD8, 0xA]);
final _coverB = Uint8List.fromList([0xFF, 0xD8, 0xB]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dataDir;
  late AppDatabase db;
  late ProviderContainer container;
  late CollectionList notifier;

  File coverFile(String relativePath) =>
      File(p.join(dataDir.path, relativePath));

  Collection single() =>
      container.read(collectionListProvider).rawCollections.single;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dataDir = await Directory.systemTemp.createTemp('collection_cover_test_');
    db = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    var tick = 0;
    container = ProviderContainer(
      overrides: dedupeOverrides([
        analyticsOverride(),
        appDatabaseProvider.overrideWithValue(db),
        collectionCoverStoreProvider.overrideWithValue(
          CollectionCoverStore(
            dataDirectory: () async => dataDir,
            // 固定递增时间，保证每次写入的文件名不同且可预测。
            now: () =>
                DateTime.utc(2026, 11, 17).add(Duration(seconds: ++tick)),
          ),
        ),
      ]),
    );
    notifier = container.read(collectionListProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  test('创建时带封面：文件落盘、数据库与状态记录相对路径', () async {
    await notifier.createCollection('有封面', coverJpeg: _coverA);

    final collection = single();
    final path = collection.localCoverPath!;
    expect(path, startsWith('collection_covers/${collection.id}_'));
    expect(await coverFile(path).readAsBytes(), _coverA);
    final row = await db.collectionDao.getById(collection.id);
    expect(row!.localCoverPath, path);
  });

  test('创建时不带封面：不写文件，使用默认封面', () async {
    await notifier.createCollection('无封面');

    expect(single().localCoverPath, isNull);
    expect(
      Directory(p.join(dataDir.path, 'collection_covers')).existsSync(),
      isFalse,
    );
  });

  test('换图写入新文件并删除旧文件；改名同时生效', () async {
    await notifier.createCollection('旧名', coverJpeg: _coverA);
    final oldPath = single().localCoverPath!;

    await notifier.updateLocalCollection(
      single().id,
      name: '新名',
      cover: CollectionCoverReplaced(_coverB),
    );

    final updated = single();
    expect(updated.name, '新名');
    expect(updated.localCoverPath, isNot(oldPath));
    expect(await coverFile(updated.localCoverPath!).readAsBytes(), _coverB);
    expect(coverFile(oldPath).existsSync(), isFalse);
    final row = await db.collectionDao.getById(updated.id);
    expect(row!.localCoverPath, updated.localCoverPath);
    expect(row.name, '新名');
  });

  test('移除封面：数据库清空路径并删除文件', () async {
    await notifier.createCollection('合集', coverJpeg: _coverA);
    final oldPath = single().localCoverPath!;

    await notifier.updateLocalCollection(
      single().id,
      name: '合集',
      cover: const CollectionCoverRemoved(),
    );

    expect(single().localCoverPath, isNull);
    expect(coverFile(oldPath).existsSync(), isFalse);
    expect(
      (await db.collectionDao.getById(single().id))!.localCoverPath,
      isNull,
    );
  });

  test('名称与封面都未变化时不写库、不刷新更新时间', () async {
    await notifier.createCollection('合集', coverJpeg: _coverA);
    final before = single();

    await Future<void>.delayed(const Duration(milliseconds: 2));
    await notifier.updateLocalCollection(
      before.id,
      name: '合集',
      cover: const CollectionCoverUnchanged(),
    );

    expect(single().updatedAt, before.updatedAt);
    expect(coverFile(before.localCoverPath!).existsSync(), isTrue);
  });

  test('写库失败时删除新文件，保留旧封面与状态', () async {
    await notifier.createCollection('合集', coverJpeg: _coverA);
    final before = single();
    await db.close();

    await expectLater(
      notifier.updateLocalCollection(
        before.id,
        name: '合集',
        cover: CollectionCoverReplaced(_coverB),
      ),
      throwsA(anything),
    );

    expect(single().localCoverPath, before.localCoverPath);
    expect(coverFile(before.localCoverPath!).existsSync(), isTrue);
    final files = Directory(p.join(dataDir.path, 'collection_covers'))
        .listSync()
        .map((f) => p.basename(f.path))
        .toList();
    expect(files, [p.basename(before.localCoverPath!)]);
  });

  test('删除合集时删除封面文件', () async {
    await notifier.createCollection('合集', coverJpeg: _coverA);
    final collection = single();

    await notifier.deleteCollection(collection.id);

    expect(container.read(collectionListProvider).rawCollections, isEmpty);
    expect(coverFile(collection.localCoverPath!).existsSync(), isFalse);
  });

  test('非本地合集不允许编辑封面', () async {
    final now = DateTime(2026, 11, 17);
    final podcast = Collection(
      id: 'p1',
      name: 'Podcast',
      createdDate: now,
      source: CollectionSource.podcast,
    );
    await notifier.createPodcastCollection(podcast);

    expect(
      () => notifier.updateLocalCollection(
        'p1',
        name: 'x',
        cover: const CollectionCoverRemoved(),
      ),
      throwsArgumentError,
    );
  });

  group('coverCollectionForAudio', () {
    final now = DateTime(2026, 11, 17);
    Collection make(
      String id, {
      CollectionSource source = CollectionSource.local,
      String? cover,
    }) => Collection(
      id: id,
      name: id,
      createdDate: now,
      source: source,
      localCoverPath: cover,
    );

    test('已订阅合集优先，其次是设置了封面的本地合集', () {
      final state = CollectionState(
        rawCollections: [
          make('plain'),
          make('covered', cover: 'collection_covers/c.jpg'),
          make('community', source: CollectionSource.community),
        ],
        audioIdsMap: const {
          'plain': ['a1', 'a2'],
          'covered': ['a1', 'a2'],
          'community': ['a2'],
        },
      );

      expect(state.coverCollectionForAudio('a1')?.id, 'covered');
      expect(state.coverCollectionForAudio('a2')?.id, 'community');
      expect(state.coverCollectionForAudio('a3'), isNull);
    });

    test('只在无封面的本地合集中时返回 null', () {
      final state = CollectionState(
        rawCollections: [make('plain')],
        audioIdsMap: const {
          'plain': ['a1'],
        },
      );

      expect(state.coverCollectionForAudio('a1'), isNull);
    });
  });
}
