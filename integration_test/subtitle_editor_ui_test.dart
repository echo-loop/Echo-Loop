/// 字幕编辑页 UI 与布局的 macOS 交互测试。
///
/// 用内置示例材料的真人语音与词级时间戳，配合 ffmpeg 生成带时间码画面的视频，
/// 走真实波形提取与 media_kit 声音 / 画面链路，在手机竖屏 / 横屏、平板、桌面四种窗口与
/// 明暗主题下验证：
/// - 布局不溢出、关键控件（工具条、波形、句子列表）都在可视范围内；
/// - 视频材料画面默认收起，显示后上下（窄）或左右（宽）分栏，跟随试听播放；
/// - 音频材料不显示画面开关；
/// - 选句、点词浮层、句子菜单、播放态等交互照常工作。
///
/// 每个关键状态截图到临时目录（日志 SUBTITLE_EDITOR_SCREENSHOT=路径）。
///
/// 运行：flutter test integration_test/subtitle_editor_ui_test.dart -d macos
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_split_geometry.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_split_provider.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_waveform_view.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/favorite_sentence_lifecycle_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/media_kit_player_backend.dart';
import 'package:echo_loop/services/source_sentence_anchor.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/services/subtitle_parser.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../test/helpers/mock_providers.dart';
import '../test/helpers/test_app.dart';

