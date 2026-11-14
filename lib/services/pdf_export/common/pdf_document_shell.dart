/// PDF 共用版式外壳：学习材料导出与收藏导出共用同一套外观
///
/// 负责固定浅色系配色、字体主题、A4 页面骨架（页边距、次页起 running header、
/// 页码 footer）、首页标题块与品牌角标。各导出类型只负责正文块的组装。
///
/// 所有函数都是纯函数（不依赖 l10n / 主 isolate 资源），可在 compute isolate 中调用。
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_assets.dart';

/// 正文色
const pdfInkColor = PdfColor.fromInt(0xFF1A1A1A);

/// 弱化文字色（翻译 / 音标 / 页眉页脚 / 元信息）
const pdfMutedColor = PdfColor.fromInt(0xFF757575);

/// 收藏标记橙（= App 浅色 `Colors.orange.shade400`）
const pdfSavedMarkColor = PdfColor.fromInt(0xFFFFA726);

/// 词条色（收藏词条名 / 词条标题）
const pdfVocabTermColor = PdfColor.fromInt(0xFF2B4C7E);

/// 分隔线色
const pdfHairlineColor = PdfColors.grey400;

/// 品牌字样（首页标题上方 + 次页起 running header）
const _brandText = 'ECHO LOOP';

/// 单个文本字段的字符数硬上限（防脏数据把单块撑超一页高度抛异常）
///
/// 左栏宽约 350pt，8.5pt 字号一页约可容 5000 字符，取 3000 留足余量。
const pdfMaxFieldChars = 3000;

/// 页面边距（A4）
const _pageMargin = pw.EdgeInsets.symmetric(horizontal: 42, vertical: 48);

/// 页数上限：长文档必须显式调大（pdf 包默认 20）
const _maxPages = 400;

/// 创建带中英文字体主题的文档
pw.Document createPdfDocument(PdfAssets assets) {
  final latin = pw.Font.ttf(ByteData.sublistView(assets.latinRegular));
  final latinBold = pw.Font.ttf(ByteData.sublistView(assets.latinBold));
  final latinItalic = pw.Font.ttf(ByteData.sublistView(assets.latinItalic));
  final cjk = pw.Font.ttf(ByteData.sublistView(assets.cjkRegular));
  return pw.Document(
    theme: pw.ThemeData.withFont(
      base: latin,
      bold: latinBold,
      italic: latinItalic,
      fontFallback: [cjk],
    ),
  );
}

/// 应用图标 provider（图标字节缺失时为 null）
pw.ImageProvider? pdfAppIconProvider(Uint8List? appIconPng) =>
    appIconPng == null ? null : pw.MemoryImage(appIconPng);

/// 构造标准 A4 MultiPage：首页无页眉，次页起 running header；底部居中 `n / total`
///
/// [build] 返回的顶层 widget 之间可断页，单个 widget 超一页高会抛异常，
/// 调用方须保证每个子块各自是顶层 child。
pw.MultiPage pdfMultiPage({
  required String title,
  required pw.ImageProvider? appIcon,
  required List<pw.Widget> Function(pw.Context context) build,
}) {
  final safeTitle = pdfSanitize(title);
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: _pageMargin,
    maxPages: _maxPages,
    header: (context) => context.pageNumber == 1
        ? pw.SizedBox()
        : _runningHeader(safeTitle, appIcon),
    footer: (context) => pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        '${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: pdfMutedColor),
      ),
    ),
    build: build,
  );
}

/// 首页标题块：右上角品牌角标 → 标题居中 → 元信息行居中 → 分隔线
///
/// [metaParts] 为空项会被调用方省略；元信息以「  ·  」连接。
pw.Widget pdfTitleBlock({
  required String title,
  required List<String> metaParts,
  required pw.ImageProvider? appIcon,
}) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pdfBrandMark(appIcon),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          pdfSanitize(title),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: pdfInkColor,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          metaParts.join('  ·  '),
          style: const pw.TextStyle(fontSize: 8, color: pdfMutedColor),
        ),
      ],
    ),
  );
}

/// 品牌角标：应用图标 + `ECHO LOOP` 文字（图标缺失时只渲染文字）
pw.Widget pdfBrandMark(pw.ImageProvider? appIcon, {double iconSize = 11}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      if (appIcon != null) ...[
        pw.Image(appIcon, width: iconSize, height: iconSize),
        pw.SizedBox(width: 3),
      ],
      pw.Text(
        _brandText,
        style: const pw.TextStyle(
          fontSize: 7.5,
          letterSpacing: 0.8,
          color: pdfMutedColor,
        ),
      ),
    ],
  );
}

/// 次页起的 running header：左品牌角标、右文档标题 + 底部 hairline
pw.Widget _runningHeader(String title, pw.ImageProvider? appIcon) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.5, color: pdfHairlineColor),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pdfBrandMark(appIcon, iconSize: 9),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 7, color: pdfMutedColor),
        ),
      ],
    ),
  );
}

/// 文本清洗：控制字符替换为空格（保持等长，收藏命中掩码按原文偏移计算不能错位），
/// 并截断超长字段防单块超一页高度抛异常
String pdfSanitize(String text) {
  var cleaned = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
  if (cleaned.length > pdfMaxFieldChars) {
    cleaned = '${cleaned.substring(0, pdfMaxFieldChars)}…';
  }
  return cleaned;
}

/// 剥去音标首尾的斜杠/方括号与空白：不同词典源音标形态不一
/// （`/.../`、`[...]`、裸音标），统一后由渲染层补一层 `/.../`。
String pdfStripPhoneticSlashes(String phonetic) {
  return phonetic.replaceAll(RegExp(r'^[\s/\[\]]+|[\s/\[\]]+$'), '');
}

/// 导出日期文本（yyyy-MM-dd），由主 isolate 生成后传入渲染端
String pdfDateText(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

/// 音频 / 视频来源图标（灰色小图标，用于来源材料名前）
///
/// 图形与 App 的 waveform / video 图标语义一致，但用 M/h/v/l/z 等基础指令手绘，
/// 避免依赖 pdf 包对 SVG 圆弧命令（a）的支持。
pw.Widget pdfMediaTypeIcon({required bool isVideo, double size = 8}) {
  return pw.SvgImage(
    svg: isVideo ? _videoIconSvg : _audioIconSvg,
    width: size,
    height: size,
  );
}

/// 音频：五根竖条的波形
const _audioIconSvg =
    '<svg viewBox="0 0 20 20">'
    '<path fill="#757575" d="M2 8h2v4H2z"/>'
    '<path fill="#757575" d="M6 4h2v12H6z"/>'
    '<path fill="#757575" d="M10 2h2v16h-2z"/>'
    '<path fill="#757575" d="M14 6h2v8h-2z"/>'
    '<path fill="#757575" d="M18 8h2v4h-2z"/>'
    '</svg>';

/// 视频：机位矩形 + 镜头梯形
const _videoIconSvg =
    '<svg viewBox="0 0 20 20">'
    '<path fill="#757575" d="M2 5h11v10H2z"/>'
    '<path fill="#757575" d="M14 9l4-3v8l-4-3z"/>'
    '</svg>';
