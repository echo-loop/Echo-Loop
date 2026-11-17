/// 字幕编辑页 UI 与布局的 macOS 交互测试。
///
/// 用内置示例材料的真人语音与词级时间戳，配合 ffmpeg 生成带时间码画面的视频，
/// 走真实波形提取与 media_kit 画面链路，在手机竖屏 / 横屏、平板、桌面四种窗口与
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

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_waveform_view.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
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
import 'package:just_audio/just_audio.dart' as ja;
import 'package:window_manager/window_manager.dart';

import '../test/helpers/shared/test_fixtures.dart';
import '../test/helpers/test_app.dart';

const _captureKey = ValueKey('subtitle-editor-capture');
const _toggleVideoKey = ValueKey('subtitle-editor-toggle-video');
const _videoKey = ValueKey('subtitle-editor-video');
const _demoName = 'B1 - Work-life balance';

/// 按真实时长模拟区间播放的音频引擎：编辑器的播放态、播放头与画面跟随都依赖
/// 「播放持续一段时间后结束」，但测试不需要真的出声。
class _RealtimeAudioEngine extends AudioEngine {
  _RealtimeAudioEngine({required this.duration, required this.sentences});

  final Duration duration;
  final List<Sentence> sentences;
  final _positionController = StreamController<Duration>.broadcast();
  Completer<void>? _playback;
  int _sessionId = 0;
  double _speed = 1.0;

  @override
  AudioEngineState build() => AudioEngineState(totalDuration: duration);

  @override
  Stream<Duration> get absolutePositionStream => _positionController.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => _playback != null;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<Duration?> loadAudio(
    AudioItem item,
    double speed, {
    String? subtitle,
  }) async => duration;

  @override
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async => sentences;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) =>
      _play(sentence.endTime - sentence.startTime);

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) => _play(end - start);

  Future<void> _play(Duration length) async {
    _finish();
    final playback = Completer<void>();
    _playback = playback;
    final timer = Timer(length * (1 / _speed), _finish);
    await playback.future;
    timer.cancel();
  }

  void _finish() {
    final playback = _playback;
    _playback = null;
    if (playback != null && !playback.isCompleted) playback.complete();
  }

  @override
  Future<void> stopPlayback() async => _finish();

  @override
  Future<void> clearClip() async {}

  @override
  Future<void> setSpeed(double speed) async => _speed = speed;

  @override
  Future<void> seekToAbsolute(Duration absolute) async {}

  void close() {
    _finish();
    unawaited(_positionController.close());
  }
}

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
    await File('${appDir.path}/lesson.m4a')
        .writeAsBytes(audio.buffer.asUint8List());
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
              addedDate: now,
              updatedAt: now,
            ),
          );
    }
  }

  testWidgets('字幕编辑页在各窗口尺寸与明暗主题下的布局与交互', (tester) async {
    await tester.runAsync(seedMedia);
    final captures = Directory(
      '${Directory.systemTemp.path}/subtitle-editor-ui-$pid',
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

    late _RealtimeAudioEngine engine;
    late AudioItem item;

    Future<void> openEditor({
      required String id,
      required String path,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      engine = _RealtimeAudioEngine(
        duration: mediaDuration,
        sentences: sentences,
      );
      item = createTestAudioItem(
        id: id,
        name: _demoName,
        audioPath: path,
        transcriptPath: null,
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
              audioEngineProvider.overrideWith(() => engine),
            ],
          ),
        ),
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

    SubtitleEditorState editorState() {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SubtitleSimpleEditorScreen)),
      );
      return container.read(subtitleEditorControllerProvider(item));
    }

    Future<void> closeEditor() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(const Duration(milliseconds: 300));
      engine.close();
    }

    addTearDown(tester.view.reset);

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
}
