import 'dart:ui';

/// 标签数据模型
class Tag {
  final String id;
  final String name;

  /// 颜色值（存储 Flutter Color.value int）
  final int colorValue;
  final DateTime createdDate;

  Tag({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdDate,
  });

  /// 获取 Flutter Color 对象
  Color get color => Color(colorValue);

  Tag copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdDate,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
