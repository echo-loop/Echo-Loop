import 'dart:typed_data';

import 'package:echo_loop/features/profile/data/avatar_image_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidPng({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 80, 40));
  return img.encodePng(image);
}

bool _isJpeg(Uint8List bytes) =>
    bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;

void main() {
  group('prepareAvatarSourceForCrop', () {
    test('超大原图的长边缩小到 1536，保持宽高比', () async {
      final output = await prepareAvatarSourceForCrop(
        _solidPng(width: 3000, height: 1500),
      );

      final decoded = img.decodeImage(output)!;
      expect(decoded.width, 1536);
      expect(decoded.height, 768);
    });

    test('EXIF 方向被烘焙进像素：横向存储的竖拍照片输出为竖向', () async {
      final source = img.Image(width: 200, height: 100);
      source.exif.imageIfd.orientation = 6; // 顺时针旋转 90°
      final sourceBytes = img.encodeJpg(source);

      final output = await prepareAvatarSourceForCrop(sourceBytes);

      final decoded = img.decodeImage(output)!;
      expect(decoded.width, 100);
      expect(decoded.height, 200);
      expect(decoded.exif.imageIfd.orientation, isNot(6));
    });

    test('无法解码的字节抛出 undecodable 异常', () async {
      await expectLater(
        prepareAvatarSourceForCrop(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<AvatarImageException>().having(
            (error) => error.failure,
            'failure',
            AvatarImageFailure.undecodable,
          ),
        ),
      );
    });
  });

  group('encodeAvatarForUpload', () {
    test('输出 512×512 JPEG 且不超过 512KB', () async {
      final output = await encodeAvatarForUpload(
        _solidPng(width: 1024, height: 1024),
      );

      expect(_isJpeg(output), isTrue);
      expect(output.length, lessThanOrEqualTo(avatarMaxBytes));
      final decoded = img.decodeImage(output)!;
      expect(decoded.width, avatarEdgePixels);
      expect(decoded.height, avatarEdgePixels);
    });

    test('小于 512 的裁剪结果也会放大到 512×512', () async {
      final output = await encodeAvatarForUpload(
        _solidPng(width: 100, height: 100),
      );

      final decoded = img.decodeImage(output)!;
      expect(decoded.width, avatarEdgePixels);
      expect(decoded.height, avatarEdgePixels);
    });

    test('圆形裁剪的透明角输出为白色而不是黑色', () async {
      final circle = img.Image(width: 100, height: 100, numChannels: 4);
      img.fill(circle, color: img.ColorRgba8(0, 0, 0, 0));
      img.fillCircle(
        circle,
        x: 50,
        y: 50,
        radius: 50,
        color: img.ColorRgba8(200, 80, 40, 255),
      );

      final output = await encodeAvatarForUpload(img.encodePng(circle));

      final decoded = img.decodeImage(output)!;
      final corner = decoded.getPixel(4, 4);
      expect(corner.r, greaterThan(240));
      expect(corner.g, greaterThan(240));
      expect(corner.b, greaterThan(240));
    });

    test('无法解码的字节抛出 undecodable 异常', () async {
      await expectLater(
        encodeAvatarForUpload(Uint8List.fromList([9, 9, 9])),
        throwsA(
          isA<AvatarImageException>().having(
            (error) => error.failure,
            'failure',
            AvatarImageFailure.undecodable,
          ),
        ),
      );
    });
  });
}
