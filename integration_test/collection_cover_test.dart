/// 本地合集封面的 macOS 交互测试。
///
/// 系统相册无法自动操作，选图入口替换为生成的测试图片；之后的预处理、真实裁剪页
/// （crop_your_image）、512 JPEG 编码、文件落盘、数据库与列表 / 素材图标展示都走真实链路。
/// 覆盖：
/// - 创建合集时设置封面，列表与合集内素材显示封面；
/// - 不设封面创建的合集仍显示首字占位；
/// - 「编辑」对话框同时改名和换图，旧文件被删除；
/// - 移除封面回到首字占位，素材图标回到默认媒体图标；
/// - 删除合集时封面文件一并删除。
///
/// 每个关键状态截图到临时目录（日志 COLLECTION_COVER_SCREENSHOT=路径）。
///
/// 运行：flutter test integration_test/collection_cover_test.dart -d macos
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/collection_cover/image_gallery_picker.dart';
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
import 'package:echo_loop/widgets/audio_list_tile.dart';
import 'package:echo_loop/widgets/square_image_crop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../test/helpers/mock_providers.dart';

const _captureKey = ValueKey('collection-cover-capture');
const _audioId = 'cover-audio';
const _coverImageKey = ValueKey('collection-cover-image');
const _placeholderKey = ValueKey('collection-cover-placeholder');
const _audioLocalCoverKey = Key('audio_list_tile_local_cover_artwork');

/// 生成 4:3 测试图：左右两种颜色 + 中央白色圆，便于从截图判断是否按 1:1 居中裁剪。
Uint8List _testImage(img.ColorRgb8 left, img.ColorRgb8 right) {
  final image = img.Image(width: 800, height: 600);
  img.fillRect(image, x1: 0, y1: 0, x2: 399, y2: 599, color: left);
  img.fillRect(image, x1: 400, y1: 0, x2: 799, y2: 599, color: right);
  img.fillCircle(
    image,
    x: 400,
    y: 300,
    radius: 120,
    color: img.ColorRgb8(255, 255, 255),
  );
  return img.encodePng(image);
}

