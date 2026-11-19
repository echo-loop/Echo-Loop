import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/pause_other_playback_provider.dart';
import 'package:echo_loop/features/media_trim/media_trim_screen.dart';
import 'package:echo_loop/features/media_trim/media_trim_split_geometry.dart';
import 'package:echo_loop/features/media_trim/media_trim_split_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/services/media_kit_player_backend.dart';
import 'package:echo_loop/theme/app_theme.dart';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/features/media_trim/media_trim_processor.dart';
import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/features/media_trim/media_trim_exporter.dart';
import 'package:echo_loop/features/media_trim/media_trim_repository.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:echo_loop/utils/audio_fingerprint.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.isMacOS) {
      print('MEDIA_TRIM_TEST_PID=$pid');
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
  late Directory directory;
  late db.AppDatabase database;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('media-trim-test-');
    appDataDirectoryOverride = directory;
    database = db.AppDatabase(
      NativeDatabase.memory(setup: db.configureAppDatabaseConnection),
    );
  });
  tearDown(() async {
    await database.close();
    appDataDirectoryOverride = null;
    await directory.delete(recursive: true);
  });
  for (final video in [false, true]) {
    for (final subtitles in [false, true]) {
      testWidgets(
        '${video ? '视频' : '音频'}${subtitles ? '有字幕' : '无字幕'}：真实生成两段并独立入库',
        (tester) async {
          final path = 'original.${video ? 'mp4' : 'm4a'}';
          final generated = await FFmpegKit.executeWithArguments([
            '-y',
            '-f',
            'lavfi',
            '-i',
            'sine=frequency=440:duration=6',
            if (video) ...[
              '-f',
              'lavfi',
              '-i',
              'testsrc2=size=${subtitles ? '240x320' : '320x240'}:rate=25:duration=6',
              '-c:v',
              'mpeg4',
              '-g',
              '100',
            ],
            '-c:a',
            'aac',
            '${directory.path}/$path',
          ]);
          expect(
            ReturnCode.isSuccess(await generated.getReturnCode()),
            isTrue,
            reason: await generated.getOutput(),
          );
          final originalHash = await computeAudioSha256(
            '${directory.path}/$path',
          );
          final now = DateTime.now();
          await database
              .into(database.audioItems)
              .insert(
                db.AudioItemsCompanion.insert(
                  id: 'source',
                  name: 'Original',
                  audioPath: Value(path),
                  audioSha256: Value(originalHash),
                  originalAudioSha256: Value(originalHash),
                  addedDate: now,
                  updatedAt: now,
                  remoteAudioId: const Value('remote-source'),
                ),
              );
          final before = (await database.audioItemDao.getById('source'))!
              .toJson();
          final sentences = subtitles
              ? [
                  Sentence(
                    index: 0,
                    text: 'Hello world',
                    startTime: const Duration(milliseconds: 1250),
                    endTime: const Duration(milliseconds: 2750),
                  ),
                  Sentence(
                    index: 1,
                    text: 'Good morning',
                    startTime: const Duration(milliseconds: 3250),
                    endTime: const Duration(milliseconds: 4750),
                  ),
                ]
              : <Sentence>[];
          final words = subtitles
              ? [
                  const WordTimestamp(
                    word: 'Hello',
                    startTime: Duration(milliseconds: 1300),
                    endTime: Duration(milliseconds: 1600),
                  ),
                ]
              : <WordTimestamp>[];
          final source = AudioItem(
            id: 'source',
            name: 'Original',
            audioPath: path,
            addedDate: now,
            transcriptSource: subtitles ? TranscriptSource.ai : null,
          );
          final boundaries = MediaTrimBoundaries(
            total: const Duration(seconds: 6),
            sentences: sentences,
          );
          final result =
              await MediaTrimExporter(
                repository: MediaTrimRepository(database),
                processor: const MediaTrimProcessor(),
              ).export(
                source: source,
                boundaries: boundaries,
                words: words,
                clips: const [
                  (
                    clip: MediaTrimClip(
                      id: 1,
                      start: Duration(milliseconds: 1250),
                      end: Duration(milliseconds: 2750),
                    ),
                    name: 'First',
                  ),
                  (
                    clip: MediaTrimClip(
                      id: 2,
                      start: Duration(milliseconds: 3250),
                      end: Duration(milliseconds: 4750),
                    ),
                    name: 'Second',
                  ),
                ],
                destination: const MediaTrimNewCollection('Clips'),
                cancellation: MediaTrimCancellation(),
                onProgress: (_) {},
              );
          final target = result.collectionId;
          final ids = await database.collectionDao.getAudioIds(target);
          expect(ids, hasLength(2));
          for (final id in ids) {
            final item = (await database.audioItemDao.getById(id))!;
            expect(item.remoteAudioId, isNull);
            expect(item.podcastEpisodeGuid, isNull);
            expect(item.importSourceType, 'trimmed');
            expect(item.audioSha256, isNot(originalHash));
            expect(item.originalAudioSha256, item.audioSha256);
            expect(
              item.audioSha256,
              await computeAudioSha256('${directory.path}/${item.audioPath}'),
            );
            expect(
              (await const MediaTrimProcessor().probe(
                '${directory.path}/${item.audioPath}',
              )).duration.inMilliseconds,
              closeTo(1500, 150),
            );
            expect(item.transcriptSource != null, subtitles);
            if (video) {
              final probe = await FFprobeKit.getMediaInformation(
                '${directory.path}/${item.audioPath}',
              );
              final track = probe
                  .getMediaInformation()!
                  .getStreams()
                  .where((stream) => stream.getType() == 'video')
                  .single;
              expect(track.getCodec(), 'h264');
              expect(
                double.parse(track.getStringProperty('duration')!),
                closeTo(1.5, 0.15),
                reason: '视频轨应覆盖整个选区，音轨时长无法检出少帧',
              );
              expect(track.getWidth(), subtitles ? 240 : 320);
              expect(track.getHeight(), subtitles ? 320 : 240);
            }
          }
          if (video) {
            final first = (await database.audioItemDao.getById(ids.first))!;
            Future<List<int>> frame(
              String input,
              String name,
              String start,
            ) async {
              final output = '${directory.path}/$name.gray';
              final session = await FFmpegKit.executeWithArguments([
                '-y',
                '-ss',
                start,
                '-i',
                input,
                '-frames:v',
                '1',
                '-vf',
                'scale=32:24,format=gray',
                '-threads:v',
                '1',
                '-f',
                'rawvideo',
                output,
              ]);
              expect(
                ReturnCode.isSuccess(await session.getReturnCode()),
                isTrue,
                reason: await session.getOutput(),
              );
              return File(output).readAsBytes();
            }

            final reference = await frame(
              '${directory.path}/$path',
              'reference',
              '1.25',
            );
            final result = await frame(
              '${directory.path}/${first.audioPath}',
              'result',
              '0',
            );
            expect(result.length, reference.length);
            var difference = 0;
            for (var i = 0; i < reference.length; i++) {
              difference += (reference[i] - result[i]).abs();
            }
            expect(
              difference / reference.length,
              lessThan(5),
              reason: '首帧应对应选区起点，而非前一个关键帧',
            );
            if (Platform.isAndroid && !subtitles) {
              final player = MediaKitPlayerBackend();
              try {
                await tester.pumpWidget(
                  MaterialApp(
                    home: player.buildVideoView(
                      viewportSize: const Size(320, 240),
                    ),
                  ),
                );
                await player.open('${directory.path}/${first.audioPath}');
                await player.play();
                await player.positionStream
                    .firstWhere(
                      (position) =>
                          position >= const Duration(milliseconds: 750),
                    )
                    .timeout(const Duration(seconds: 10));
                expect(player.videoAspectRatio, closeTo(4 / 3, 0.01));
              } finally {
                await tester.pumpWidget(const SizedBox.shrink());
                await player.dispose();
              }
            }
          }
          if (subtitles) {
            final srt = await database.audioItemDao.getTranscriptSrt(ids.first);
            expect(srt, contains('00:00:00,000 --> 00:00:01,500'));
            final json = await database.audioItemDao.getWordTimestamps(
              ids.first,
            );
            expect(
              decodeWordTimestamps(json!)!.single.startTime,
              const Duration(milliseconds: 50),
            );
          }
          expect(
            (await database.audioItemDao.getById('source'))!.toJson(),
            before,
          );
          expect(
            await computeAudioSha256('${directory.path}/$path'),
            originalHash,
          );
          await database.audioItemDao.hardDelete('source');
          expect(
            await File(
              '${directory.path}/${(await database.audioItemDao.getById(ids.first))!.audioPath}',
            ).exists(),
            isTrue,
          );
        },
      );
    }
  }

  /// 生成测试媒体并写入原材料记录。
  Future<AudioItem> seedSource({
    required bool video,
    required bool subtitles,
  }) async {
    final path = video ? 'ui.mp4' : 'ui.m4a';
    final generated = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=6',
      if (video) ...[
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=640x360:rate=25:duration=6',
        '-c:v',
        'mpeg4',
      ],
      '-c:a',
      'aac',
      '${directory.path}/$path',
    ]);
    expect(ReturnCode.isSuccess(await generated.getReturnCode()), isTrue);
    final now = DateTime.now();
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: 'ui-source',
            name: 'UI source',
            audioPath: Value(path),
            transcriptSource: Value(subtitles ? 1 : null),
            transcriptSrt: Value(subtitles ? _uiSrt : null),
            addedDate: now,
            updatedAt: now,
          ),
        );
    return AudioItem(
      id: 'ui-source',
      name: 'UI source',
      audioPath: path,
      transcriptSource: subtitles ? TranscriptSource.ai : null,
      addedDate: now,
    );
  }

  Future<_UiHarness> pumpScreen(WidgetTester tester, AudioItem source) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) => RepaintBoundary(
            key: const ValueKey('trim-capture'),
            child: MediaTrimScreen(source: source),
          ),
        ),
        GoRoute(
          path: '/collections/:id',
          builder: (_, state) => const Scaffold(body: Text('saved-collection')),
        ),
      ],
    );
    final presentation = ValueNotifier<(double, bool)>((1.0, false));
    // 用内存偏好，分栏宽度等设置不写入用户真实偏好，用例之间也互不影响。
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
          // 测试只验证剪辑页本身，不启动全局播放链路。
          pauseOtherPlaybackProvider.overrideWithValue(() async {}),
        ],
        child: ValueListenableBuilder<(double, bool)>(
          valueListenable: presentation,
          builder: (context, config, child) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            themeMode: config.$2 ? ThemeMode.dark : ThemeMode.light,
            darkTheme: AppTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(config.$1)),
              child: child!,
            ),
            routerConfig: router,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    final harness = _UiHarness(tester, router, presentation, preferences);
    await harness.waitFor(find.byKey(const ValueKey('trim-timeline')));
    return harness;
  }

  testWidgets('剪辑页面有字幕：整句起止、新片段、保存并跳转合集', (tester) async {
    final source = await seedSource(video: false, subtitles: true);
    final ui = await pumpScreen(tester, source);
    await ui.resize(const Size(1280, 800));
    await ui.capture('subtitles-empty-desktop');

    // 第一段：点第 1 句试听（播放头移到该句），新片段从这里取整句；材料只有两句，
    // 一次就取满，再把结束端往前收一句。
    await ui.tap(find.byKey(const ValueKey('trim-sentence-0')));
    await ui.settleAsync(const Duration(milliseconds: 300));
    await ui.tap(find.byKey(const ValueKey('trim-add')));
    await ui.tap(find.byKey(const ValueKey('trim-end-earlier')));
    // 剩下的空白只有一句、不足下限：新片段给出顶部 toast，不建段。
    await ui.tap(find.byKey(const ValueKey('trim-add')));
    expect(find.textContaining('没有足够长的空白'), findsOneWidget);
    expect(find.byKey(const ValueKey('trim-clip-2')), findsNothing);
    // 第二段：取消选中后点第 2 句，用 I 键以播放位置为起点建段。
    await ui.sendKey(LogicalKeyboardKey.escape);
    await ui.tap(find.byKey(const ValueKey('trim-sentence-1')));
    await ui.settleAsync(const Duration(milliseconds: 600));
    await ui.sendKey(LogicalKeyboardKey.keyI);
    await ui.settleAsync();
    expect(find.byKey(const ValueKey('trim-clip-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('trim-clip-2')), findsOneWidget);

    await ui.tap(find.byKey(const ValueKey('trim-play')));
    await ui.settleAsync(const Duration(milliseconds: 400));
    await ui.tap(find.byKey(const ValueKey('trim-play')));

    await ui.captureVariants('subtitles');
    // 窄屏：字幕在第二个标签页。
    await ui.resize(const Size(390, 844));
    await ui.tap(find.byKey(const ValueKey('trim-tab-transcript')));
    await ui.capture('subtitles-phone-transcript');
    await ui.resize(const Size(1280, 800));

    await ui.save('UI clips');
    final rows = await database.audioItemDao.getAllActive();
    expect(rows, hasLength(3));
    final created = rows.where((row) => row.id != 'ui-source').toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    expect(created.map((row) => row.name), [
      'UI source · 01',
      'UI source · 02',
    ]);
    for (final row in created) {
      expect(row.sentenceCount, 1);
    }
    expect(await database.audioItemDao.getTranscriptSrt('ui-source'), _uiSrt);
    await ui.dispose();
  });

  testWidgets('剪辑页面无字幕：输入时间、短材料不提供自动分段、保存', (tester) async {
    final source = await seedSource(video: false, subtitles: false);
    final ui = await pumpScreen(tester, source);
    await ui.resize(const Size(1280, 800));

    await ui.tap(find.byKey(const ValueKey('trim-add')));
    await ui.setTime('trim-start-time', '0:01.250');
    await ui.setTime('trim-end-time', '0:02.750');
    await ui.tap(find.byKey(const ValueKey('trim-start-later')));
    // 起止编辑框显示精确时间。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trim-start-time')),
        matching: find.text('0:01.350'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trim-end-time')),
        matching: find.text('0:02.750'),
      ),
      findsOneWidget,
    );

    // 在时间轴上把终点把手向右拖约 1 秒。
    final timeline = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('trim-timeline')),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    double xAt(double seconds) =>
        timeline.left + 14 + (timeline.width - 28) * seconds / 6;
    await tester.dragFrom(
      Offset(xAt(2.75), timeline.center.dy),
      Offset(xAt(3.75) - xAt(2.75), 0),
    );
    await ui.settleAsync(const Duration(milliseconds: 300));
    final dragged = find.descendant(
      of: find.byKey(const ValueKey('trim-end-time')),
      matching: find.textContaining(RegExp(r'^0:03\.[67]\d\d$')),
    );
    expect(dragged, findsOneWidget);

    // 快捷键：空格播放 / 暂停；N 新建，剩余空白都短于 6 秒全长时只提示。
    await ui.sendKey(LogicalKeyboardKey.space);
    await ui.settleAsync(const Duration(milliseconds: 500));
    await ui.sendKey(LogicalKeyboardKey.space);
    await ui.settleAsync();
    await ui.sendKey(LogicalKeyboardKey.keyN);
    await ui.settleAsync();
    expect(find.byKey(const ValueKey('trim-clip-2')), findsNothing);
    // Esc 取消选中，点到末尾附近后按 I 从播放位置建段。
    await ui.sendKey(LogicalKeyboardKey.escape);
    await tester.tapAt(Offset(xAt(4.5), timeline.center.dy));
    await ui.settleAsync();
    await ui.sendKey(LogicalKeyboardKey.keyI);
    await ui.settleAsync();
    expect(find.byKey(const ValueKey('trim-clip-2')), findsOneWidget);

    // 选中片段 1，把终点把手拖到片段 2 起点附近：吸附对齐到 4.5 秒，首尾无缝衔接。
    await ui.tap(find.byKey(const ValueKey('trim-clip-1')));
    final gesture = await tester.startGesture(
      Offset(xAt(3.75) + 6, timeline.center.dy),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(Offset(xAt(4.45) + 6, timeline.center.dy));
    await ui.settleAsync();
    await ui.capture('audio-snap-guide');
    await gesture.up();
    await ui.settleAsync(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trim-end-time')),
        matching: find.text('0:04.500'),
      ),
      findsOneWidget,
    );

    // 选中片段时才显示「放大到当前片段」；Esc 取消选中后隐藏。
    await ui.tap(find.byKey(const ValueKey('trim-zoom-clip')));
    await ui.capture('audio-zoomed-clip');
    await ui.sendKey(LogicalKeyboardKey.escape);
    await ui.settleAsync();
    expect(find.byKey(const ValueKey('trim-zoom-clip')), findsNothing);
    await ui.tap(find.byKey(const ValueKey('trim-clip-1')));

    await ui.captureVariants('audio');

    // 6 秒材料比最短段长还短：自动分段不提供选项，不能应用。
    await ui.tap(find.byKey(const ValueKey('trim-auto-split')));
    expect(find.byKey(const ValueKey('trim-split-too-short')), findsOneWidget);
    expect(find.byKey(const ValueKey('trim-split-1')), findsNothing);
    await tester.tapAt(const Offset(4, 4));
    await ui.settleAsync();

    await ui.save('Manual clips');
    expect(await database.audioItemDao.getAllActive(), hasLength(3));
    await ui.dispose();
  });

  testWidgets('剪辑页面视频：预览画面与布局截图', (tester) async {
    final source = await seedSource(video: true, subtitles: false);
    final ui = await pumpScreen(tester, source);
    await ui.resize(const Size(1280, 800));
    await ui.tap(find.byKey(const ValueKey('trim-add')));
    // 画面默认收起。6 秒素材只有在手机宽度下才能放大：放大后展开画面、切到矮窗口
    // 整页滚动布局，时间轴换了位置也不重置缩放。
    await ui.resize(const Size(390, 844));
    await ui.tap(find.byKey(const ValueKey('trim-zoom-in')));
    Finder zoomOut() => find.descendant(
      of: find.byKey(const ValueKey('trim-zoom-out')),
      matching: find.byType(IconButton),
    );
    bool isZoomed() => tester.widget<IconButton>(zoomOut()).onPressed != null;
    expect(isZoomed(), isTrue);
    await ui.resize(const Size(390, 560));
    expect(isZoomed(), isTrue, reason: '切到矮窗口布局不重置缩放');
    await ui.resize(const Size(390, 844));
    expect(isZoomed(), isTrue, reason: '切回固定头部布局不重置缩放');
    await ui.tap(find.byKey(const ValueKey('trim-zoom-out')));
    await ui.capture('video-hidden-phone');
    final timelineTop = tester.getTopLeft(
      find.byKey(const ValueKey('trim-timeline')),
    );
    await ui.tap(find.byKey(const ValueKey('trim-toggle-video')));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('trim-timeline'))).dy,
      greaterThan(timelineTop.dy),
    );
    // 页面左右边距固定 16，不随窗口宽度跳变。
    for (final size in [
      const Size(390, 844),
      const Size(700, 844),
      const Size(1600, 800),
    ]) {
      await ui.resize(size);
      final timeline = tester.getRect(
        find.byKey(const ValueKey('trim-timeline')),
      );
      expect(timeline.left, 16, reason: '$size 左边距');
    }
    await ui.resize(const Size(390, 844));
    await ui.tap(find.byKey(const ValueKey('trim-zoom-in')));
    await ui.tap(find.byKey(const ValueKey('trim-toggle-video')));
    expect(isZoomed(), isTrue, reason: '收起画面不重置缩放');
    await ui.tap(find.byKey(const ValueKey('trim-toggle-video')));
    expect(isZoomed(), isTrue, reason: '展开画面不重置缩放');
    await ui.resize(const Size(1280, 800));
    final initialTimelineWidth = tester
        .getSize(find.byKey(const ValueKey('trim-timeline-column')))
        .width;
    await tester.drag(
      find.byKey(const ValueKey('practice-media-split-divider')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    final expandedTimelineWidth = tester
        .getSize(find.byKey(const ValueKey('trim-timeline-column')))
        .width;
    expect(expandedTimelineWidth, greaterThan(initialTimelineWidth));
    final divider = find.byKey(const ValueKey('practice-media-split-divider'));
    await tester.tap(divider);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(divider);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('trim-clip-column'))).width,
      closeTo(400, 1),
    );
    expect(
      ui.preferences.containsKey(MediaTrimSplitNotifier.storageKey),
      isFalse,
      reason: '双击恢复默认清除偏好',
    );
    // 回归：拖动中缩窄窗口，右栏不被挤到最小宽度以下；拖动中切到窄布局，
    // 分隔条被移除也按拖动结束保存，切回宽布局不残留拖动中的宽度。
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(300, 0));
    await tester.pump();
    await ui.resize(const Size(1000, 800));
    expect(
      tester.getSize(find.byKey(const ValueKey('trim-clip-column'))).width,
      greaterThanOrEqualTo(MediaTrimSplitGeometry.minClipColumnWidth - 0.5),
    );
    await ui.resize(const Size(390, 844));
    await gesture.up();
    final savedFraction = ui.preferences.getDouble(
      MediaTrimSplitNotifier.storageKey,
    );
    expect(savedFraction, isNotNull, reason: '分隔条被移除时保存拖动结果');
    await ui.resize(const Size(1280, 800));
    expect(
      tester.getSize(find.byKey(const ValueKey('trim-timeline-column'))).width,
      closeTo(
        MediaTrimSplitGeometry.resolveTimelineWidth(
          width: 1280,
          fraction: savedFraction,
        ),
        0.5,
      ),
    );
    await tester.tap(divider);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(divider);
    await tester.pumpAndSettle();
    await ui.tap(find.byKey(const ValueKey('trim-play')));
    await ui.settleAsync(const Duration(milliseconds: 800));
    await ui.tap(find.byKey(const ValueKey('trim-play')));
    await ui.captureVariants('video');
    await ui.dispose();
  });
}

