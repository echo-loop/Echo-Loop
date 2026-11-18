import 'dart:io';
import 'dart:math';

import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/services/subtitle_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'subtitle_editor_test_support.dart';

/// 字幕与词级时间的不变量：任何编辑序列之后都必须成立，否则保存出的字幕或
/// 词级时间就是错的。
void expectConsistent(SubtitleEditorState state, String step) {
  final sentences = state.sentences;
  final tokens = [
    for (final sentence in sentences)
      ...sentence.text.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty),
  ];
  expect(
    state.words.map((w) => w.word).toList(),
    tokens,
    reason: '$step：词列表应与句子文字逐词一致',
  );
  var offset = 0;
  for (var i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    expect(sentence.index, i, reason: '$step：句子序号应连续');
    expect(sentence.text.trim(), isNotEmpty, reason: '$step：不应出现空句');
    expect(
      sentence.endTime,
      greaterThanOrEqualTo(sentence.startTime),
      reason: '$step：第 $i 句起止颠倒',
    );
    if (i > 0) {
      expect(
        sentence.startTime,
        greaterThanOrEqualTo(sentences[i - 1].endTime),
        reason: '$step：第 $i 句与上一句重叠或乱序',
      );
    }
    final count = sentence.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .length;
    final words = state.words.sublist(offset, offset + count);
    offset += count;
    expect(
      words.first.startTime,
      sentence.startTime,
      reason: '$step：第 $i 句首词应贴句首',
    );
    expect(words.last.endTime, sentence.endTime, reason: '$step：第 $i 句末词应贴句尾');
    for (var k = 0; k < words.length; k++) {
      expect(
        words[k].endTime,
        greaterThanOrEqualTo(words[k].startTime),
        reason: '$step：第 $i 句第 $k 词起止颠倒',
      );
      if (k > 0) {
        expect(
          words[k].startTime,
          greaterThanOrEqualTo(words[k - 1].endTime),
          reason: '$step：第 $i 句第 $k 词与前一词重叠',
        );
      }
    }
  }
}

String describeWords(List<WordTimestamp> words) => [
  for (final w in words)
    '${w.word}@${w.startTime.inMilliseconds}-${w.endTime.inMilliseconds}',
].join(' ');

