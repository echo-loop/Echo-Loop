/// 字幕编辑器声音链路（media_kit）的真机 / 桌面集成测试。
///
/// 回归：iOS 上字幕编辑器原先用 just_audio（AVPlayer）出声，AVFoundation 不解封装
/// matroska，打开 mkv 视频即报「(-11828) 无法打开」，整页不可编辑。编辑器改为独占
/// 一个 media_kit 播放器后，mkv / avi 等容器也能直接试听。macOS 与 iOS 共用
/// AVFoundation，桌面上即可复现原问题。
///
/// 用 ffmpeg 合成带音轨的 mkv 与 avi，走真实数据库、真实 media_kit 播放器，验证：
/// - 编辑页加载成功、时长正确，不触达 just_audio 引擎；波形能提取；
/// - 句子 / 单词试听按原生终点结束，播放头停在句尾，倍速生效；
/// - 中途停止、切换句子按取消结束；视频画面也能加载；
/// - 离开页面释放播放器。
/// 结论依据关键日志（`[SubtitleEditorAudio]` / `[SubtitleEditor]`）断言。
///
/// 运行：flutter test integration_test/subtitle_editor_media_kit_audio_test.dart -d macos
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_simple_editor_screen.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/media_kit_player_backend.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../test/helpers/mock_providers.dart';
import '../test/helpers/test_app.dart';

const _audioTag = 'SubtitleEditorAudio';
const _mediaSeconds = 8;