const _uiSrt =
    '1\n00:00:01,250 --> 00:00:02,750\nHello world\n\n'
    '2\n00:00:03,250 --> 00:00:04,750\nGood morning\n';

/// 页面集成测试的操作封装：真实播放器与 FFmpeg 需要在 runAsync 中推进。
class _UiHarness {
  _UiHarness(this.tester, this.router, this.presentation, this.preferences);

  final WidgetTester tester;
  final GoRouter router;
  final ValueNotifier<(double, bool)> presentation;
  final SharedPreferences preferences;

  Future<void> settleAsync([
    Duration duration = const Duration(milliseconds: 100),
  ]) async {
    final end = DateTime.now().add(duration);
    do {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    } while (DateTime.now().isBefore(end));
  }

  Future<void> waitFor(Finder finder) async {
    for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
      await settleAsync();
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(Finder finder) async {
    await waitFor(finder);
    await tester.ensureVisible(finder.first);
    await settleAsync();
    await tester.tap(finder.first);
    await settleAsync(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  /// 发送快捷键。测试窗口失去前台时 App 进入 inactive，Flutter 会把焦点暂存到根节点，
  /// 快捷键就收不到（见 troubleshooting 7.56）；先恢复为 resumed，让焦点回到页面。
  Future<void> sendKey(LogicalKeyboardKey key) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  Future<void> resize(Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await settleAsync(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  Future<void> setTime(String key, String value) async {
    await tap(find.byKey(ValueKey(key)));
    await tester.enterText(
      find.byKey(const ValueKey('trim-time-input')),
      value,
    );
    await tap(find.byKey(const ValueKey('trim-dialog-confirm')));
  }

  Future<void> save(String collectionName) async {
    await tap(find.byKey(const ValueKey('trim-save')));
    await waitFor(find.byKey(const ValueKey('trim-new-collection')));
    await tester.enterText(
      find.byKey(const ValueKey('trim-new-collection')),
      collectionName,
    );
    await tap(find.byKey(const ValueKey('trim-confirm-save')));
    await waitFor(find.text('saved-collection'));
  }

  /// 手机 / 桌面、明 / 暗、150% 字号下各截一张，并检查布局无异常。
  Future<void> captureVariants(String prefix) async {
    for (final (size, dark, scale, name) in [
      (const Size(1280, 800), false, 1.0, 'desktop-light'),
      (const Size(1280, 800), true, 1.0, 'desktop-dark'),
      (const Size(390, 844), false, 1.0, 'phone-light'),
      (const Size(390, 844), true, 1.0, 'phone-dark'),
      (const Size(390, 844), false, 1.5, 'phone-large-text'),
      (const Size(844, 390), false, 1.0, 'phone-landscape'),
    ]) {
      presentation.value = (scale, dark);
      await resize(size);
      await capture('$prefix-$name');
    }
    presentation.value = (1.0, false);
    await resize(const Size(1280, 800));
  }

  Future<void> capture(String name) async {
    await settleAsync(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    if (!Platform.isMacOS) return;
    final captures = Directory(
      '${Directory.systemTemp.path}/media-trim-review-$pid',
    );
    await captures.create(recursive: true);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('trim-capture')),
    );
    final file = File('${captures.path}/$name.png');
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('MEDIA_TRIM_SCREENSHOT=${file.path}');
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await settleAsync(const Duration(milliseconds: 300));
    router.dispose();
    presentation.dispose();
    tester.view.reset();
  }
}
