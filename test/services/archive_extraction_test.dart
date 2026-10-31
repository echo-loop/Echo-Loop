import 'dart:io';

import 'package:archive/archive.dart';
import 'package:echo_loop/services/archive_extraction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('archive_extraction_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// 生成一个包含单个文件的 zip，返回其路径。
  String writeZip(Map<String, List<int>> entries) {
    final archive = Archive();
    entries.forEach((name, bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    final zipPath = p.join(tempDir.path, 'sample.zip');
    File(zipPath).writeAsBytesSync(ZipEncoder().encode(archive));
    return zipPath;
  }

  test('后台解压把归档内容完整写入输出目录', () async {
    final zipPath = writeZip({
      'model/encoder.onnx': [1, 2, 3],
      'model/tokens.txt': 'hello'.codeUnits,
    });
    final outputDir = Directory(p.join(tempDir.path, 'out'))..createSync();

    await extractArchiveInBackground(zipPath, outputDir.path);

    expect(
      File(p.join(outputDir.path, 'model', 'encoder.onnx')).readAsBytesSync(),
      [1, 2, 3],
    );
    expect(
      File(p.join(outputDir.path, 'model', 'tokens.txt')).readAsStringSync(),
      'hello',
    );
  });

  test('归档不存在时向调用方抛出错误，而不是静默成功', () async {
    final outputDir = Directory(p.join(tempDir.path, 'out'))..createSync();

    await expectLater(
      extractArchiveInBackground(
        p.join(tempDir.path, 'missing.zip'),
        outputDir.path,
      ),
      throwsA(anything),
    );
  });
}
