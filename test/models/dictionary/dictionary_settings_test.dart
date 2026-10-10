import 'package:echo_loop/models/dictionary/dictionary_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DictionarySettings', () {
    test('默认值', () {
      final s = DictionarySettings();
      expect(s.defaultSourceId, 'local');
      expect(s.disabledIds, isEmpty);
      expect(s.autoSpeakOnLookup, isTrue);
      expect(s.adFilteringEnabled, isFalse);
    });

    test('toJson / fromJson 往返一致', () {
      final s = DictionarySettings(
        defaultSourceId: 'ai',
        disabledIds: {'cambridge', 'oxford'},
        autoSpeakOnLookup: false,
        adFilteringEnabled: true,
      );
      final back = DictionarySettings.fromJson(s.toJson());
      expect(back.defaultSourceId, 'ai');
      expect(back.disabledIds, {'cambridge', 'oxford'});
      expect(back.autoSpeakOnLookup, isFalse);
      expect(back.adFilteringEnabled, isTrue);
      expect(back, s);
    });

    test('防御性解析：缺字段/类型不符回退缺省', () {
      final s = DictionarySettings.fromJson({
        'defaultSourceId': 42, // 类型不符
        'disabledIds': 'nope', // 类型不符
      });
      expect(s.defaultSourceId, 'local');
      expect(s.disabledIds, isEmpty);
      expect(s.autoSpeakOnLookup, isTrue);
      expect(s.adFilteringEnabled, isFalse);
    });

    test('disabledIds 过滤非字符串元素', () {
      final s = DictionarySettings.fromJson({
        'disabledIds': ['cambridge', 1, null, 'oxford'],
      });
      expect(s.disabledIds, {'cambridge', 'oxford'});
    });

    test('copyWith 保留未改字段', () {
      final s = DictionarySettings(
        defaultSourceId: 'local',
        disabledIds: {'cambridge'},
      );
      final c = s.copyWith(defaultSourceId: 'ai');
      expect(c.defaultSourceId, 'ai');
      expect(c.disabledIds, {'cambridge'});
      expect(c.autoSpeakOnLookup, isTrue);
      expect(c.adFilteringEnabled, isFalse);
    });

    test('disabledIds 不可变（外部修改原集合不影响实例）', () {
      final raw = {'cambridge'};
      final s = DictionarySettings(disabledIds: raw);
      raw.add('oxford');
      expect(s.disabledIds, {'cambridge'});
      expect(() => s.disabledIds.add('x'), throwsUnsupportedError);
    });

    test('值相等与 hashCode 一致（顺序无关）', () {
      final a = DictionarySettings(disabledIds: {'a', 'b'});
      final b = DictionarySettings(disabledIds: {'b', 'a'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
