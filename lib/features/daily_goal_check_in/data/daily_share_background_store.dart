import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/app_logger.dart';
import '../domain/share_card_template.dart';

class CachedDailyShareBackground {
  const CachedDailyShareBackground(this.template, this.bytes);
  final ShareCardTemplate template;
  final Uint8List bytes;
}

/// 仅持久化公开背景与模板，不存储账号、头像或合成卡片。
/// 串行文件操作并最后提交清单，使失败写入不会破坏原先可用的背景。
class DailyShareBackgroundStore {
  DailyShareBackgroundStore({Future<Directory> Function()? resolveDirectory})
    : _resolveDirectory = resolveDirectory ?? getTemporaryDirectory;

  static const directoryName = 'daily_check_in_share_backgrounds';
  static const maxImageBytes = 20 * 1024 * 1024;
  final Future<Directory> Function() _resolveDirectory;
  Future<void> _pending = Future<void>.value();
  int _sequence = 0;

  Future<Directory> _directory() async =>
      Directory(p.join((await _resolveDirectory()).path, directoryName));

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<CachedDailyShareBackground?> read(DateTime date) =>
      _serialize(() async {
        final directory = await _directory();
        final manifest = File(p.join(directory.path, 'manifest.json'));
        if (!await manifest.exists()) {
          await _clearDirectory(directory);
          return null;
        }
        try {
          if (await manifest.length() > 128 * 1024) {
            throw const FormatException('背景清单过大');
          }
          final decoded = jsonDecode(await manifest.readAsString());
          if (decoded is! Map<String, Object?> || decoded['version'] != 1) {
            throw const FormatException('背景清单格式无效');
          }
          if (decoded['date'] != _dateKey(date)) {
            await _clearDirectory(directory);
            return null;
          }
          final filename = decoded['image'];
          if (filename is! String ||
              !RegExp(r'^background-\d+-\d+\.bin$').hasMatch(filename)) {
            throw const FormatException('背景文件名无效');
          }
          final template = ShareCardTemplate.fromJson(decoded['template']);
          final file = File(p.join(directory.path, filename));
          final length = await file.length();
          if (length == 0 || length > maxImageBytes) {
            throw const FormatException('背景文件大小无效');
          }
          final bytes = await file.readAsBytes();
          if (decoded['sha256'] != sha256.convert(bytes).toString()) {
            throw const FormatException('背景文件校验失败');
          }
          await _validateImage(bytes);
          return CachedDailyShareBackground(template, bytes);
        } on FileSystemException catch (error) {
          AppLogger.log('DailyShare', '读取背景缓存失败，将重新获取: $error');
          return null;
        } on FormatException catch (error) {
          AppLogger.log('DailyShare', '背景缓存无效，将重新获取: $error');
          try {
            await _clearDirectory(directory);
          } on FileSystemException catch (cleanupError) {
            AppLogger.log('DailyShare', '清理损坏背景缓存失败: $cleanupError');
          }
          return null;
        }
      });

  Future<void> write(
    DateTime date,
    ShareCardTemplate template,
    Uint8List bytes,
  ) => _serialize(() async {
    await _validateImage(bytes);
    // 同时验证序列化结果，防止无效领域对象落盘后无法恢复。
    final templateJson = template.toJson();
    ShareCardTemplate.fromJson(templateJson);
    final directory = await _directory();
    await directory.create(recursive: true);
    final suffix = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final filename = 'background-$suffix.bin';
    final image = File(p.join(directory.path, filename));
    final temporaryImage = File('${image.path}.tmp');
    await temporaryImage.writeAsBytes(bytes, flush: true);
    await temporaryImage.rename(image.path);
    final manifest = File(p.join(directory.path, 'manifest.json'));
    final temporaryManifest = File(
      p.join(directory.path, 'manifest-$suffix.tmp'),
    );
    await temporaryManifest.writeAsString(
      jsonEncode({
        'version': 1,
        'date': _dateKey(date),
        'image': filename,
        'sha256': sha256.convert(bytes).toString(),
        'template': templateJson,
      }),
      flush: true,
    );
    await temporaryManifest.rename(manifest.path);
    await for (final entity in directory.list()) {
      if (entity.path != image.path && entity.path != manifest.path) {
        await entity.delete(recursive: true);
      }
    }
  });

  Future<void> clear() => _serialize(() async {
    await _clearDirectory(await _directory());
  });

  Future<void> removeExpired(DateTime date) async {
    // 读取同时验证日期、清单和背景；过期或损坏缓存会被移除。
    await read(date);
  }

  Future<void> _clearDirectory(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _validateImage(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.lengthInBytes > maxImageBytes) {
      throw const FormatException('背景文件大小无效');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width <= 0 ||
            descriptor.height <= 0 ||
            descriptor.width * descriptor.height > 40000000) {
          throw const FormatException('背景尺寸无效');
        }
      } finally {
        descriptor.dispose();
      }
    } on Exception catch (error) {
      // 外部缓存图片的解码错误统一作为缓存损坏处理，不隐藏文件写入错误。
      throw FormatException('背景图片格式无效: $error');
    } finally {
      buffer.dispose();
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
