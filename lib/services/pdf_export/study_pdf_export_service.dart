/// 学习材料 PDF 导出门面
///
/// 拆成两个可独立复用的步骤（预览页按选项多次生成字节、仅分享时才落盘）：
/// - [StudyPdfExportService.buildBytes]「读字体 → isolate 生成 PDF 字节」：
///   字体经 [PdfAssetsLoader] 读取（只能在主 isolate，会话内缓存），
///   PDF 生成（字体解析 + 子集化，数百 ms 级 CPU）放 `compute` isolate；
/// - [StudyPdfExportService.writeTempPdf]「字节写临时文件」，委托共用实现
///   [writePdfTempFile]（分享后不可立即删除，见其注释）。
library;

import 'package:flutter/foundation.dart';

import '../../models/pdf_export/study_pdf_data.dart';
import '../app_logger.dart';
import 'common/pdf_assets.dart';
import 'common/pdf_document_shell.dart';
import 'common/pdf_file_actions.dart';
import 'study_pdf_builder.dart';

/// 学习材料 PDF 导出服务
class StudyPdfExportService {
  /// 生成 PDF 字节（预览 / 下载 / 分享共用同一份产物）
  ///
  /// [labels] 为按当前 locale 组装好的 PDF 内文案（isolate 内拿不到 l10n）。
  Future<Uint8List> buildBytes(
    StudyPdfDocument document, {
    required StudyPdfLabels labels,
  }) async {
    final total = Stopwatch()..start();
    final sw = Stopwatch()..start();
    final assets = await PdfAssetsLoader().load();
    AppLogger.log('PdfExport', '读字体 ${sw.elapsedMilliseconds}ms');
    sw
      ..reset()
      ..start();

    final request = StudyPdfBuildRequest(
      document: document,
      assets: assets,
      exportDate: pdfDateText(DateTime.now()),
      labels: labels,
    );

    final bytes = await compute(buildStudyPdfBytes, request);
    AppLogger.log(
      'PdfExport',
      'PDF 生成 ${sw.elapsedMilliseconds}ms (${bytes.length ~/ 1024}KB)',
    );
    AppLogger.log('PdfExport', '生成字节总耗时 ${total.elapsedMilliseconds}ms');
    return bytes;
  }

  /// 把生成好的 PDF 字节写入临时目录（分享路径用），返回文件完整路径
  Future<String> writeTempPdf(Uint8List bytes, String title) =>
      writePdfTempFile(bytes, title);
}
