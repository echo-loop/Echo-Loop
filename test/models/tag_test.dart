import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/tag.dart';

void main() {
  group('Tag', () {
    test('构造函数创建正确的实例', () {
      final tag = Tag(
        id: 'tag-1',
        name: 'Business English',
        colorValue: 0xFFF44336,
        createdDate: DateTime(2026, 1, 1),
      );

      expect(tag.id, 'tag-1');
      expect(tag.name, 'Business English');
      expect(tag.colorValue, 0xFFF44336);
      expect(tag.createdDate, DateTime(2026, 1, 1));
    });

    test('color getter 返回正确的 Color 对象', () {
      final tag = Tag(
        id: 'tag-1',
        name: 'Test',
        colorValue: 0xFF2196F3,
        createdDate: DateTime(2026, 1, 1),
      );

      expect(tag.color, const Color(0xFF2196F3));
    });

    test('copyWith 复制并覆盖指定字段', () {
      final tag = Tag(
        id: 'tag-1',
        name: 'Original',
        colorValue: 0xFFF44336,
        createdDate: DateTime(2026, 1, 1),
      );

      final copied = tag.copyWith(name: 'Renamed', colorValue: 0xFF4CAF50);

      expect(copied.id, 'tag-1');
      expect(copied.name, 'Renamed');
      expect(copied.colorValue, 0xFF4CAF50);
      expect(copied.createdDate, DateTime(2026, 1, 1));
    });

    test('copyWith 无参数时返回相同值的实例', () {
      final tag = Tag(
        id: 'tag-1',
        name: 'Test',
        colorValue: 0xFFF44336,
        createdDate: DateTime(2026, 1, 1),
      );

      final copied = tag.copyWith();

      expect(copied.id, tag.id);
      expect(copied.name, tag.name);
      expect(copied.colorValue, tag.colorValue);
      expect(copied.createdDate, tag.createdDate);
    });
  });
}
