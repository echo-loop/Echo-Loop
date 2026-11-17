import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 代码引用的 `assets/` 图片必须在 pubspec.yaml 中声明，否则发布包不含该资源，
/// SvgPicture 会静默不渲染，图标在界面上直接消失。
void main() {
  test('lib 中引用的 assets 资源均已在 pubspec.yaml 声明', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^\s*-\s*(assets/\S+)',
      multiLine: true,
    ).allMatches(pubspec).map((match) => match.group(1)!).toSet();
    final declaredDirectories = declared.where((path) => path.endsWith('/'));

    bool isDeclared(String asset) =>
        declared.contains(asset) ||
        declaredDirectories.any((directory) => asset.startsWith(directory));

    final assetPattern = RegExp(r'assets/[A-Za-z0-9_/.\-]+\.(?:svg|png)');
    final referenced = <String>{};
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      referenced.addAll(
        assetPattern
            .allMatches(file.readAsStringSync())
            .map((match) => match.group(0)!),
      );
    }

    final missing = referenced.where((asset) => !isDeclared(asset)).toList()
      ..sort();
    expect(missing, isEmpty, reason: '以下资源未在 pubspec.yaml 声明：$missing');
  });
}
