import 'dart:async';
import 'dart:io';

import 'package:echo_loop/database/app_database.dart' show BookmarksCompanion;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path/path.dart' as p;

import '../../helpers/mock_providers.dart';

void main() {
  late _RecordingAudioEngine audioEngine;
  late ProviderContainer container;
  late ProviderSubscription<SubtitleEditorState> subscription;
  late AudioItem audioItem;
  late List<Sentence> sentences;

  setUp(() {
    audioItem = createTestAudioItem(totalDuration: 12);
    sentences = [
      Sentence(
        index: 0,
        text: 'First sentence.',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 4),
      ),
      Sentence(
        index: 1,
        text: 'Second sentence.',
        startTime: const Duration(seconds: 4),
        endTime: const Duration(seconds: 8),
      ),
      Sentence(
        index: 2,
        text: 'Third sentence.',
        startTime: const Duration(seconds: 8),
        endTime: const Duration(seconds: 12),
      ),
    ];
    audioEngine = _RecordingAudioEngine(
      duration: const Duration(seconds: 12),
      sentences: sentences,
    );
    container = ProviderContainer(
      overrides: [audioEngineProvider.overrideWith(() => audioEngine)],
    );
    subscription = container.listen(
      subtitleEditorControllerProvider(audioItem),
      (_, _) {},
      fireImmediately: true,
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
    audioEngine.disposeController();
  });

  SubtitleEditorController controller() {
    return container.read(subtitleEditorControllerProvider(audioItem).notifier);
  }

  SubtitleEditorState state() {
    return container.read(subtitleEditorControllerProvider(audioItem));
  }

  test('togglePlaybackFromPlayhead 从红线播放到音频末尾', () async {
    final notifier = controller();
    await notifier.load();
    notifier.scrubTo(const Duration(seconds: 5));
    await notifier.setPlaybackSpeed(1.25);

    final playback = notifier.togglePlaybackFromPlayhead();
    await Future<void>.delayed(Duration.zero);

    expect(audioEngine.lastSpeed, 1.25);
    expect(audioEngine.playRangeOnceCallCount, 1);
    expect(audioEngine.lastPlayStart, const Duration(seconds: 5));
    expect(audioEngine.lastPlayEnd, const Duration(seconds: 12));
    expect(state().isPlaying, isTrue);

    audioEngine.completePlayback();
    await playback;

    expect(state().isPlaying, isFalse);
    expect(state().playbackPosition, const Duration(seconds: 12));
    expect(audioEngine.clearClipCallCount, 2);
  });

  test('togglePlaybackFromPlayhead 播放中再次点击会暂停', () async {
    final notifier = controller();
    await notifier.load();
    notifier.scrubTo(const Duration(seconds: 3));

    final playback = notifier.togglePlaybackFromPlayhead();
    await Future<void>.delayed(Duration.zero);
    audioEngine.emitPosition(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);

    await notifier.togglePlaybackFromPlayhead();
    expect(audioEngine.stopPlaybackCallCount, 1);
    expect(state().isPlaying, isFalse);
    expect(state().playbackPosition, const Duration(seconds: 5));

    audioEngine.emitPosition(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(state().playbackPosition, const Duration(seconds: 5));

    audioEngine.completePlayback();
    await playback;
    expect(state().isPlaying, isFalse);
  });

  test('setPlaybackSpeed 播放中实时转发到底层音频引擎', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.togglePlaybackFromPlayhead();
    await Future<void>.delayed(Duration.zero);
    await notifier.setPlaybackSpeed(1.5);

    expect(state().playbackSpeed, 1.5);
    expect(audioEngine.speedCalls, contains(1.5));

    audioEngine.completePlayback();
    await playback;
  });

  test('scrubTo 和 finishScrub 更新播放头、选中句并 seek', () async {
    final notifier = controller();
    await notifier.load();

    notifier.scrubTo(const Duration(seconds: 6));
    expect(state().selectedSentenceIndex, 1);
    expect(state().playbackPosition, const Duration(seconds: 6));

    await notifier.finishScrub(const Duration(seconds: 20));
    expect(audioEngine.clearClipCallCount, 1);
    expect(audioEngine.lastSeekAbsolute, const Duration(seconds: 12));
    expect(state().playbackPosition, const Duration(seconds: 12));
  });

  test('playSentence 播完单句后清理 clip，避免后续 seek 仍落在旧句子', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.playSentence(0);
    await Future<void>.delayed(Duration.zero);
    audioEngine.completePlayback();
    await playback;

    expect(audioEngine.playClipOnceCallCount, 1);
    expect(audioEngine.clearClipCallCount, 2);
    expect(state().isPlaying, isFalse);
    expect(state().playingSentenceIndex, isNull);
  });

  test('playSentence 播放中切换句子会停止旧 session 并从新句句首开始', () async {
    final notifier = controller();
    await notifier.load();

    final firstPlayback = notifier.playSentence(0);
    await Future<void>.delayed(Duration.zero);
    expect(state().playingSentenceIndex, 0);
    expect(state().playbackPosition, Duration.zero);

    final secondPlayback = notifier.playSentence(1);
    await Future<void>.delayed(Duration.zero);

    expect(audioEngine.stopPlaybackCallCount, 1);
    expect(audioEngine.clearClipCallCount, 2);
    expect(audioEngine.playClipOnceCallCount, 2);
    expect(audioEngine.lastPlayedSentence?.index, 1);
    expect(state().playingSentenceIndex, 1);
    expect(state().playbackPosition, const Duration(seconds: 4));

    audioEngine.completePlayback();
    await Future.wait([firstPlayback, secondPlayback]);

    expect(state().isPlaying, isFalse);
    expect(state().playbackPosition, const Duration(seconds: 8));
  });

  test('播放头在 position stream 稀疏时仍按本地时钟平滑推进', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.playSentence(1);
    await Future<void>.delayed(Duration.zero);
    final start = state().playbackPosition;

    await Future<void>.delayed(const Duration(milliseconds: 160));
    final advanced = state().playbackPosition;

    expect(start, const Duration(seconds: 4));
    expect(advanced, greaterThan(start));
    expect(advanced, lessThan(const Duration(seconds: 5)));

    audioEngine.completePlayback();
    await playback;
  });

  test('mergeWithNext 停止播放并让红线跟随合并后的选中句', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.playSentence(1);
    await Future<void>.delayed(Duration.zero);

    notifier.mergeWithNext(1);

    expect(state().isPlaying, isFalse);
    expect(state().selectedSentenceIndex, 1);
    expect(state().playbackPosition, const Duration(seconds: 4));
    expect(audioEngine.clearClipCallCount, greaterThanOrEqualTo(1));

    audioEngine.completePlayback();
    await playback;
  });

  test('deleteSentence 停止播放并让红线跟随删除后的选中句', () async {
    final notifier = controller();
    await notifier.load();
    notifier.selectSentence(1);

    notifier.deleteSentence(1);

    expect(state().isPlaying, isFalse);
    expect(state().selectedSentenceIndex, 1);
    expect(state().sentences[1].text, 'Third sentence.');
    expect(state().playbackPosition, const Duration(seconds: 8));
  });

  test('adjustSelectedSentenceBoundary 调整选中句 end 并标记已修改', () async {
    final notifier = controller();
    await notifier.load();
    notifier.selectSentence(1); // [4s, 8s]

    notifier.adjustSelectedSentenceBoundary(
      BoundaryEdge.end,
      const Duration(seconds: 7),
    );

    expect(state().sentences[1].endTime, const Duration(seconds: 7));
    expect(state().sentences[1].startTime, const Duration(seconds: 4));
    // 相邻句不变。
    expect(state().sentences[2].startTime, const Duration(seconds: 8));
    expect(state().isDirty, isTrue);
  });

  test('adjustSelectedSentenceBoundary 越界被钳制到相邻句边界', () async {
    final notifier = controller();
    await notifier.load();
    notifier.selectSentence(1); // [4s, 8s]，下一句 start = 8s

    notifier.adjustSelectedSentenceBoundary(
      BoundaryEdge.end,
      const Duration(seconds: 99), // 远超 next.start
    );

    expect(state().sentences[1].endTime, const Duration(seconds: 8));
  });

  test('adjustSelectedSentenceBoundary 无选中句时不动 state', () async {
    final notifier = controller();
    await notifier.load();
    // load 后默认无选中句。
    final before = state().sentences;

    notifier.adjustSelectedSentenceBoundary(
      BoundaryEdge.start,
      const Duration(seconds: 1),
    );

    expect(state().sentences, same(before));
    expect(state().isDirty, isFalse);
  });

  test('playSentence 播放到句尾不把焦点跳到下一句', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.playSentence(0); // [0s, 4s]，与句1首尾相接
    await Future<void>.delayed(Duration.zero);
    expect(state().selectedSentenceIndex, 0);

    // 底层 position 推进到句尾（= 下一句起点），单句播放应保持焦点在句0。
    audioEngine.emitPosition(const Duration(seconds: 4));
    await Future<void>.delayed(Duration.zero);
    expect(state().selectedSentenceIndex, 0);

    audioEngine.completePlayback();
    await playback;
    expect(state().selectedSentenceIndex, 0);
  });

  test('adjustSentenceBoundary 可调整相邻句且不改变当前选中句', () async {
    final notifier = controller();
    await notifier.load();
    notifier.selectSentence(1); // 选中句1，但调整句0的结束边界

    notifier.adjustSentenceBoundary(
      0,
      BoundaryEdge.end,
      const Duration(seconds: 3),
    );

    expect(state().sentences[0].endTime, const Duration(seconds: 3));
    expect(state().selectedSentenceIndex, 1); // 选中句不变
    expect(state().isDirty, isTrue);
  });

  test('restoreSentences 撤销删除：还原快照并保持已修改状态', () async {
    final notifier = controller();
    await notifier.load();
    final snapshot = List<Sentence>.from(state().sentences);

    notifier.deleteSentence(1);
    expect(state().sentences.length, 2);

    notifier.restoreSentences(snapshot);
    expect(state().sentences.length, 3);
    expect(state().sentences[1].text, 'Second sentence.');
    expect(state().isDirty, isTrue);
    expect(state().isPlaying, isFalse);
  });

  test('setWaveformZoomScale 限制缩放范围（1.0 ~ 按音频长度）', () async {
    final notifier = controller();
    await notifier.load(); // totalDuration = 12s → maxZoom = 12 / 2 = 6.0

    expect(state().maxWaveformZoomScale, 6.0);

    notifier.setWaveformZoomScale(10);
    expect(state().waveformZoomScale, 6.0);

    notifier.setWaveformZoomScale(0.2);
    expect(state().waveformZoomScale, 1.0);
  });

  test('initZoomForViewport 按可视区宽度设置初始缩放（每厘米约 1 秒）', () async {
    final notifier = controller();
    await notifier.load(); // totalDuration = 12s → maxZoom = 6.0

    // 1 厘米 ≈ 62.992 逻辑像素；scale = 62.992 * 12 / 360 ≈ 2.1。
    notifier.initZoomForViewport(360);
    expect(state().waveformZoomScale, closeTo(2.0997, 0.001));

    // 仅生效一次：后续调用被忽略。
    notifier.initZoomForViewport(180);
    expect(state().waveformZoomScale, closeTo(2.0997, 0.001));
  });

  test('initZoomForViewport 宽度非法时不生效，留待后续重试', () async {
    final notifier = controller();
    await notifier.load();

    notifier.initZoomForViewport(0);
    expect(state().waveformZoomScale, 1.0);

    // 上次未消费 init 标志，合法宽度仍可生效。
    notifier.initZoomForViewport(360);
    expect(state().waveformZoomScale, closeTo(2.0997, 0.001));
  });

  test('initZoomForViewport 超长音频缩放被 max 截断', () async {
    final notifier = controller();
    await notifier.load(); // maxZoom = 6.0

    // 极窄可视区会算出超大 scale，应被 maxWaveformZoomScale 截断。
    notifier.initZoomForViewport(50);
    expect(state().waveformZoomScale, 6.0);
  });

  test('sentenceCountChanged：调边界为 false，删除/合并为 true', () async {
    final notifier = controller();
    await notifier.load();
    expect(notifier.sentenceCountChanged, isFalse);

    // 仅前移第 1 句尾边界（4s → 3s），数量不变。
    notifier.adjustSentenceBoundary(
      0,
      BoundaryEdge.end,
      const Duration(seconds: 3),
    );
    expect(notifier.sentenceCountChanged, isFalse);

    // 删除一句，数量变化。
    notifier.deleteSentence(2);
    expect(notifier.sentenceCountChanged, isTrue);
  });

  group('save 是否清空学习进度/收藏', () {
    late Directory tempDir;
    late TestBookmarkDao bookmarkDao;
    late TestLearningProgressNotifier progressNotifier;

    setUp(() async {
      // save() 会向 transcriptPath 写文件，准备临时目录与已存在的字幕文件。
      tempDir = await Directory.systemTemp.createTemp('subtitle_save_test');
      appDataDirectoryOverride = tempDir;
      final transcriptFile = File(
        p.join(tempDir.path, audioItem.transcriptPath!),
      );
      await transcriptFile.parent.create(recursive: true);
      await transcriptFile.writeAsString('');

      bookmarkDao = TestBookmarkDao();
      // 预置收藏与学习进度，用来验证保存后是否被清空。
      await bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: audioItem.id,
          sentenceIndex: 1,
          sentenceText: 'Second sentence.',
          startTime: 4,
          endTime: 8,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      progressNotifier = TestLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            audioItem.id: LearningProgress(
              audioItemId: audioItem.id,
              updatedAt: DateTime(2026, 1, 1),
            ),
          },
        ),
      );
    });

    tearDown(() async {
      appDataDirectoryOverride = null;
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    ProviderContainer saveContainer() {
      // 用独立的音频引擎实例：全局 setUp 的容器已挂载了共享 audioEngine，
      // 同一 Notifier 实例不能在两个容器中重复挂载。
      final engine = _RecordingAudioEngine(
        duration: const Duration(seconds: 12),
        sentences: sentences,
      );
      addTearDown(engine.disposeController);
      return ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => engine),
          bookmarkDaoProvider.overrideWithValue(bookmarkDao),
          audioItemDaoProvider.overrideWithValue(TestAudioItemDao()),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
        ],
      );
    }

    test('仅调整时间戳（句子数量不变）保留学习进度和收藏', () async {
      final c = saveContainer();
      addTearDown(c.dispose);
      // 保持监听，避免 autoDispose 在 await 期间销毁控制器。
      c.listen(subtitleEditorControllerProvider(audioItem), (_, _) {});
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      // 仅前移第 1 句的尾边界（4s → 3s），句子数量保持 3。
      notifier.adjustSentenceBoundary(
        0,
        BoundaryEdge.end,
        const Duration(seconds: 3),
      );
      final saved = await notifier.save();

      expect(saved, isTrue);
      expect(
        await bookmarkDao.getBookmarkedIndices(audioItem.id),
        contains(1),
        reason: '句子数量未变，收藏应保留',
      );
      expect(
        c
            .read(learningProgressNotifierProvider)
            .progressMap
            .containsKey(audioItem.id),
        isTrue,
        reason: '句子数量未变，学习进度应保留',
      );
    });

    test('删除句子（句子数量变化）清空学习进度和收藏', () async {
      final c = saveContainer();
      addTearDown(c.dispose);
      // 保持监听，避免 autoDispose 在 await 期间销毁控制器。
      c.listen(subtitleEditorControllerProvider(audioItem), (_, _) {});
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      // 删除一句，句子数量从 3 变 2。
      notifier.deleteSentence(2);
      final saved = await notifier.save();

      expect(saved, isTrue);
      expect(
        await bookmarkDao.getBookmarkedIndices(audioItem.id),
        isEmpty,
        reason: '句子数量变化，收藏应清空',
      );
      expect(
        c
            .read(learningProgressNotifierProvider)
            .progressMap
            .containsKey(audioItem.id),
        isFalse,
        reason: '句子数量变化，学习进度应清空',
      );
    });

    test('LP 正持有该音频时，保存后以 forceTranscriptReload 重载', () async {
      // 字幕原地改写同名 SRT，id/transcriptPath 不变。loadAudio 去重守卫只比 id+path，
      // 不强制重载会命中守卫跳过解析，使自由练习/盲听显示陈旧拆分句子。
      final recordingLp = _RecordingListeningPractice(
        ListeningPracticeState(currentAudioItem: audioItem),
      );
      final engine = _RecordingAudioEngine(
        duration: const Duration(seconds: 12),
        sentences: sentences,
      );
      addTearDown(engine.disposeController);
      final c = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => engine),
          bookmarkDaoProvider.overrideWithValue(bookmarkDao),
          audioItemDaoProvider.overrideWithValue(TestAudioItemDao()),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
          listeningPracticeProvider.overrideWith(() => recordingLp),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
        ],
      );
      addTearDown(c.dispose);
      c.listen(subtitleEditorControllerProvider(audioItem), (_, _) {});
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      notifier.deleteSentence(2);
      final saved = await notifier.save();

      expect(saved, isTrue);
      expect(recordingLp.loadAudioForceFlags, isNotEmpty, reason: '应触发 LP 重载');
      expect(
        recordingLp.loadAudioForceFlags.last,
        isTrue,
        reason: '必须强制重载以绕过 loadAudio 的 id+path 去重守卫',
      );
    });
  });
}

