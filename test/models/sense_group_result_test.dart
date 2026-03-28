/// SenseGroupResult / SenseGroup 模型单元测试
///
/// 验证意群拆分结果的 JSON 反序列化和序列化逻辑。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/sense_group_result.dart';

void main() {
  group('SenseGroup', () {
    test('fromJson 正确解析意群字段', () {
      final json = {'text': 'in the morning', 'isCore': true};
      final sg = SenseGroup.fromJson(json);

      expect(sg.text, 'in the morning');
      expect(sg.isCore, true);
    });

    test('toJson 正确序列化', () {
      const sg = SenseGroup(text: 'at night', isCore: false);
      final json = sg.toJson();

      expect(json, {'text': 'at night', 'isCore': false});
    });

    test('fromJson / toJson 往返一致', () {
      final original = {'text': 'have been working', 'isCore': true};
      final sg = SenseGroup.fromJson(original);
      final restored = sg.toJson();

      expect(restored, original);
    });

    test('fromJson 处理空字符串', () {
      final json = {'text': '', 'isCore': false};
      final sg = SenseGroup.fromJson(json);

      expect(sg.text, '');
      expect(sg.isCore, false);
    });

    test('fromJson 缺少 isCore 字段时默认 false', () {
      final json = <String, dynamic>{'text': 'only text'};
      final sg = SenseGroup.fromJson(json);

      expect(sg.text, 'only text');
      expect(sg.isCore, false);
    });

    test('const 构造函数 isCore 默认值为 false', () {
      const sg = SenseGroup(text: 'hello');
      expect(sg.text, 'hello');
      expect(sg.isCore, false);
    });

    test('const 构造函数支持指定 isCore', () {
      const sg = SenseGroup(text: 'hello', isCore: true);
      expect(sg.isCore, true);
    });
  });

  group('SenseGroupResult', () {
    test('fromJson 正确解析典型 API 响应', () {
      final json = {
        'groups': [
          {'text': 'I have been', 'isCore': false},
          {'text': 'working hard', 'isCore': true},
          {'text': 'since last month', 'isCore': false},
        ],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups.length, 3);
      expect(result.groups[0].text, 'I have been');
      expect(result.groups[0].isCore, false);
      expect(result.groups[1].text, 'working hard');
      expect(result.groups[1].isCore, true);
      expect(result.groups[2].text, 'since last month');
    });

    test('fromJson 处理空意群列表', () {
      final json = {'groups': <dynamic>[]};
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups, isEmpty);
    });

    test('fromJson 处理单个意群', () {
      final json = {
        'groups': [
          {'text': 'Hello', 'isCore': true},
        ],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups.length, 1);
      expect(result.groups[0].text, 'Hello');
      expect(result.groups[0].isCore, true);
    });

    test('fromJson 缺少 groups 字段时抛出异常', () {
      final json = <String, dynamic>{'other': 'value'};
      expect(
        () => SenseGroupResult.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromJson 解析含标点的意群文本', () {
      final json = {
        'groups': [
          {'text': 'Well,', 'isCore': false},
          {'text': 'I think so.', 'isCore': true},
        ],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups[0].text, 'Well,');
      expect(result.groups[1].text, 'I think so.');
      expect(result.groups[1].isCore, true);
    });
  });
}
