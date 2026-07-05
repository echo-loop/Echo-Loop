import 'dart:async';
import 'dart:io';

import 'package:echo_loop/database/app_database.dart' show BookmarksCompanion;
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../helpers/mock_providers.dart';

void main() {
  late _RecordingAudioEngine audioEngine;
  late ProviderContainer container;
  late ProviderSubscription<SubtitleEditorState> subscription;
  late AudioItem audioItem;
  late List<Sentence> sentences;
  late TestAudioItemDao audioItemDao;

  setUp(() {
    audioItem = createTestAudioItem(totalDuration: 12);
    audioItemDao = TestAudioItemDao();
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
      overrides: [
        audioEngineProvider.overrideWith(() => audioEngine),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
      ],
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

  test('load 默认选中第一句，让波形边界手柄立即显示', () async {
    final notifier = controller();
    await notifier.load();

    expect(state().selectedSentenceIndex, 0);
    expect(state().selectedSentence, sentences.first);
    expect(state().playbackPosition, sentences.first.startTime);
    expect(state().selectionEpoch, 0);
  });

  test('setPlaybackSpeed 播放中实时转发到底层音频引擎', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.playSentence(0);
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

  test('adjustWord 拖相邻句末词终点同步该句边界且不改变当前选中句', () async {
    final notifier = controller();
    await notifier.load();
    notifier.selectSentence(1); // 选中句1，但调整句0的结束边界（句0末词 'sentence.' = 全局词 1）

    notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));

    expect(state().sentences[0].endTime, const Duration(seconds: 3));
    expect(state().selectedSentenceIndex, 1); // 选中句不变
    expect(state().isDirty, isTrue);
  });

  test('adjustWord 拖句子边界回原位后不再视为已修改', () async {
    final notifier = controller();
    await notifier.load();
    notifier.selectSentence(1); // [4s, 8s]，句1末词 'sentence.' = 全局词 3，终点 8s

    notifier.adjustWord(3, BoundaryEdge.end, const Duration(seconds: 7));
    expect(state().isDirty, isTrue);

    notifier.adjustWord(3, BoundaryEdge.end, const Duration(seconds: 8));
    expect(state().sentences[1].endTime, const Duration(seconds: 8));
    expect(state().isDirty, isFalse);
  });

  test('restoreSentences 撤销删除：还原到原始字幕后不再视为已修改', () async {
    final notifier = controller();
    await notifier.load();
    final snapshot = List<Sentence>.from(state().sentences);

    notifier.deleteSentence(1);
    expect(state().sentences.length, 2);

    notifier.restoreSentences(snapshot);
    expect(state().sentences.length, 3);
    expect(state().sentences[1].text, 'Second sentence.');
    expect(state().isDirty, isFalse);
    expect(state().isPlaying, isFalse);
  });

  test('setWaveformZoomScale 限制缩放范围（1.0 ~ 按音频长度）', () async {
    final notifier = controller();
    await notifier.load();
    notifier.initZoomForViewport(360);

    expect(state().maxWaveformZoomScale, closeTo(4.1994, 0.001));

    notifier.setWaveformZoomScale(20);
    expect(state().waveformZoomScale, closeTo(4.1994, 0.001));

    notifier.setWaveformZoomScale(0.2);
    expect(state().waveformZoomScale, 1.0);
  });

  test('maxWaveformZoomScale 长音频按 2cm/秒自适应，不被固定上限截断', () async {
    final localAudioItem = createTestAudioItem(totalDuration: 1800);
    final localAudioEngine = _RecordingAudioEngine(
      duration: const Duration(minutes: 30),
      sentences: sentences,
    );
    final localContainer = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWith(() => localAudioEngine),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
      ],
    );
    final localSubscription = localContainer.listen(
      subtitleEditorControllerProvider(localAudioItem),
      (_, _) {},
      fireImmediately: true,
    );

    try {
      final notifier = localContainer.read(
        subtitleEditorControllerProvider(localAudioItem).notifier,
      );
      await notifier.load();
      notifier.initZoomForViewport(360);
      final st = localContainer.read(
        subtitleEditorControllerProvider(localAudioItem),
      );

      // 1cm ≈ 62.992 逻辑像素。30 分钟音频、360px 可用宽度下，最大缩放 =
      // 1800s × 2cm/s × 62.992px/cm / 360px ≈ 629.92，旧固定 300x 会不够。
      expect(st.maxWaveformZoomScale, closeTo(629.92, 0.01));
    } finally {
      localSubscription.close();
      localContainer.dispose();
      localAudioEngine.disposeController();
    }
  });

  test('initZoomForViewport 按可视区宽度设置初始缩放（每厘米约 1 秒）', () async {
    final notifier = controller();
    await notifier.load(); // totalDuration = 12s → maxZoom = 12.0

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

  test('initZoomForViewport 同时设置初始缩放和 2cm/秒最大缩放', () async {
    final notifier = controller();
    await notifier.load();

    notifier.initZoomForViewport(360);

    expect(state().waveformZoomScale, closeTo(2.0997, 0.001));
    expect(state().maxWaveformZoomScale, closeTo(4.1994, 0.001));
  });

  test('sentenceCountChanged：调边界为 false，删除/合并为 true', () async {
    final notifier = controller();
    await notifier.load();
    expect(notifier.sentenceCountChanged, isFalse);

    // 仅前移第 0 句尾边界（末词 'sentence.' = 全局词 1，4s → 3s），数量不变。
    notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));
    expect(notifier.sentenceCountChanged, isFalse);

    // 删除一句，数量变化。
    notifier.deleteSentence(2);
    expect(notifier.sentenceCountChanged, isTrue);
  });

  group('词级：拆词（不丢词）/ 对齐 / 点词播放', () {
    test('label 来自句子文本按空格拆分，含句首单字母词不丢失（bug1 回归）', () async {
      // 句首单字母词 "I" 的真实词级时间可能略早于 SRT 句起点；按文本 token 拆词
      // 才不会把它丢给上一句。
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'I finished 3 reports.',
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 4),
          ),
        );
      // 真实词级数据：词 "I" 起点 0.8s 早于句起点 1s（模拟边界错位）。
      audioItemDao.wordTimestampsStore[audioItem.id] = encodeWordTimestamps([
        const WordTimestamp(
          word: 'I',
          startTime: Duration(milliseconds: 800),
          endTime: Duration(milliseconds: 1100),
          confidence: 0.9,
        ),
        const WordTimestamp(
          word: 'finished',
          startTime: Duration(milliseconds: 1100),
          endTime: Duration(milliseconds: 2000),
          confidence: 0.9,
        ),
        const WordTimestamp(
          word: '3',
          startTime: Duration(milliseconds: 2000),
          endTime: Duration(milliseconds: 2500),
          confidence: 0.9,
        ),
        const WordTimestamp(
          word: 'reports.',
          startTime: Duration(milliseconds: 2500),
          endTime: Duration(milliseconds: 3900),
          confidence: 0.9,
        ),
      ]);
      final notifier = controller();
      await notifier.load();

      final words = notifier.wordsOfSelectedSentence;
      expect(words.map((w) => w.word).toList(), [
        'I',
        'finished',
        '3',
        'reports.',
      ]);
      // "I" 的真实起点早于句起点，被钳到句起点，不丢词。
      expect(words.first.word, 'I');
      expect(words.first.startTime, const Duration(seconds: 1));
      // 中间词保留真实时间。
      expect(words[1].startTime, const Duration(milliseconds: 1100));
    });

    test('无 DB 词级数据时按句内字符比例切分（首词贴句首、末词贴句尾）', () async {
      final notifier = controller();
      await notifier.load();

      final firstWords = notifier.wordsOfSelectedSentence;
      expect(firstWords.map((w) => w.word).toList(), ['First', 'sentence.']);
      expect(firstWords.first.startTime, Duration.zero);
      expect(firstWords.last.endTime, const Duration(seconds: 4));
    });

    test('wordsOfSelectedSentence 返回选中句的全部 token', () async {
      final notifier = controller();
      await notifier.load();
      notifier.selectSentence(1); // "Second sentence." [4s, 8s]

      final words = notifier.wordsOfSelectedSentence;
      expect(words.map((w) => w.word).toList(), ['Second', 'sentence.']);
      expect(words.first.startTime, const Duration(seconds: 4));
      expect(words.last.endTime, const Duration(seconds: 8));
    });

    test('playWord 播放该词区间并置位 focusedWordIndex', () async {
      final notifier = controller();
      await notifier.load();
      final words = notifier.wordsOfSelectedSentence;

      final playback = notifier.playWord(1);
      await Future<void>.delayed(Duration.zero);

      expect(state().focusedWordIndex, 1);
      expect(state().isPlaying, isTrue);
      expect(audioEngine.playRangeOnceCallCount, 1);
      expect(audioEngine.lastPlayStart, words[1].startTime);
      expect(audioEngine.lastPlayEnd, words[1].endTime);

      audioEngine.completePlayback();
      await playback;

      // 播放结束保留点中词，便于继续查看词边界。
      expect(state().isPlaying, isFalse);
      expect(state().focusedWordIndex, 1);
    });

    test('句子播放中点词改播该词，清空 playingSentenceIndex（句子行恢复播放按钮）', () async {
      final notifier = controller();
      await notifier.load();

      final sentencePlay = notifier.playSentence(0);
      await Future<void>.delayed(Duration.zero);
      expect(state().playingSentenceIndex, 0);
      expect(state().isPlaying, isTrue);

      // 句子播放中点击单词：改为播放该词，句子行不应再显示「停止」。
      final wordPlay = notifier.playWord(1);
      await Future<void>.delayed(Duration.zero);
      expect(state().playingSentenceIndex, isNull);
      expect(state().playbackMode, SubtitleEditorPlaybackMode.word);
      expect(state().isPlaying, isTrue);

      audioEngine.completePlayback();
      await wordPlay;
      await sentencePlay;
    });

    test('选中其他句清空 focusedWordIndex（退出词聚焦态）', () async {
      final notifier = controller();
      await notifier.load();
      final playback = notifier.playWord(0);
      await Future<void>.delayed(Duration.zero);
      expect(state().focusedWordIndex, 0);

      notifier.selectSentence(2);
      expect(state().focusedWordIndex, isNull);

      audioEngine.completePlayback();
      await playback;
    });

    test('拖动句子边界保留 focusedWordIndex（词参考线不消失，bug3 回归）', () async {
      final notifier = controller();
      await notifier.load();
      final playback = notifier.playWord(0);
      await Future<void>.delayed(Duration.zero);
      audioEngine.completePlayback();
      await playback;
      expect(state().focusedWordIndex, 0);

      // 拖动当前选中句（句0）的结束边界（末词 'sentence.' = 全局词 1），
      // 词聚焦态应保留（参考线不消失）。
      notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));
      expect(state().focusedWordIndex, 0);
    });

    test('adjustWord 拖动内部词边界更新词时间并标记 dirty', () async {
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'one two three',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 9),
          ),
        );
      final notifier = controller();
      await notifier.load();

      // 词 1 'two' 的起点（word0 与 word1 之间的边界）右移到 4s。
      notifier.adjustWord(1, BoundaryEdge.start, const Duration(seconds: 4));
      final words = notifier.wordsOfSelectedSentence;
      expect(words[1].startTime, const Duration(seconds: 4));
      expect(state().isDirty, isTrue);
    });

    test('adjustWord 越界被钳制（不跨相邻词、不小于最小词长）', () async {
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'one two three',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 9),
          ),
        );
      final notifier = controller();
      await notifier.load();
      final before = notifier.wordsOfSelectedSentence;

      // 把词 1 起点拖到极右（超过自身结束）→ 钳到 word1.end - 最小词长。
      notifier.adjustWord(1, BoundaryEdge.start, const Duration(seconds: 99));
      final after = notifier.wordsOfSelectedSentence;
      expect(after[1].startTime, lessThanOrEqualTo(before[1].endTime));
      expect(
        after[1].endTime.inMilliseconds - after[1].startTime.inMilliseconds,
        greaterThanOrEqualTo(
          SubtitleEditorController.kMinWordDuration.inMilliseconds,
        ),
      );
    });

    test('adjustWord 拖句首词起点同步句子起点，且不越过首词结束（bug#1）', () async {
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'one two three',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 9),
          ),
        );
      final notifier = controller();
      await notifier.load();
      final firstWordEnd = notifier.wordsOfSelectedSentence.first.endTime;

      // 句首词起点右移到 1s：句子起点同步前移。
      notifier.adjustWord(0, BoundaryEdge.start, const Duration(seconds: 1));
      expect(state().sentences.first.startTime, const Duration(seconds: 1));
      expect(state().words.first.startTime, const Duration(seconds: 1));
      expect(state().isDirty, isTrue);

      // 继续右移到极右（超过首词结束）→ 钳到「首词结束 − 最小词长」，绝不穿越。
      notifier.adjustWord(0, BoundaryEdge.start, const Duration(seconds: 99));
      final start = state().sentences.first.startTime;
      expect(start, lessThan(firstWordEnd), reason: '句子起点不能越过第一个词的结束');
      expect(
        start,
        lessThanOrEqualTo(
          firstWordEnd - SubtitleEditorController.kMinWordDuration,
        ),
      );
    });

    test('adjustWord 拖句末词终点同步句子终点，且不越过末词起点（bug#2）', () async {
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'one two three',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 9),
          ),
        );
      final notifier = controller();
      await notifier.load();
      final lastWordStart = notifier.wordsOfSelectedSentence.last.startTime;

      // 句末词终点左移到 5s：句子终点同步前移。
      notifier.adjustWord(2, BoundaryEdge.end, const Duration(seconds: 5));
      expect(state().sentences.first.endTime, const Duration(seconds: 5));
      expect(state().words.last.endTime, const Duration(seconds: 5));

      // 继续左移到极左（早于末词起点）→ 钳到「末词起点 + 最小词长」，绝不穿越。
      notifier.adjustWord(2, BoundaryEdge.end, Duration.zero);
      final end = state().sentences.first.endTime;
      expect(end, greaterThan(lastWordStart), reason: '句子终点不能越过最后一个词的起点');
      expect(
        end,
        greaterThanOrEqualTo(
          lastWordStart + SubtitleEditorController.kMinWordDuration,
        ),
      );
    });

    test('adjustWord 句首词起点左拖钳到前一句终点（不与前句重叠）', () async {
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'alpha beta',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 4),
          ),
        )
        ..add(
          Sentence(
            index: 1,
            text: 'gamma delta',
            startTime: const Duration(seconds: 5),
            endTime: const Duration(seconds: 9),
          ),
        );
      final notifier = controller();
      await notifier.load();
      notifier.selectSentence(1);

      // 句 1 首词 'gamma'（全局词下标 2）起点左拖到 0 → 钳到前一句终点 4s。
      notifier.adjustWord(2, BoundaryEdge.start, Duration.zero);
      expect(state().sentences[1].startTime, const Duration(seconds: 4));
      expect(state().words[2].startTime, const Duration(seconds: 4));
    });

    test('wordBoundariesForWaveform 覆盖选中句+前后句，当前句为主样式', () async {
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'a b',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        )
        ..add(
          Sentence(
            index: 1,
            text: 'c d',
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 6),
          ),
        )
        ..add(
          Sentence(
            index: 2,
            text: 'e f',
            startTime: const Duration(seconds: 6),
            endTime: const Duration(seconds: 9),
          ),
        );
      final notifier = controller();
      await notifier.load();
      notifier.selectSentence(1);

      final b = notifier.wordBoundariesForWaveform;
      // 三句各 2 词 = 6 条，globalIndex 连续覆盖 0..5。
      expect(b.map((e) => e.globalIndex).toList(), [0, 1, 2, 3, 4, 5]);
      // 仅当前句（句 1，词 2/3）为主样式。
      expect(b.where((e) => e.primary).map((e) => e.globalIndex).toList(), [
        2,
        3,
      ]);
      // 每句首词为句起、末词为句止。
      expect(b[2].isSentenceStart, isTrue);
      expect(b[3].isSentenceEnd, isTrue);
    });
  });

  group('词级：就地编辑单词 / 分句', () {
    /// 用单句 'one two three' [0,3s] 物化 3 个等长词，断言时间更可控。
    void useSingleSentence() {
      sentences
        ..clear()
        ..add(
          Sentence(
            index: 0,
            text: 'one two three',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        );
      audioItemDao.wordTimestampsStore[audioItem.id] =
          encodeWordTimestamps(const [
            WordTimestamp(
              word: 'one',
              startTime: Duration.zero,
              endTime: Duration(seconds: 1),
              confidence: 1,
            ),
            WordTimestamp(
              word: 'two',
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 2),
              confidence: 1,
            ),
            WordTimestamp(
              word: 'three',
              startTime: Duration(seconds: 2),
              endTime: Duration(seconds: 3),
              confidence: 1,
            ),
          ]);
    }

    test('editWord 改名单词：文本更新、词数不变、其余词时间不变', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.editWord(1, 'TWO');

      expect(state().sentences[0].text, 'one TWO three');
      final words = notifier.wordsOfSelectedSentence;
      expect(words.map((w) => w.word).toList(), ['one', 'TWO', 'three']);
      expect(words[1].startTime, const Duration(seconds: 1));
      expect(words[1].endTime, const Duration(seconds: 2));
      expect(words[2].startTime, const Duration(seconds: 2));
      expect(state().isDirty, isTrue);
    });

    test('editWord 删空中间词：移除该词、其余词时间不变（保留时间空隙）', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.editWord(1, '');

      expect(state().sentences[0].text, 'one three');
      final words = notifier.wordsOfSelectedSentence;
      expect(words.map((w) => w.word).toList(), ['one', 'three']);
      expect(words[0].endTime, const Duration(seconds: 1));
      expect(words[1].startTime, const Duration(seconds: 2));
      expect(words[1].endTime, const Duration(seconds: 3));
    });

    test('editWord 删首词：句起跟随新首词，其余词时间不变', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.editWord(0, '');

      expect(state().sentences[0].text, 'two three');
      expect(state().sentences[0].startTime, const Duration(seconds: 1));
      final words = notifier.wordsOfSelectedSentence;
      expect(words.map((w) => w.word).toList(), ['two', 'three']);
      expect(words[0].startTime, const Duration(seconds: 1));
      expect(words[1].endTime, const Duration(seconds: 3));
    });

    test('editWord 拆多词：按字符比例分配原词区间，合计等于原区间', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      // 'two' [1s,2s] → 'two and'（各 3 字符）平分为 [1s,1.5s] + [1.5s,2s]。
      notifier.editWord(1, 'two and');

      expect(state().sentences[0].text, 'one two and three');
      final words = notifier.wordsOfSelectedSentence;
      expect(words.map((w) => w.word).toList(), ['one', 'two', 'and', 'three']);
      expect(words[1].startTime, const Duration(seconds: 1));
      expect(words[1].endTime, const Duration(milliseconds: 1500));
      expect(words[2].startTime, const Duration(milliseconds: 1500));
      expect(words[2].endTime, const Duration(seconds: 2));
    });

    test('editWord 删句中唯一词：整句被删（多句场景）', () async {
      sentences
        ..clear()
        ..addAll([
          Sentence(
            index: 0,
            text: 'hi',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 2),
          ),
          Sentence(
            index: 1,
            text: 'there world',
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 6),
          ),
        ]);
      final notifier = controller();
      await notifier.load();
      notifier.selectSentence(0);

      notifier.editWord(0, '');

      expect(state().sentences.length, 1);
      expect(state().sentences[0].text, 'there world');
    });

    test('splitSentenceAtWord 从该词分句：句数+1、文本与起止正确、词对齐保持', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.splitSentenceAtWord(1);

      expect(state().sentences.length, 2);
      expect(state().sentences[0].text, 'one');
      expect(state().sentences[0].startTime, Duration.zero);
      expect(state().sentences[0].endTime, const Duration(seconds: 1));
      expect(state().sentences[1].text, 'two three');
      expect(state().sentences[1].startTime, const Duration(seconds: 1));
      expect(state().sentences[1].endTime, const Duration(seconds: 3));
      // 词数不变，时间保留。
      expect(state().words.length, 3);
      expect(state().selectedSentenceIndex, 0);
      expect(state().isDirty, isTrue);
    });

    test('splitSentenceAtWord(0) 首词不允许分句，no-op', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.splitSentenceAtWord(0);

      expect(state().sentences.length, 1);
      expect(state().isDirty, isFalse);
    });
  });

  group('save 是否清空学习进度/收藏', () {
    late Directory tempDir;
    late TestBookmarkDao bookmarkDao;
    late TestAudioItemDao audioItemDao;
    late TestLearningProgressNotifier progressNotifier;

    setUp(() async {
      // save() 现在把字幕内容写入 DB transcript_srt 列（不再落文件）。
      tempDir = await Directory.systemTemp.createTemp('subtitle_save_test');
      appDataDirectoryOverride = tempDir;

      audioItemDao = TestAudioItemDao();
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
          audioItemDaoProvider.overrideWithValue(audioItemDao),
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

      // 仅前移第 0 句尾边界（末词 'sentence.' = 全局词 1，4s → 3s），句子数量保持 3。
      notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));
      final saved = await notifier.save();

      expect(saved, isTrue);
      // 字幕内容写入 DB transcript_srt 列
      final savedSrt = audioItemDao.transcriptSrtStore[audioItem.id];
      expect(savedSrt, isNotNull);
      expect(savedSrt!, contains('-->'));
      final savedWords = decodeWordTimestamps(
        audioItemDao.wordTimestampsStore[audioItem.id]!,
      );
      expect(savedWords, isNotNull);
      expect(savedWords!.map((w) => w.word).take(2), ['First', 'sentence.']);
      expect(savedWords.first.startTime, Duration.zero);
      expect(savedWords.last.endTime, const Duration(seconds: 12));
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

    test('拖动词边界后保存：同时更新词级字幕和句子 SRT', () async {
      final c = saveContainer();
      addTearDown(c.dispose);
      c.listen(subtitleEditorControllerProvider(audioItem), (_, _) {});
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      // 句子未增减（词级编辑），调整句 0 内 'sentence.' 的起点到 2s。
      notifier.adjustWord(1, BoundaryEdge.start, const Duration(seconds: 2));
      expect(
        c.read(subtitleEditorControllerProvider(audioItem)).isDirty,
        isTrue,
      );

      final saved = await notifier.save();
      expect(saved, isTrue);

      // 句子 SRT 写入。
      expect(audioItemDao.transcriptSrtStore[audioItem.id], contains('-->'));
      // 词级字幕写入且反映拖动后的时间。
      final savedWords = decodeWordTimestamps(
        audioItemDao.wordTimestampsStore[audioItem.id]!,
      )!;
      expect(savedWords.length, greaterThanOrEqualTo(2));
      expect(savedWords[1].word, 'sentence.');
      expect(savedWords[1].startTime, const Duration(seconds: 2));
      // 句子数量未变，收藏与进度保留。
      expect(await bookmarkDao.getBookmarkedIndices(audioItem.id), contains(1));
    });

    test('保存成功后重置字幕基线，未继续修改时不再保存', () async {
      final c = saveContainer();
      addTearDown(c.dispose);
      // 保持监听，避免 autoDispose 在 await 期间销毁控制器。
      c.listen(subtitleEditorControllerProvider(audioItem), (_, _) {});
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      // 句0 末词 'sentence.' = 全局词 1，前移其终点 4s → 3s。
      notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));
      expect(c.read(subtitleEditorControllerProvider(audioItem)).isDirty, true);

      final saved = await notifier.save();
      expect(saved, isTrue);
      expect(
        c.read(subtitleEditorControllerProvider(audioItem)).isDirty,
        false,
      );

      final savedAgain = await notifier.save();
      expect(savedAgain, isFalse);
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

    test('保存确认只在句子数量变化且已有实际进度或收藏时需要', () async {
      Future<SubtitleEditorController> loadedNotifier({
        required TestBookmarkDao bookmarkDao,
        required TestLearningProgressNotifier progressNotifier,
      }) async {
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
            listeningPracticeProvider.overrideWith(
              () => TestListeningPractice(),
            ),
            learningProgressNotifierProvider.overrideWith(
              () => progressNotifier,
            ),
          ],
        );
        addTearDown(c.dispose);
        c.listen(subtitleEditorControllerProvider(audioItem), (_, _) {});
        final notifier = c.read(
          subtitleEditorControllerProvider(audioItem).notifier,
        );
        await notifier.load();
        notifier.deleteSentence(2);
        return notifier;
      }

      final emptyNotifier = await loadedNotifier(
        bookmarkDao: TestBookmarkDao(),
        progressNotifier: TestLearningProgressNotifier(),
      );
      expect(emptyNotifier.sentenceCountChanged, isTrue);
      expect(await emptyNotifier.hasResettableLearningData(), isFalse);

      final bookmarkOnlyDao = TestBookmarkDao();
      await bookmarkOnlyDao.addBookmark(
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
      final bookmarkNotifier = await loadedNotifier(
        bookmarkDao: bookmarkOnlyDao,
        progressNotifier: TestLearningProgressNotifier(),
      );
      expect(await bookmarkNotifier.hasResettableLearningData(), isTrue);

      final progressNotifier = await loadedNotifier(
        bookmarkDao: TestBookmarkDao(),
        progressNotifier: TestLearningProgressNotifier(
          LearningProgressState(
            progressMap: {
              audioItem.id: LearningProgress(
                audioItemId: audioItem.id,
                // v2：精听是入口（未开始）；跟读表示已开始学习
                currentSubStage: SubStageType.listenAndRepeat,
                updatedAt: DateTime(2026, 1, 1),
              ),
            },
          ),
        ),
      );
      expect(await progressNotifier.hasResettableLearningData(), isTrue);

      final placeholderNotifier = await loadedNotifier(
        bookmarkDao: TestBookmarkDao(),
        progressNotifier: TestLearningProgressNotifier(
          LearningProgressState(
            progressMap: {
              // v2 默认起点行 currentSubStage = 入口子步骤（逐句精听）
              audioItem.id: LearningProgress(
                audioItemId: audioItem.id,
                currentSubStage: SubStageType.intensiveListen,
                updatedAt: DateTime(2026, 1, 1),
              ),
            },
          ),
        ),
      );
      expect(
        await placeholderNotifier.hasResettableLearningData(),
        isFalse,
        reason: 'ensureProgress 创建的默认起点行不代表用户已有学习进度',
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
          audioItemDaoProvider.overrideWithValue(audioItemDao),
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
  Future<Duration?> loadAudio(
    AudioItem item,
    double speed, {
    String? subtitle,
  }) async => duration;

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
    int sessionId, {
    void Function()? onClipReady,
  }) async {
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
