/// 收藏导出门面：只读加载数据 → 按格式渲染字节
///
/// 新增格式：在 [FavoritesExportFormat] 加枚举值，并在 [export] 的穷尽 switch 中
/// 补一个分支（编译期强制），渲染实现放在 favorites_export/ 下。
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import '../../models/favorites_export/favorites_export_data.dart';
import '../../models/favorites_export/favorites_export_options.dart';
import '../pdf_export/common/pdf_assets.dart';
import '../pdf_export/common/pdf_document_shell.dart';
import 'favorites_export_loader.dart';
import 'favorites_pdf_builder.dart';

/// 收藏导出服务
class FavoritesExportService {
  final FavoritesExportLoader _loader;

  FavoritesExportService({required FavoritesExportLoader loader})
    : _loader = loader;

  /// 生成导出字节
  ///
  /// [buildLabels] 在数据加载完成后调用（元信息需要句子 / 词汇计数，且 isolate 内拿不到 l10n）；
  /// [targetLanguage] 为用户母语代码，用于定位翻译与 AI 查词缓存。
  Future<Uint8List> export({
    required FavoritesExportOptions options,
    required FavoritesExportFormat format,
    required String targetLanguage,
    required FavoritesExportLabels Function(FavoritesExportDocument document)
    buildLabels,
  }) async {
    final document = await _loader.load(
      options,
      targetLanguage: targetLanguage,
    );
    final labels = buildLabels(document);
    return switch (format) {
      FavoritesExportFormat.pdf => _renderPdf(document, labels),
    };
  }

  Future<Uint8List> _renderPdf(
    FavoritesExportDocument document,
    FavoritesExportLabels labels,
  ) async {
    final assets = await PdfAssetsLoader().load();
    final request = FavoritesPdfBuildRequest(
      document: document,
      assets: assets,
      exportDate: pdfDateText(DateTime.now()),
      labels: labels,
    );
    return compute(buildFavoritesPdfBytes, request);
  }
}