/// 三句字幕，时间与合成音频对齐（单位毫秒）。
const _sentenceRanges = [(500, 3000), (3000, 5500), (5500, 7500)];
const _srt = '''1
00:00:00,500 --> 00:00:03,000
alpha bravo charlie

2
00:00:03,000 --> 00:00:05,500
delta echo foxtrot

3
00:00:05,500 --> 00:00:07,500
golf hotel india
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory appDir;
  late db.AppDatabase database;

  setUpAll(() async {
    if (Platform.isMacOS) {
      await windowManager.ensureInitialized();
      await windowManager.show();
      await windowManager.focus();
    }
  });

  tearDownAll(() async {
    if (Platform.isMacOS) await windowManager.hide();
  });

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('subtitle-editor-mk-');
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

  /// 合成 [_mediaSeconds] 秒的带音轨视频并入库（含字幕）。
  Future<AudioItem> seedVideo(String fileName, List<String> codecArgs) async {
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=320x240:rate=25:duration=$_mediaSeconds',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=$_mediaSeconds',
      ...codecArgs,
      '${appDir.path}/$fileName',
    ]);
    expect(
      ReturnCode.isSuccess(await session.getReturnCode()),
      isTrue,
      reason: await session.getOutput(),
    );
    final now = DateTime.now();
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: fileName,
            name: fileName,
            audioPath: Value(fileName),
            transcriptSrt: const Value(_srt),
            transcriptSource: Value(TranscriptSource.local.index),
            addedDate: now,
            updatedAt: now,
          ),
        );
    return createTestAudioItem(
      id: fileName,
      name: fileName,
      audioPath: fileName,
      transcriptPath: null,
      transcriptSource: TranscriptSource.local,
      totalDuration: _mediaSeconds,
    );
  }

  for (final (fileName, codecArgs) in [
    ('lesson.mkv', ['-c:v', 'mpeg4', '-c:a', 'aac']),
    ('lesson.avi', ['-c:v', 'mpeg4', '-c:a', 'pcm_s16le']),
  ]) {
    testWidgets('$fileName：编辑器经 media_kit 出声，句 / 词试听按句尾结束', (tester) async {
      final item = (await tester.runAsync(
        () => seedVideo(fileName, codecArgs),
      ))!;
      final h = _Harness(tester, item);
      SharedPreferences.setMockInitialValues({});
      final preferences = await tester.runAsync(SharedPreferences.getInstance);

      await tester.pumpWidget(
        createTestScreen(
          SubtitleSimpleEditorScreen(audioItem: item),
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            sharedPreferencesProvider.overrideWithValue(preferences!),
            mediaBackendFactoryProvider.overrideWithValue(() {
              final backend = MediaKitPlayerBackend();
              h.mediaBackends.add(backend);
              return backend;
            }),
          ],
        ),
      );
      await h.waitUntil(
        () => !h.state().isLoading,
        '编辑页应加载完成（原问题：iOS/macOS 上 AVPlayer 打不开 $fileName）',
      );

      // ── 加载：media_kit 打开容器、时长正确，未经 just_audio ──
      expect(h.state().errorMessage, isNull);
      expect(h.state().sentences, hasLength(3));
      final duration = h.state().totalDuration!;
      expect(
        (duration.inMilliseconds - _mediaSeconds * 1000).abs(),
        lessThan(300),
        reason: '时长应来自 media_kit 解析的媒体',
      );
      h.expectLog(_audioTag, '打开媒体 complete file=$fileName');
      h.expectLog('SubtitleEditor', '编辑页加载完成 audio=$fileName video=true');

      // ── 波形：经 FFmpeg 解码，不依赖系统解码器（ExtAudioFile 读不了 mkv/avi） ──
      await h.waitUntil(
        () => h.state().waveform != null || h.state().waveformFailed,
        '波形应提取结束',
      );
      expect(
        h.state().waveformFailed,
        isFalse,
        reason: '原问题：ExtAudioOpenURL error 1954115647，波形生成失败',
      );
      expect(
        (h.state().waveform!.duration.inMilliseconds - _mediaSeconds * 1000)
            .abs(),
        lessThan(300),
      );
      expect(
        AppLogger.instance.entries.where(
          (entry) =>
              entry.tag == 'AudioEngine' ||
              entry.tag == 'ForegroundAudioEngine',
        ),
        isEmpty,
        reason: '字幕编辑不应再经过 just_audio 引擎',
      );

      // ── 整句试听：播放中 → 播到句尾自动停，播放头停在句尾 ──
      final (secondStart, secondEnd) = _sentenceRanges[1];
      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
      await h.settle(const Duration(milliseconds: 800));
      expect(h.state().isPlaying, isTrue);
      expect(h.state().playingSentenceIndex, 1);
      await h.waitUntil(() => !h.state().isPlaying, '第二句应自然播完');
      expect(h.state().playbackPosition, Duration(milliseconds: secondEnd));
      h.expectRangeEnded(
        range: '$secondStart-${secondEnd}ms',
        expectedElapsedMs: secondEnd - secondStart,
      );

      // ── 单词试听：短区间同样由原生终点裁切 ──
      await tester.tap(find.byKey(const ValueKey('subtitle-word-label-0')));
      await h.settle();
      await h.waitUntil(() => !h.state().isPlaying, '单词应自然播完');
      final word = h.controller().wordsOfSelectedSentence.first;
      h.expectRangeEnded(
        range:
            '${word.startTime.inMilliseconds}-${word.endTime.inMilliseconds}ms',
        expectedElapsedMs: (word.endTime - word.startTime).inMilliseconds,
      );

      // ── 倍速：2x 播放第一句，用时约为一半 ──
      await h.controller().setPlaybackSpeed(2.0);
      final (firstStart, firstEnd) = _sentenceRanges[0];
      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-0')));
      await h.settle();
      await h.waitUntil(() => !h.state().isPlaying, '第一句 2x 应自然播完');
      h.expectRangeEnded(
        range: '$firstStart-${firstEnd}ms',
        expectedElapsedMs: (firstEnd - firstStart) ~/ 2,
      );
      await h.controller().setPlaybackSpeed(1.0);

      // ── 播放中切换句子：旧区间取消，新区间播完 ──
      final (thirdStart, thirdEnd) = _sentenceRanges[2];
      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-0')));
      await h.settle(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-2')));
      await h.settle(const Duration(milliseconds: 300));
      expect(h.state().playingSentenceIndex, 2);
      h.expectLog(_audioTag, 'reason=cancelled');
      await h.waitUntil(() => !h.state().isPlaying, '第三句应自然播完');
      h.expectRangeEnded(
        range: '$thirdStart-${thirdEnd}ms',
        expectedElapsedMs: thirdEnd - thirdStart,
      );

      // ── 中途停止：按取消结束，播放头停在停止处 ──
      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
      await h.settle(const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('subtitle-sentence-play-1')));
      await h.settle();
      expect(h.state().isPlaying, isFalse);
      final stoppedAt = h.state().playbackPosition;
      expect(stoppedAt, greaterThan(Duration(milliseconds: secondStart)));
      expect(stoppedAt, lessThan(Duration(milliseconds: secondEnd)));
      await h.settle(const Duration(milliseconds: 500));
      expect(h.state().playbackPosition, stoppedAt, reason: '停止后播放头不再移动');

      // ── 视频画面同样由 media_kit 打开 ──
      await tester.tap(
        find.byKey(const ValueKey('subtitle-editor-toggle-video')),
      );
      await h.waitUntil(
        () => AppLogger.instance.entries.any(
          (entry) =>
              entry.tag == 'SubtitleEditorVideo' &&
              entry.message.contains('视频画面已加载'),
        ),
        '视频画面应加载完成',
      );

      // ── 离开页面释放播放器 ──
      await tester.pumpWidget(const SizedBox.shrink());
      await h.waitUntil(
        () => AppLogger.instance.entries.any(
          (entry) => entry.tag == _audioTag && entry.message == '播放器已释放',
        ),
        '离开页面应释放声音播放器',
      );
      expect(tester.takeException(), isNull);
      h.dumpLogs();
    });
  }
}

class _Harness {
  _Harness(this.tester, this.item);

  final WidgetTester tester;
  final AudioItem item;

  /// 起播位置允许偏离区间起点的范围（定位精度）。
  static const _startToleranceMs = 100;

  /// 实际播放时长允许偏离区间时长的范围（事件上报延迟）。默认 0.2 秒输出
  /// 缓冲下句尾会被截掉约 200ms，超出此范围。
  static const _playedToleranceMs = 100;

  /// 编辑页创建的真实 media_kit 后端：先建声音播放器，显示画面后再建视频播放器。
  final List<MediaKitPlayerBackend> mediaBackends = [];

  ProviderContainer get _container => ProviderScope.containerOf(
    tester.element(find.byType(SubtitleSimpleEditorScreen)),
  );

  SubtitleEditorState state() =>
      _container.read(subtitleEditorControllerProvider(item));

  SubtitleEditorController controller() =>
      _container.read(subtitleEditorControllerProvider(item).notifier);

  /// 让真实异步（文件 IO、原生播放器事件、计时器）推进一段时间。
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

  void expectLog(String tag, String fragment) {
    expect(
      AppLogger.instance.entries.any(
        (entry) => entry.tag == tag && entry.message.contains(fragment),
      ),
      isTrue,
      reason: '应有日志 [$tag] …$fragment…',
    );
  }

  /// 按日志核对最近一次 [range] 区间自然播完：起播位置落在起点，从起播到停止
  /// 的实际播放时长接近理论值（句尾没有被截掉，也没有越过句尾）。
  void expectRangeEnded({
    required String range,
    required int expectedElapsedMs,
  }) {
    final entries = AppLogger.instance.entries
        .where((entry) => entry.tag == 'SubtitleEditorAudio')
        .toList();
    final request = entries.lastWhere(
      (entry) => entry.message.contains('range=$range'),
      orElse: () => fail('缺少区间播放请求日志 range=$range'),
    );
    final id = RegExp(r'id=(\d+)').firstMatch(request.message)!.group(1);
    final started = entries.lastWhere(
      (entry) => entry.message.startsWith('区间播放 started id=$id '),
      orElse: () => fail('缺少起播日志 id=$id'),
    );
    final result = entries.lastWhere(
      (entry) => entry.message.startsWith('区间播放 return id=$id '),
      orElse: () => fail('缺少区间播放结束日志 id=$id'),
    );
    int field(LogEntry entry, String name) => int.parse(
      RegExp('$name=(-?\\d+)ms').firstMatch(entry.message)!.group(1)!,
    );
    final summary = '${started.message} / ${result.message}';
    expect(
      result.message,
      matches(RegExp('reason=(paused|completed) ')),
      reason: '应自然播完而非被取消：$summary',
    );
    expect(
      (field(started, 'position') - field(started, 'targetStart')).abs(),
      lessThanOrEqualTo(_startToleranceMs),
      reason: '定位应落在区间起点：$summary',
    );
    final played = field(result, 'played');
    expect(
      (played - expectedElapsedMs).abs(),
      lessThanOrEqualTo(_playedToleranceMs),
      reason: '实际播放 ${played}ms 应接近区间时长 ${expectedElapsedMs}ms：$summary',
    );
  }

  void dumpLogs() {
    for (final entry in AppLogger.instance.entries) {
      if (entry.tag.startsWith('SubtitleEditor')) {
        // ignore: avoid_print
        print('SUBTITLE_EDITOR_LOG $entry');
      }
    }
  }
}
