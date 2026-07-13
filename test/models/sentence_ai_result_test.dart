import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';

void main() {
  group('SentenceTranslation', () {
    test('fromJson 正确解析翻译字段', () {
      final json = {'translation': '这是一个测试句子。'};
      final result = SentenceTranslation.fromJson(json);
      expect(result.translation, '这是一个测试句子。');
    });

    test('fromJson 处理空翻译', () {
      final json = {'translation': ''};
      final result = SentenceTranslation.fromJson(json);
      expect(result.translation, '');
    });

    test('fromJson 防御性：缺 translation 字段回退空串，不抛（流式半成品帧）', () {
      final json = <String, dynamic>{'other': 'value'};
      expect(SentenceTranslation.fromJson(json).translation, '');
    });

    test('fromJson 防御性：translation 非字符串回退空串', () {
      expect(
        SentenceTranslation.fromJson(<String, dynamic>{
          'translation': 42,
        }).translation,
        '',
      );
    });

    test('const 构造函数支持相等比较', () {
      const a = SentenceTranslation(translation: 'hello');
      const b = SentenceTranslation(translation: 'hello');
      // const 对象是同一实例
      expect(identical(a, b), isTrue);
    });
  });

  group('SentenceAnalysis', () {
    test('fromJson 正确解析顶层结构化数组', () {
      final json = {
        'grammar': [
          {'point': '主谓宾', 'note': '核心结构'},
        ],
        'vocabulary': [
          {'term': 'run', 'note': '经营'},
        ],
        'listening': [
          {'phrase': 'did you', 'note': '连读为 /dɪdʒuː/'},
        ],
      };
      final result = SentenceAnalysis.fromJson(json);
      expect(result.grammar.single.point, '主谓宾');
      expect(result.grammar.single.note, '核心结构');
      expect(result.vocabulary.single.term, 'run');
      expect(result.listening.single.phrase, 'did you');
      expect(result.isNotEmpty, isTrue);
    });

    test('fromJson 防御性：缺字段回退空列表，永不抛', () {
      final result = SentenceAnalysis.fromJson(<String, dynamic>{});
      expect(result.grammar, isEmpty);
      expect(result.vocabulary, isEmpty);
      expect(result.listening, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('fromJson 防御性：半成品快照（缺 note / null 元素）不抛', () {
      final json = {
        'grammar': [
          {'point': '主谓宾'}, // note 尚未到达
          null, // 流式 null 占位
        ],
      };
      final result = SentenceAnalysis.fromJson(json);
      expect(result.grammar.single.point, '主谓宾');
      expect(result.grammar.single.note, '');
    });

    test('toJson 与 fromJson 对称（L2 缓存往返）', () {
      const original = SentenceAnalysis(
        grammar: [GrammarPoint(point: 'p', note: 'e')],
        vocabulary: [VocabularyItem(term: 't', note: 'n')],
        listening: [ListeningPoint(phrase: 'ph', note: 'no')],
      );
      final round = SentenceAnalysis.fromJson(original.toJson());
      expect(round.grammar.single.point, 'p');
      expect(round.vocabulary.single.note, 'n');
      expect(round.listening.single.phrase, 'ph');
    });

    test('isEmpty：全空要点视为空', () {
      const empty = SentenceAnalysis(
        grammar: [GrammarPoint(point: '', note: '')],
      );
      expect(empty.isEmpty, isTrue);
    });

    test('文本投影 grammarText/vocabularyText/listeningText', () {
      const analysis = SentenceAnalysis(
        grammar: [
          GrammarPoint(point: '主谓宾', note: '核心结构'),
          GrammarPoint(point: '定语从句', note: '修饰名词'),
        ],
        vocabulary: [VocabularyItem(term: 'run', note: '经营')],
        listening: [ListeningPoint(phrase: '', note: '仅详解')],
      );
      expect(analysis.grammarText, '主谓宾: 核心结构\n定语从句: 修饰名词');
      expect(analysis.vocabularyText, 'run: 经营');
      expect(analysis.listeningText, '仅详解');
    });
  });
}
