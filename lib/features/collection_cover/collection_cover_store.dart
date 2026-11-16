// 本地合集自定义封面的文件读写。
//
// 封面存放在应用数据目录的 `collection_covers/` 下，数据库只保存相对路径。
// 文件名带写入时间戳：换图后路径变化，Flutter 图片缓存不会继续显示旧图。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../services/app_logger.dart';
import '../../utils/app_data_dir.dart';

const _logTag = 'CollectionCover';

/// 封面目录名（相对应用数据目录）；备份按数据库中的相对路径收集，无需单独登记。
const collectionCoversDirectoryName = 'collection_covers';

class CollectionCoverStore {
  CollectionCoverStore({
    this.dataDirectory = getAppDataDirectory,
    this.now = DateTime.now,
  });

  final Future<Directory> Function() dataDirectory;
  final DateTime Function() now;

  /// 写入封面 JPEG，返回相对应用数据目录的路径。
  ///
  /// 先写临时文件再重命名，避免中途失败留下半截图片被数据库引用。
  Future<String> save({
    required String collectionId,
    required Uint8List jpegBytes,
  }) async {
    final dataDir = await dataDirectory();
    final fileName = '${collectionId}_${now().microsecondsSinceEpoch}.jpg';
    final relativePath = p.posix.join(collectionCoversDirectoryName, fileName);
    final target = File(p.join(dataDir.path, relativePath));
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.part');
    try {
      await partial.writeAsBytes(jpegBytes, flush: true);
      await partial.rename(target.path);
    } on FileSystemException catch (error) {
      AppLogger.log(
        _logTag,
        'save failed: collectionId=$collectionId path=$relativePath error=$error',
      );
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    AppLogger.log(
      _logTag,
      'saved: collectionId=$collectionId path=$relativePath '
      'bytes=${jpegBytes.length}',
    );
    return relativePath;
  }

  /// 删除不再被引用的封面文件。
  ///
  /// 只在数据库已不再引用该文件后调用：此时删除失败只会留下孤儿文件，不影响
  /// 用户可见状态，因此记录日志后继续，不让清理失败把已成功的修改报成失败。
  Future<void> delete(String relativePath) async {
    final dataDir = await dataDirectory();
    final file = File(p.join(dataDir.path, relativePath));
    try {
      if (await file.exists()) {
        await file.delete();
        AppLogger.log(_logTag, 'deleted: path=$relativePath');
      } else {
        AppLogger.log(_logTag, 'delete skipped, missing: path=$relativePath');
      }
    } on FileSystemException catch (error) {
      AppLogger.log(_logTag, 'delete failed: path=$relativePath error=$error');
    }
  }
}

final collectionCoverStoreProvider = Provider<CollectionCoverStore>(
  (ref) => CollectionCoverStore(),
);

/// 应用数据目录的绝对路径，供 UI 把封面相对路径同步解析为文件。
///
/// 首次解析完成前为 loading，UI 先显示默认占位；之后常驻，不再有异步间隙。
final appDataDirectoryPathProvider = FutureProvider<String>(
  (ref) async => (await getAppDataDirectory()).path,
);

/// 把封面相对路径解析为绝对路径文件；数据目录尚未解析时返回 null。
File? resolveCollectionCoverFile(
  String? dataDirectoryPath,
  String? relativePath,
) {
  if (dataDirectoryPath == null || relativePath == null) return null;
  return File(p.join(dataDirectoryPath, relativePath));
}