void main() {
  const demo = 'assets/demo/B1 - Work-life balance';

  // 多个固定种子：覆盖不同的操作组合，失败时可按种子复现。
  for (final seed in [20261117, 1, 42, 7, 2024]) {
    test('随机编辑序列（种子 $seed）：每一步数据自洽；全部撤销回到原样，全部重做回到最终结果', () async {
      final sentences = await SubtitleParser.parseSubtitleString(
        File('$demo.srt').readAsStringSync(),
      );
      final duration = sentences.last.endTime + const Duration(seconds: 3);
      final item = createTestAudioItem(totalDuration: duration.inSeconds + 1);
      await useTemporaryAppDataDirectory();
      final dao = TestAudioItemDao();
      dao.transcriptSrtStore[item.id] = File('$demo.srt').readAsStringSync();
      dao.wordTimestampsStore[item.id] = File('$demo.words.json')
          .readAsStringSync();
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          ...subtitleEditorPlaybackOverrides(RangeRecordingBackend(duration)),
          audioItemDaoProvider.overrideWithValue(dao),
        ]),
      );
      addTearDown(container.dispose);
      final provider = subtitleEditorControllerProvider(item);
      container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      SubtitleEditorState state() => container.read(provider);

      await controller.load();
      expectConsistent(state(), '加载');
      final originalSentences = state().sentences;
      final originalWords = describeWords(state().words);

      final random = Random(seed);
      const vocabulary = ['really', 'very', 'and', 'so', 'well,', 'OK.'];
      String randomWord() => vocabulary[random.nextInt(vocabulary.length)];
      final operations = <String, void Function()>{
        'editWord': () {
          final words = controller.wordsOfSelectedSentence;
          if (words.isEmpty) return;
          controller.editWord(random.nextInt(words.length), randomWord());
        },
        'insertWords': () {
          final words = controller.wordsOfSelectedSentence;
          if (words.isEmpty) return;
          controller.insertWords(
            random.nextInt(words.length),
            '${randomWord()} ${randomWord()}',
            after: random.nextBool(),
          );
        },
        'deleteWord': () {
          final words = controller.wordsOfSelectedSentence;
          if (words.isEmpty) return;
          controller.deleteWord(random.nextInt(words.length));
        },
        'editSentenceText': () {
          final index = state().selectedSentenceIndex!;
          final tokens = state().sentences[index].text.split(' ');
          // 改一个词、删一个词、在随机位置加一个词。
          tokens[random.nextInt(tokens.length)] = randomWord();
          if (tokens.length > 2) tokens.removeAt(random.nextInt(tokens.length));
          tokens.insert(random.nextInt(tokens.length + 1), randomWord());
          controller.editSentenceText(index, tokens.join(' '));
        },
        'split': () {
          final words = controller.wordsOfSelectedSentence;
          if (words.length < 2) return;
          controller.splitSentenceAtWord(1 + random.nextInt(words.length - 1));
        },
        'merge': () =>
            controller.mergeWithNext(random.nextInt(state().sentences.length)),
        'delete': () =>
            controller.deleteSentence(random.nextInt(state().sentences.length)),
        'insertSentence': () {
          final index = random.nextInt(state().sentences.length);
          final slot = controller.insertSlotNear(
            index,
            after: random.nextBool(),
          );
          if (slot != null) controller.insertSentence(slot, 'New line here.');
        },
        'insertAtPlayhead': () {
          controller.scrubTo(
            Duration(milliseconds: random.nextInt(duration.inMilliseconds)),
          );
          final slot = controller.insertSlotAtPlayhead;
          if (slot != null) controller.insertSentence(slot, 'Missed words.');
        },
        'drag': () {
          final words = state().words;
          final index = random.nextInt(words.length);
          final edge = random.nextBool()
              ? BoundaryEdge.start
              : BoundaryEdge.end;
          final base = edge == BoundaryEdge.start
              ? words[index].startTime
              : words[index].endTime;
          // 多帧拖动，越界由控制器钳制。
          for (var frame = 1; frame <= 3; frame++) {
            controller.adjustWord(
              index,
              edge,
              base +
                  Duration(milliseconds: (random.nextInt(1200) - 600) * frame),
            );
          }
          controller.endWordAdjust();
        },
        'undo': controller.undo,
        'redo': controller.redo,
      };
      final names = operations.keys.toList();

      for (var step = 0; step < 150; step++) {
        controller.selectSentence(random.nextInt(state().sentences.length));
        final name = names[random.nextInt(names.length)];
        operations[name]!();
        expectConsistent(state(), '第 $step 步 $name');
      }

      // 记录最终结果，再全部撤销，然后重做同样步数回到最终结果（序列可能以撤销结尾，
      // 重做栈里还有更靠后的步骤，故不能「重做到底」）。
      final finalSentences = state().sentences;
      final finalWords = describeWords(state().words);
      var undoCount = 0;
      while (state().canUndo) {
        controller.undo();
        undoCount++;
        expectConsistent(state(), '撤销第 $undoCount 步');
      }
      expect(undoCount, greaterThan(50), reason: '随机序列应产生足够多的编辑');
      expect(state().sentences, hasLength(originalSentences.length));
      for (var i = 0; i < originalSentences.length; i++) {
        expect(state().sentences[i].text, originalSentences[i].text);
        expect(state().sentences[i].startTime, originalSentences[i].startTime);
        expect(state().sentences[i].endTime, originalSentences[i].endTime);
      }
      expect(describeWords(state().words), originalWords);
      expect(state().isDirty, isFalse, reason: '全部撤销后应视为未修改');

      for (var i = 0; i < undoCount; i++) {
        controller.redo();
      }
      expect(
        state().sentences.map((s) => '${s.text}|${s.startTime}|${s.endTime}'),
        finalSentences.map((s) => '${s.text}|${s.startTime}|${s.endTime}'),
      );
      expect(describeWords(state().words), finalWords);
    });
  }
}
