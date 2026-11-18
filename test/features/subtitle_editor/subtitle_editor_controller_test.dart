import 'dart:io';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/transcript_change_sync_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'subtitle_editor_test_support.dart';

void main() {
  late RangeRecordingBackend audioEngine;
  late ProviderContainer container;
  late ProviderSubscription<SubtitleEditorState> subscription;
  late AudioItem audioItem;
  late List<Sentence> sentences;
  late TranscriptAudioItemDao audioItemDao;

  setUp(() async {
    await useTemporaryAppDataDirectory();
    audioItem = createTestAudioItem(totalDuration: 12);
    audioItemDao = TranscriptAudioItemDao(() => sentences);
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
    audioEngine = RangeRecordingBackend(const Duration(seconds: 12));
    container = ProviderContainer(
      overrides: dedupeOverrides([
        ...subtitleEditorPlaybackOverrides(audioEngine),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
      ]),
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
    expect(state().selectedSentence?.text, sentences.first.text);
    expect(state().playbackPosition, sentences.first.startTime);
    expect(state().selectionEpoch, 0);
  });

  test('媒体打不开时显示加载错误，不进入可编辑状态', () async {
    audioEngine.openError = Exception('无法打开');

    await controller().load();

    expect(state().isLoading, isFalse);
    expect(state().errorMessage, contains('无法打开'));
    expect(state().sentences, isEmpty);
  });

  test('无本地音频时标记音频缺失，而不是波形生成失败', () async {
    final missingAudioItem = audioItem.copyWith(audioPath: null);
    final localContainer = ProviderContainer(
      overrides: dedupeOverrides([
        ...subtitleEditorPlaybackOverrides(
          RangeRecordingBackend(const Duration(seconds: 12)),
        ),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
      ]),
    );
    final localSubscription = localContainer.listen(
      subtitleEditorControllerProvider(missingAudioItem),
      (_, _) {},
      fireImmediately: true,
    );

    try {
      final notifier = localContainer.read(
        subtitleEditorControllerProvider(missingAudioItem).notifier,
      );
      await notifier.load();
      await pumpEventQueue();
      final st = localContainer.read(
        subtitleEditorControllerProvider(missingAudioItem),
      );

      expect(st.waveformAudioMissing, isTrue);
      expect(st.waveformFailed, isFalse);
    } finally {
      localSubscription.close();
      localContainer.dispose();
    }
  });

  test('setPlaybackSpeed 播放中实时转发到底层音频引擎', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.playSentence(0);
    await Future<void>.delayed(Duration.zero);
    await notifier.setPlaybackSpeed(1.5);

    expect(state().playbackSpeed, 1.5);
    expect(audioEngine.rateCalls, contains(1.5));

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
    expect(audioEngine.seekCalls.last, const Duration(seconds: 12));
    expect(audioEngine.playbackEnd, isNull, reason: '定位前撤销区间终点');
    expect(state().playbackPosition, const Duration(seconds: 12));
  });

  test('playSentence 播完单句后撤销区间终点，避免后续播放停在旧句尾', () async {
    final notifier = controller();
    await notifier.load();

    final playback = notifier.playSentence(0);
    await Future<void>.delayed(Duration.zero);
    audioEngine.completePlayback();
    await playback;

    expect(audioEngine.ranges, [(Duration.zero, const Duration(seconds: 4))]);
    expect(audioEngine.playbackEnd, isNull);
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

    expect(audioEngine.ranges, [
      (Duration.zero, const Duration(seconds: 4)),
      (const Duration(seconds: 4), const Duration(seconds: 8)),
    ]);
    expect(audioEngine.playing, isTrue);
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
    expect(audioEngine.playing, isFalse);

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

  group('撤销 / 重做', () {
    test('删除后撤销还原原始字幕，回到未修改；重做再次删除', () async {
      final notifier = controller();
      await notifier.load();
      expect(state().canUndo, isFalse);

      notifier.deleteSentence(1);
      expect(state().sentences.length, 2);
      expect(state().canUndo, isTrue);

      notifier.undo();
      expect(state().sentences.length, 3);
      expect(state().sentences[1].text, 'Second sentence.');
      expect(state().isDirty, isFalse);
      expect(state().isPlaying, isFalse);
      expect(state().canUndo, isFalse);
      expect(state().canRedo, isTrue);

      notifier.redo();
      expect(state().sentences.length, 2);
      expect(state().isDirty, isTrue);
      expect(state().canRedo, isFalse);
    });

    test('一次边界拖动（多帧）只算一步撤销，撤销后选中并居中被改的句子', () async {
      final notifier = controller();
      await notifier.load();
      notifier.selectSentence(1);

      // 拖句 1 末词终点（全局词 3）：多帧移动，松手结束。
      notifier.adjustWord(3, BoundaryEdge.end, const Duration(seconds: 7));
      notifier.adjustWord(
        3,
        BoundaryEdge.end,
        const Duration(milliseconds: 6500),
      );
      notifier.endWordAdjust();
      expect(state().sentences[1].endTime, const Duration(milliseconds: 6500));

      notifier.selectSentence(0);
      final epoch = state().selectionEpoch;
      notifier.undo();

      expect(state().sentences[1].endTime, const Duration(seconds: 8));
      expect(state().selectedSentenceIndex, 1);
      expect(state().selectionEpoch, greaterThan(epoch));
      expect(state().canUndo, isFalse);
      expect(state().isDirty, isFalse);
    });

    test('仅改内部词边界后撤销回原样，不再视为已修改', () async {
      final notifier = controller();
      await notifier.load();

      // 句 0 'First sentence.'：内部边界 = 词 0 终点。
      final before = state().words[0].endTime;
      notifier.adjustWord(
        0,
        BoundaryEdge.end,
        before - const Duration(milliseconds: 300),
      );
      notifier.endWordAdjust();
      expect(state().isDirty, isTrue);

      notifier.undo();
      expect(state().words[0].endTime, before);
      expect(state().isDirty, isFalse);
    });

    test('新编辑清空重做栈', () async {
      final notifier = controller();
      await notifier.load();

      notifier.deleteSentence(2);
      notifier.undo();
      expect(state().canRedo, isTrue);

      notifier.mergeWithNext(0);
      expect(state().canRedo, isFalse);
      notifier.redo();
      expect(state().sentences.length, 2);
      expect(state().sentences[0].text, 'First sentence. Second sentence.');
    });
  });

  test('setWaveformZoomScale 限制缩放范围（1.0 ~ 按音频长度）', () async {
    final notifier = controller();
    await notifier.load();
    notifier.initZoomForViewport(360);

    expect(state().maxWaveformZoomScale, closeTo(10.4987, 0.001));

    notifier.setWaveformZoomScale(20);
    expect(state().waveformZoomScale, closeTo(10.4987, 0.001));

    notifier.setWaveformZoomScale(0.2);
    expect(state().waveformZoomScale, 1.0);
  });

  test('maxWaveformZoomScale 长音频按 5cm/秒自适应，不被固定上限截断', () async {
    final localAudioItem = createTestAudioItem(totalDuration: 1800);
    final localContainer = ProviderContainer(
      overrides: dedupeOverrides([
        ...subtitleEditorPlaybackOverrides(
          RangeRecordingBackend(const Duration(minutes: 30)),
        ),
        audioItemDaoProvider.overrideWithValue(audioItemDao),
      ]),
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
      // 1800s × 5cm/s × 62.992px/cm / 360px ≈ 1574.80，旧固定 300x 会不够。
      expect(st.maxWaveformZoomScale, closeTo(1574.80, 0.01));
    } finally {
      localSubscription.close();
      localContainer.dispose();
    }
  });

  test('initZoomForViewport 按可视区宽度设置初始缩放（每厘米约 1 秒）', () async {
    final notifier = controller();
    await notifier.load(); // totalDuration = 12s

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

  test('initZoomForViewport 同时设置初始缩放和 5cm/秒最大缩放', () async {
    final notifier = controller();
    await notifier.load();

    notifier.initZoomForViewport(360);

    expect(state().waveformZoomScale, closeTo(2.0997, 0.001));
    expect(state().maxWaveformZoomScale, closeTo(10.4987, 0.001));
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
        ),
        const WordTimestamp(
          word: 'finished',
          startTime: Duration(milliseconds: 1100),
          endTime: Duration(milliseconds: 2000),
        ),
        const WordTimestamp(
          word: '3',
          startTime: Duration(milliseconds: 2000),
          endTime: Duration(milliseconds: 2500),
        ),
        const WordTimestamp(
          word: 'reports.',
          startTime: Duration(milliseconds: 2500),
          endTime: Duration(milliseconds: 3900),
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
      expect(audioEngine.ranges, [(words[1].startTime, words[1].endTime)]);

      audioEngine.completePlayback();
      await playback;

      // 播放结束保留点中词，便于继续查看词边界。
      expect(state().isPlaying, isFalse);
      expect(state().focusedWordIndex, 1);
    });

    test('只试听单词（波形点词）：播放该词，播放头始终停在原处', () async {
      final notifier = controller();
      await notifier.load();
      final words = notifier.wordsOfSelectedSentence;
      notifier.scrubTo(const Duration(milliseconds: 300));
      final before = state().playbackPosition;

      final playback = notifier.playWord(1, movesPlayhead: false);
      await Future<void>.delayed(Duration.zero);
      expect(state().playbackMode, SubtitleEditorPlaybackMode.wordAudition);
      expect(state().isPlaying, isTrue);
      expect(state().focusedWordIndex, 1);
      expect(audioEngine.ranges.last.$1, words[1].startTime);
      expect(state().playbackPosition, before);

      // 播放中的位置流与计时器都不移动播放头。
      audioEngine.emitPosition(
        words[1].startTime + const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(state().playbackPosition, before);

      audioEngine.completePlayback();
      await playback;
      expect(state().isPlaying, isFalse);
      expect(state().playbackPosition, before);
      expect(
        audioEngine.playbackEnd,
        isNull,
        reason: '播完必须停止底层播放器并撤销区间终点，否则后续播放会停在词尾',
      );
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

    group('moveWord 整体平移单词', () {
      List<(Duration, Duration)> spans(List<WordTimestamp> words) => [
        for (final w in words) (w.startTime, w.endTime),
      ];

      Future<SubtitleEditorController> load() async {
        sentences
          ..clear()
          ..addAll([
            Sentence(
              index: 0,
              text: 'one two three',
              startTime: const Duration(seconds: 1),
              endTime: const Duration(seconds: 9),
            ),
            Sentence(
              index: 1,
              text: 'next',
              startTime: const Duration(seconds: 12),
              endTime: const Duration(seconds: 14),
            ),
          ]);
        final notifier = controller();
        await notifier.load();
        return notifier;
      }

      test('相接的相邻词共享边界随之移动，不短于最小词长；多帧拖动只算一步撤销', () async {
        final notifier = await load();
        final before = notifier.wordsOfSelectedSentence;
        final length = before[1].endTime - before[1].startTime;

        notifier.moveWord(
          1,
          before[1].startTime + const Duration(milliseconds: 100),
        );
        notifier.moveWord(1, const Duration(seconds: 99));
        notifier.endWordAdjust();
        final after = notifier.wordsOfSelectedSentence;
        expect(after[1].endTime - after[1].startTime, length, reason: '词长不变');
        expect(
          after[2].endTime - after[2].startTime,
          SubtitleEditorController.kMinWordDuration,
          reason: '后一个词被压到最小词长为止',
        );
        expect(after[0].endTime, after[1].startTime, reason: '前一个词跟着变长');
        expect(after[0].startTime, before[0].startTime);
        expect(after[2].endTime, before[2].endTime);
        expect(state().sentences[0].startTime, const Duration(seconds: 1));
        expect(state().isDirty, isTrue);

        notifier.undo();
        expect(spans(notifier.wordsOfSelectedSentence), spans(before));
        expect(state().canUndo, isFalse);
      });

      test('与相邻词有间隙时整体平移，不越过相邻词', () async {
        final notifier = await load();
        // 先把 two 的两端各收进 0.5s，留出间隙。
        final two = notifier.wordsOfSelectedSentence[1];
        notifier.adjustWord(
          1,
          BoundaryEdge.start,
          two.startTime + const Duration(milliseconds: 500),
        );
        notifier.adjustWord(
          1,
          BoundaryEdge.end,
          two.endTime - const Duration(milliseconds: 500),
        );
        notifier.endWordAdjust();
        final before = notifier.wordsOfSelectedSentence;

        notifier.moveWord(1, Duration.zero);
        final after = notifier.wordsOfSelectedSentence;
        expect(after[1].startTime, before[0].endTime, reason: '贴住前一个词为止');
        expect(
          after[1].endTime - after[1].startTime,
          before[1].endTime - before[1].startTime,
        );
        expect(spans(after)..removeAt(1), spans(before)..removeAt(1));
      });

      test('句首词左移带动句子起点，不越过前一句（无前句则 0）', () async {
        final notifier = await load();
        final first = notifier.wordsOfSelectedSentence.first;
        final length = first.endTime - first.startTime;

        notifier.moveWord(0, const Duration(milliseconds: -500));
        expect(state().sentences[0].startTime, Duration.zero);
        expect(state().words[0].startTime, Duration.zero);
        expect(state().words[0].endTime, length);
      });

      test('句末词右移带动句子终点，不越过后一句起点', () async {
        final notifier = await load();
        final last = notifier.wordsOfSelectedSentence.last;
        final length = last.endTime - last.startTime;

        notifier.moveWord(2, const Duration(seconds: 20));
        expect(state().sentences[0].endTime, const Duration(seconds: 12));
        expect(state().words[2].endTime, const Duration(seconds: 12));
        expect(
          state().words[2].startTime,
          const Duration(seconds: 12) - length,
        );
      });
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
      audioItemDao.wordTimestampsStore[audioItem.id] = encodeWordTimestamps(
        const [
          WordTimestamp(
            word: 'one',
            startTime: Duration.zero,
            endTime: Duration(seconds: 1),
          ),
          WordTimestamp(
            word: 'two',
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 2),
          ),
          WordTimestamp(
            word: 'three',
            startTime: Duration(seconds: 2),
            endTime: Duration(seconds: 3),
          ),
        ],
      );
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

    test('highlightedWordIndex 按播放头取词；点词播完后仍是点的词', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      // 进入页面播放头在句首 → 第一个词。
      expect(notifier.highlightedWordIndex, 0);
      notifier.scrubTo(const Duration(milliseconds: 1500));
      expect(notifier.highlightedWordIndex, 1);
      // 句尾不属于任何词。
      notifier.scrubTo(const Duration(seconds: 3));
      expect(notifier.highlightedWordIndex, isNull);

      final playback = notifier.playWord(1);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.highlightedWordIndex, 1);
      audioEngine.completePlayback();
      await playback;
      // 播完播放头停在词尾（= 下一个词的起点），高亮仍是刚播的词。
      expect(state().playbackPosition, const Duration(seconds: 2));
      expect(notifier.highlightedWordIndex, 1);

      // 再定位播放头即按位置取词。
      notifier.scrubTo(const Duration(milliseconds: 2500));
      expect(notifier.highlightedWordIndex, 2);
    });

    test('播放中定位播放头会先停止播放', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      final playback = notifier.playSentence(0);
      await Future<void>.delayed(Duration.zero);
      expect(state().isPlaying, isTrue);

      notifier.scrubTo(const Duration(milliseconds: 500));
      expect(state().isPlaying, isFalse);
      expect(state().playbackPosition, const Duration(milliseconds: 500));
      audioEngine.completePlayback();
      await playback;
      expect(state().playbackPosition, const Duration(milliseconds: 500));
    });

    test('insertWords 在两个紧挨的词之间插词：与前一词按字数分时间，其余不变', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      // 'one' [0,1s] 后插 'big'（各 3 字符）→ one [0,0.5s] + big [0.5s,1s]。
      notifier.insertWords(0, 'big', after: true);

      expect(state().sentences[0].text, 'one big two three');
      final words = notifier.wordsOfSelectedSentence;
      expect(words.map((w) => w.word).toList(), ['one', 'big', 'two', 'three']);
      expect(words[0].endTime, const Duration(milliseconds: 500));
      expect(words[1].startTime, const Duration(milliseconds: 500));
      expect(words[1].endTime, const Duration(seconds: 1));
      expect(words[2].startTime, const Duration(seconds: 1));
      expect(words[3].endTime, const Duration(seconds: 3));
      expect(state().canUndo, isTrue);
    });

    test('insertWords 在首词前插词：从首词借时间，句起不变', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.insertWords(0, 'and', after: false);

      expect(state().sentences[0].text, 'and one two three');
      expect(state().sentences[0].startTime, Duration.zero);
      final words = notifier.wordsOfSelectedSentence;
      expect(words[0].startTime, Duration.zero);
      expect(words[1].endTime, const Duration(seconds: 1));
      expect(words[2].startTime, const Duration(seconds: 1));
    });

    test('insertWords 留空不插入、不记撤销', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.insertWords(1, '   ', after: true);

      expect(state().sentences[0].text, 'one two three');
      expect(state().canUndo, isFalse);
    });

    test('editSentenceText 只给改动的词重新分时间，未改动的词保留原时间', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      // 'two' 改成 'TWO', 末尾加 'four'：one / three 保留原时间。
      notifier.editSentenceText(0, 'one TWO three four');

      expect(state().sentences[0].text, 'one TWO three four');
      final words = notifier.wordsOfSelectedSentence;
      expect(words[0].endTime, const Duration(seconds: 1));
      expect(words[1].startTime, const Duration(seconds: 1));
      expect(words[1].endTime, const Duration(seconds: 2));
      // 句尾新词没有空隙可用，与 three 一起按字数（5:4）分 [2s,3s]。
      expect(words[2].startTime, const Duration(seconds: 2));
      expect(words[3].endTime, const Duration(seconds: 3));
      expect(words[3].startTime, const Duration(milliseconds: 2556));
    });

    test('editSentenceText 删掉首词：句起跟随新首词；清空整句等于删句', () async {
      useSingleSentence();
      sentences.add(
        Sentence(
          index: 1,
          text: 'four five',
          startTime: const Duration(seconds: 3),
          endTime: const Duration(seconds: 5),
        ),
      );
      audioItemDao.wordTimestampsStore.remove(audioItem.id);
      final notifier = controller();
      await notifier.load();

      notifier.editSentenceText(1, 'five');
      expect(state().sentences[1].text, 'five');
      expect(
        state().sentences[1].startTime,
        greaterThan(const Duration(seconds: 3)),
      );

      notifier.editSentenceText(1, '  ');
      expect(state().sentences.length, 1);

      notifier.undo();
      notifier.undo();
      expect(state().sentences[1].text, 'four five');
      expect(state().isDirty, isFalse);
    });

    test('editSentenceText 文字未变时不记撤销', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.editSentenceText(0, ' one  two three ');

      expect(state().canUndo, isFalse);
      expect(state().isDirty, isFalse);
    });

    test('deleteWord 删除中间词', () async {
      useSingleSentence();
      final notifier = controller();
      await notifier.load();

      notifier.deleteWord(1);

      expect(state().sentences[0].text, 'one three');
    });
  });

  group('插入新句', () {
    /// 两句之间留 2s 空隙：[0,2s] 空隙 [2s,4s] [4s,6s]，音频共 12s。
    void useGappedSentences() {
      sentences
        ..clear()
        ..addAll([
          Sentence(
            index: 0,
            text: 'Hello there',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 2),
          ),
          Sentence(
            index: 1,
            text: 'Good bye',
            startTime: const Duration(seconds: 4),
            endTime: const Duration(seconds: 6),
          ),
        ]);
    }

    test('句间空隙可插入；紧挨的两句之间不可插入', () async {
      final notifier = controller();
      await notifier.load();
      // 默认三句首尾相接，句间没有空隙；第 2 句之后到音频结尾也没有。
      expect(notifier.insertSlotNear(0, after: true), isNull);
      expect(notifier.insertSlotNear(0, after: false), isNull);
      expect(notifier.insertSlotNear(2, after: true), isNull);
    });

    test('在下方插入：新句占满空隙并被选中，其余词时间不变，可撤销', () async {
      useGappedSentences();
      final notifier = controller();
      await notifier.load();
      final wordsBefore = List.of(state().words);

      final slot = notifier.insertSlotNear(0, after: true);
      expect(slot, (
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      ));
      notifier.insertSentence(slot!, 'I missed this');

      expect(state().sentences.map((s) => s.text).toList(), [
        'Hello there',
        'I missed this',
        'Good bye',
      ]);
      expect(state().sentences[1].index, 1);
      expect(state().selectedSentenceIndex, 1);
      expect(state().words.length, wordsBefore.length + 3);
      expect(state().words.last.startTime, wordsBefore.last.startTime);

      notifier.undo();
      expect(state().sentences.length, 2);
      expect(state().isDirty, isFalse);
    });

    test('播放头停在空隙时给出插入区间，落在句内时没有', () async {
      useGappedSentences();
      final notifier = controller();
      await notifier.load();

      notifier.scrubTo(const Duration(seconds: 3));
      expect(notifier.insertSlotAtPlayhead, (
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      ));

      notifier.scrubTo(const Duration(seconds: 1));
      expect(notifier.insertSlotAtPlayhead, isNull);

      // 末句之后 [6s,12s] 也是空隙。
      notifier.scrubTo(const Duration(seconds: 9));
      expect(notifier.insertSlotAtPlayhead, (
        start: const Duration(seconds: 6),
        end: const Duration(seconds: 12),
      ));
    });

    test('文字为空时不插入', () async {
      useGappedSentences();
      final notifier = controller();
      await notifier.load();

      notifier.insertSentence((
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      ), '  ');

      expect(state().sentences.length, 2);
      expect(state().canUndo, isFalse);
    });
  });

  group('save 同步学习数据（不再清空）', () {
    late Directory tempDir;
    late _RecordingTranscriptChangeSync transcriptSync;
    late TranscriptAudioItemDao audioItemDao;

    setUp(() async {
      // save() 把字幕内容写入 DB transcript_srt 列（不再落文件）。
      tempDir = await Directory.systemTemp.createTemp('subtitle_save_test');
      appDataDirectoryOverride = tempDir;
      audioItemDao = TranscriptAudioItemDao(() => sentences);
    });

    tearDown(() async {
      appDataDirectoryOverride = null;
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    ProviderContainer saveContainer({
      TestListeningPractice Function()? listeningPractice,
      TestAudioLibrary Function()? audioLibrary,
    }) {
      // 用独立的播放器实例：全局 setUp 的容器已持有共享 backend。
      final c = ProviderContainer(
        overrides: dedupeOverrides([
          ...subtitleEditorPlaybackOverrides(
            RangeRecordingBackend(const Duration(seconds: 12)),
          ),
          audioItemDaoProvider.overrideWithValue(audioItemDao),
          audioLibraryProvider.overrideWith(
            audioLibrary ?? () => TestAudioLibrary(),
          ),
          listeningPracticeProvider.overrideWith(
            listeningPractice ?? () => TestListeningPractice(),
          ),
          transcriptChangeSyncProvider.overrideWith((ref) {
            return transcriptSync = _RecordingTranscriptChangeSync(ref);
          }),
        ]),
      );
      addTearDown(c.dispose);
      // 保持监听，避免 autoDispose 在 await 期间销毁控制器。
      c.listen(subtitleEditorControllerProvider(audioItem), (_, _) {});
      return c;
    }

    test('调整边界后保存：写入 SRT 与词级字幕，并按新旧句子同步学习数据', () async {
      final c = saveContainer();
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      // 句 0 末词 'sentence.' = 全局词 1，起点 → 2s、终点 4s → 3s，句子数量保持 3。
      notifier.adjustWord(1, BoundaryEdge.start, const Duration(seconds: 2));
      notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));
      expect(await notifier.save(), isTrue);

      final savedSrt = audioItemDao.transcriptSrtStore[audioItem.id];
      expect(savedSrt, contains('-->'));
      final savedWords = decodeWordTimestamps(
        audioItemDao.wordTimestampsStore[audioItem.id]!,
      )!;
      expect(savedWords.map((w) => w.word).take(2), ['First', 'sentence.']);
      expect(savedWords[1].startTime, const Duration(seconds: 2));
      expect(savedWords.first.startTime, Duration.zero);
      expect(savedWords.last.endTime, const Duration(seconds: 12));

      final call = transcriptSync.calls.single;
      expect(call.audioItemId, audioItem.id);
      expect(call.oldSentences.map((s) => s.endTime).first, seconds(4));
      expect(call.newSentences.map((s) => s.endTime).first, seconds(3));
      expect(call.newSentences, hasLength(3));
    });

    test('删除句子后保存：同步而不清空，第二次保存以上次保存为基线', () async {
      final c = saveContainer();
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      notifier.deleteSentence(1);
      expect(await notifier.save(), isTrue);
      notifier.deleteSentence(0);
      expect(await notifier.save(), isTrue);

      expect(transcriptSync.calls, hasLength(2));
      final first = transcriptSync.calls.first;
      expect(first.oldSentences.map((s) => s.text), [
        'First sentence.',
        'Second sentence.',
        'Third sentence.',
      ]);
      expect(first.newSentences.map((s) => s.text), [
        'First sentence.',
        'Third sentence.',
      ]);
      expect(first.newSentences.map((s) => s.index), [
        0,
        1,
      ], reason: '新句子以落库的 SRT 重新解析，索引即列表位置');
      final second = transcriptSync.calls.last;
      expect(second.oldSentences.map((s) => s.text), [
        'First sentence.',
        'Third sentence.',
      ]);
      expect(second.newSentences.map((s) => s.text), ['Third sentence.']);
    });

    test('同步后的步骤失败：可重试保存，且不会按旧基线重复换算学习断点', () async {
      final library = _FailingOnceAudioLibrary();
      final c = saveContainer(audioLibrary: () => library);
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      SubtitleEditorState current() =>
          c.read(subtitleEditorControllerProvider(audioItem));
      await notifier.load();

      notifier.deleteSentence(1);
      expect(await notifier.save(), isFalse, reason: '素材库更新失败');
      expect(current().isDirty, isTrue, reason: '失败后仍可重试保存');
      expect(current().errorMessage, isNotNull);

      expect(await notifier.save(), isTrue);
      expect(current().isDirty, isFalse);
      expect(transcriptSync.calls, hasLength(2));
      final retry = transcriptSync.calls.last;
      expect(
        retry.oldSentences.map((s) => s.text),
        retry.newSentences.map((s) => s.text),
        reason: '首次同步已完成，重试以已保存字幕为基线（不再换算）',
      );
      expect(retry.newSentences, hasLength(2));
    });

    test('保存成功后重置字幕基线，未继续修改时不再保存', () async {
      final c = saveContainer();
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      // 句0 末词 'sentence.' = 全局词 1，前移其终点 4s → 3s。
      notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));
      expect(c.read(subtitleEditorControllerProvider(audioItem)).isDirty, true);

      expect(await notifier.save(), isTrue);
      expect(
        c.read(subtitleEditorControllerProvider(audioItem)).isDirty,
        false,
      );
      expect(await notifier.save(), isFalse);
      expect(transcriptSync.calls, hasLength(1));
    });

    test('保存后仍可撤销，撤销后相对保存版本为已修改', () async {
      final c = saveContainer();
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      SubtitleEditorState current() =>
          c.read(subtitleEditorControllerProvider(audioItem));
      await notifier.load();

      notifier.adjustWord(1, BoundaryEdge.end, const Duration(seconds: 3));
      notifier.endWordAdjust();
      expect(await notifier.save(), isTrue);
      expect(current().isDirty, isFalse);
      expect(current().canUndo, isTrue);

      notifier.undo();
      expect(current().sentences[0].endTime, const Duration(seconds: 4));
      expect(current().isDirty, isTrue);
    });

    test('LP 正持有该音频时，保存后以 forceTranscriptReload 重载', () async {
      // 字幕原地改写同名 SRT，id/transcriptPath 不变。loadAudio 去重守卫只比 id+path，
      // 不强制重载会命中守卫跳过解析，使自由练习/盲听显示陈旧拆分句子。
      final recordingLp = _RecordingListeningPractice(
        ListeningPracticeState(currentAudioItem: audioItem),
      );
      final c = saveContainer(listeningPractice: () => recordingLp);
      final notifier = c.read(
        subtitleEditorControllerProvider(audioItem).notifier,
      );
      await notifier.load();

      notifier.deleteSentence(2);
      expect(await notifier.save(), isTrue);

      expect(recordingLp.loadAudioForceFlags, isNotEmpty, reason: '应触发 LP 重载');
      expect(
        recordingLp.loadAudioForceFlags.last,
        isTrue,
        reason: '必须强制重载以绕过 loadAudio 的 id+path 去重守卫',
      );
    });
  });
}

Duration seconds(int value) => Duration(seconds: value);

/// 第一次更新素材库时失败，模拟字幕已落库、同步已完成后的后续步骤出错。
class _FailingOnceAudioLibrary extends TestAudioLibrary {
  bool _failed = false;

  @override
  Future<void> updateAudioItem(AudioItem updatedItem) async {
    if (!_failed) {
      _failed = true;
      throw StateError('library update failed');
    }
    await super.updateAudioItem(updatedItem);
  }
}

/// 记录字幕保存后的学习数据同步请求，同步本身由 TranscriptChangeSync 的测试覆盖。
class _RecordingTranscriptChangeSync extends TranscriptChangeSync {
  _RecordingTranscriptChangeSync(super.ref);

  final calls =
      <
        ({
          String audioItemId,
          List<Sentence> oldSentences,
          List<Sentence> newSentences,
        })
      >[];

  @override
  Future<void> apply(
    String audioItemId, {
    required List<Sentence> oldSentences,
    required List<Sentence> newSentences,
  }) async {
    calls.add((
      audioItemId: audioItemId,
      oldSentences: oldSentences,
      newSentences: newSentences,
    ));
  }
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
