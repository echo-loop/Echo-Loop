import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/services/favorites_export/favorites_export_definitions.dart';

void main() {
  group('definitionFromAiEntry 单词', () {
    test('取第一个义项：词性 + 译文拼接，并附第一个例句与 us 音标', () {
      final entry = DictionaryEntry.fromJson({
        'headword': 'kitty',
        'pronunciation': {'uk': 'kiti-uk', 'us': 'kiti-us'},
        'meanings': [
          {
            'partOfSpeech': 'n.',
            'translation': ['小猫', '猫咪'],
            'definition': 'a young cat',
            'examples': [
              {'sentence': 'The kitty is sleeping.', 'translation': '小猫在睡觉。'},
              {'sentence': 'Second example.', 'translation': '第二个例句。'},
            ],
          },
          {
            'partOfSpeech': 'v.',
            'translation': ['忽略'],
            'definition': 'ignored',
            'examples': <Object>[],
          },
        ],
      });

      final definition = definitionFromAiEntry(entry);

      expect(definition?.definition, 'n. 小猫；猫咪');
      expect(definition?.phonetic, 'kiti-us');
      expect(definition?.example?.text, 'The kitty is sleeping.');
      expect(definition?.example?.translation, '小猫在睡觉。');
    });

    test('义项译文为空时回落到英文释义，无例句则 example 为空', () {
      final entry = DictionaryEntry.fromJson({
        'headword': 'run',
        'pronunciation': {'uk': '', 'us': ''},
        'meanings': [
          {
            'partOfSpeech': 'v.',
            'translation': <String>[],
            'definition': 'move fast',
            'examples': <Object>[],
          },
        ],
      });

      final definition = definitionFromAiEntry(entry);

      expect(definition?.definition, 'v. move fast');
      expect(definition?.phonetic, isNull);
      expect(definition?.example, isNull);
    });

    test('义项列表为空返回 null', () {
      final entry = DictionaryEntry.fromJson({
        'headword': 'empty',
        'pronunciation': {'uk': '', 'us': ''},
        'meanings': <Object>[],
      });

      expect(definitionFromAiEntry(entry), isNull);
    });
  });

  group('definitionFromAiEntry 意群', () {
    test('多词表达取第一个义项与其第一个例句，不含音标', () {
      final entry = MultiWordDictionaryEntry.fromJson({
        'headword': 'look up',
        'meanings': [
          {
            'translation': ['查阅'],
            'examples': [
              {'sentence': 'Look up the word.', 'translation': '查一下这个词。'},
            ],
          },
        ],
      });

      final definition = definitionFromAiEntry(entry);

      expect(definition?.definition, '查阅');
      expect(definition?.phonetic, isNull);
      expect(definition?.example?.text, 'Look up the word.');
    });
  });

  group('definitionFromLocalEntry 基础词典', () {
    test('取第一行非空释义与音标，不含例句', () {
      const entry = DictEntry(
        word: 'kitty',
        phonetic: "'kiti",
        translation: 'n. 小猫\nn. 全部赌注',
      );

      final definition = definitionFromLocalEntry(entry);

      expect(definition?.definition, 'n. 小猫');
      expect(definition?.phonetic, "'kiti");
      expect(definition?.example, isNull);
    });

    test('无释义也无音标返回 null；只有音标仍保留', () {
      const empty = DictEntry(word: 'x', phonetic: '  ');
      const phoneticOnly = DictEntry(word: 'y', phonetic: 'waɪ');

      expect(definitionFromLocalEntry(empty), isNull);
      expect(definitionFromLocalEntry(phoneticOnly)?.phonetic, 'waɪ');
      expect(definitionFromLocalEntry(phoneticOnly)?.definition, isNull);
    });
  });
}
