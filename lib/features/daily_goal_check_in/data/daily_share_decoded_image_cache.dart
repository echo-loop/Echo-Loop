import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../services/app_logger.dart';

/// 每种用途仅保留当前资源；调用方持有独立句柄，替换或清空不会使正在绘制的图失效。
class DailyShareDecodedImageCache {
  final Map<DailyShareImageRole, _DecodedEntry> _entries = {};
  bool _disposed = false;

  Future<ui.Image> acquire(DailyShareImageRole role, Uint8List bytes) async {
    if (_disposed) throw StateError('分享解码缓存已释放');
    var entry = _entries[role];
    final hit = entry != null && identical(entry.bytes, bytes);
    if (!hit) {
      entry?.retire();
      entry = _DecodedEntry(bytes, _decode(role, bytes));
      _entries[role] = entry;
    }
    final current = entry;
    current.borrowers++;
    try {
      final image = await current.image;
      AppLogger.log(
        'DailyShare',
        '图片解码缓存 用途=${role.name} 命中=$hit 尺寸=${image.width}x${image.height}',
      );
      return image.clone();
    } catch (_) {
      if (identical(_entries[role], current)) _entries.remove(role);
      current.retire();
      rethrow;
    } finally {
      current.borrowers--;
      current.releaseIfUnused();
    }
  }

  void clear() {
    for (final entry in _entries.values) {
      entry.retire();
    }
    _entries.clear();
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  Future<ui.Image> _decode(DailyShareImageRole role, Uint8List bytes) async {
    final watch = Stopwatch()..start();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (width, height) {
        final (targetWidth, targetHeight, cover) = switch (role) {
          DailyShareImageRole.background => (1080, 1440, true),
          DailyShareImageRole.avatar => (54, 54, true),
          DailyShareImageRole.logo => (80, 80, false),
          DailyShareImageRole.qrCode => (106, 106, false),
        };
        final scale = math.min(
          1.0,
          cover
              ? math.max(targetWidth / width, targetHeight / height)
              : math.min(targetWidth / width, targetHeight / height),
        );
        return ui.TargetImageSize(
          width: math.max(1, (width * scale).ceil()),
          height: math.max(1, (height * scale).ceil()),
        );
      },
    );
    try {
      final image = (await codec.getNextFrame()).image;
      AppLogger.log(
        'DailyShare',
        '图片解码完成 用途=${role.name} 耗时=${watch.elapsedMilliseconds}ms',
      );
      return image;
    } finally {
      codec.dispose();
    }
  }
}

enum DailyShareImageRole { background, logo, qrCode, avatar }

class _DecodedEntry {
  _DecodedEntry(this.bytes, Future<ui.Image> loading) {
    image = loading.then((value) {
      decoded = value;
      releaseIfUnused();
      return value;
    });
  }

  final Uint8List bytes;
  late final Future<ui.Image> image;
  ui.Image? decoded;
  int borrowers = 0;
  bool retired = false;

  void retire() {
    retired = true;
    releaseIfUnused();
  }

  void releaseIfUnused() {
    if (retired && borrowers == 0) {
      decoded?.dispose();
      decoded = null;
    }
  }
}
