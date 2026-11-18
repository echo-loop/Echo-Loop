import 'dart:io';

import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/pause_other_playback_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:echo_loop/utils/srt_generator.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/shared/fake_media_player_backend.dart';

/// 记录每次起播区间的 fake backend；[completePlayback] 模拟原生终点到达。
class RangeRecordingBackend extends FakeMediaPlayerBackend {
  /// [completesImmediately] 为 true 时起播即播完，用于不关心播放过程的界面测试。
  RangeRecordingBackend(
    Duration duration, {
    this.completesImmediately = false,
  }) {
    setDuration(duration);
  }

  final bool completesImmediately;

  /// 每次起播时的（起点，原生终点）。
  final ranges = <(Duration, Duration?)>[];

  @override
  Future<void> play() async {
    ranges.add((position, playbackEnd));
    await super.play();
    if (completesImmediately) completePlayback();
  }

  /// 与 media_kit 一致：播到原生终点时先报自然结束，再报暂停。
  void completePlayback() {
    if (!playing) return;
    emitCompleted();
    emitPlaying(false);
  }
}

/// 字幕编辑器的播放依赖：独占播放器换成 [backend]，进入页面不去暂停真实播放链路。
List<Override> subtitleEditorPlaybackOverrides(
  FakeMediaPlayerBackend backend,
) => [
  mediaBackendFactoryProvider.overrideWithValue(() => backend),
  pauseOtherPlaybackProvider.overrideWithValue(() async {}),
];

/// 编辑器按材料路径打开媒体、在数据目录下缓存波形；测试改用临时目录，结束后清理。
Future<void> useTemporaryAppDataDirectory() async {
  final directory = await Directory.systemTemp.createTemp(
    'subtitle_editor_test',
  );
  appDataDirectoryOverride = directory;
  addTearDown(() async {
    appDataDirectoryOverride = null;
    if (directory.existsSync()) await directory.delete(recursive: true);
  });
}

/// 把句子序列化为 SRT，写入 fake DAO 作为编辑器读取的字幕。
String srtOf(List<Sentence> sentences) => generateSrtContent([
  for (final sentence in sentences)
    TranscriptSentence(
      text: sentence.text,
      startTime: sentence.startTime,
      endTime: sentence.endTime,
    ),
]);

/// 字幕从 DB 读取：未写入时按 [sentences] 当前内容生成 SRT，便于用例在加载前改句子。
class TranscriptAudioItemDao extends TestAudioItemDao {
  TranscriptAudioItemDao(this._sentences);

  final List<Sentence> Function() _sentences;

  @override
  Future<String?> getTranscriptSrt(String audioItemId) async =>
      transcriptSrtStore[audioItemId] ?? srtOf(_sentences());
}
