import 'package:flutter/material.dart';

/// 标签预定义颜色板（10 个颜色）
const List<int> kTagColors = [
  0xFFF44336, // Red
  0xFFE91E63, // Pink
  0xFF9C27B0, // Purple
  0xFF3F51B5, // Indigo
  0xFF2196F3, // Blue
  0xFF00BCD4, // Cyan
  0xFF4CAF50, // Green
  0xFFFFC107, // Amber
  0xFFFF9800, // Orange
  0xFF795548, // Brown
];

/// 获取颜色对应的 Color 对象
Color tagColorFromValue(int value) => Color(value);