const _captureKey = ValueKey('subtitle-editor-capture');
const _toggleVideoKey = ValueKey('subtitle-editor-toggle-video');
const _videoKey = ValueKey('subtitle-editor-video');
const _dividerKey = ValueKey('practice-media-split-divider');
const _demoName = 'B1 - Work-life balance';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory appDir;
  late db.AppDatabase database;
  late List<Sentence> sentences;
  late Duration mediaDuration;

  setUpAll(() async {
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
    appDir = await Directory.systemTemp.createTemp('subtitle-editor-ui-');
    appDataDirectoryOverride = appDir;
    database = db.AppDatabase(
      NativeDatabase.memory(setup: db.configureAppDatabaseConnection),
    );
    AppLogger.instance.clear();
  });

  tearDown(() async {
    await database.close();
    appDataDirectoryOverride = null;
    await appDir.delete(recursive: true);
  });

  /// 写入示例音频，并合成一段带时间码画面的同长视频。
  Future<void> seedMedia() async {
    final audio = await rootBundle.load('assets/demo/$_demoName.m4a');
    final source = File('${appDir.path}/source.m4a');
    await source.writeAsBytes(audio.buffer.asUint8List());
    // 示例音频在末句结束后只剩约 0.2 秒；补 1 秒静音，留出补句等用例需要的句尾空隙。
    final padded = await FFmpegKit.executeWithArguments([
      '-y',
      '-i',
      source.path,
      '-af',
      'apad=pad_dur=1',
      '-c:a',
      'aac',
      '${appDir.path}/lesson.m4a',
    ]);
    expect(
      ReturnCode.isSuccess(await padded.getReturnCode()),
      isTrue,
      reason: await padded.getOutput(),
    );
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=640x360:rate=25',
      '-i',
      '${appDir.path}/lesson.m4a',
      '-shortest',
      '-c:v',
      'mpeg4',
      '-q:v',
      '5',
      '-c:a',
      'copy',
      '${appDir.path}/lesson.mp4',
    ]);
    expect(
      ReturnCode.isSuccess(await session.getReturnCode()),
      isTrue,
      reason: await session.getOutput(),
    );
    final srt = await rootBundle.loadString('assets/demo/$_demoName.srt');
    sentences = await SubtitleParser.parseSubtitleString(srt);
    mediaDuration = sentences.last.endTime + const Duration(seconds: 1);
    final words = await rootBundle.loadString(
      'assets/demo/$_demoName.words.json',
    );
    final now = DateTime.now();
    for (final (id, path) in [
      ('lesson-video', 'lesson.mp4'),
      ('lesson-audio', 'lesson.m4a'),
    ]) {
      await database
          .into(database.audioItems)
          .insert(
            db.AudioItemsCompanion.insert(
              id: id,
              name: _demoName,
              audioPath: Value(path),
              wordTimestampsJson: Value(words),
              transcriptSrt: Value(srt),
              transcriptSource: Value(TranscriptSource.local.index),
              addedDate: now,
              updatedAt: now,
            ),
          );
    }
  }

  /// 准备示例材料并创建测试脚手架。
  Future<_EditorHarness> createHarness(WidgetTester tester) async {
    await tester.runAsync(seedMedia);
    final captures = Directory(
      '${Directory.systemTemp.path}/subtitle-editor-ui-$pid',
    );
    await captures.create(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final harness = _EditorHarness(
      tester: tester,
      captures: captures,
      database: database,
      preferences: await SharedPreferences.getInstance(),
      sentences: sentences,
      mediaDuration: mediaDuration,
    );
    addTearDown(tester.view.reset);
    return harness;
  }

  testWidgets('字幕编辑页在各窗口尺寸与明暗主题下的布局与交互', (tester) async {
    final h = await createHarness(tester);
    final settle = h.settle;
    final waitUntil = h.waitUntil;
    final capture = h.capture;
    final resize = h.resize;
    final expectEditorVisible = h.expectEditorVisible;
    final openEditor = h.openEditor;
    final editorState = h.editorState;
    final closeEditor = h.closeEditor;

    // ── 手机竖屏，视频材料：画面默认收起 ──
    const phone = Size(390, 844);
    await resize(phone);
    await openEditor(id: 'lesson-video', path: 'lesson.mp4');
    expect(find.byKey(_toggleVideoKey), findsOneWidget);
    expect(find.byKey(_videoKey), findsNothing);
    expectEditorVisible(phone);
    await capture('01-phone-light-initial');

    // 选中第二句：拆成单词 chip，波形居中到该句。
    await tester.tap(find.text(sentences[1].text));
    await settle();
    expect(editorState().selectedSentenceIndex, 1);
    expect(find.byKey(const ValueKey('subtitle-word-label-0')), findsOneWidget);
    await capture('02-phone-light-selected');

    // 点词弹出「编辑 / 前断句」浮层。
    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-2')));
    await settle();
    expect(
      find.byKey(const ValueKey('subtitle-word-split-button-2')),
      findsOneWidget,
    );
    await capture('03-phone-light-word-toolbar');
    await tester.tapAt(const Offset(200, 30));
    await settle();

    // 句子菜单。
    await tester.tap(find.byTooltip('Show menu').at(1));
    await settle();
    expect(find.text('Merge with next'), findsOneWidget);
    await capture('04-phone-light-menu');
    await tester.tapAt(const Offset(200, 30));
    await settle();

    // 播放第二句：行内按钮变停止，波形显示播放头。
    await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
    await settle(const Duration(milliseconds: 1200));
    expect(editorState().isPlaying, isTrue);
    await capture('05-phone-light-playing');
    await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
    await settle();
    expect(editorState().isPlaying, isFalse);

    // 显示画面：上下排布，画面加载后跟随播放。
    await tester.tap(find.byKey(_toggleVideoKey));
    await settle();
    expect(find.byKey(_videoKey), findsOneWidget);
    await waitUntil(
      () => AppLogger.instance.entries.any(
        (entry) =>
            entry.tag == 'SubtitleEditorVideo' && entry.message.contains('已加载'),
      ),
      '视频画面应加载完成',
    );
    expectEditorVisible(phone);
    await capture('06-phone-light-video');

    // ── 播放头 / 高亮单词 / 视频画面三者一致 ──
    final controller = h.editorController();
    final video = h.mediaBackends.last;
    void expectInSync(String moment, {required int toleranceMs}) {
      final state = editorState();
      final position = state.playbackPosition;
      final drift = (video.position - position).inMilliseconds.abs();
      expect(drift, lessThanOrEqualTo(toleranceMs), reason: '$moment：画面与播放头偏差');
      final highlighted = controller.highlightedWordIndex;
      if (highlighted != null && state.focusedWordIndex == null) {
        final word = controller.wordsOfSelectedSentence[highlighted];
        expect(
          position >= word.startTime && position < word.endTime,
          isTrue,
          reason: '$moment：高亮的词应包含播放头',
        );
      }
    }

    // 在底部时间轴行轻点定位（波形上点到当前句的词是试听），再按住顶部播放头手柄往左拖。
    final waveRect = tester.getRect(find.byType(SubtitleWaveformView));
    final tapX = waveRect.left + waveRect.width * .6;
    await tester.tapAt(
      Offset(tapX, waveRect.bottom - SubtitleWaveformView.axisHeight / 2),
    );
    await settle(const Duration(milliseconds: 600));
    final tapped = editorState().playbackPosition;
    final playheadDrag = await tester.startGesture(
      Offset(tapX, waveRect.top + 9),
    );
    for (var i = 0; i < 6; i++) {
      await playheadDrag.moveBy(const Offset(-15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await playheadDrag.up();
    await settle(const Duration(milliseconds: 800));
    expect(
      editorState().playbackPosition,
      lessThan(tapped),
      reason: '拖动播放头应向前定位',
    );
    expect(controller.highlightedWordIndex, isNotNull, reason: '播放头落在词上时应高亮该词');
    expectInSync('拖动播放头后', toleranceMs: 50);
    await capture('06b-phone-light-playhead-scrubbed');

    // 播放中画面跟随，停止后三者回到同一时刻。
    final playIndex = editorState().selectedSentenceIndex!;
    await tester.tap(find.byKey(ValueKey('subtitle-sentence-play-$playIndex')));
    await settle(const Duration(milliseconds: 1500));
    expect(editorState().isPlaying, isTrue);
    expectInSync('播放中', toleranceMs: 250);
    await capture('06c-phone-light-playing-karaoke');
    await tester.tap(find.byKey(ValueKey('subtitle-sentence-play-$playIndex')));
    await settle(const Duration(milliseconds: 800));
    expectInSync('停止后', toleranceMs: 50);
    await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-2')));
    await settle(const Duration(milliseconds: 1500));
    await capture('07-phone-light-video-playing');
    await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-2')));
    await settle();

    // ── 平板竖屏：仍上下排布 ──
    const tablet = Size(820, 1180);
    await resize(tablet);
    expectEditorVisible(tablet);
    await capture('08-tablet-light-video');

    // ── 桌面：显示画面时左右分栏，收起后单栏并限制阅读宽度 ──
    const desktop = Size(1280, 800);
    await resize(desktop);
    expectEditorVisible(desktop);
    final videoRect = tester.getRect(find.byKey(_videoKey));
    final listRowRect = tester.getRect(
      find.byKey(const ValueKey('subtitle-sentence-play-0')),
    );
    expect(listRowRect.left, greaterThan(videoRect.right), reason: '宽屏应左右分栏');
    await capture('09-desktop-light-video');

    double? savedFraction() => ProviderScope.containerOf(
      tester.element(find.byType(SubtitleSimpleEditorScreen)),
    ).read(subtitleEditorSplitProvider);
    double listLeft() => tester
        .getRect(find.byKey(const ValueKey('subtitle-sentence-play-0')))
        .left;

    // 默认宽度让画面尽量填满左栏高度；画面受右栏最小阅读宽度限制时，
    // 波形保持固定高度，底部只留少量空白。
    final autoListLeft = listLeft();
    final waveformBottom = tester
        .getRect(find.byType(SubtitleWaveformView))
        .bottom;
    expect(desktop.height - waveformBottom, lessThan(120), reason: '左栏不应留大片空白');

    // 拖动分隔条向左：画面变小、句子列表变宽，并记住比例。
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(_dividerKey)),
    );
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await settle();
    expect(listLeft(), lessThan(autoListLeft - 150));
    expect(savedFraction(), isNotNull);
    await capture('09b-desktop-light-video-dragged');

    // 双击分隔条恢复自动适配。
    await tester.tap(find.byKey(_dividerKey));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byKey(_dividerKey));
    await settle(const Duration(milliseconds: 500));
    expect(savedFraction(), isNull);
    expect(listLeft(), moreOrLessEquals(autoListLeft, epsilon: 1));

    // 回归：拖动中缩窄窗口，句子列表不被挤到最小宽度以下；拖动中切到上下布局，
    // 分隔条被移除也按拖动结束保存，切回左右布局不残留拖动中的宽度。
    final resizeDrag = await tester.startGesture(
      tester.getCenter(find.byKey(_dividerKey)),
    );
    for (var i = 0; i < 10; i++) {
      await resizeDrag.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    const narrowDesktop = Size(1000, 800);
    await resize(narrowDesktop);
    final narrowListLeft = listLeft();
    expect(
      narrowDesktop.width - tester.getRect(find.byKey(_dividerKey)).right,
      greaterThanOrEqualTo(SubtitleEditorSplitGeometry.minSentenceColumnWidth),
    );
    await resize(phone);
    await resizeDrag.up();
    expect(savedFraction(), isNotNull, reason: '分隔条被移除时保存拖动结果');
    await resize(desktop);
    final restoredListLeft = listLeft();
    await tester.tap(find.byKey(_dividerKey));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byKey(_dividerKey));
    await settle(const Duration(milliseconds: 500));
    expect(savedFraction(), isNull);
    // 残留的拖动宽度是窄窗口下的像素值，切回宽窗口会与窄窗口时几乎一样；
    // 按比例恢复则左栏随窗口变宽。
    expect(
      restoredListLeft,
      greaterThan(narrowListLeft + 100),
      reason: '切回左右布局按保存的比例，而不是残留的拖动宽度',
    );

    // 高窗口：画面受宽度限制（右栏保留舒适阅读宽度）无法再大时，布局不溢出。
    const tallDesktop = Size(1180, 920);
    await resize(tallDesktop);
    expectEditorVisible(tallDesktop);
    final tallWaveform = tester.getRect(find.byType(SubtitleWaveformView));
    // 波形固定高度，不随窗口加高；画面受宽度限制时多余空间留在底部。
    expect(
      tallWaveform.height,
      moreOrLessEquals(SubtitleWaveformView.height, epsilon: 1),
    );
    await capture('09c-tall-desktop-light-video');
    await resize(desktop);
    await tester.tap(find.byKey(_toggleVideoKey));
    await settle();
    expect(find.byKey(_videoKey), findsNothing);
    expectEditorVisible(desktop);
    await capture('10-desktop-light-no-video');

    // ── 手机横屏：显示画面时左右分栏，所有控件可达 ──
    const landscape = Size(844, 390);
    await resize(landscape);
    expectEditorVisible(landscape);
    await capture('11-landscape-light-no-video');
    await tester.tap(find.byKey(_toggleVideoKey));
    await settle(const Duration(milliseconds: 800));
    expectEditorVisible(landscape);
    await capture('12-landscape-light-video');
    await closeEditor();

    // ── 暗色主题 ──
    await resize(phone);
    await openEditor(
      id: 'lesson-video',
      path: 'lesson.mp4',
      themeMode: ThemeMode.dark,
    );
    await tester.tap(find.text(sentences[1].text));
    await settle();
    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-1')));
    await settle(const Duration(milliseconds: 600));
    await capture('13-phone-dark-selected');
    await tester.tapAt(const Offset(200, 30));
    await settle();
    await tester.tap(find.byKey(_toggleVideoKey));
    await settle(const Duration(milliseconds: 1500));
    await capture('14-phone-dark-video');
    await resize(desktop);
    await capture('15-desktop-dark-video');
    await closeEditor();

    // ── 音频材料：不显示画面开关 ──
    await resize(phone);
    await openEditor(id: 'lesson-audio', path: 'lesson.m4a');
    expect(find.byKey(_toggleVideoKey), findsNothing);
    await capture('16-phone-light-audio');
    await closeEditor();
  });

  testWidgets('波形：播放头手柄、句子主题色与逐词单词块', (tester) async {
    final h = await createHarness(tester);
    final settle = h.settle;
    final capture = h.capture;
    final editorState = h.editorState;

    final waveformFinder = find.byType(SubtitleWaveformView);

    /// 波形层当前的视图偏移（从 painter 读取，与绘制同源）。
    double viewOffset() {
      for (final cp in tester.widgetList<CustomPaint>(
        find.descendant(of: waveformFinder, matching: find.byType(CustomPaint)),
      )) {
        final painter = cp.painter;
        if (painter.runtimeType.toString() == '_WaveformLayerPainter') {
          return (painter as dynamic).viewOffset as double;
        }
      }
      fail('找不到波形层 painter');
    }

    /// 时间点在屏幕上的横坐标（与波形绘制用同一套坐标换算）。
    double screenXOf(Duration time) {
      final rect = tester.getRect(waveformFinder);
      final state = editorState();
      final metrics = WaveformMetrics(
        viewport: rect.width,
        zoom: state.waveformZoomScale,
        duration: state.totalDuration!,
        padding: SubtitleWaveformView.horizontalPadding,
      );
      return rect.left + metrics.screenX(time, viewOffset());
    }

    Color numberColor(int index) => tester
        .widget<Text>(find.byKey(ValueKey('subtitle-sentence-number-$index')))
        .style!
        .color!;

    Future<void> exercise({
      required Size size,
      required ThemeMode themeMode,
      required String tag,
    }) async {
      await h.resize(size);
      await h.openEditor(
        id: 'lesson-audio',
        path: 'lesson.m4a',
        themeMode: themeMode,
      );
      final controller = h.editorController();

      // 相邻句编号颜色两两不同（三色轮换）。
      expect(numberColor(0), isNot(numberColor(1)));
      expect(numberColor(1), isNot(numberColor(2)));
      expect(numberColor(0), isNot(numberColor(2)));
      await capture('w01-$tag-unselected');

      // 选中第二句：播放头停在句首，与句首边界重合。
      await tester.tap(find.text(sentences[1].text));
      await settle(const Duration(milliseconds: 600));
      final sentenceStart = editorState().sentences[1].startTime;
      expect(editorState().playbackPosition, sentenceStart);
      await capture('w02-$tag-selected-words');

      final waveRect = tester.getRect(waveformFinder);
      final laneY = waveRect.top + 9;
      final words = controller.wordsOfSelectedSentence;
      expect(words.length, greaterThan(2));

      // 轻点第三个词的单词块：只试听该词，播放头停在原处，视图不滚动。
      final offsetBefore = viewOffset();
      final word = words[2];
      final wordCenterX =
          (screenXOf(word.startTime) + screenXOf(word.endTime)) / 2;
      final modes = <SubtitleEditorPlaybackMode>[];
      final modeListener = controller.addListener(
        (state) => modes.add(state.playbackMode),
        fireImmediately: false,
      );
      await tester.tapAt(Offset(wordCenterX, laneY));
      await settle(const Duration(milliseconds: 150));
      // 短词可能在 150ms 内播完，按记录到的模式变化判断，不依赖时机。
      expect(modes, contains(SubtitleEditorPlaybackMode.wordAudition));
      expect(modes, isNot(contains(SubtitleEditorPlaybackMode.word)));
      expect(editorState().focusedWordIndex, 2);
      expect(editorState().playbackPosition, sentenceStart);
      await capture('w03-$tag-word-playing');
      await settle(const Duration(milliseconds: 1200));
      expect(editorState().isPlaying, isFalse);
      expect(editorState().playbackPosition, sentenceStart, reason: '播放头不动');
      modeListener();
      expect(viewOffset(), moreOrLessEquals(offsetBefore, epsilon: .5));

      // 重新选句，让播放头回到句首（与句首边界重合）。
      controller.selectSentence(1);
      await settle(const Duration(milliseconds: 400));
      final startX = screenXOf(sentenceStart);

      // 从线身按住拖动：抓的是句首边界，播放头不动。
      final boundaryDrag = await tester.startGesture(
        Offset(startX, waveRect.top + 40),
      );
      for (var i = 0; i < 3; i++) {
        await boundaryDrag.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await boundaryDrag.up();
      await settle();
      expect(
        editorState().sentences[1].startTime,
        greaterThan(sentenceStart),
        reason: '线身与播放头重叠时应拖动句首边界',
      );
      expect(editorState().playbackPosition, sentenceStart);
      controller.undo();
      await settle();
      expect(editorState().sentences[1].startTime, sentenceStart);

      // 从顶部手柄按住拖动：拖的是播放头，句首边界不动。
      final playheadDrag = await tester.startGesture(Offset(startX, laneY));
      for (var i = 0; i < 4; i++) {
        await playheadDrag.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await capture('w04-$tag-playhead-dragging');
      await playheadDrag.up();
      await settle();
      expect(editorState().playbackPosition, greaterThan(sentenceStart));
      expect(editorState().sentences[1].startTime, sentenceStart);
      expect(editorState().canUndo, isFalse, reason: '拖动播放头不应产生编辑');

      // 放大后逐词单词块显示完整单词。
      controller.setWaveformZoomScale(editorState().waveformZoomScale * 2.5);
      controller.selectSentence(1);
      await settle(const Duration(milliseconds: 400));
      await capture('w05-$tag-zoomed-words');
      await h.closeEditor();
    }

    await exercise(
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
      tag: 'phone-light',
    );
    await exercise(
      size: const Size(1280, 800),
      themeMode: ThemeMode.light,
      tag: 'desktop-light',
    );
    await exercise(
      size: const Size(390, 844),
      themeMode: ThemeMode.dark,
      tag: 'phone-dark',
    );
  });

  testWidgets('字幕编辑：插词、整句改字、补句、撤销 / 重做与桌面快捷键', (tester) async {
    final h = await createHarness(tester);
    const phone = Size(390, 844);
    const desktop = Size(1280, 800);
    final editorState = h.editorState;
    String textOf(int index) => editorState().sentences[index].text;

    Future<void> pressShortcut(
      LogicalKeyboardKey key, {
      bool meta = false,
      bool shift = false,
    }) async {
      if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await h.settle();
    }

    bool isTyping() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;

    /// 单词浮层完整落在窗口内（首尾词也不被裁掉）。
    void expectToolbarInside(Size size, int wordIndex) {
      final edit = tester.getRect(
        find.byKey(ValueKey('subtitle-word-edit-button-$wordIndex')),
      );
      final delete = tester.getRect(
        find.byKey(ValueKey('subtitle-word-delete-button-$wordIndex')),
      );
      expect(edit.left, greaterThanOrEqualTo(0), reason: '浮层左缘越界');
      expect(delete.right, lessThanOrEqualTo(size.width), reason: '浮层右缘越界');
    }

    // ── 手机：点词浮层的插词 / 删除 ──
    await h.resize(phone);
    await h.openEditor(id: 'lesson-audio', path: 'lesson.m4a');
    expect(find.byKey(const ValueKey('subtitle-editor-undo')), findsOneWidget);
    expect(editorState().canUndo, isFalse);
    await h.capture('20-phone-undo-redo-disabled');

    await tester.tap(find.text(h.sentences[1].text));
    await h.settle();
    final originalText = textOf(1);
    final tokens = originalText.split(' ');

    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-2')));
    await h.settle();
    expectToolbarInside(phone, 2);
    await h.capture('21-phone-word-toolbar');

    // 首词与末词的浮层也不应越出屏幕。
    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-0')));
    await h.settle();
    expectToolbarInside(phone, 0);
    final lastWord = tokens.length - 1;
    await tester.tap(find.byKey(ValueKey('subtitle-word-label-$lastWord')));
    await h.settle();
    expectToolbarInside(phone, lastWord);
    await h.capture('22-phone-word-toolbar-last');

    // 在第 3 个词后插词：输入框出现并已获得焦点。
    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-2')));
    await h.settle();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-insert-after-2')),
    );
    await h.settle();
    expect(find.byKey(const ValueKey('subtitle-word-insert-field')), findsOne);
    expect(isTyping(), isTrue, reason: '插词输入框应自动获得焦点');
    await tester.enterText(
      find.byKey(const ValueKey('subtitle-word-insert-field')),
      'really',
    );
    await h.capture('23-phone-word-inserting');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.settle();
    final inserted = [...tokens]..insert(3, 'really');
    expect(textOf(1), inserted.join(' '));
    expect(editorState().canUndo, isTrue);
    expect(editorState().isDirty, isTrue);
    await h.capture('24-phone-word-inserted');

    // ── 整句改文字：未改动的词保留原时间 ──
    final wordsBefore = h.editorController().wordsOfSelectedSentence;
    await tester.tap(
      find.byKey(const ValueKey('subtitle-sentence-edit-text-1')),
    );
    await h.settle();
    final sentenceField = find.descendant(
      of: find.byKey(const ValueKey('subtitle-sentence-text-field-1')),
      matching: find.byType(TextField),
    );
    expect(sentenceField, findsOne);
    expect(isTyping(), isTrue, reason: '整句输入框应自动获得焦点');
    await h.capture('25-phone-sentence-editing');
    final edited = [...inserted]..[0] = 'Honestly,';
    await tester.enterText(sentenceField, edited.join(' '));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.settle();
    expect(textOf(1), edited.join(' '));
    final wordsAfter = h.editorController().wordsOfSelectedSentence;
    expect(wordsAfter.last.startTime, wordsBefore.last.startTime);
    expect(wordsAfter[2].endTime, wordsBefore[2].endTime);

    // ── 撤销两步回到原文且不再是已修改；重做一步 ──
    await tester.tap(find.byKey(const ValueKey('subtitle-editor-undo')));
    await h.settle();
    expect(textOf(1), inserted.join(' '));
    await tester.tap(find.byKey(const ValueKey('subtitle-editor-undo')));
    await h.settle();
    expect(textOf(1), originalText);
    expect(editorState().isDirty, isFalse);
    expect(editorState().canUndo, isFalse);
    await tester.tap(find.byKey(const ValueKey('subtitle-editor-redo')));
    await h.settle();
    expect(textOf(1), inserted.join(' '));
    await h.capture('26-phone-after-undo-redo');

    // ── 补句：播放头点到句间空隙，波形上出现「添加句子」 ──
    final sentences = editorState().sentences;
    final total = editorState().totalDuration!;
    Duration? gapCenter;
    var gapNeighbor = 0;
    for (var i = 0; i <= sentences.length; i++) {
      final gapStart = i == 0 ? Duration.zero : sentences[i - 1].endTime;
      final gapEnd = i == sentences.length ? total : sentences[i].startTime;
      if (gapEnd - gapStart >= const Duration(milliseconds: 600)) {
        gapCenter = gapStart + (gapEnd - gapStart) ~/ 2;
        gapNeighbor = i == sentences.length ? i - 1 : i;
        break;
      }
    }
    expect(gapCenter, isNotNull, reason: '示例材料应至少有一处句间空隙');
    final addButton = find.byKey(
      const ValueKey('subtitle-waveform-insert-sentence'),
    );

    /// 像用户一样：先选中空隙旁的句子让波形滚到那里，再把播放头点进空隙。
    /// 长句居中后空隙仍可能在视口外，此时缩小波形。
    Future<void> placePlayheadInGap() async {
      h.editorController().selectSentence(gapNeighbor);
      await h.settle(const Duration(milliseconds: 400));
      h.editorController().scrubTo(gapCenter!);
      await h.settle(const Duration(milliseconds: 400));
      if (addButton.evaluate().isEmpty) {
        h.editorController().setWaveformZoomScale(
          editorState().waveformZoomScale / 3,
        );
        await h.settle(const Duration(milliseconds: 400));
      }
    }

    await placePlayheadInGap();
    expect(addButton, findsOne);
    await h.capture('27-phone-waveform-gap');

    final countBefore = sentences.length;
    await tester.tap(addButton);
    await h.settle(const Duration(milliseconds: 500));
    String editorLogs() => AppLogger.instance.entries
        .where((e) => e.tag == 'SubtitleEditor')
        .map((e) => e.message)
        .join(' | ');
    final draftField = find.descendant(
      of: find.byKey(const ValueKey('subtitle-new-sentence-field')),
      matching: find.byType(TextField),
    );
    expect(draftField, findsOne, reason: '日志：${editorLogs()}');
    expect(isTyping(), isTrue, reason: '新句输入框应自动获得焦点');
    expect(editorState().sentences.length, countBefore, reason: '确认前不插入');
    // ignore: avoid_print
    print('SUBTITLE_EDITOR_LOG ${editorLogs()}');
    await h.capture('28-phone-new-sentence-draft');
    await tester.enterText(draftField, 'This line was missing.');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.settle(const Duration(milliseconds: 500));
    expect(editorState().sentences.length, countBefore + 1);
    final newIndex = editorState().selectedSentenceIndex!;
    expect(textOf(newIndex), 'This line was missing.');
    final newSentence = editorState().sentences[newIndex];
    expect(newSentence.startTime, lessThanOrEqualTo(gapCenter!));
    expect(newSentence.endTime, greaterThanOrEqualTo(gapCenter));
    await h.capture('29-phone-new-sentence-inserted');

    // 句子菜单：编辑文字、上下插入、合并上一句 / 下一句、删除。
    await tester.tap(find.byTooltip('Show menu').at(newIndex));
    await h.settle();
    // 菜单项 + 选中行右下角的入口。
    expect(find.text('Edit text'), findsNWidgets(2));
    expect(find.text('Insert sentence above'), findsOne);
    expect(find.text('Merge with previous'), findsOne);
    await h.capture('30-phone-sentence-menu');
    await tester.tapAt(const Offset(200, 30));
    await h.settle();
    await h.closeEditor();

    // ── 桌面：键盘操作 ──
    await h.resize(desktop);
    await h.openEditor(id: 'lesson-audio', path: 'lesson.m4a');
    // 进入页面默认选中第一句。
    expect(editorState().selectedSentenceIndex, 0);

    await pressShortcut(LogicalKeyboardKey.arrowDown);
    expect(editorState().selectedSentenceIndex, 1);
    await pressShortcut(LogicalKeyboardKey.arrowDown);
    await pressShortcut(LogicalKeyboardKey.arrowUp);
    expect(editorState().selectedSentenceIndex, 1);

    // 回车打开整句编辑，Esc 放弃修改。
    final desktopOriginal = textOf(1);
    await pressShortcut(LogicalKeyboardKey.enter);
    final desktopField = find.descendant(
      of: find.byKey(const ValueKey('subtitle-sentence-text-field-1')),
      matching: find.byType(TextField),
    );
    expect(desktopField, findsOne);
    expect(isTyping(), isTrue);
    await tester.enterText(desktopField, 'Changed but cancelled');
    await h.capture('31-desktop-sentence-editing');
    await pressShortcut(LogicalKeyboardKey.escape);
    expect(desktopField, findsNothing);
    expect(textOf(1), desktopOriginal);
    expect(isTyping(), isFalse);

    // 输入框收起后快捷键仍然有效：删词后 ⌘Z / ⇧⌘Z。
    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-1')));
    await h.settle();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-delete-button-1')),
    );
    await h.settle();
    expect(textOf(1), isNot(desktopOriginal));
    await pressShortcut(LogicalKeyboardKey.keyZ, meta: true);
    expect(textOf(1), desktopOriginal);
    await pressShortcut(LogicalKeyboardKey.keyZ, meta: true, shift: true);
    expect(textOf(1), isNot(desktopOriginal));

    // 新句草稿按 Esc 放弃，不留空句。
    final desktopCount = editorState().sentences.length;
    await placePlayheadInGap();
    await tester.tap(addButton);
    await h.settle(const Duration(milliseconds: 500));
    expect(draftField, findsOne);
    // 焦点在下一帧才落到输入框；机器繁忙时先等它就绪再按 Esc。
    await h.waitUntil(isTyping, '新句输入框应获得焦点');
    await h.capture('32-desktop-new-sentence-draft');
    await pressShortcut(LogicalKeyboardKey.escape);
    expect(draftField, findsNothing);
    expect(editorState().sentences.length, desktopCount);

    // 再做几类会改结构 / 词时间的编辑后保存：插词、整句改字、补句。
    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-2')));
    await h.settle();
    await tester.tap(
      find.byKey(const ValueKey('subtitle-word-insert-before-2')),
    );
    await h.settle();
    await tester.enterText(
      find.byKey(const ValueKey('subtitle-word-insert-field')),
      'usually',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.settle();
    h.editorController().selectSentence(3);
    await h.settle();
    await pressShortcut(LogicalKeyboardKey.enter);
    final thirdField = find.descendant(
      of: find.byKey(const ValueKey('subtitle-sentence-text-field-3')),
      matching: find.byType(TextField),
    );
    final thirdText = textOf(3);
    await tester.enterText(thirdField, '$thirdText Right?');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.settle();
    expect(textOf(3), '$thirdText Right?');
    await placePlayheadInGap();
    await tester.tap(addButton);
    await h.settle(const Duration(milliseconds: 500));
    await tester.enterText(draftField, 'A brand new line.');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.settle();
    expect(editorState().sentences.length, desktopCount + 1);

    // ⌘S 保存。
    expect(editorState().isDirty, isTrue);
    await pressShortcut(LogicalKeyboardKey.keyS, meta: true);
    await h.waitUntil(() => !editorState().isDirty, '⌘S 应保存修改');
    await h.capture('33-desktop-saved');

    // 落库内容与编辑结果逐句、逐词一致。
    String sentenceKey(Sentence s) =>
        '${s.text}|${s.startTime.inMilliseconds}|${s.endTime.inMilliseconds}';
    String wordKey(WordTimestamp w) =>
        '${w.word}|${w.startTime.inMilliseconds}|${w.endTime.inMilliseconds}';
    final expectedSentences = editorState().sentences.map(sentenceKey).toList();
    final expectedWords = editorState().words.map(wordKey).toList();
    final dao = h.database.audioItemDao;
    final savedSrt = await tester.runAsync(
      () => dao.getTranscriptSrt('lesson-audio'),
    );
    final savedSentences = (await tester.runAsync(
      () => SubtitleParser.parseSubtitleString(savedSrt!),
    ))!;
    expect(savedSentences.map(sentenceKey).toList(), expectedSentences);
    final savedWordsJson = await tester.runAsync(
      () => dao.getWordTimestamps('lesson-audio'),
    );
    final savedWords = decodeWordTimestamps(savedWordsJson!)!;
    expect(savedWords.map(wordKey).toList(), expectedWords);
    final savedRow = (await tester.runAsync(
      () => dao.getById('lesson-audio'),
    ))!;
    expect(savedRow.sentenceCount, expectedSentences.length);
    expect(savedRow.wordCount, expectedWords.length);
    await h.closeEditor();

    // 重新打开：看到的就是保存的内容，且未修改、无撤销记录。
    await h.openEditor(id: 'lesson-audio', path: 'lesson.m4a');
    expect(
      editorState().sentences.map(sentenceKey).toList(),
      expectedSentences,
    );
    expect(editorState().words.map(wordKey).toList(), expectedWords);
    expect(editorState().isDirty, isFalse);
    expect(editorState().canUndo, isFalse);
    expect(find.text('A brand new line.'), findsOne);
    await h.capture('33b-desktop-reopened');
    await h.closeEditor();

    // ── 暗色：浮层与新句输入行 ──
    // 恢复示例字幕（上面保存的新句占掉了末尾空隙），暗色场景从同一份初始数据开始。
    final demoWords = await rootBundle.loadString(
      'assets/demo/$_demoName.words.json',
    );
    final demoSrt = await rootBundle.loadString('assets/demo/$_demoName.srt');
    await tester.runAsync(() async {
      await dao.updateTranscriptSrt('lesson-audio', demoSrt);
      await dao.updateWordTimestamps('lesson-audio', demoWords);
    });
    await h.resize(phone);
    await h.openEditor(
      id: 'lesson-audio',
      path: 'lesson.m4a',
      themeMode: ThemeMode.dark,
    );
    h.editorController().selectSentence(1);
    await h.settle();
    await tester.tap(find.byKey(const ValueKey('subtitle-word-label-2')));
    await h.settle();
    await h.capture('34-phone-dark-word-toolbar');
    await tester.tapAt(const Offset(200, 30));
    await h.settle();
    await placePlayheadInGap();
    await tester.tap(addButton);
    await h.settle(const Duration(milliseconds: 500));
    await h.capture('35-phone-dark-new-sentence-draft');
    await h.closeEditor();
  });

  testWidgets('保存字幕：收藏句、收藏词改写为新字幕中的句子，学习进度按时间保留', (tester) async {
    final h = await createHarness(tester);
    const desktop = Size(1280, 800);
    const audioId = 'lesson-audio';
    final original = h.sentences;
    final dao = database.audioItemDao;
    final demoSrt = await rootBundle.loadString('assets/demo/$_demoName.srt');

    // 独立容器写入学习数据：与编辑页共用同一个数据库，走真实收藏生命周期
    // （含 FSRS 调度）与学习进度持久化。
    final seed = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(h.preferences),
        analyticsOverride(),
        notificationPermissionOverride(),
        ...learningSettingsOverrides(prefs: h.preferences),
      ]),
    );
    addTearDown(seed.dispose);
    final savedWord = original[5].text.split(' ')[3].toLowerCase();
    await tester.runAsync(() async {
      await dao.updateTranscriptSrt(audioId, demoSrt);
      final lifecycle = seed.read(favoriteSentenceLifecycleProvider);
      for (final index in [1, 2, 3, 4]) {
        await lifecycle.save(audioId, original[index]);
      }
      await database.savedWordDao.saveWord(
        word: savedWord,
        audioItemId: audioId,
        sentenceText: original[5].text,
        sentenceStartMs: original[5].startTime.inMilliseconds,
        sentenceEndMs: original[5].endTime.inMilliseconds,
      );
      final progress = seed.read(learningProgressProvider.notifier);
      await progress.ensureProgress(audioId);
      await progress.saveBlindListenSentenceIndex(
        audioId,
        5,
        isFreePlay: false,
      );
      await progress.saveIntensiveListenSentenceIndex(
        audioId,
        4,
        isFreePlay: false,
      );
      await progress.saveShadowingSentenceIndex(audioId, 1, isFreePlay: false);
    });
    final progressBefore = (await tester.runAsync(
      () => database.learningProgressDao.getByAudioId(audioId),
    ))!;
    final subjectIds = (await tester.runAsync(
      () => database.bookmarkDao.getByAudioId(audioId),
    ))!.map((b) => b.memorySubjectId!).toSet();
    expect(subjectIds, hasLength(4));

    await h.resize(desktop);
    await h.openEditor(id: audioId, path: 'lesson.m4a');
    final controller = h.editorController();
    final editorState = h.editorState;

    // 原 S0..S5：拆分 S0、改 S1 的字、合并 S3+S4、删除 S2。
    controller.selectSentence(0);
    controller.splitSentenceAtWord(5);
    final fixedText = original[1].text.replaceFirst('9', 'nine');
    controller.editSentenceText(2, fixedText);
    controller.mergeWithNext(4);
    controller.deleteSentence(3);
    await h.settle();
    expect(editorState().sentences, hasLength(5));
    await h.capture('40-desktop-structure-edited');

    // ⌘S 保存：直接保存，不再弹出「会清除学习进度和收藏」的确认框。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await h.settle();
    expect(find.byType(AlertDialog), findsNothing);
    await h.waitUntil(() => !editorState().isDirty, '⌘S 应直接保存');
    expect(find.text('Subtitle changes saved.'), findsOneWidget);
    await h.capture('41-desktop-saved-without-confirm');

    final saved = (await tester.runAsync(() async {
      final srt = await dao.getTranscriptSrt(audioId);
      return SubtitleParser.parseSubtitleString(srt!);
    }))!;
    expect(saved.map((s) => s.text).toList(), [
      editorState().sentences[0].text,
      editorState().sentences[1].text,
      fixedText,
      '${original[3].text} ${original[4].text}',
      original[5].text,
    ]);

    // 收藏句：按区间定位后改写为新字幕中对应的句子（S1 → 改字后的 2，S3、S4 →
    // 合并句 3）；S2 已删除，保持原样且不计入句子收藏。
    final bookmarks = (await tester.runAsync(
      () => database.bookmarkDao.getByAudioId(audioId),
    ))!;
    expect(bookmarks, hasLength(4), reason: '收藏一条都不丢');
    expect(
      await tester.runAsync(
        () => database.bookmarkDao.getBookmarkedIndices(audioId),
      ),
      {2, 3},
    );
    String describe(String text, Duration start, Duration end) =>
        '$text@${start.inMilliseconds}-${end.inMilliseconds}';
    String describeSentence(Sentence s) =>
        describe(s.text, s.startTime, s.endTime);
    Duration ms(double seconds) =>
        Duration(milliseconds: (seconds * 1000).round());
    expect(
      [
        for (final b in bookmarks)
          describe(b.sentenceText, ms(b.startTime), ms(b.endTime)),
      ]..sort(),
      [
        describeSentence(saved[2]),
        describeSentence(saved[3]),
        describeSentence(saved[3]),
        describeSentence(original[2]),
      ]..sort(),
    );
    final schedules = (await tester.runAsync(
      () => (database.select(
        database.memorySchedules,
      )..where((t) => t.subjectId.isIn(subjectIds))).get(),
    ))!;
    expect(schedules.map((s) => s.status).toList(), List.filled(4, 'active'));

    // 收藏词：来源句改写为新字幕中对应的第 4 句（S5）。
    final words = (await tester.runAsync(
      () => database.savedWordDao.getByAudioId(audioId),
    ))!;
    expect(words.single.word, savedWord);
    expect(words.single.sentenceText, saved[4].text);
    expect(
      (words.single.sentenceStartMs, words.single.sentenceEndMs),
      (saved[4].startTime.inMilliseconds, saved[4].endTime.inMilliseconds),
    );
    expect(
      resolveSourceSentenceIndex(
        SourceSentenceAnchor.fromMilliseconds(
          startMs: words.single.sentenceStartMs,
          endMs: words.single.sentenceEndMs,
        ),
        saved,
      ),
      4,
    );

    // 学习进度：阶段不变，盲听 S5 → 4、精听 S4 → 合并句 3，难句跟读位置清除。
    final progressAfter = (await tester.runAsync(
      () => database.learningProgressDao.getByAudioId(audioId),
    ))!;
    expect(progressAfter.currentStage, progressBefore.currentStage);
    expect(progressAfter.currentSubStage, progressBefore.currentSubStage);
    expect(progressAfter.blindListenSentenceIndex, 4);
    expect(progressAfter.intensiveListenSentenceIndex, 3);
    expect(progressAfter.shadowingSentenceIndex, isNull);

    // 用编辑前的旧句子取消收藏（模拟仍持有旧列表的页面）：旧 S4 的旧编号 4 在新字幕
    // 中是 S5，但按时间它属于合并句 3；只取消合并句上的收藏（S3、S4 两条）。
    await tester.runAsync(
      () => seed
          .read(favoriteSentenceLifecycleProvider)
          .remove(audioId, original[4]),
    );
    expect(
      await tester.runAsync(
        () => database.bookmarkDao.getBookmarkedIndices(audioId),
      ),
      {2},
    );
    final activeAfterRemove = (await tester.runAsync(
      () => database.bookmarkDao.getByAudioId(audioId),
    ))!;
    expect(activeAfterRemove.map((b) => b.sentenceText).toSet(), {
      fixedText,
      original[2].text,
    }, reason: 'S1 与来源句已删除的 S2 不受影响');
    await h.closeEditor();

    // 重新打开：编辑结果即保存内容。
    await h.openEditor(id: audioId, path: 'lesson.m4a');
    expect(editorState().sentences.map((s) => s.text).toList()[2], fixedText);
    expect(editorState().isDirty, isFalse);
    await h.capture('42-desktop-reopened-after-sync');
    await h.closeEditor();
  });
}