/// 记录 loadAudio 的 forceTranscriptReload 入参，用于验证保存后是否强制重载 LP。
class _RecordingListeningPractice extends TestListeningPractice {
  _RecordingListeningPractice([super.initialState]);

  final List<bool> loadAudioForceFlags = [];

  @override
  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    loadAudioForceFlags.add(forceTranscriptReload);
    await super.loadAudio(
      audioItem,
      forceTranscriptReload: forceTranscriptReload,
    );
  }
}

class _RecordingAudioEngine extends AudioEngine {
  _RecordingAudioEngine({required this.duration, required this.sentences});

  final Duration duration;
  final List<Sentence> sentences;
  final _positionController = StreamController<Duration>.broadcast();
  final speedCalls = <double>[];
  Completer<void>? _playbackCompleter;
  int _sessionId = 0;

  int playRangeOnceCallCount = 0;
  int playClipOnceCallCount = 0;
  int stopPlaybackCallCount = 0;
  int clearClipCallCount = 0;
  double? lastSpeed;
  Duration? lastPlayStart;
  Duration? lastPlayEnd;
  Duration? lastSeekAbsolute;
  Sentence? lastPlayedSentence;

  @override
  AudioEngineState build() => AudioEngineState(totalDuration: duration);

  @override
  Stream<Duration> get absolutePositionStream => _positionController.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => _playbackCompleter != null;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<Duration?> loadAudio(AudioItem item, double speed) async => duration;

  @override
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async => sentences;

  @override
  Future<void> setSpeed(double speed) async {
    lastSpeed = speed;
    speedCalls.add(speed);
  }

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId,
  ) async {
    playRangeOnceCallCount += 1;
    lastPlayStart = start;
    lastPlayEnd = end;
    _playbackCompleter = Completer<void>();
    await _playbackCompleter!.future;
  }

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    playClipOnceCallCount += 1;
    lastPlayedSentence = sentence;
    _playbackCompleter = Completer<void>();
    await _playbackCompleter!.future;
  }

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCallCount += 1;
    _playbackCompleter?.complete();
    _playbackCompleter = null;
  }

  @override
  Future<void> clearClip() async {
    clearClipCallCount += 1;
  }

  @override
  Future<void> seekToAbsolute(Duration absolute) async {
    lastSeekAbsolute = absolute;
  }

  void completePlayback() {
    _playbackCompleter?.complete();
    _playbackCompleter = null;
  }

  void emitPosition(Duration position) {
    _positionController.add(position);
  }

  void disposeController() {
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete();
    }
    unawaited(_positionController.close());
  }
}
