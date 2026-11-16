import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/features/media_trim/media_trim_editor_controller.dart';
import 'package:echo_loop/features/media_trim/media_trim_exporter.dart';
import 'package:echo_loop/features/media_trim/media_trim_processor.dart';
import 'package:echo_loop/features/media_trim/media_trim_waveform_loader.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_waveform/just_waveform.dart';

import '../../helpers/shared/fake_media_player_backend.dart';

class _FakeProcessor extends MediaTrimProcessor {
  /// 测试可改成更长的材料，验证需要足够空白的场景。
  Duration duration = const Duration(seconds: 20);

  @override
  Future<MediaTrimSourceInfo> probe(String path) async =>
      MediaTrimSourceInfo(duration: duration);
}

/// 波形不是这里的测试对象：保持加载中，避免触达原生插件。
class _PendingWaveformLoader extends MediaTrimWaveformLoader {
  _PendingWaveformLoader() : super(const MediaTrimProcessor());

  @override
  Future<Waveform> load({
    required AudioItem source,
    required String mediaPath,
    required MediaTrimCancellation cancellation,
    required void Function(double progress) onProgress,
  }) => Completer<Waveform>().future;
}

Duration ms(int value) => Duration(milliseconds: value);

const _srt = '''1
00:00:02,000 --> 00:00:04,000
First sentence

2
00:00:06,000 --> 00:00:08,000
Second sentence

3
00:00:12,000 --> 00:00:14,000
Third sentence
''';

/// 每 2 秒一句，每句 1.5 秒、句间留 0.5 秒空白，用于验证自动找空白。
String _denseSrt(int count) {
  String time(int millis) {
    final seconds = (millis ~/ 1000).toString().padLeft(2, '0');
    final rest = (millis % 1000).toString().padLeft(3, '0');
    return '00:00:$seconds,$rest';
  }

  return [
    for (var i = 0; i < count; i++)
      '${i + 1}\n${time(i * 2000)} --> ${time(i * 2000 + 1500)}\nSentence ${i + 1}\n',
  ].join('\n');
}