/// 集成测试脚手架：等待、截图、调整窗口、打开 / 关闭编辑页。
class _EditorHarness {
  _EditorHarness({
    required this.tester,
    required this.captures,
    required this.database,
    required this.preferences,
    required this.sentences,
    required this.mediaDuration,
  });

  final WidgetTester tester;
  final Directory captures;
  final db.AppDatabase database;
  final SharedPreferences preferences;
  final List<Sentence> sentences;
  final Duration mediaDuration;
  late AudioItem item;

  /// 编辑页创建的真实 media_kit 后端：进入页面先建声音播放器，显示画面后再建
  /// 视频画面播放器（总在最后），用于核对画面位置与播放头一致。
  final List<MediaKitPlayerBackend> mediaBackends = [];

  /// 让真实异步（波形提取、文件 IO、计时器）推进一段时间。
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

  Future<void> waitUntil(bool Function() condition, String reason) async {
    for (var i = 0; i < 150 && !condition(); i++) {
      await settle(const Duration(milliseconds: 100));
    }
    expect(condition(), isTrue, reason: reason);
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
    print('SUBTITLE_EDITOR_SCREENSHOT=${file.path}');
  }

  Future<void> resize(Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await settle(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  /// 关键控件都在视口内，且句子列表至少露出一行。
  void expectEditorVisible(Size size) {
    final slider = tester.getRect(
      find.byKey(const ValueKey('subtitle-waveform-zoom-slider')),
    );
    final waveform = tester.getRect(find.byType(SubtitleWaveformView));
    expect(slider.bottom, lessThanOrEqualTo(size.height));
    expect(waveform.right, lessThanOrEqualTo(size.width));
    expect(
      tester
          .getRect(find.byKey(const ValueKey('subtitle-sentence-play-0')))
          .top,
      lessThan(size.height),
    );
  }

  Future<void> openEditor({
    required String id,
    required String path,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    // 字幕从库里读（种子数据写入示例字幕，保存后读到保存的版本），声音走真实 media_kit。
    item = createTestAudioItem(
      id: id,
      name: _demoName,
      audioPath: path,
      transcriptPath: null,
      transcriptSource: TranscriptSource.local,
      totalDuration: mediaDuration.inSeconds,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: item),
          themeMode: themeMode,
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            sharedPreferencesProvider.overrideWithValue(preferences),
            // 用真实素材库：保存时句数 / 词数经它写回数据库（默认测试替身不落库）。
            audioLibraryProvider.overrideWith(AudioLibrary.new),
            mediaBackendFactoryProvider.overrideWithValue(() {
              final backend = MediaKitPlayerBackend();
              mediaBackends.add(backend);
              return backend;
            }),
          ],
        ),
      ),
    );
    // 与应用启动一致先加载素材库：保存时句数 / 词数经素材库写回数据库。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SubtitleSimpleEditorScreen)),
    );
    await tester.runAsync(
      () => container.read(audioLibraryProvider.notifier).loadLibrary(),
    );
    await waitUntil(
      () => find
          .byKey(const ValueKey('subtitle-sentence-play-0'))
          .evaluate()
          .isNotEmpty,
      '句子列表应加载完成',
    );
    // 等待真实波形提取完成。
    await waitUntil(
      () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      '波形应提取完成',
    );
  }

  SubtitleEditorController editorController() {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SubtitleSimpleEditorScreen)),
    );
    return container.read(subtitleEditorControllerProvider(item).notifier);
  }

  SubtitleEditorState editorState() {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SubtitleSimpleEditorScreen)),
    );
    return container.read(subtitleEditorControllerProvider(item));
  }

  Future<void> closeEditor() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(const Duration(milliseconds: 300));
  }
}
