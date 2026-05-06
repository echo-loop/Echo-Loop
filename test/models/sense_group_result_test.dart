/// SenseGroupResult 模型单元测试
///
/// 验证意群拆分结果（双粒度：medium + fine）的 JSON 反序列化和序列化逻辑。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sense_group_result.dart';

void main() {
  group('SenseGroupResult', () {
    test('fromJson 正确解析典型 API 响应', () {
      final json = {
        'medium': ['I have been', 'working hard', 'since last month'],
        'fine': ['I', 'have been', 'working', 'hard', 'since last month'],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.medium.length, 3);
      expect(result.medium[0], 'I have been');
      expect(result.medium[1], 'working hard');
      expect(result.medium[2], 'since last month');
      expect(result.fine.length, 5);
    });

    test('fromJson 处理空意群列表', () {
      final json = {
        'medium': <dynamic>[],
        'fine': <dynamic>[],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.medium, isEmpty);
      expect(result.fine, isEmpty);
    });

    test('fromJson 处理缺少字段时返回空列表', () {
      final json = <String, dynamic>{};
      final result = SenseGroupResult.fromJson(json);

      expect(result.medium, isEmpty);
      expect(result.fine, isEmpty);
    });

    test('toJson 正确序列化', () {
      const result = SenseGroupResult(
        medium: ['Hello', 'World'],
        fine: ['Hello', 'World'],
      );
      final json = result.toJson();

      expect(json['medium'], ['Hello', 'World']);
      expect(json['fine'], ['Hello', 'World']);
    });

    test('fromJson / toJson 往返一致', () {
      final original = {
        'medium': ['test medium'],
        'fine': ['test fine'],
      };
      final result = SenseGroupResult.fromJson(original);
      final restored = result.toJson();

      expect(restored['medium'], original['medium']);
      expect(restored['fine'], original['fine']);
    });

    test('areBothEqual 当两种粒度相同时返回 true', () {
      const result = SenseGroupResult(
        medium: ['same', 'content'],
        fine: ['same', 'content'],
      );
      expect(result.areBothEqual, true);
    });

    test('areBothEqual 当长度不同时返回 false', () {
      const result = SenseGroupResult(
        medium: ['same', 'content'],
        fine: ['same'],
      );
      expect(result.areBothEqual, false);
    });

    test('areBothEqual 当内容不同时返回 false', () {
      const result = SenseGroupResult(
        medium: ['same', 'content'],
        fine: ['same', 'different'],
      );
      expect(result.areBothEqual, false);
    });
  });
}