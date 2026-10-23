import 'package:echo_loop/features/chatbot/sentence_passage.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:flutter_test/flutter_test.dart';

Sentence sentence(int index, String text) => Sentence(
  index: index,
  text: text,
  startTime: Duration(seconds: index),
  endTime: Duration(seconds: index + 1),
);

void main() {
  test('以当前句为锚点，最多包含前五句和后两句', () {
    final sentences = List.generate(10, (index) => sentence(index, 'S$index'));

    expect(
      buildSentencePassage(sentences, currentSentenceIndex: 6),
      'S1\nS2\nS3\nS4\nS5\nS6\nS7\nS8',
    );
  });

  test('材料开头和结尾按现有句子截取', () {
    final sentences = List.generate(4, (index) => sentence(index, 'S$index'));

    expect(
      buildSentencePassage(sentences, currentSentenceIndex: 0),
      'S0\nS1\nS2',
    );
    expect(
      buildSentencePassage(sentences, currentSentenceIndex: 3),
      'S0\nS1\nS2\nS3',
    );
  });

  test('无效位置、当前句为空或没有邻句时回退为无段落', () {
    expect(buildSentencePassage(const [], currentSentenceIndex: 0), isNull);
    expect(
      buildSentencePassage([
        sentence(0, 'Only sentence.'),
      ], currentSentenceIndex: 0),
      isNull,
    );
    expect(
      buildSentencePassage([
        sentence(0, '  '),
        sentence(1, 'Neighbor'),
      ], currentSentenceIndex: 0),
      isNull,
    );
    expect(
      buildSentencePassage([sentence(0, 'A')], currentSentenceIndex: 4),
      isNull,
    );
  });

  test('跳过空白邻句并清理每句首尾空白', () {
    expect(
      buildSentencePassage([
        sentence(0, ' Before '),
        sentence(1, ' Current '),
        sentence(2, '  '),
      ], currentSentenceIndex: 1),
      'Before\nCurrent',
    );
  });

  test('沿完整字幕扫描并跳过空白句补足邻句', () {
    final sentences = [
      sentence(0, 'S0'),
      sentence(1, 'S1'),
      sentence(2, 'S2'),
      sentence(3, ' '),
      sentence(4, 'S4'),
      sentence(5, 'S5'),
      sentence(6, 'S6'),
      sentence(7, 'Current'),
      sentence(8, ' '),
      sentence(9, 'S9'),
      sentence(10, 'S10'),
    ];

    expect(
      buildSentencePassage(sentences, currentSentenceIndex: 7),
      'S1\nS2\nS4\nS5\nS6\nCurrent\nS9\nS10',
    );
  });

  test('解析器按来源音频加载完整字幕，而不是练习筛选列表', () async {
    final sourceSentences = List.generate(
      9,
      (index) => sentence(index, 'S$index'),
    );
    String? requestedAudioItemId;

    final passage = await resolveSentencePassage(
      target: const SentenceChatTarget(
        text: 'S5',
        audioItemId: 'audio-1',
        sentenceIndex: 5,
      ),
      loadSentences: (audioItemId) async {
        requestedAudioItemId = audioItemId;
        return sourceSentences;
      },
    );

    expect(requestedAudioItemId, 'audio-1');
    expect(passage, 'S0\nS1\nS2\nS3\nS4\nS5\nS6\nS7');
  });

  test('来源不完整时不加载字幕并回退单句', () async {
    var loadCalled = false;

    final passage = await resolveSentencePassage(
      target: const SentenceChatTarget(text: 'Current.'),
      loadSentences: (_) async {
        loadCalled = true;
        return [sentence(0, 'Current.')];
      },
    );

    expect(loadCalled, isFalse);
    expect(passage, isNull);
  });

  test('字幕读取失败时回退单句', () async {
    final passage = await resolveSentencePassage(
      target: const SentenceChatTarget(
        text: 'Current.',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
      ),
      loadSentences: (_) async => throw StateError('subtitle unavailable'),
    );

    expect(passage, isNull);
  });
}
