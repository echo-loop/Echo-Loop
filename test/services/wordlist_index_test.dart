import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/dictionary/wordlist_index.dart';

void main() {
  group('parseWordlist', () {
    test('转小写、去空行、去重并保持升序', () {
      final words = parseWordlist('Banana\n\napple \napple\n  cherry\n');

      expect(words, ['apple', 'banana', 'cherry']);
    });

    test('丢弃带撇号的所有格形式', () {
      final words = parseWordlist("aa\naa's\naachen's\naardvark");

      expect(words, ['aa', 'aardvark']);
    });
  });

  group('WordlistIndex.suggest', () {
    final index = WordlistIndex(
      parseWordlist('app\napple\napplication\napply\napricot\nbanana'),
    );

    test('按前缀返回候选词（大小写不敏感）', () {
      expect(index.suggest('APP'), ['app', 'apple', 'application', 'apply']);
    });

    test('最多返回 8 条', () {
      final many = WordlistIndex(
        parseWordlist(List.generate(20, (i) => 'word$i').join('\n')),
      );

      expect(many.suggest('word'), hasLength(kWordlistSuggestionLimit));
    });

    test('无匹配或空输入返回空列表', () {
      expect(index.suggest('zzz'), isEmpty);
      expect(index.suggest('   '), isEmpty);
    });

    test('前缀长于所有候选时不会越界', () {
      expect(index.suggest('bananas'), isEmpty);
    });
  });
}
