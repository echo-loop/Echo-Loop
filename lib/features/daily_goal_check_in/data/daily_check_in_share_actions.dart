import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/temp_cleanup_service.dart';
import '../providers/daily_check_in_share_provider.dart';

abstract interface class DailyShareActions {
  Future<bool> save(PreparedDailyCheckInShare card);
  Future<void> share(PreparedDailyCheckInShare card, Rect origin);
}

final dailyShareActionsProvider = Provider<DailyShareActions>((ref) {
  // 换号后释放导出路径索引；系统正在使用的文件由过期清理接管。
  ref.watch(dailyShareUserIdProvider);
  ref.watch(dailyCheckInShareProvider.select((state) => state.card?.image));
  final actions = PlatformDailyShareActions();
  ref.onDispose(actions.clearMemoryCache);
  return actions;
});

class PlatformDailyShareActions implements DailyShareActions {
  Uint8List? _lastBytes;
  String? _lastPath;

  void clearMemoryCache() {
    _lastBytes = null;
    _lastPath = null;
  }

  @override
  Future<bool> save(PreparedDailyCheckInShare card) async {
    if (Platform.isIOS || Platform.isAndroid) {
      await Gal.putImageBytes(card.image.pngBytes, name: _name(card));
      return true;
    }
    final path = await FilePicker.platform.saveFile(
      fileName: '${_name(card)}.png',
      type: FileType.custom,
      allowedExtensions: const ['png'],
    );
    if (path == null) return false;
    await File(path).writeAsBytes(card.image.pngBytes, flush: true);
    return true;
  }

  @override
  Future<void> share(PreparedDailyCheckInShare card, Rect origin) async {
    await cleanupStaleDailyShareExportTemp();
    var path = _lastPath;
    if (!identical(_lastBytes, card.image.pngBytes) ||
        path == null ||
        !await File(path).exists()) {
      final directory = await (await getTemporaryDirectory()).createTemp(
        dailyShareExportTempPrefix,
      );
      path = '${directory.path}/${_name(card)}.png';
      await File(path).writeAsBytes(card.image.pngBytes, flush: true);
      _lastBytes = card.image.pngBytes;
      _lastPath = path;
    }
    await File('${File(path).parent.path}/$dailyShareExportLeaseName')
        .writeAsString('', flush: true);
    // 不在返回后删文件：macOS AirDrop 可能尚未读取图片。
    await Share.shareXFiles(
      [XFile(path, mimeType: 'image/png')],
      subject: 'Echo Loop',
      sharePositionOrigin: origin,
    );
  }

  String _name(PreparedDailyCheckInShare card) =>
      'Echo_Loop_${card.date.toIso8601String().substring(0, 10)}';
}