/// 测试宿主：「我的合集」列表 + 第一个合集中素材的列表项（合集详情页同款组件）。
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionListProvider);
    final audio = ref.watch(
      audioLibraryProvider.select(
        (s) => s.audioItems.where((a) => a.id == _audioId).firstOrNull,
      ),
    );
    final host = state.collections
        .where((c) => state.getAudioIds(c.id).contains(_audioId))
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('合集封面'),
        actions: [
          IconButton(
            key: const ValueKey('host-create'),
            icon: const Icon(Icons.add),
            onPressed: () => showCreateCollectionDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: CollectionListView(collections: state.collections)),
          if (audio != null && host != null) ...[
            const Divider(),
            AudioListTile(
              key: const ValueKey('host-audio-tile'),
              audioItem: audio,
              collectionId: host.id,
              showMenu: false,
            ),
          ],
        ],
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory appDir;
  late db.AppDatabase database;

  List<String> logs() => [
    for (final entry in AppLogger.instance.entries)
      if (entry.tag == 'CollectionCover') entry.message,
  ];

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
    appDir = await Directory.systemTemp.createTemp('collection-cover-test-');
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

  testWidgets('创建 / 编辑 / 移除 / 删除本地合集封面', (tester) async {
    final captures = Directory(
      '${Directory.systemTemp.path}/collection-cover-$pid',
    );
    await captures.create(recursive: true);

    final pickedImages = [
      _testImage(img.ColorRgb8(230, 80, 60), img.ColorRgb8(40, 120, 220)),
      _testImage(img.ColorRgb8(40, 170, 90), img.ColorRgb8(250, 200, 40)),
      _testImage(img.ColorRgb8(120, 60, 200), img.ColorRgb8(240, 240, 240)),
    ];
    var pickCount = 0;

    final audio = createTestAudioItem(
      id: _audioId,
      name: 'Cover Material',
      transcriptPath: null,
    );
    final now = DateTime(2026, 11, 17);
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: _audioId,
            name: 'Cover Material',
            addedDate: now,
            updatedAt: now,
            audioPath: const Value('audios/test.mp3'),
          ),
        );

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

    Future<void> waitFor(Finder finder, {String? reason}) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await settle(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets, reason: reason);
    }

    late Future<void> Function(String name) capture;

    Future<void> waitUntil(bool Function() condition, String reason) async {
      for (var i = 0; i < 100 && !condition(); i++) {
        await settle(const Duration(milliseconds: 100));
      }
      if (!condition()) await capture('failure');
      expect(condition(), isTrue, reason: reason);
    }

    capture = (String name) async {
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
      print('COLLECTION_COVER_SCREENSHOT=${file.path}');
    };

    final prefs = await SharedPreferences.getInstance();

    /// 输入合集名称。窗口失去前台时焦点会被暂存到根节点导致输入落空
    /// （troubleshooting 7.56），先恢复 resumed 再输入，并确认输入生效。
    Future<void> typeName(String name) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final field = find.byKey(const ValueKey('collection-name-field'));
      await tester.tap(field);
      await tester.enterText(field, name);
      await settle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        name,
        reason: '名称应输入成功',
      );
    }

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
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [audio])),
          ),
          imageGalleryPickerProvider.overrideWithValue(() async {
            final bytes = pickedImages[pickCount % pickedImages.length];
            pickCount++;
            return bytes;
          }),
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
    final notifier = container.read(collectionListProvider.notifier);
    await tester.runAsync(notifier.loadCollections);
    await settle();

    Collection byName(String name) => container
        .read(collectionListProvider)
        .rawCollections
        .singleWhere((c) => c.name == name);
    File coverFile(String relativePath) =>
        File(p.join(appDir.path, relativePath));
    Finder tileOf(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(Card));

    /// 在当前表单里点封面 → 真实裁剪页 → 完成，回到表单。
    Future<void> pickAndCrop(String captureName) async {
      await waitFor(find.byType(SquareImageCropScreen), reason: '应进入裁剪页');
      // 等裁剪器解码完图片再截图与确认。
      await settle(const Duration(milliseconds: 800));
      await capture(captureName);
      await tester.tap(find.text('完成'));
      await waitUntil(
        () => find.byType(SquareImageCropScreen).evaluate().isEmpty,
        '裁剪完成后应回到表单',
      );
      await waitUntil(
        () => logs().any((m) => m.startsWith('cover drafted')),
        '应生成封面草稿',
      );
    }

    // ── 1. 创建合集时设置封面 ─────────────────────────────────────
    await tester.tap(find.byKey(const ValueKey('host-create')));
    await settle(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('collection-option-local')));
    await settle(const Duration(milliseconds: 400));
    expect(find.byKey(_placeholderKey), findsOneWidget);
    await typeName('封面测试');
    await settle();
    expect(find.byKey(const ValueKey('collection-cover-remove')), findsNothing);
    await capture('01_create_form_default');

    await tester.tap(find.byKey(const ValueKey('collection-cover-picker')));
    await pickAndCrop('02_crop_screen');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('local-collection-dialog')),
        matching: find.byKey(_coverImageKey),
      ),
      findsOneWidget,
    );
    await capture('03_create_form_with_cover');

    await tester.tap(find.byKey(const ValueKey('collection-form-submit')));
    await waitUntil(
      () => container.read(collectionListProvider).rawCollections.isNotEmpty,
      '合集应创建成功',
    );
    await settle(const Duration(milliseconds: 500));
    final created = byName('封面测试');
    final firstCoverPath = created.localCoverPath!;
    expect(coverFile(firstCoverPath).existsSync(), isTrue);
    final firstJpeg = img.decodeJpg(
      coverFile(firstCoverPath).readAsBytesSync(),
    )!;
    expect((firstJpeg.width, firstJpeg.height), (512, 512));
    final row = await tester.runAsync(
      () => database.collectionDao.getById(created.id),
    );
    expect(row!.localCoverPath, firstCoverPath);
    expect(
      find.descendant(of: tileOf('封面测试'), matching: find.byKey(_coverImageKey)),
      findsOneWidget,
    );

    // 素材加入合集后，合集上下文的素材图标显示合集封面。
    await tester.runAsync(
      () => notifier.addAudioToCollection(created.id, _audioId),
    );
    await waitFor(find.byKey(_audioLocalCoverKey), reason: '素材应显示合集封面');
    await capture('04_list_and_material_with_cover');

    // ── 2. 不设封面创建：首字占位 ────────────────────────────────
    await tester.tap(find.byKey(const ValueKey('host-create')));
    await settle(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('collection-option-local')));
    await settle(const Duration(milliseconds: 400));
    await typeName('默认封面');
    await settle();
    await tester.tap(find.byKey(const ValueKey('collection-form-submit')));
    await waitUntil(
      () => container.read(collectionListProvider).rawCollections.length == 2,
      '第二个合集应创建成功',
    );
    await settle(const Duration(milliseconds: 500));
    expect(byName('默认封面').localCoverPath, isNull);
    expect(
      find.descendant(
        of: tileOf('默认封面'),
        matching: find.byKey(_placeholderKey),
      ),
      findsOneWidget,
    );

    Future<void> openEdit(String name) async {
      await tester.tap(
        find.descendant(
          of: tileOf(name),
          matching: find.byIcon(Icons.more_horiz),
        ),
      );
      await settle(const Duration(milliseconds: 400));
      await tester.tap(find.text('编辑'));
      await settle(const Duration(milliseconds: 500));
      await waitFor(find.byKey(const ValueKey('local-collection-dialog')));
    }

    Future<void> saveEdit(String reason) async {
      final updatesBefore = logs()
          .where((m) => m.startsWith('collection updated'))
          .length;
      await tester.tap(find.byKey(const ValueKey('collection-form-submit')));
      await waitUntil(
        () =>
            logs().where((m) => m.startsWith('collection updated')).length >
            updatesBefore,
        reason,
      );
      await settle(const Duration(milliseconds: 500));
    }

    // ── 3. 编辑：改名 + 换图 ─────────────────────────────────────
    await openEdit('封面测试');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('local-collection-dialog')),
        matching: find.byKey(_coverImageKey),
      ),
      findsOneWidget,
      reason: '编辑表单应显示已有封面',
    );
    await capture('05_edit_dialog_existing_cover');
    // 对话框宽度与封面尺寸随可用空间自适应：小屏手机、桌面宽窗口都不溢出。
    Future<void> resize(Size size) async {
      tester.view.physicalSize = size;
      await settle(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }

    await resize(const Size(320, 568));
    await capture('05b_edit_dialog_small_phone');
    await resize(const Size(1200, 800));
    // AlertDialog 外层铺满屏幕，卡片宽度取其内部第一个 Material。
    final wideDialogWidth = tester
        .getSize(
          find
              .descendant(
                of: find.byKey(const ValueKey('local-collection-dialog')),
                matching: find.byType(Material),
              )
              .first,
        )
        .width;
    expect(wideDialogWidth, lessThanOrEqualTo(420), reason: '宽屏下对话框应封顶');
    await capture('05c_edit_dialog_wide');
    await resize(const Size(390, 844));
    AppLogger.instance.clear();
    // 点按封面即可更换。
    await tester.tap(find.byKey(const ValueKey('collection-cover-picker')));
    await pickAndCrop('07_crop_replace');
    await typeName('封面测试（改）');
    await settle();
    await saveEdit('改名换图应保存');
    final renamed = byName('封面测试（改）');
    final secondCoverPath = renamed.localCoverPath!;
    expect(secondCoverPath, isNot(firstCoverPath));
    expect(coverFile(secondCoverPath).existsSync(), isTrue);
    await waitUntil(() => !coverFile(firstCoverPath).existsSync(), '旧封面文件应被删除');
    expect(find.byKey(_audioLocalCoverKey), findsOneWidget);
    await capture('08_after_rename_and_replace');

    // ── 4. 编辑：移除封面 ────────────────────────────────────────
    await openEdit('封面测试（改）');
    await tester.tap(find.byKey(const ValueKey('collection-cover-remove')));
    await settle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('local-collection-dialog')),
        matching: find.byKey(_placeholderKey),
      ),
      findsOneWidget,
    );
    await saveEdit('移除封面应保存');
    expect(byName('封面测试（改）').localCoverPath, isNull);
    await waitUntil(
      () => !coverFile(secondCoverPath).existsSync(),
      '移除后封面文件应被删除',
    );
    expect(
      find.descendant(
        of: tileOf('封面测试（改）'),
        matching: find.byKey(_placeholderKey),
      ),
      findsOneWidget,
    );
    expect(find.byKey(_audioLocalCoverKey), findsNothing, reason: '素材应回到默认图标');
    await capture('09_after_remove');

    // ── 5. 再次添加封面后删除合集，文件随之删除 ─────────────────
    await openEdit('封面测试（改）');
    AppLogger.instance.clear();
    // 无封面时没有「移除」，点按封面直接选图。
    expect(find.byKey(const ValueKey('collection-cover-remove')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('collection-cover-picker')));
    await pickAndCrop('10_crop_add_again');
    await saveEdit('重新添加封面应保存');
    final thirdCoverPath = byName('封面测试（改）').localCoverPath!;
    expect(coverFile(thirdCoverPath).existsSync(), isTrue);

    await tester.tap(
      find.descendant(
        of: tileOf('封面测试（改）'),
        matching: find.byIcon(Icons.more_horiz),
      ),
    );
    await settle(const Duration(milliseconds: 400));
    await tester.tap(find.text('删除').last);
    await settle(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await waitUntil(
      () => container
          .read(collectionListProvider)
          .rawCollections
          .every((c) => c.name != '封面测试（改）'),
      '合集应被删除',
    );
    await waitUntil(
      () => !coverFile(thirdCoverPath).existsSync(),
      '删除合集后封面文件应被删除',
    );
    await capture('11_after_delete');

    final remaining = Directory(p.join(appDir.path, 'collection_covers'))
        .listSync()
        .whereType<File>()
        .toList();
    expect(remaining, isEmpty, reason: '不应留下孤儿封面文件');
    // ignore: avoid_print
    print('COLLECTION_COVER_LOGS:\n${logs().join('\n')}');
  });
}
