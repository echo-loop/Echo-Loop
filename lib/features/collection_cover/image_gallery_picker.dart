import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// 从系统相册 / 文件选择器选一张图片，返回原始字节；用户取消返回 null。
typedef ImageGalleryPicker = Future<Uint8List?> Function();

/// 系统选图入口。抽成 provider 是因为集成测试无法驱动系统相册，需要替换为测试图片。
final imageGalleryPickerProvider = Provider<ImageGalleryPicker>(
  (ref) => _pickFromGallery,
);

Future<Uint8List?> _pickFromGallery() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  return picked?.readAsBytes();
}
