/// PDF 字节的落盘与分享（学习材料导出与收藏导出共用）
library;

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

import '../../audio_export_service.dart';

/// 临时导出目录前缀（已登记 temp_cleanup_service 白名单，清缓存时统一回收）
const pdfTempDirPrefix = 'pdf_export_';

/// 生成导出文件名：净化后的标题 + `.pdf`
String pdfFileNameFor(String title) =>
    '${AudioExportService().sanitizeFileName(title)}.pdf';

/// 把字节写入临时目录，返回文件完整路径（分享用）
///
/// 分享方**不可**在分享返回后立即删除该文件：macOS 在用户点选 AirDrop 时
/// 即 resolve、传输尚未开始，提前删会让 AirDrop 永远卡在 Waiting，
/// 交由清理服务统一回收。
Future<String> writePdfTempFile(Uint8List bytes, String title) async {
  final systemTemp = await getTemporaryDirectory();
  final dir = Directory(
    p.join(
      systemTemp.path,
      '$pdfTempDirPrefix${DateTime.now().millisecondsSinceEpoch}',
    ),
  );
  await dir.create(recursive: true);
  final pdfPath = p.join(dir.path, pdfFileNameFor(title));
  await File(pdfPath).writeAsBytes(bytes);
  return pdfPath;
}

/// 另存为：移动端由系统存储面板直接写入 bytes；桌面端只返回路径，之后自行写文件。
///
/// 返回 true 表示已写入，false 表示用户取消。写入失败抛出异常由调用方提示。
Future<bool> savePdfBytes({
  required Uint8List bytes,
  required String title,
  required String dialogTitle,
}) async {
  final isMobile = Platform.isIOS || Platform.isAndroid;
  final home = Platform.environment['HOME'];
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: pdfFileNameFor(title),
    bytes: bytes,
    initialDirectory: !isMobile && home != null ? '$home/Downloads' : null,
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  if (savePath == null) return false;
  if (!isMobile) {
    await File(savePath).writeAsBytes(bytes);
  }
  return true;
}

/// 系统分享面板分享 PDF
///
/// [sharePositionOrigin] 为 iPad / macOS popover 的锚点；[title] 同时作为
/// iOS 分享卡片标题（不传则卡片只剩副标题）。
Future<void> sharePdfBytes({
  required Uint8List bytes,
  required String title,
  required Rect sharePositionOrigin,
}) async {
  final pdfPath = await writePdfTempFile(bytes, title);
  await Share.shareXFiles(
    [XFile(pdfPath, mimeType: 'application/pdf')],
    subject: title,
    sharePositionOrigin: sharePositionOrigin,
  );
}
