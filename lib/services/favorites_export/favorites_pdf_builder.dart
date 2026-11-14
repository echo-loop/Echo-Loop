/// 收藏导出 PDF 渲染器
///
/// 顶层函数 [buildFavoritesPdfBytes] 可直接作为 `compute` 入口在 isolate 中执行。
/// 外观（配色、页眉页脚、标题块、字体）全部复用 `pdf_document_shell`，
/// 与学习材料导出保持同一视觉语言；本文件只负责收藏内容的正文块。
///
/// 版式（MultiPage 约束：只有顶层兄弟块之间可断页，每个句子 / 词条各自是顶层 child）：
/// - 「句子」分区：每个来源材料一个小标题，其下逐句原文 + 灰色译文；
/// - 「词汇」分区：词条蓝色粗体 + 音标 → 释义 → 例句 → 来源句（灰色斜体）。
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/favorites_export/favorites_export_data.dart';
import '../pdf_export/common/pdf_assets.dart';
import '../pdf_export/common/pdf_document_shell.dart';

/// 渲染文案（isolate 内拿不到 l10n，由调用方按当前 locale 组装）
class FavoritesExportLabels {
  /// 首页大标题（同时作为文件名来源）
  final String title;

  /// 「句子」分区标题
  final String sentencesSection;

  /// 「词汇」分区标题
  final String wordsSection;

  /// 来源材料已删除或缺失时的占位文案
  final String unknownSource;

  /// 元信息：句子数，如「44 句」
  final String metaSentences;

  /// 元信息：词汇数，如「12 词」
  final String metaWords;

  const FavoritesExportLabels({
    required this.title,
    required this.sentencesSection,
    required this.wordsSection,
    required this.unknownSource,
    required this.metaSentences,
    required this.metaWords,
  });
}

/// PDF 渲染请求（compute 入口参数，只含可跨 isolate 的类型）
class FavoritesPdfBuildRequest {
  final FavoritesExportDocument document;
  final PdfAssets assets;

  /// 导出日期（yyyy-MM-dd，由调用方生成，isolate 内不取时钟）
  final String exportDate;
  final FavoritesExportLabels labels;

  const FavoritesPdfBuildRequest({
    required this.document,
    required this.assets,
    required this.exportDate,
    required this.labels,
  });
}

/// 分区标题字号
const _sectionTitleSize = 12.0;

/// 来源材料行相对关联句子块文字的额外缩进（体现层级）
const _sourceIndent = 14.0;

/// 来源材料标签底色 / 文字色
const _tagBackgroundColor = PdfColor.fromInt(0xFFE3E3E3);
const _tagTextColor = PdfColor.fromInt(0xFF424242);

/// 生成收藏导出 PDF 字节（compute 入口）
Future<Uint8List> buildFavoritesPdfBytes(
  FavoritesPdfBuildRequest request,
) async {
  final doc = createPdfDocument(request.assets);
  final appIcon = pdfAppIconProvider(request.assets.appIconPng);
  doc.addPage(
    pdfMultiPage(
      title: request.labels.title,
      appIcon: appIcon,
      build: (context) => _buildBlocks(request, appIcon),
    ),
  );
  return doc.save();
}

/// 组装顶层块：标题 → 句子分区 → 词汇分区（无内容的分区整体省略）
List<pw.Widget> _buildBlocks(
  FavoritesPdfBuildRequest request,
  pw.ImageProvider? appIcon,
) {
  final document = request.document;
  final labels = request.labels;
  final blocks = <pw.Widget>[
    pdfTitleBlock(
      title: labels.title,
      metaParts: [
        request.exportDate,
        if (document.sentenceCount > 0) labels.metaSentences,
        if (document.vocabularyCount > 0) labels.metaWords,
      ],
      appIcon: appIcon,
    ),
    pw.SizedBox(height: 18),
  ];

  if (document.sentenceGroups.isNotEmpty) {
    blocks.add(_sectionTitle(labels.sentencesSection));
    for (final group in document.sentenceGroups) {
      blocks.add(
        _groupTitle(
          group.sourceName ?? labels.unknownSource,
          group.sourceMedia,
        ),
      );
      for (final sentence in group.sentences) {
        blocks.add(_sentenceBlock(sentence));
      }
      blocks.add(pw.SizedBox(height: 10));
    }
  }

  if (document.vocabulary.isNotEmpty) {
    blocks.add(_sectionTitle(labels.wordsSection));
    for (final entry in document.vocabulary) {
      blocks.add(_vocabBlock(entry, unknownSource: labels.unknownSource));
    }
  }
  return blocks;
}

