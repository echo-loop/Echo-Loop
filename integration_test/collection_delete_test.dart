/// 删除本地合集的 macOS 交互测试。
///
/// 真实数据库（内存 SQLite）、真实音频库 / 合集 Provider、真实磁盘文件，覆盖：
/// - 删除确认弹窗没有复选框，提示音频及学习记录一并删除、其他合集不受影响；
/// - 取消删除不改变任何数据；
/// - 确认删除后：只属于该合集的音频连同文件、学习记录被删除；
///   同时在其他合集中的音频及其文件、学习记录保留，其他合集关联完好；
/// - 空合集的删除弹窗不显示音频提示。
///
/// 每个关键状态截图到临时目录（日志 COLLECTION_DELETE_SCREENSHOT=路径）。
///
/// 运行：flutter test integration_test/collection_delete_test.dart -d macos
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/user_region/user_region_bootstrapper.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/screens/collection_screen.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:echo_loop/utils/time_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../test/helpers/mock_providers.dart';

const _captureKey = ValueKey('collection-delete-capture');
const _hint = '合集内的材料及其学习记录将一并删除，同时在其他合集中的材料不受影响。';

// 只在 A 中 / A、B 共有 / 只在 B 中。
const _onlyInA = 'audio-only-a';
const _shared = 'audio-shared';
const _onlyInB = 'audio-only-b';

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(
      collectionListProvider.select((s) => s.collections),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('删除合集')),
      body: CollectionListView(collections: collections),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory appDir;
  late db.AppDatabase database;

  setUpAll(() async {
    initTimeago();
    if (Platform.isMacOS) {
      await windowManager.ensureInitialized();
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
    }
  });

  tearDownAll(() async {
    if (Platform.isMacOS) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.hide();
    }
  });

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('collection-delete-test-');
    appDataDirectoryOverride = appDir;
    database = db.AppDatabase(
      NativeDatabase.memory(setup: db.configureAppDatabaseConnection),
    );
    AppLogger.instance.clear();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await database.close();
    appDataDirectoryOverride = null;
    await appDir.delete(recursive: true);
  });

  testWidgets('删除本地合集：删独占音频与学习记录，保留其他合集中的音频', (tester) async {
    final captures = Directory(
      '${Directory.systemTemp.path}/collection-delete-$pid',
    );
    await captures.create(recursive: true);

    Future<void> settle([
      Duration duration = const Duration(milliseconds: 200),
    ]) async {
      final end = DateTime.now().add(duration);
      do {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      } while (DateTime.now().isBefore(end));
    }

    Future<void> capture(String name) async {
      await settle(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_captureKey),
      );
      final file = File('${captures.path}/$name.png');
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('COLLECTION_DELETE_SCREENSHOT=${file.path}');
    }

    Future<void> waitUntil(bool Function() condition, String reason) async {
      for (var i = 0; i < 100 && !condition(); i++) {
        await settle(const Duration(milliseconds: 100));
      }
      if (!condition()) await capture('failure');
      expect(condition(), isTrue, reason: reason);
    }

    // ── 准备：三个音频的真实文件、数据库记录与学习记录 ──────────────
    File audioFile(String id) => File(p.join(appDir.path, 'audios', '$id.mp3'));
    File transcriptFile(String id) =>
        File(p.join(appDir.path, 'transcripts', '$id.srt'));
    final now = DateTime(2026, 11, 17);
    for (final id in [_onlyInA, _shared, _onlyInB]) {
      await audioFile(id).create(recursive: true);
      await audioFile(id).writeAsBytes(List.filled(64, 1));
      await transcriptFile(id).create(recursive: true);
      await transcriptFile(id)
          .writeAsString('1\n00:00:00,000 --> 00:00:01,000\nHi\n');
      await database
          .into(database.audioItems)
          .insert(
            db.AudioItemsCompanion.insert(
              id: id,
              name: id,
              addedDate: now,
              updatedAt: now,
              audioPath: Value('audios/$id.mp3'),
              transcriptPath: Value('transcripts/$id.srt'),
              transcriptSource: const Value(1),
            ),
          );
      await database
          .into(database.learningProgresses)
          .insert(
            db.LearningProgressesCompanion.insert(
              audioItemId: id,
              updatedAt: now,
              blindListenPassCount: const Value(2),
            ),
          );
    }

    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          userRegionBootstrapProvider.overrideWith(
            (ref) async => const UserRegionBootstrapResult(
              isChinaUser: false,
              source: UserRegionDecisionSource.systemFallback,
              remoteConfig: RemoteConfig.defaults,
            ),
          ),
          analyticsOverride(),
        ]),
        child: RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const _Host(),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    );
    // 音频库页面不在宿主里，显式保持 provider 存活。
    final keepAudioLibraryAlive = container.listen(
      audioLibraryProvider,
      (_, __) {},
    );
    addTearDown(keepAudioLibraryAlive.close);
    final collections = container.read(collectionListProvider.notifier);
    await tester.runAsync(
      () => container.read(audioLibraryProvider.notifier).loadLibrary(),
    );
    await tester.runAsync(collections.loadCollections);
    await tester.runAsync(() => collections.createCollection('合集 A'));
    await tester.runAsync(() => collections.createCollection('合集 B'));
    await tester.runAsync(() => collections.createCollection('空合集'));
    await settle();

    Collection byName(String name) => container
        .read(collectionListProvider)
        .rawCollections
        .singleWhere((c) => c.name == name);
    final a = byName('合集 A');
    final b = byName('合集 B');
    await tester.runAsync(() async {
      await collections.addAudiosToCollection(a.id, [_onlyInA, _shared]);
      await collections.addAudiosToCollection(b.id, [_shared, _onlyInB]);
    });
    await settle();
    expect(
      container.read(audioLibraryProvider).audioItems.map((i) => i.id).toSet(),
      {_onlyInA, _shared, _onlyInB},
    );

    Future<void> openDeleteDialog(String name) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
          matching: find.byIcon(Icons.more_horiz),
        ),
      );
      await settle(const Duration(milliseconds: 400));
      await tester.tap(find.text('删除').last);
      await settle(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    Future<Set<String>> dbAudioIds() async => (await tester.runAsync(
      () => database.select(database.audioItems).get(),
    ))!.map((r) => r.id).toSet();
    Future<Set<String>> dbProgressIds() async => (await tester.runAsync(
      () => database.select(database.learningProgresses).get(),
    ))!.map((r) => r.audioItemId).toSet();

    await capture('01_list');

    // ── 1. 弹窗文案：无复选框，有音频提示 ───────────────────────────
    await openDeleteDialog('合集 A');
    expect(find.text('确定要删除「合集 A」吗？'), findsOneWidget);
    expect(find.text(_hint), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await capture('02_dialog_with_audio');

    // ── 2. 取消：数据不变 ──────────────────────────────────────────
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await settle(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(collectionListProvider).rawCollections, hasLength(3));
    expect(await dbAudioIds(), {_onlyInA, _shared, _onlyInB});
    expect(audioFile(_onlyInA).existsSync(), isTrue);

    // ── 3. 确认删除合集 A ──────────────────────────────────────────
    await openDeleteDialog('合集 A');
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await waitUntil(
      () => container
          .read(collectionListProvider)
          .rawCollections
          .every((c) => c.id != a.id),
      '合集 A 应被删除',
    );
    await settle(const Duration(milliseconds: 400));

    // 独占音频：记录、文件、学习记录都被删除。
    expect(await dbAudioIds(), {_shared, _onlyInB});
    expect(await dbProgressIds(), {_shared, _onlyInB});
    expect(audioFile(_onlyInA).existsSync(), isFalse);
    expect(transcriptFile(_onlyInA).existsSync(), isFalse);
    // 共享音频与 B 的独占音频完好。
    for (final id in [_shared, _onlyInB]) {
      expect(audioFile(id).existsSync(), isTrue, reason: '$id 音频文件应保留');
      expect(transcriptFile(id).existsSync(), isTrue, reason: '$id 字幕应保留');
    }
    expect(
      container.read(audioLibraryProvider).audioItems.map((i) => i.id).toSet(),
      {_shared, _onlyInB},
    );
    expect(container.read(collectionListProvider).getAudioIds(b.id), [
      _shared,
      _onlyInB,
    ]);
    final bAudioIdsInDb = await tester.runAsync(
      () => database.collectionDao.getAudioIds(b.id),
    );
    expect(bAudioIdsInDb!.toSet(), {_shared, _onlyInB});
    expect(
      await tester.runAsync(() => database.collectionDao.getById(a.id)),
      isNull,
    );
    await capture('03_after_delete_a');

    // ── 4. 空合集：不显示音频提示 ──────────────────────────────────
    await openDeleteDialog('空合集');
    expect(find.text('确定要删除「空合集」吗？'), findsOneWidget);
    expect(find.text(_hint), findsNothing);
    await capture('04_dialog_empty_collection');
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await waitUntil(
      () => container
          .read(collectionListProvider)
          .rawCollections
          .every((c) => c.name != '空合集'),
      '空合集应被删除',
    );
    expect(await dbAudioIds(), {_shared, _onlyInB});
    await capture('05_after_delete_empty');
  });
}
