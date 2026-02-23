import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/models/tag.dart';

void main() {
  group('TagState', () {
    test('默认状态', () {
      const state = TagState();
      expect(state.tags, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.audioIdsMap, isEmpty);
      expect(state.isEmpty, isTrue);
    });

    test('getAudioIds 返回标签关联的音频', () {
      final state = TagState(
        audioIdsMap: {
          't1': ['a1', 'a2'],
        },
      );
      expect(state.getAudioIds('t1'), ['a1', 'a2']);
      expect(state.getAudioIds('t2'), isEmpty);
    });

    test('audioToTagsMap 返回正确的反向索引', () {
      final state = TagState(
        audioIdsMap: {
          't1': ['a1', 'a2'],
          't2': ['a2', 'a3'],
        },
      );

      final reverse = state.audioToTagsMap;
      expect(reverse['a1'], ['t1']);
      expect(reverse['a2'], containsAll(['t1', 't2']));
      expect(reverse['a3'], ['t2']);
    });

    test('copyWith 正确复制', () {
      final tag = Tag(
        id: 't1',
        name: 'Tag 1',
        colorValue: 0xFFF44336,
        createdDate: DateTime(2026, 1, 1),
      );
      final state = TagState(tags: [tag]);

      final copied = state.copyWith(isLoading: true);
      expect(copied.tags.length, 1);
      expect(copied.isLoading, isTrue);
    });
  });
}
