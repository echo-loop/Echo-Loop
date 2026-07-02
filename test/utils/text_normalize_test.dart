import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/text_normalize.dart';

void main() {
  group('normalizeForCache', () {
    test('去除首尾空白', () {
      expect(normalizeForCache('  hello world  '), 'hello world');
    });

    test('转换为小写', () {
      expect(normalizeForCache('Hello World'), 'hello world');
    });

    test('合并连续空白', () {
      expect(normalizeForCache('hello   world'), 'hello world');
    });

    test('保留尾部标点', () {
      expect(normalizeForCache('hello world.'), 'hello world.');
      expect(normalizeForCache('hello world!'), 'hello world!');
      expect(normalizeForCache('hello world?'), 'hello world?');
      expect(normalizeForCache('hello world;'), 'hello world;');
      expect(normalizeForCache('hello world:'), 'hello world:');
      expect(normalizeForCache('hello world...'), 'hello world...');
    });

    test('不去除中间标点', () {
      expect(normalizeForCache('hello, world'), 'hello, world');
      expect(normalizeForCache("it's a test"), "it's a test");
    });

    test('综合归一化', () {
      expect(normalizeForCache('  Hello,  World!  '), 'hello, world!');
    });

    test('空字符串', () {
      expect(normalizeForCache(''), '');
    });

    test('纯空白字符串', () {
      expect(normalizeForCache('   '), '');
    });
  });

  group('normalizeWord', () {
    test('去除首尾空白', () {
      expect(normalizeWord('  hello  '), 'hello');
    });

    test('一律转小写', () {
      expect(normalizeWord('Hello'), 'hello');
    });

    test('全大写缩写不做特殊保留，统一小写化', () {
      expect(normalizeWord('NASA'), 'nasa');
      expect(normalizeWord('FBI'), 'fbi');
      expect(normalizeWord('COVID-19'), 'covid-19');
    });

    test('剥离首尾标点，保留词内连字符', () {
      expect(normalizeWord('"word"'), 'word');
      expect(normalizeWord('(test)'), 'test');
      expect(normalizeWord('co-op.'), 'co-op');
    });

    test('保留右侧撇号（所有格/缩写）', () {
      expect(normalizeWord("dogs'"), "dogs'");
      expect(normalizeWord("it's"), "it's");
      expect(normalizeWord("library's"), "library's");
      expect(normalizeWord("dogs'."), "dogs'");
    });

    test('弯撇号统一为直撇号（排版文本 I’d → i\'d）', () {
      expect(normalizeWord('I’d'), "i'd");
      expect(normalizeWord('it’s'), "it's");
      expect(normalizeWord('dogs’'), "dogs'");
      expect(normalizeWord('don‘t'), "don't");
    });

    test('空字符串', () {
      expect(normalizeWord(''), '');
    });

    test('词组：内部连续空白折叠为单个空格', () {
      expect(normalizeWord('give  up'), 'give up');
      expect(normalizeWord('give\nup on'), 'give up on');
      expect(normalizeWord('  Look   Forward  To  '), 'look forward to');
    });

    test('词组：剥离首尾标点，保留内部标点', () {
      expect(normalizeWord('"give up"'), 'give up');
      expect(normalizeWord('well, you know.'), 'well, you know');
    });

    test('单词无内部空白，行为不变', () {
      expect(normalizeWord('Hello.'), 'hello');
    });
  });

  group('hashText', () {
    test('相同文本生成相同哈希', () {
      final hash1 = hashText('Hello World');
      final hash2 = hashText('Hello World');
      expect(hash1, hash2);
    });

    test('归一化后相同的文本生成相同哈希', () {
      final hash1 = hashText('Hello World.');
      final hash2 = hashText('  hello   world.  ');
      expect(hash1, hash2);
    });

    test('不同文本生成不同哈希', () {
      final hash1 = hashText('Hello');
      final hash2 = hashText('World');
      expect(hash1, isNot(hash2));
      expect(hashText('Hello.'), isNot(hashText('Hello?')));
    });

    test('哈希值为 64 字符十六进制字符串', () {
      final hash = hashText('test');
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('空字符串也能正常哈希', () {
      final hash = hashText('');
      expect(hash.length, 64);
    });
  });
}