void main() {
  late Directory directory;
  late db.AppDatabase database;
  late FakeMediaPlayerBackend player;
  late ProviderContainer container;
  late _FakeProcessor processor;

  Future<MediaTrimEditorController> open({
    required bool withSubtitles,
    String srt = _srt,
  }) async {
    final now = DateTime.now();
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: 'source',
            name: 'Source',
            audioPath: const Value('source.m4a'),
            transcriptSource: Value(withSubtitles ? 1 : null),
            transcriptSrt: Value(withSubtitles ? srt : null),
            addedDate: now,
            updatedAt: now,
          ),
        );
    final source = AudioItem(
      id: 'source',
      name: 'Source',
      audioPath: 'source.m4a',
      addedDate: now,
      transcriptSource: withSubtitles ? TranscriptSource.ai : null,
    );
    final provider = mediaTrimEditorProvider(source);
    container.listen(provider, (_, _) {});
    for (var i = 0; i < 100; i++) {
      if (container.read(provider).status != MediaTrimLoadStatus.loading) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(container.read(provider).status, MediaTrimLoadStatus.ready);
    return container.read(provider.notifier);
  }

  setUp(() async {
    processor = _FakeProcessor();
    directory = await Directory.systemTemp.createTemp('trim-editor-');
    appDataDirectoryOverride = directory;
    await File('${directory.path}/source.m4a').writeAsBytes([1]);
    database = db.AppDatabase(
      NativeDatabase.memory(setup: db.configureAppDatabaseConnection),
    );
    player = FakeMediaPlayerBackend()
      ..pauseDelay = const Duration(milliseconds: 10);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        mediaBackendFactoryProvider.overrideWithValue(() => player),
        mediaTrimProcessorProvider.overrideWithValue(processor),
        mediaTrimWaveformLoaderProvider.overrideWithValue(
          _PendingWaveformLoader(),
        ),
        mediaTrimPauseOtherPlaybackProvider.overrideWithValue(() async {}),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    appDataDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  test('切换片段后，过期的试听请求不能继续起播', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipInGap();
    final first = controller.state.selectedClipId!;
    controller.setEdgeTime(MediaTrimEdge.end, ms(10000));
    controller.addClipInGap();
    final second = controller.state.selectedClipId!;

    controller.selectClip(first);
    final stale = controller.toggleClipPreview(first);
    controller.selectClip(second);
    await stale;
    expect(player.playCalls, 0);

    await controller.toggleClipPreview(second);
    expect(player.playCalls, 1);
    expect(player.playbackEndCalls.last, ms(20000));
    expect(player.seekCalls.last, ms(10000));
  });

  test('试听片段期间保持试听目标，播放器先暂停再起播也不会丢失', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipInGap();
    final id = controller.state.selectedClipId!;
    await controller.toggleClipPreview(id);
    await Future<void>.delayed(Duration.zero);
    final state = controller.state;
    expect(state.isPlaying, isTrue);
    expect(
      state.preview,
      isA<MediaTrimClipPreview>().having((p) => p.clipId, 'clipId', id),
    );
    // 再次点同一片段即停止。
    await controller.toggleClipPreview(id);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.isPlaying, isFalse);
    expect(player.playCalls, 1);
  });

  test('页面销毁后，未完成的试听不能继续驱动播放器', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipInGap();
    player.closeStreamsOnDispose = false;
    final pending = controller.toggleClipPreview(
      controller.state.selectedClipId!,
    );
    container.dispose();
    await pending;
    expect(player.playCalls, 0);
    // 重新创建容器供 tearDown 释放。
    container = ProviderContainer();
  });

  test('选中片段后播放头钳在片段内；取消选中后恢复自由定位', () async {
    final controller = await open(withSubtitles: false);
    await controller.seek(ms(5000));
    controller.addClipInGap();
    final clip = controller.state.selectedClip!;
    expect((clip.start, clip.end), (ms(5000), ms(20000)));
    expect(controller.state.position, ms(5000));

    await controller.seek(ms(1000));
    expect(controller.state.position, ms(5000));
    await controller.seekBy(const Duration(seconds: -3));
    expect(controller.state.position, ms(5000));
    controller.scrub(ms(2000));
    controller.endScrub();
    expect(controller.state.position, ms(5000));

    controller.clearSelection();
    await controller.seek(ms(1000));
    expect(controller.state.position, ms(1000));
    expect(controller.state.selectedClipId, isNull);
  });

  test('试听片段：未移动播放头从起点播；手动移到片段内则从该处播；播完再播回到起点', () async {
    final controller = await open(withSubtitles: false);
    await controller.seek(ms(5000));
    controller.addClipInGap();
    final id = controller.state.selectedClipId!;
    controller.clearSelection();
    await controller.seek(ms(0));
    controller.selectClip(id);
    await controller.toggleClipPreview(id);
    expect(player.seekCalls.last, ms(5000), reason: '选中时播放头回到起点');
    await controller.pause();

    await controller.seek(ms(15000));
    await controller.togglePlayback();
    expect(player.seekCalls.last, ms(15000), reason: '从手动定位处继续');
    expect(player.playbackEndCalls.last, ms(20000), reason: '选中片段时以片段终点为界');
    await controller.pause();

    await controller.seek(ms(19900));
    await controller.toggleClipPreview(id);
    expect(player.seekCalls.last, ms(5000), reason: '已到末尾时从头播放');
  });

  test('调整一端后播放头停到该端；越过另一端时停在最短长度，不整段跳走', () async {
    final controller = await open(withSubtitles: false);
    await controller.seek(ms(5000));
    controller.addClipInGap();
    controller.stepEdge(MediaTrimEdge.end, -1);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.selectedClip!.end, ms(19900));
    expect(controller.state.position, ms(19900));

    controller.dragEdge(MediaTrimEdge.start, ms(19950));
    controller.endEdgeDrag(MediaTrimEdge.start);
    await Future<void>.delayed(Duration.zero);
    final clip = controller.state.selectedClip!;
    expect((clip.start, clip.end), (ms(19600), ms(19900)));
    expect(controller.state.position, ms(19600));
  });

  test('重复选中当前片段时请求时间轴重新显示它', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipInGap();
    final id = controller.state.selectedClipId!;
    final serial = controller.state.revealSerial;
    controller.selectClip(id);
    expect(controller.state.revealSerial, serial + 1);
  });

  test('有字幕：从点句定位处取整句建段，不足 10 秒向前补句；没有空白时失败', () async {
    final controller = await open(withSubtitles: true);
    final boundaries = controller.state.boundaries!;
    await controller.toggleSentencePreview(1);
    expect(controller.addClipInGap(), isTrue);
    final clip = controller.state.selectedClip!;
    // 第 2 句往后只有约 9 秒，不足 10 秒时向前补上第 1 句。
    expect((clip.start, clip.end), boundaries.rangeForSpans(0, 2));
    // 已没有空白。
    expect(controller.addClipInGap(), isFalse);
    expect(controller.state.clips, hasLength(1));
  });

  test('连续新建依次填充后面的空白，片段按起点排序', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipInGap();
    controller.setEdgeTime(MediaTrimEdge.end, ms(10000));
    expect(controller.addClipInGap(), isTrue);
    final clips = controller.state.clips;
    expect(clips, hasLength(2));
    expect((clips.last.start, clips.last.end), (ms(10000), ms(20000)));
    expect(controller.state.selectedClipId, clips.last.id);
    expect(controller.state.clipName(clips.first), 'Source · 01');
    expect(controller.addClipInGap(), isFalse);
  });

  test('有字幕：连续两次新片段在同一播放头处不重叠，第二次绕回前面的空白', () async {
    processor.duration = const Duration(seconds: 40);
    final controller = await open(withSubtitles: true, srt: _denseSrt(20));
    final boundaries = controller.state.boundaries!;
    // 第一段从 24 秒起到末尾，前面约 24 秒空白。
    await controller.seek(ms(24000));
    expect(controller.addClipInGap(), isTrue);
    final first = controller.state.selectedClip!;
    // 播放头仍在第一段内，第一段之后没有空白，应从前面的空白取段。
    await controller.seek(ms(28000));
    expect(controller.addClipInGap(), isTrue);
    final second = controller.state.selectedClip!;
    expect(second.end <= first.start, isTrue, reason: '新片段不能与第一段重叠');
    expect((second.start, second.end), boundaries.rangeForSpans(0, 11));
    expect(controller.state.clips, hasLength(2));
  });

  test('自动分段替换现有片段；删除选中片段后选中相邻片段', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipInGap();
    final count = controller.autoSplit(const Duration(seconds: 5));
    expect(count, 4);
    final clips = controller.state.clips;
    expect(clips.first.start, Duration.zero);
    expect(clips.last.end, ms(20000));

    controller.selectClip(clips[3].id);
    controller.removeClip(clips[3].id);
    expect(controller.state.clips, hasLength(3));
    expect(controller.state.selectedClipId, clips[2].id);
    expect(controller.state.isDirty, isTrue);
  });

  test('重命名为空或默认名时恢复自动命名', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipInGap();
    final id = controller.state.selectedClipId!;
    controller.renameClip(id, '  Intro  ');
    expect(controller.state.clipName(controller.state.selectedClip!), 'Intro');
    controller.renameClip(id, '');
    expect(controller.state.selectedClip!.customName, isNull);
    expect(
      controller.state.clipName(controller.state.selectedClip!),
      'Source · 01',
    );
  });

  test('手动输入时间：有字幕时吸附到句间，句内输入被吸附而不是报错', () async {
    final controller = await open(withSubtitles: true);
    controller.addClipInGap();
    final failure = controller.setEdgeTime(MediaTrimEdge.end, ms(7000));
    expect(failure, isNull);
    final boundaries = controller.state.boundaries!;
    expect(controller.state.selectedClip!.end, boundaries.endAt(1));
    expect(
      controller.setEdgeTime(MediaTrimEdge.end, ms(30000)),
      MediaTrimFailure.clipOutOfRange,
    );
  });

  test('原材料声明有字幕但内容缺失时加载失败，不当作无字幕', () async {
    final now = DateTime.now();
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: 'broken',
            name: 'Broken',
            audioPath: const Value('source.m4a'),
            transcriptSource: const Value(1),
            addedDate: now,
            updatedAt: now,
          ),
        );
    final source = AudioItem(
      id: 'broken',
      name: 'Broken',
      audioPath: 'source.m4a',
      addedDate: now,
      transcriptSource: TranscriptSource.ai,
    );
    final provider = mediaTrimEditorProvider(source);
    container.listen(provider, (_, _) {});
    for (var i = 0; i < 100; i++) {
      if (container.read(provider).status != MediaTrimLoadStatus.loading) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(container.read(provider).status, MediaTrimLoadStatus.failed);
    expect(
      container.read(provider).loadFailure,
      MediaTrimFailure.transcriptNotReady,
    );
  });
}
