import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/audio_fingerprint.dart';

void main() {
  group('computeAudioSha256', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sha256_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('对同一文件多次计算结果一致', () async {
      final file = File('${tempDir.path}/test.mp3');
      file.writeAsBytesSync(List.generate(1024, (i) => i % 256));

      final hash1 = await computeAudioSha256(file.path);
      final hash2 = await computeAudioSha256(file.path);
      expect(hash1, hash2);
    });

    test('对不同内容文件结果不同', () async {
      final file1 = File('${tempDir.path}/a.mp3');
      file1.writeAsBytesSync([1, 2, 3]);

      final file2 = File('${tempDir.path}/b.mp3');
      file2.writeAsBytesSync([4, 5, 6]);

      final hash1 = await computeAudioSha256(file1.path);
      final hash2 = await computeAudioSha256(file2.path);
      expect(hash1, isNot(hash2));
    });

    test('空文件不报错', () async {
      final file = File('${tempDir.path}/empty.mp3');
      file.writeAsBytesSync([]);

      final hash = await computeAudioSha256(file.path);
      expect(hash, isNotEmpty);
      // SHA256 of empty input is well-known
      expect(
        hash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('文件不存在时抛出异常', () async {
      expect(
        () => computeAudioSha256('${tempDir.path}/nonexistent.mp3'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('跨多个 64KB 分块的文件与一次性计算结果一致', () async {
      final bytes = List.generate(64 * 1024 * 3 + 123, (i) => (i * 31) % 256);
      final file = File('${tempDir.path}/large.mp3');
      file.writeAsBytesSync(bytes);

      final hash = await computeAudioSha256(file.path);
      expect(hash, sha256.convert(bytes).toString());
    });

    test('返回值为 64 位十六进制字符串', () async {
      final file = File('${tempDir.path}/hex.mp3');
      file.writeAsBytesSync([0xFF, 0x00, 0xAB]);

      final hash = await computeAudioSha256(file.path);
      expect(hash.length, 64);
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });
}
