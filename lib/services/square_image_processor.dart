// 用户选择图片 → 1:1 裁剪 → 512 JPEG 的图片处理，头像与本地合集封面共用。
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 输出边长（像素）。头像与后端建议的 512×512 一致；合集封面最大显示约 72pt，
/// 512 在 3x 屏上仍足够清晰。
const int squareImageEdgePixels = 512;

/// 输出文件上限（字节），取后端单个头像文件上限；封面沿用同一上限即可。
const int squareImageMaxBytes = 512 * 1024;

/// 送入裁剪器的原图长边上限。超大相机照片直接交给裁剪器会占用大量内存，
/// 而输出只有 512 像素，1536 已留足裁剪余量。
const int _cropSourceMaxEdgePixels = 1536;

/// 依次尝试的 JPEG 质量；前者通常已足够小，后者只在极端图片下兜底。
const List<int> _jpegQualities = [85, 70, 55];

enum SquareImageFailure { undecodable, tooLarge }

class SquareImageException implements Exception {
  const SquareImageException(this.failure, {this.cause});

  final SquareImageFailure failure;

  /// 解码失败时保留第三方库抛出的原始错误，便于日志排查。
  final Object? cause;

  @override
  String toString() => 'SquareImageException(${failure.name})';
}

/// 把用户选择的原图整理为裁剪器可用的 JPEG：修正 EXIF 方向并限制长边。
///
/// 在后台 isolate 执行，避免大图解码阻塞 UI。
Future<Uint8List> prepareSquareCropSource(Uint8List sourceBytes) {
  return compute(_prepareSquareCropSource, sourceBytes);
}

/// 把裁剪结果缩放为 512×512 JPEG，并保证不超过 [squareImageMaxBytes]。
///
/// 调用方必须保证输入为正方形裁剪结果（裁剪器以 1:1 圆形或方形框裁剪）；
/// 此处直接拉伸到正方形，非正方形输入会变形。
Future<Uint8List> encodeSquareJpeg(Uint8List croppedBytes) {
  return compute(_encodeSquareJpeg, croppedBytes);
}

Uint8List _prepareSquareCropSource(Uint8List sourceBytes) {
  final decoded = _decodeOrThrow(sourceBytes);
  // bakeOrientation 会把 EXIF 方向烘焙进像素并清除该标记，避免裁剪器与后端再次旋转。
  final upright = img.bakeOrientation(decoded);
  final longestEdge = upright.width > upright.height
      ? upright.width
      : upright.height;
  final scaled = longestEdge <= _cropSourceMaxEdgePixels
      ? upright
      : img.copyResize(
          upright,
          width: upright.width >= upright.height
              ? _cropSourceMaxEdgePixels
              : null,
          height: upright.height > upright.width
              ? _cropSourceMaxEdgePixels
              : null,
        );
  return img.encodeJpg(scaled, quality: 90, chroma: img.JpegChroma.yuv420);
}

Uint8List _encodeSquareJpeg(Uint8List croppedBytes) {
  final decoded = _decodeOrThrow(croppedBytes);
  final square = img.copyResize(
    decoded,
    width: squareImageEdgePixels,
    height: squareImageEdgePixels,
    interpolation: img.Interpolation.average,
  );
  // 圆形裁剪（头像）的结果在圆外是透明像素，JPEG 不支持透明，直接编码会变成黑角，
  // 因此先铺白底再编码。
  final flattened = img.compositeImage(
    img.fill(
      img.Image(width: squareImageEdgePixels, height: squareImageEdgePixels),
      color: img.ColorRgb8(255, 255, 255),
    ),
    square,
  );
  for (final quality in _jpegQualities) {
    final encoded = img.encodeJpg(
      flattened,
      quality: quality,
      chroma: img.JpegChroma.yuv420,
    );
    if (encoded.length <= squareImageMaxBytes) return encoded;
  }
  throw const SquareImageException(SquareImageFailure.tooLarge);
}

img.Image _decodeOrThrow(Uint8List bytes) {
  // 输入来自用户选择的任意文件，属于不可信边界。image 包对截断或损坏的数据
  // 会抛出 ImageException，对过短的输入甚至抛出 RangeError，因此这里统一转为
  // 业务异常，由 UI 提示用户换一张图，而不是把底层异常直接暴露出去。
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) return decoded;
  } on Object catch (error) {
    throw SquareImageException(SquareImageFailure.undecodable, cause: error);
  }
  throw const SquareImageException(SquareImageFailure.undecodable);
}