/// 分区标题（粗体 + 底部细线）
pw.Widget _sectionTitle(String text) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 6, bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.5, color: pdfHairlineColor),
      ),
    ),
    child: pw.Text(
      pdfSanitize(text),
      style: pw.TextStyle(
        fontSize: _sectionTitleSize,
        fontWeight: pw.FontWeight.bold,
        color: pdfInkColor,
      ),
    ),
  );
}

/// 来源材料标题：标签样式（浅灰圆角底 + 深色粗体小字），
/// 与正文句子、灰色译文在视觉上明确区分，避免被误读为字幕翻译。
/// 名称前显示音频 / 视频图标；来源未知时 [media] 为 null，不显示图标。
pw.Widget _groupTitle(String text, FavoriteSourceMedia? media) {
  return pw.Align(
    alignment: pw.Alignment.centerLeft,
    child: pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: _tagBackgroundColor,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (media != null) ...[
            pdfMediaTypeIcon(isVideo: media == FavoriteSourceMedia.video),
            pw.SizedBox(width: 4),
          ],
          pw.Text(
            pdfSanitize(text),
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: _tagTextColor,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 单个收藏句：原文 + 可选灰色译文
pw.Widget _sentenceBlock(FavoriteSentence sentence) {
  final translation = sentence.translation;
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 9),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          pdfSanitize(sentence.text),
          style: const pw.TextStyle(fontSize: 10, color: pdfInkColor),
        ),
        if (translation != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            pdfSanitize(translation),
            style: const pw.TextStyle(fontSize: 8.5, color: pdfMutedColor),
          ),
        ],
      ],
    ),
  );
}

/// 单个收藏词条
///
/// 层次：词形与音标 → 释义（正文色，不带边线）→ 关联句子块（左侧竖线，
/// 含例句与来源句）。来源材料名称位于来源句块内，右对齐斜体小字。
pw.Widget _vocabBlock(
  FavoriteVocabularyEntry entry, {
  required String unknownSource,
}) {
  final phonetic = entry.phonetic;
  final definition = entry.definition;
  final example = entry.example;
  final sourceSentence = entry.sourceSentence;
  final sourceName = entry.sourceName;
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Flexible(
              child: pw.Text(
                pdfSanitize(entry.term),
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfVocabTermColor,
                ),
              ),
            ),
            if (phonetic != null) ...[
              pw.SizedBox(width: 6),
              pw.Flexible(
                child: pw.Text(
                  '/${pdfSanitize(pdfStripPhoneticSlashes(phonetic))}/',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: pdfMutedColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (definition != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              pdfSanitize(definition),
              style: const pw.TextStyle(fontSize: 9.5, color: pdfInkColor),
            ),
          ),
        if (example != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: _associatedBlock([
              pw.Text(
                pdfSanitize(example.text),
                style: const pw.TextStyle(fontSize: 8.5, color: pdfInkColor),
              ),
              if (example.translation != null)
                pw.Text(
                  pdfSanitize(example.translation!),
                  style: const pw.TextStyle(fontSize: 8, color: pdfMutedColor),
                ),
            ]),
          ),
        if (sourceSentence != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: _associatedBlock([
              pw.Text(
                pdfSanitize(sourceSentence),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontStyle: pw.FontStyle.italic,
                  color: pdfMutedColor,
                ),
              ),
              _sourceLine(sourceName ?? unknownSource, entry.sourceMedia),
            ]),
          ),
      ],
    ),
  );
}

/// 来源材料行：左对齐，相对关联句子再缩进一级（层级关系），
/// 前缀两个横线，名称前为音频 / 视频图标
pw.Widget _sourceLine(String name, FavoriteSourceMedia? media) {
  final style = pw.TextStyle(
    fontSize: 7.5,
    fontStyle: pw.FontStyle.italic,
    color: pdfMutedColor,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: _sourceIndent, top: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('——', style: style),
        pw.SizedBox(width: 3),
        if (media != null) ...[
          pdfMediaTypeIcon(
            isVideo: media == FavoriteSourceMedia.video,
            size: 7,
          ),
          pw.SizedBox(width: 3),
        ],
        pw.Flexible(child: pw.Text(pdfSanitize(name), style: style)),
      ],
    ),
  );
}

/// 关联句子块：左侧竖线 + 缩进，把例句 / 来源句与释义区分开
pw.Widget _associatedBlock(List<pw.Widget> children) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(left: 7),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        left: pw.BorderSide(width: 1.5, color: pdfHairlineColor),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 2),
          children[i],
        ],
      ],
    ),
  );
}
