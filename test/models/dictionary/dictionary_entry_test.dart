import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DictionaryEntry.fromJson', () {
    test('解析完整 v2 结构', () {
      final json = {
        'headword': 'vocabulary',
        'pronunciation': {'uk': 'vəˈkæb.jə.lər.i', 'us': 'vəˈkæb.jə.ler.i'},
        'meanings': [
          {
            'partOfSpeech': 'n.',
            'translation': ['词汇', '词汇量'],
            'definition': 'all the words known and used by a person',
            'usageNote': '不可数名词',
            'examples': [
              {
                'sentence': 'He has a wide vocabulary.',
                'translation': '他词汇量很大。',
              },
            ],
            'synonyms': ['lexicon', 'lexis'],
            'antonyms': <String>[],
          },
        ],
        'commonExpressions': [
          {
            'expression': 'expand one\'s vocabulary',
            'type': 'collocation',
            'meaning': '扩充词汇量',
            'example': {
              'sentence': 'Reading expands your vocabulary.',
              'translation': '阅读扩充词汇量。',
            },
          },
        ],
        'wordFamily': [
          {
            'word': 'vocabular',
            'partOfSpeech': 'adj.',
            'meaning': '词汇的',
            'example': {'sentence': '', 'translation': ''},
          },
        ],
        'forms': [
          {'form': 'vocabularies', 'label': '复数'},
        ],
        'etymology': '源自拉丁语 vocabulum。',
        'learnerTips': ['注意与 word 的区别。', '不可数，无复数。'],
      };

      final entry = DictionaryEntry.fromJson(json);

      expect(entry.headword, 'vocabulary');
      expect(entry.pronunciation.uk, 'vəˈkæb.jə.lər.i');
      expect(entry.pronunciation.us, 'vəˈkæb.jə.ler.i');
      expect(entry.meanings, hasLength(1));
      expect(entry.meanings.first.partOfSpeech, 'n.');
      expect(entry.meanings.first.translation, ['词汇', '词汇量']);
      expect(
        entry.meanings.first.definition,
        'all the words known and used by a person',
      );
      expect(
        entry.meanings.first.examples.first.sentence,
        'He has a wide vocabulary.',
      );
      expect(entry.meanings.first.synonyms, ['lexicon', 'lexis']);
      expect(entry.meanings.first.antonyms, isEmpty);
      expect(
        entry.commonExpressions.first.expression,
        "expand one's vocabulary",
      );
      expect(entry.wordFamily.first.word, 'vocabular');
      expect(entry.wordFamily.first.meaning, '词汇的');
      expect(entry.forms, hasLength(1));
      expect(entry.forms.first.form, 'vocabularies');
      expect(entry.forms.first.label, '复数');
      expect(entry.etymology, '源自拉丁语 vocabulum。');
      expect(entry.learnerTips, ['注意与 word 的区别。', '不可数，无复数。']);
      expect(entry.isEmpty, isFalse);
    });

    test('字段缺失/类型不符回退空串与空列表', () {
      final entry = DictionaryEntry.fromJson({
        'headword': 123, // 类型不符
        'meanings': 'oops', // 类型不符
        // pronunciation/commonExpressions/wordFamily/etymology/learnerTips 全缺
      });

      expect(entry.headword, '');
      expect(entry.pronunciation.uk, '');
      expect(entry.pronunciation.us, '');
      expect(entry.meanings, isEmpty);
      expect(entry.commonExpressions, isEmpty);
      expect(entry.wordFamily, isEmpty);
      expect(entry.forms, isEmpty);
      expect(entry.etymology, '');
      expect(entry.learnerTips, isEmpty);
      expect(entry.isEmpty, isTrue);
    });

    test('learnerTips 非数组回退空列表，wordFamily.meaning 缺失回退空串', () {
      final entry = DictionaryEntry.fromJson({
        'learnerTips': '不是数组', // 类型不符
        'wordFamily': [
          {'word': 'runner', 'partOfSpeech': 'n.'}, // 缺 meaning
        ],
      });

      expect(entry.learnerTips, isEmpty);
      expect(entry.wordFamily.first.meaning, '');
    });

    test('meanings 内含非法元素被过滤', () {
      final entry = DictionaryEntry.fromJson({
        'meanings': [
          'not a map',
          {'partOfSpeech': 'v.', 'definition': '做'},
        ],
      });

      expect(entry.meanings, hasLength(1));
      expect(entry.meanings.first.partOfSpeech, 'v.');
      expect(entry.meanings.first.translation, isEmpty); // 缺 translation 兜底空列表
      expect(entry.meanings.first.usageNote, ''); // 缺失字段兜底
      expect(entry.meanings.first.examples, isEmpty);
    });

    test('translation 非数组回退空列表', () {
      final entry = DictionaryEntry.fromJson({
        'meanings': [
          {'partOfSpeech': 'n.', 'translation': '不是数组', 'definition': 'x'},
        ],
      });
      expect(entry.meanings.first.translation, isEmpty);
    });

    test('forms 非数组回退空列表，form/label 缺失回退空串', () {
      final entry = DictionaryEntry.fromJson({
        'forms': [
          {'form': 'ran'}, // 缺 label
          'not a map', // 非法元素被过滤
        ],
      });
      expect(entry.forms, hasLength(1));
      expect(entry.forms.first.form, 'ran');
      expect(entry.forms.first.label, '');

      final bad = DictionaryEntry.fromJson({'forms': '不是数组'});
      expect(bad.forms, isEmpty);
    });

    test('toJson / fromJson 往返一致', () {
      final json = {
        'headword': 'run',
        'pronunciation': {'uk': 'rʌn', 'us': 'rʌn'},
        'meanings': [
          {
            'partOfSpeech': 'v.',
            'definition': '跑',
            'usageNote': '',
            'examples': [
              {'sentence': 'I run.', 'translation': '我跑。'},
            ],
            'synonyms': <String>[],
            'antonyms': <String>[],
          },
        ],
        'commonExpressions': <Map<String, dynamic>>[],
        'wordFamily': <Map<String, dynamic>>[],
        'etymology': '',
        'learnerTips': <String>[],
      };

      final roundTrip = DictionaryEntry.fromJson(
        DictionaryEntry.fromJson(json).toJson(),
      );

      expect(roundTrip.headword, 'run');
      expect(roundTrip.meanings.first.definition, '跑');
      expect(roundTrip.meanings.first.examples.first.translation, '我跑。');
    });

    test('只有音标也不算空', () {
      final entry = DictionaryEntry.fromJson({
        'pronunciation': {'uk': 'test', 'us': ''},
      });
      expect(entry.isEmpty, isFalse);
    });
  });

  group('AiDictionaryEntry.fromJson', () {
    test('queryType=multi_word 解析新多词表达结构', () {
      final entry = AiDictionaryEntry.fromJson({
        'queryType': 'multi_word',
        'originalExpression': 'pretty busy',
        'naturalness': '',
        'category': '搭配',
        'pronunciationTips': ['pretty 可弱读。'],
        'keyPoints': ['pretty 是程度副词，不是“漂亮”。'],
        'meanings': [
          {
            'translation': ['挺忙的'],
            'examples': [
              {
                'sentence': 'I’m pretty busy this afternoon.',
                'translation': '我今天下午挺忙的。',
              },
            ],
          },
        ],
        'similarExpressions': [
          {
            'expression': 'very busy',
            'difference': '语气更强。',
            'sentence': 'I’m very busy this week.',
            'translation': '我这周非常忙。',
          },
        ],
        'background': '',
      });

      expect(entry, isA<MultiWordDictionaryEntry>());
      final multi = entry as MultiWordDictionaryEntry;
      expect(multi.queryType, AiDictionaryQueryType.multiWord);
      expect(multi.headword, 'pretty busy');
      expect(multi.category, '搭配');
      expect(multi.pronunciationTips, ['pretty 可弱读。']);
      expect(multi.keyPoints, ['pretty 是程度副词，不是“漂亮”。']);
      expect(multi.meanings.first.translation, ['挺忙的']);
      expect(
        multi.meanings.first.examples.first.sentence,
        'I’m pretty busy this afternoon.',
      );
      expect(multi.similarExpressions.first.expression, 'very busy');
      expect(
        multi.similarExpressions.first.sentence,
        'I’m very busy this week.',
      );
      expect(multi.isEmpty, isFalse);
    });

    test('originalExpression 可识别多词表达，兼容 queryType 缺失的新缓存', () {
      final entry = AiDictionaryEntry.fromJson({
        'originalExpression': 'pretty busy',
        'category': '搭配',
      });

      expect(entry, isA<MultiWordDictionaryEntry>());
      expect(entry.headword, 'pretty busy');
    });

    test('旧缓存缺 queryType 默认解析为单词', () {
      final entry = AiDictionaryEntry.fromJson({
        'headword': 'run',
        'meanings': [
          {'partOfSpeech': 'v.', 'definition': 'move fast'},
        ],
      });

      expect(entry, isA<DictionaryEntry>());
      expect(entry.queryType, AiDictionaryQueryType.singleWord);
    });

    test('多词表达字段缺失/类型不符防御性回退', () {
      final entry =
          AiDictionaryEntry.fromJson({
                'queryType': 'multi_word',
                'originalExpression': 123,
                'meanings': 'bad',
                'similarExpressions': [
                  {'expression': 'very busy'},
                  'bad',
                ],
              })
              as MultiWordDictionaryEntry;

      expect(entry.headword, '');
      expect(entry.meanings, isEmpty);
      expect(entry.similarExpressions, hasLength(1));
      expect(entry.similarExpressions.first.expression, 'very busy');
      expect(entry.similarExpressions.first.difference, '');
    });
  });
}
