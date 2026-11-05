/// DictEntry 词典 API 解析测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/dict_entry.dart';

void main() {
  group('DictEntry.fromApiJson', () {
    test('按义项拼成释义行，词性缩写保留，缺词性时无前缀', () {
      final entry = DictEntry.fromApiJson({
        'headword': 'run',
        'phonetic': 'rʌn',
        'definitions': [
          {
            'pos': 'vi',
            'translations': ['跑', '奔'],
            'examples': [],
          },
          {
            'pos': null,
            'translations': ['运行'],
            'examples': [],
          },
        ],
        'collins': 5,
        'tags': ['cet4'],
      });

      expect(entry.word, 'run');
      expect(entry.phonetic, 'rʌn');
      expect(entry.translation, 'vi. 跑, 奔\n运行');
      expect(entry.collins, 5);
      expect(entry.examTags, ['CET4']);
    });

    test('只保留可展示的考试标签，忽略其它来源标签', () {
      final entry = DictEntry.fromApiJson({
        'headword': 'a',
        'definitions': [
          {
            'pos': 'art',
            'translations': ['一个'],
          },
        ],
        'tags': ['zk', 'gk', 'ky', 'gre', 'toefl'],
      });

      expect(entry.examTags, ['GRE', 'TOEFL']);
    });

    test('忽略未知字段与未知词性，后端新增结构不影响解析', () {
      final entry = DictEntry.fromApiJson({
        'headword': 'x',
        'version': 2,
        'brandNewField': {'anything': true},
        'definitions': [
          {
            'pos': 'future-pos',
            'translations': ['新释义'],
            'examples': [
              {'sentence': 'x', 'translation': null, 'extra': 1},
            ],
            'newDefinitionField': 3,
          },
        ],
      });

      expect(entry.translation, 'future-pos. 新释义');
    });

    test('字段类型不符时取默认值而不抛错', () {
      final entry = DictEntry.fromApiJson({
        'headword': 'word',
        'phonetic': 42,
        'collins': 'five',
        'tags': 'cet4',
        'definitions': [
          {
            'pos': 7,
            'translations': ['词'],
          },
        ],
      });

      expect(entry.phonetic, '');
      expect(entry.collins, 0);
      expect(entry.examTags, isEmpty);
      expect(entry.translation, '词');
    });

    test('没有可用释义时抛出 FormatException，不返回空词条', () {
      expect(
        () => DictEntry.fromApiJson({
          'headword': 'empty',
          'definitions': [
            {'pos': 'n', 'translations': <String>[]},
          ],
        }),
        throwsFormatException,
      );
    });

    test('缺少 headword 时抛出 FormatException', () {
      expect(
        () => DictEntry.fromApiJson({
          'definitions': [
            {
              'pos': 'n',
              'translations': ['x'],
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
