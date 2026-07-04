import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dict_speakable_texts.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';

ExampleSentence _ex(String s, [String t = '译文']) =>
    ExampleSentence(sentence: s, translation: t);

DictionaryEntry _entry({
  String headword = 'run',
  List<WordMeaning> meanings = const [],
  List<CommonExpression> commonExpressions = const [],
  List<WordFamilyItem> wordFamily = const [],
}) => DictionaryEntry(
  headword: headword,
  pronunciation: const Pronunciation(uk: '', us: ''),
  meanings: meanings,
  commonExpressions: commonExpressions,
  wordFamily: wordFamily,
  forms: const [],
  etymology: '',
  learnerTips: const [],
);

MultiWordDictionaryEntry _multiEntry() => MultiWordDictionaryEntry(
  originalExpression: 'machine learning',
  naturalness: '',
  category: '术语',
  pronunciationTips: const [],
  keyPoints: const [],
  meanings: const [
    MultiWordMeaning(
      translation: ['机器学习'],
      examples: [
        ExampleSentence(
          sentence: 'Machine learning improves recommendations.',
          translation: '机器学习改善推荐。',
        ),
      ],
    ),
  ],
  similarExpressions: const [
    SimilarExpression(
      expression: 'deep learning',
      difference: '深度学习是机器学习子领域。',
      sentence: 'Deep learning powers image recognition.',
      translation: '深度学习支持图像识别。',
    ),
  ],
  background: '',
);

WordMeaning _meaning(List<ExampleSentence> examples) => WordMeaning(
  partOfSpeech: 'v.',
  translation: const [],
  definition: 'def',
  usageNote: '',
  examples: examples,
  synonyms: const [],
  antonyms: const [],
);

void main() {
  group('dictionarySpeakableTexts', () {
    test('AI 结果按显示顺序提取 headword + 三类例句', () {
      final result = AiDictResult(
        _entry(
          headword: 'run',
          meanings: [
            _meaning([_ex('I run every day.'), _ex('She runs fast.')]),
          ],
          commonExpressions: [
            const CommonExpression(
              expression: 'run out',
              type: 'phrasal verb',
              meaning: '用完',
              example: ExampleSentence(
                sentence: 'We ran out of milk.',
                translation: '我们牛奶用完了。',
              ),
            ),
          ],
          wordFamily: [
            const WordFamilyItem(
              word: 'runner',
              partOfSpeech: 'n.',
              meaning: '跑步者',
              example: ExampleSentence(
                sentence: 'He is a fast runner.',
                translation: '他跑得快。',
              ),
            ),
          ],
        ),
      );

      expect(dictionarySpeakableTexts(result), [
        'run',
        'I run every day.',
        'She runs fast.',
        'We ran out of milk.',
        'He is a fast runner.',
      ]);
    });

    test('本地源仅 headword（无例句）', () {
      final result = LocalDictResult(
        const DictEntry(
          word: 'cat',
          phonetic: '/kæt/',
          translation: 'n. 猫',
          collins: 3,
          examTags: [],
        ),
      );
      expect(dictionarySpeakableTexts(result), ['cat']);
    });

    test('网页源仅 headword', () {
      final result = WebDictResult(
        sourceId: 'cambridge',
        url: Uri.parse('https://dictionary.cambridge.org/x'),
        word: 'dog',
      );
      expect(dictionarySpeakableTexts(result), ['dog']);
    });

    test('空例句句子被剔除', () {
      final result = AiDictResult(
        _entry(
          headword: 'go',
          meanings: [
            _meaning([_ex(''), _ex('   '), _ex('Let us go.')]),
          ],
        ),
      );
      expect(dictionarySpeakableTexts(result), ['go', 'Let us go.']);
    });

    test('重复例句保序去重', () {
      final result = AiDictResult(
        _entry(
          headword: 'see',
          meanings: [
            _meaning([_ex('I see.'), _ex('I see.')]),
          ],
        ),
      );
      expect(dictionarySpeakableTexts(result), ['see', 'I see.']);
    });

    test('AI 多词表达提取 headword + 义项例句 + 相似表达例句', () {
      final result = AiDictResult(_multiEntry());

      expect(dictionarySpeakableTexts(result), [
        'machine learning',
        'Machine learning improves recommendations.',
        'Deep learning powers image recognition.',
      ]);
    });
  });
}
