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
  @override
  Future<MediaTrimSourceInfo> probe(String path) async =>
      const MediaTrimSourceInfo(duration: Duration(seconds: 20));
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

void main() {
  late Directory directory;
  late db.AppDatabase database;
  late FakeMediaPlayerBackend player;
  late ProviderContainer container;

  Future<MediaTrimEditorController> open({required bool withSubtitles}) async {
    final now = DateTime.now();
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: 'source',
            name: 'Source',
            audioPath: const Value('source.m4a'),
            transcriptSource: Value(withSubtitles ? 1 : null),
            transcriptSrt: Value(withSubtitles ? _srt : null),
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
        mediaTrimProcessorProvider.overrideWithValue(_FakeProcessor()),
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
    controller.addClipAtPlayhead();
    final first = controller.state.selectedClipId!;
    await controller.seek(ms(10000));
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
    final id = controller.state.selectedClipId!;
    final serial = controller.state.revealSerial;
    controller.selectClip(id);
    expect(controller.state.revealSerial, serial + 1);
  });

  test('有字幕：点句试听定位后新建整句片段，结束端按整句推后', () async {
    final controller = await open(withSubtitles: true);
    final boundaries = controller.state.boundaries!;
    await controller.toggleSentencePreview(0);
    controller.addClipAtPlayhead();
    final firstId = controller.state.selectedClipId!;

    // 试听片段外的句子会让播放头离开选中片段，此时新建得到该句片段。
    await controller.toggleSentencePreview(1);
    controller.addClipAtPlayhead();
    var clip = controller.state.selectedClip!;
    expect(clip.id, isNot(firstId));
    expect((clip.start, clip.end), boundaries.rangeForSpans(1, 1));

    controller.stepEdge(MediaTrimEdge.end, 1);
    clip = controller.state.selectedClip!;
    expect((clip.start, clip.end), boundaries.rangeForSpans(1, 2));
    expect(clip.sentencesWithin(boundaries.sentences), hasLength(2));
  });

  test('在相同位置重复新建只选中已有片段，片段按起点排序', () async {
    final controller = await open(withSubtitles: true);
    await controller.seek(ms(12500));
    controller.addClipAtPlayhead();
    // 选中片段时播放头只在片段内，先取消选中再定位到别处。
    controller.clearSelection();
    await controller.seek(ms(0));
    controller.addClipAtPlayhead();
    controller.addClipAtPlayhead();
    final clips = controller.state.clips;
    expect(clips, hasLength(2));
    expect(clips.first.start < clips.last.start, isTrue);
    expect(controller.state.clipName(clips.first), 'Source · 01');
    expect(controller.state.selectedClipId, clips.first.id);
  });

  test('自动分段替换现有片段；删除选中片段后选中相邻片段', () async {
    final controller = await open(withSubtitles: false);
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
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
    controller.addClipAtPlayhead();
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
