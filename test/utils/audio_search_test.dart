import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/utils/audio_search.dart';
import 'package:flutter_test/flutter_test.dart';

AudioItem _item(String id, {String? name, String? description}) => AudioItem(
  id: id,
  name: name ?? id,
  description: description,
  addedDate: DateTime(2026, 1, 1),
);

Collection _collection(
  String id, {
  String? name,
  String? description,
  String? authorNickname,
}) => Collection(
  id: id,
  name: name ?? id,
  description: description,
  authorNickname: authorNickname,
  createdDate: DateTime(2026, 1, 1),
);

void main() {
  group('filterCollectionsByKeyword', () {
    final collections = [
      _collection('a', name: 'Daily English', description: 'Office talk'),
      _collection('b', name: 'Podcasts', description: 'Long form ENGLISH'),
      _collection('c', name: 'Music', authorNickname: 'English Ann'),
      _collection('d', name: 'History'),
    ];

    test('空关键词或纯空格返回全部合集', () {
      expect(filterCollectionsByKeyword(collections, ''), collections);
      expect(filterCollectionsByKeyword(collections, '   '), collections);
    });

    test('名称、描述或作者任一命中即保留，且保持传入顺序', () {
      final result = filterCollectionsByKeyword(collections, 'english');

      expect(result.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('匹配不区分大小写，正则特殊字符按字面量匹配', () {
      final special = [_collection('x', name: 'C++ (basics)')];

      expect(filterCollectionsByKeyword(special, 'C++').map((e) => e.id), [
        'x',
      ]);
      expect(filterCollectionsByKeyword(special, '.*'), isEmpty);
    });
  });

  group('filterAudioItemsByKeyword', () {
    final items = [
      _item('a', name: 'Coffee Talk', description: 'Ordering at a cafe'),
      _item('b', name: 'Airport', description: 'Check-in and COFFEE break'),
      _item('c', name: 'Weather', description: null),
    ];

    test('空关键词或纯空格返回全部节目', () {
      expect(filterAudioItemsByKeyword(items, ''), items);
      expect(filterAudioItemsByKeyword(items, '   '), items);
    });

    test('标题或描述任一字段命中即保留，且保持原顺序', () {
      final result = filterAudioItemsByKeyword(items, 'coffee');

      expect(result.map((e) => e.id), ['a', 'b']);
    });

    test('匹配不区分大小写', () {
      expect(filterAudioItemsByKeyword(items, 'WEATHER').map((e) => e.id), [
        'c',
      ]);
    });

    test('去除首尾空格后再匹配', () {
      expect(filterAudioItemsByKeyword(items, '  airport  ').map((e) => e.id), [
        'b',
      ]);
    });

    test('描述为空时仅匹配标题', () {
      expect(filterAudioItemsByKeyword(items, 'cafe').map((e) => e.id), ['a']);
      expect(filterAudioItemsByKeyword(items, 'zzz'), isEmpty);
    });

    test('关键词中的正则特殊字符按普通文本匹配', () {
      final special = [_item('x', name: 'C++ (basics)')];

      expect(filterAudioItemsByKeyword(special, 'c++').map((e) => e.id), ['x']);
      expect(filterAudioItemsByKeyword(special, '(basics'), hasLength(1));
      expect(filterAudioItemsByKeyword(special, '.*'), isEmpty);
    });
  });

  group('buildDescriptionSnippet', () {
    test('匹配位置靠前时保留完整描述', () {
      const description = 'Coffee is served hot every morning.';

      expect(buildDescriptionSnippet(description, 'coffee'), description);
    });

    test('无匹配时保留完整描述', () {
      const description = 'Nothing relevant here.';

      expect(buildDescriptionSnippet(description, 'zzz'), description);
    });

    test('匹配位置靠后时截取包含关键词的上下文', () {
      final description = '${'x' * 200} the secret keyword ${'y' * 200}';

      final snippet = buildDescriptionSnippet(description, 'keyword');

      expect(snippet, startsWith('…'));
      expect(snippet, contains('keyword'));
      expect(snippet.length, lessThan(description.length));
    });

    test('换行会压成空格，使第一段之后的命中内容仍在单行内可见', () {
      const description = 'First paragraph.\n\nSecond paragraph has keyword.';

      expect(
        buildDescriptionSnippet(description, 'keyword'),
        'First paragraph. Second paragraph has keyword.',
      );
    });

    test('截取时不会把关键词切掉', () {
      final description = '${'a ' * 100}target';

      final snippet = buildDescriptionSnippet(description, 'target');

      expect(snippet, endsWith('target'));
    });
  });
}
