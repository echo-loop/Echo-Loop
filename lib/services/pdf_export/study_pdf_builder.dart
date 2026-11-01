/// 学习材料 PDF 渲染器（学术论文风格版式）
///
/// 纯函数式 builder：`StudyPdfBuildRequest`（文档数据 + 字体字节）→ PDF 字节。
/// 顶层函数 [buildStudyPdfBytes] 可直接作为 `compute` 入口在 isolate 中执行
/// （字体解析 + 子集化是数百 ms 级 CPU 开销，不能占用主 isolate）。
///
/// 版式设计（简洁克制，无彩色底色块）：
/// - 正文左栏（flex 5）句子 + 右栏（flex 2）词汇旁注，学术旁注比例；
///   全文无任何词汇旁注时不分栏，句子占满整行；
/// - 收藏词/意群 = 橙色细下划线（与 App 正文视觉语言一致；pdf 包无
///   dotted 下划线，用细实线近似）；收藏句 = 整句词条蓝 + 句末小书签图标；
/// - 词汇旁注全文统一编号：正文命中词后放上标小号蓝色标号，右栏词条
///   前放同号标号，两向内部链接（标号 ↔ 词条锚点）；
/// - 翻译弱化为句下灰色小字；AI 解析集中在文末「附录 · 句子解析」，
///   正文句末尾注标记 [n] 与附录条目 [n] 互为内部链接；
/// - 首页标题居中 + ECHO LOOP 品牌行，次页起 running header。
///
/// 版式约束（pdf 包 MultiPage 语义）：
/// - 只有顶层兄弟块之间可以断页，单个 widget 超一页高会直接抛异常；
///   因此「句子行 / 翻译块 / 附录条目各字段」各自是 MultiPage 的直接 child。
/// - `maxPages` 默认 20，长文必须显式调大。
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/pdf_export/study_pdf_data.dart';
import '../../widgets/practice/sentence_word_selection.dart'
    show charMaskFromRanges, splitByMask;

/// PDF 生成请求（compute 入口参数，只含可跨 isolate 的类型）
class StudyPdfBuildRequest {
  /// 文档数据
  final StudyPdfDocument document;

  /// 英文正文字体（NotoSans-Regular，TrueType）
  final Uint8List latinRegular;

  /// 英文粗体字体（NotoSans-Bold）
  final Uint8List latinBold;

  /// 英文斜体字体（NotoSans-Italic，词性渲染用）
  final Uint8List latinItalic;

  /// CJK 回退字体（NotoSansSC-Regular）
  final Uint8List cjkRegular;

  /// 应用图标 PNG 字节（96px 小图，品牌角标用；null 则只渲染品牌文字）
  final Uint8List? appIconPng;

  /// 导出日期（yyyy-MM-dd，由调用方生成，isolate 内不取时钟）
  final String exportDate;

  /// 本地化文案（由调用方按当前 locale 组装，isolate 内拿不到 l10n）
  final StudyPdfLabels labels;

  const StudyPdfBuildRequest({
    required this.document,
    required this.latinRegular,
    required this.latinBold,
    required this.latinItalic,
    required this.cjkRegular,
    this.appIconPng,
    required this.exportDate,
    required this.labels,
  });
}

// ---------- 版式常量（固定浅色系，与 App 主题无关） ----------

/// 正文色
const _inkColor = PdfColor.fromInt(0xFF1A1A1A);

/// 弱化文字色（翻译/音标/页眉页脚/日期）
const _mutedColor = PdfColor.fromInt(0xFF757575);

/// 收藏标记橙（= App 浅色 `Colors.orange.shade400`，收藏词下划线 + 书签图标）
const _savedMarkColor = PdfColor.fromInt(0xFFFFA726);

/// 词汇笔记词条色
const _vocabTermColor = PdfColor.fromInt(0xFF2B4C7E);

/// 分隔线色
const _hairlineColor = PdfColors.grey400;

/// 附录解析字段标签 badge 底色（语法/词汇/听力）
const _fieldBadgeBgColor = PdfColor.fromInt(0xFFE3E3E3);

/// 附录解析字段标签 badge 文字色
const _fieldBadgeTextColor = PdfColor.fromInt(0xFF424242);

/// 附录解析正文里 `引用片段` 的背景高亮色
const _inlineHighlightBgColor = PdfColor.fromInt(0xFFF0F0F0);

/// 背景高亮片段的字符数上限：内联组件不可换行，超长引用退化为
/// 无底色深色文本，防撑破版面（附录整行宽 ~510pt，48 个 CJK ≈ 380pt）
const _maxHighlightChars = 48;

/// 品牌字样（首页标题上方 + 次页起 running header）
const _brandText = 'ECHO LOOP';

/// 正文左右栏 flex 比例（学术旁注版式，左栏 ~71%）
const _bodyFlex = 5;
const _notesFlex = 2;

/// 左右栏间距
const _columnGap = 16.0;

/// 单个文本字段的字符数硬上限（防脏数据把单块撑超一页高度抛异常）
///
/// 左栏宽约 350pt，8.5pt 字号一页约可容 5000 字符，取 3000 留足余量。
const _maxFieldChars = 3000;

/// 书签图标（Material bookmark 形状，收藏句句末标记）
const _bookmarkSvg =
    '<svg viewBox="0 0 24 24"><path d="M6 2h12v20l-6-5-6 5z" fill="#FFA726"/></svg>';

/// 生成学习材料 PDF 字节（compute 入口）
Future<Uint8List> buildStudyPdfBytes(StudyPdfBuildRequest request) async {
  final latin = pw.Font.ttf(ByteData.sublistView(request.latinRegular));
  final latinBold = pw.Font.ttf(ByteData.sublistView(request.latinBold));
  final latinItalic = pw.Font.ttf(ByteData.sublistView(request.latinItalic));
  final cjk = pw.Font.ttf(ByteData.sublistView(request.cjkRegular));

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: latin,
      bold: latinBold,
      italic: latinItalic,
      fontFallback: [cjk],
    ),
  );

  final title = _sanitize(request.document.title);
  final appIcon = request.appIconPng == null
      ? null
      : pw.MemoryImage(request.appIconPng!);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 48),
      maxPages: 400,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _runningHeader(title, appIcon),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
        ),
      ),
      build: (context) => _buildBlocks(request, appIcon),
    ),
  );

  return doc.save();
}

/// 品牌角标：应用图标 + `ECHO LOOP` 文字（图标缺失时只渲染文字）
pw.Widget _brandMark(pw.ImageProvider? appIcon, {double iconSize = 11}) {
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
          letterSpacing: 2,
          color: _mutedColor,
        ),
      ),
    ],
  );
}

/// 组装 MultiPage 顶层块列表（块间可断页）：标题 → 正文 → 附录
List<pw.Widget> _buildBlocks(
  StudyPdfBuildRequest request,
  pw.ImageProvider? appIcon,
) {
  final document = request.document;

  // 尾注编号：按正文出现顺序给「有解析的句子」分配 [1..n]，
  // 正文句末标记与附录条目共用同一映射。
  // 词条标号由 loader 全文档统一分配（StudyPdfVocabNote.number）
  final noteNumbers = <int, int>{};
  var hasVocabNotes = false;
  for (final paragraph in document.paragraphs) {
    for (final sentence in paragraph) {
      if (sentence.hasAnalysis) {
        noteNumbers[sentence.index] = noteNumbers.length + 1;
      }
      hasVocabNotes = hasVocabNotes || sentence.vocabNotes.isNotEmpty;
    }
  }
  // 全文无任何词汇旁注时不分栏（句子占满整行）
  final twoColumn = hasVocabNotes;

  final blocks = <pw.Widget>[
    _titleBlock(document, request.exportDate, request.labels, appIcon),
    pw.SizedBox(height: 18),
  ];

  for (final paragraph in document.paragraphs) {
    for (final sentence in paragraph) {
      blocks.addAll(
        _sentenceBlocks(
          sentence,
          noteNumbers[sentence.index],
          twoColumn: twoColumn,
        ),
      );
    }
    // 段间距（明显大于行高，最后一段之后多余的间距无碍观感）
    blocks.add(pw.SizedBox(height: 14));
  }

  if (noteNumbers.isNotEmpty) {
    blocks.addAll(_appendixBlocks(document, noteNumbers, request.labels));
  }
  return blocks;
}

/// 次页起的 running header：左品牌角标、右文档标题 + 底部 hairline
pw.Widget _runningHeader(String title, pw.ImageProvider? appIcon) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.5, color: _hairlineColor),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _brandMark(appIcon, iconSize: 9),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 7, color: _mutedColor),
        ),
      ],
    ),
  );
}

/// 首页标题块：右上角品牌角标（图标+文字，不显眼）→ 标题居中 →
/// 元信息行居中（日期 · 时长 · 句数 · 词数）→ 分隔线
pw.Widget _titleBlock(
  StudyPdfDocument document,
  String exportDate,
  StudyPdfLabels labels,
  pw.ImageProvider? appIcon,
) {
  // 元信息行：时长未知（0）/词数为 0 时省略对应项。
  // 时长文案带前缀（如「时长 05:32」）——紧跟日期的裸 mm:ss 会被误读成导出时刻
  final metaParts = [
    exportDate,
    if (document.durationSeconds > 0) labels.metaDuration,
    labels.metaSentences,
    if (document.wordCount > 0) labels.metaWords,
  ];
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.5, color: _hairlineColor),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _brandMark(appIcon),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          _sanitize(document.title),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _inkColor,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          metaParts.join('  ·  '),
          style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
        ),
      ],
    ),
  );
}

/// 一个句子展开成的顶层块序列：左栏（句子 + 弱化翻译）+ 右栏词汇旁注
///
/// 翻译与句子同在左栏 Column 内紧邻排列（若作为独立顶层块，会被
/// 右栏词汇列的高度推到 Row 之后，句子与翻译之间出现大空隙）。
/// [noteNumber] 为该句的附录尾注编号（无解析时为 null 不加标记）。
/// [twoColumn] 为 false（全文无词汇旁注）时不分栏，句子占满整行。
/// 有解析或有词条的句子包一层锚点 `sent-{index}`，供附录 [n] 与
/// 右栏词条标号跳回正文。
List<pw.Widget> _sentenceBlocks(
  StudyPdfSentence sentence,
  int? noteNumber, {
  required bool twoColumn,
}) {
  final body = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sentenceText(sentence, noteNumber),
      if (sentence.translation != null) _translationText(sentence.translation!),
    ],
  );

  pw.Widget block = !twoColumn
      ? body
      : pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(flex: _bodyFlex, child: body),
            pw.SizedBox(width: _columnGap),
            pw.Expanded(
              flex: _notesFlex,
              child: _vocabColumn(sentence.vocabNotes),
            ),
          ],
        );
  if (sentence.hasAnalysis || sentence.vocabNotes.isNotEmpty) {
    block = pw.Anchor(name: 'sent-${sentence.index}', child: block);
  }
  return [block, pw.SizedBox(height: 4)];
}

/// 绘制隔离容器：借道 [pw.SingleChildWidget.paintChild] 的
/// saveContext/restoreContext（PDF q/Q）包裹子树绘制。
///
/// pdf 包 RichText 按 span 跟踪画布 fill color，而 `_WidgetSpan.paint`
/// 直接调 `widget.paint` 不保存图形状态——WidgetSpan 内部改色会
/// 泄漏给外层后续 span（正文被染成标号色）。所有内嵌进 RichText 的
/// WidgetSpan 子树都用本容器包一层。
class _PaintIsolate extends pw.SingleChildWidget {
  _PaintIsolate({required pw.Widget child}) : super(child: child);

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }
}

/// NotoSans 字体 descent 占字号比例（基线到字形框底部）
const _notoDescentRatio = 0.293;

/// 收藏词自绘下划线：距字形框底部的间隙（线画在 descender 之下）
const _savedUnderlineGap = 1.1;

/// 「词 + 词条标号」原子单元：内嵌 RichText 的 WidgetSpan，
/// 整体不可断行（标号不会与所属词分处两行、错挂到相邻词）
///
/// 标号在词后（尾注/脚注的标准位置）；[_PaintIsolate] 保证内部
/// 标号色不泄漏到外层。baseline = -字号×NotoSans descent，
/// 使内部文字基线与外层行基线对齐（与附录 badge 同一校准方法）。
pw.InlineSpan _wordWithMarkers(
  String word,
  pw.TextStyle style,
  List<int> numbers,
) {
  return pw.WidgetSpan(
    baseline: -(style.fontSize ?? 10.5) * _notoDescentRatio,
    child: _PaintIsolate(
      child: pw.RichText(
        text: pw.TextSpan(
          style: style,
          children: [
            pw.TextSpan(text: word, style: style),
            for (final number in numbers)
              _vocabMarkerSpan(number, destination: 'vocab-$number'),
          ],
        ),
      ),
    ),
  );
}

/// 收藏词渲染：词底自绘橙色细下划线（Container 底边框）+ 可选词条标号
///
/// 不用 pdf 包的 `TextDecoration.underline`——它画在 baseline 下
/// descent/2 处（写死不可调），会切过 g/y 等字形的 descender；
/// 自绘线在字形框之下 [_savedUnderlineGap]，且只在词下、不延伸到标号。
/// baseline = -(字号×descent + 间隙)，内部文字基线与外层行基线对齐。
pw.InlineSpan _savedWordSpan(
  String word,
  pw.TextStyle style,
  List<int> numbers,
) {
  final baseline =
      -((style.fontSize ?? 10.5) * _notoDescentRatio + _savedUnderlineGap);
  final underlined = pw.Container(
    padding: const pw.EdgeInsets.only(bottom: _savedUnderlineGap),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _savedMarkColor, width: 0.7),
      ),
    ),
    child: pw.Text(word, style: style),
  );
  if (numbers.isEmpty) {
    return pw.WidgetSpan(
      baseline: baseline,
      child: _PaintIsolate(child: underlined),
    );
  }
  return pw.WidgetSpan(
    baseline: baseline,
    child: _PaintIsolate(
      child: pw.RichText(
        text: pw.TextSpan(
          style: style,
          children: [
            pw.WidgetSpan(baseline: baseline, child: underlined),
            for (final number in numbers)
              _vocabMarkerSpan(number, destination: 'vocab-$number'),
          ],
        ),
      ),
    ),
  );
}

/// 词条标号：上标小号蓝色数字（正文命中词后 / 右栏词条前），
/// [destination] 非空时挂内部链接
pw.TextSpan _vocabMarkerSpan(int number, {String? destination}) {
  return pw.TextSpan(
    text: '$number',
    baseline: 3,
    style: pw.TextStyle(
      fontSize: 5.5,
      fontWeight: pw.FontWeight.bold,
      color: _vocabTermColor,
    ),
    annotation: destination == null ? null : pw.AnnotationLink(destination),
  );
}

/// 句子正文：正常字体颜色；收藏句整句改词条蓝；收藏词/意群命中片段
/// 加橙色细下划线，命中词后放词条标号（链接到右栏词条锚点）；收藏句句末
/// 加书签图标；有解析的句子加尾注标记 [n]（链接到附录条目锚点）
pw.Widget _sentenceText(StudyPdfSentence sentence, int? noteNumber) {
  final text = _sanitize(sentence.text);
  // 收藏句：整句文字改为词条蓝（与右栏收藏词条同色），突出显示；
  // 与句末书签图标、句内收藏词橙色下划线并存。
  final baseStyle = pw.TextStyle(
    fontSize: 10.5,
    lineSpacing: 3,
    color: sentence.isBookmarked ? _vocabTermColor : _inkColor,
  );

  // 词条标号插入点（loader 已按全文档词条逐句算好并升序：同一收藏词
  // 在任何句子出现都标同号）；位置落在截断之外时钳到文本末尾
  final markers = <(int, int)>[
    for (final (pos, number) in sentence.vocabMarkers)
      if (pos > 0) (pos.clamp(0, text.length), number),
  ];

  // 收藏命中掩码按原文长度构建；splitByMask 对越界索引视为未命中，
  // 截断不会引起区间错位。收藏段逐词渲染（词底自绘下划线 + 词后标号，
  // 词+标号是原子单元不可断行——RichText 各 span 是独立断行单元，
  // 标号单独成 span 会被折到下一行开头、错挂到下个词）
  final mask = charMaskFromRanges(sentence.text.length, sentence.savedRanges);
  final spans = <pw.InlineSpan>[];
  var markerIdx = 0;

  // 取出落在 (from, to] 内的标号（更早的视作已消费的重叠区间，跳过）
  List<int> takeMarkers(int from, int to) {
    final numbers = <int>[];
    while (markerIdx < markers.length && markers[markerIdx].$1 <= to) {
      if (markers[markerIdx].$1 > from) {
        numbers.add(markers[markerIdx].$2);
      }
      markerIdx++;
    }
    return numbers;
  }

  for (final (start, end, saved) in splitByMask(0, text.length, mask)) {
    var cursor = start;
    if (saved) {
      // 收藏段：逐词渲染为下划线单元，且把该词后紧跟的**段内**空白并入
      // 同一单元，使意群/词组下划线连续贯穿词间空格（否则空格处断开，看
      // 起来像收藏了一堆独立单词）。收藏区间两端已修边为非空白，故段内空白
      // 必为词间空白、其右必有词——不会出现悬垂到段尾的下划线。
      // 标号（takeMarkers 取本词范围末尾的标号）附在该词单元之后；意群标号
      // 落在整段末词（无尾随空白），不受空白并入影响。
      while (cursor < end) {
        var wordEnd = cursor;
        while (wordEnd < end && text[wordEnd].trim().isNotEmpty) {
          wordEnd++;
        }
        final numbers = takeMarkers(cursor, wordEnd);
        var unitEnd = wordEnd;
        while (unitEnd < end && text[unitEnd].trim().isEmpty) {
          unitEnd++;
        }
        spans.add(
          _savedWordSpan(text.substring(cursor, unitEnd), baseStyle, numbers),
        );
        cursor = unitEnd;
      }
      continue;
    }
    // 非收藏段：标号位置都在收藏区间末尾，正常不落在这里；
    // 防御截断/脏数据——有则把标号挂到其所属词的原子单元上
    while (markerIdx < markers.length && markers[markerIdx].$1 <= end) {
      final (pos, _) = markers[markerIdx];
      if (pos <= cursor) {
        markerIdx++;
        continue;
      }
      final numbers = takeMarkers(cursor, pos);
      var wordStart = pos;
      while (wordStart > cursor && text[wordStart - 1].trim().isNotEmpty) {
        wordStart--;
      }
      if (wordStart > cursor) {
        spans.add(
          pw.TextSpan(
            text: text.substring(cursor, wordStart),
            style: baseStyle,
          ),
        );
      }
      spans.add(
        _wordWithMarkers(text.substring(wordStart, pos), baseStyle, numbers),
      );
      cursor = pos;
    }
    if (cursor < end) {
      spans.add(
        pw.TextSpan(text: text.substring(cursor, end), style: baseStyle),
      );
    }
  }

  spans.addAll([
    if (sentence.isBookmarked)
      pw.WidgetSpan(
        // 下移让图标与正文小写字高的视觉中心对齐（默认底边落在基线上，
        // 图标整体偏高）
        baseline: -3.0,
        child: _PaintIsolate(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(left: 3),
            child: pw.SvgImage(svg: _bookmarkSvg, width: 9, height: 11.5),
          ),
        ),
      ),
    if (noteNumber != null)
      pw.TextSpan(
        text: ' [$noteNumber]',
        // 小号标记基线对齐时视觉中心偏低，微升与正文行居中
        baseline: 0.6,
        style: const pw.TextStyle(fontSize: 6.5, color: _mutedColor),
        annotation: pw.AnnotationLink('note-$noteNumber'),
      ),
  ]);

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.RichText(
      text: pw.TextSpan(style: baseStyle, children: spans),
    ),
  );
}

/// 词条有标号时包 `vocab-{n}` 锚点（正文标号跳转目标），无标号原样返回
pw.Widget _anchorIfNumbered(int number, pw.Widget child) {
  if (number <= 0) return child;
  return pw.Anchor(name: 'vocab-$number', child: child);
}

/// 右栏词汇笔记列（无笔记时占位保持左栏宽度恒定）
///
/// 每个词条包锚点 `vocab-{n}`（正文标号跳转目标），词条前放同号标号。
/// 顶部补 [_sentenceText] 相同的 2pt 上内边距，使首个词条与句子首行上沿对齐
/// （句子正文有 vertical:2 内边距，右栏无则整体偏高）。
pw.Widget _vocabColumn(List<StudyPdfVocabNote> notes) {
  if (notes.isEmpty) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final note in notes)
          _anchorIfNumbered(
            note.number,
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        if (note.number > 0) ...[
                          _vocabMarkerSpan(note.number),
                          const pw.TextSpan(text: ' '),
                        ],
                        pw.TextSpan(
                          text: _sanitize(note.term),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _vocabTermColor,
                          ),
                        ),
                        if (note.phonetic.isNotEmpty)
                          pw.TextSpan(
                            // 音标可能已自带首尾斜杠（AI 词典 pronunciation
                            // 常含 `/.../`），剥掉后统一补一层，避免双斜线
                            text:
                                '  /${_stripPhoneticSlashes(_sanitize(note.phonetic))}/',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontStyle: pw.FontStyle.italic,
                              color: _mutedColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final gloss in note.glosses)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 4, top: 1),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          style: const pw.TextStyle(
                            fontSize: 8,
                            lineSpacing: 2,
                            color: _inkColor,
                          ),
                          children: [
                            const pw.TextSpan(text: '· '),
                            // 词性斜体（弱化色），与释义文本分离
                            if (gloss.pos.isNotEmpty)
                              pw.TextSpan(
                                text: '${_sanitize(gloss.pos)} ',
                                style: pw.TextStyle(
                                  fontStyle: pw.FontStyle.italic,
                                  color: _mutedColor,
                                ),
                              ),
                            pw.TextSpan(text: _sanitize(gloss.text)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// 句子下方的翻译：无底色灰色小字（弱化）
pw.Widget _translationText(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 1, bottom: 2),
    child: pw.Text(
      _sanitize(text),
      style: const pw.TextStyle(
        fontSize: 9,
        lineSpacing: 2.5,
        color: _mutedColor,
      ),
    ),
  );
}

/// 附录「句子解析」：另起一页，逐条 [n] 句子原文 + 语法/词汇/听力
///
/// 条目内各字段是独立顶层块，长解析可跨页断行。
List<pw.Widget> _appendixBlocks(
  StudyPdfDocument document,
  Map<int, int> noteNumbers,
  StudyPdfLabels labels,
) {
  final blocks = <pw.Widget>[
    pw.NewPage(),
    pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.5, color: _hairlineColor),
        ),
      ),
      child: pw.Text(
        labels.appendixTitle,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _inkColor,
        ),
      ),
    ),
    pw.SizedBox(height: 12),
  ];

  for (final paragraph in document.paragraphs) {
    for (final sentence in paragraph) {
      final number = noteNumbers[sentence.index];
      if (number == null) continue;
      // 条目锚点 `note-{n}`（正文尾注 [n] 跳转目标）；
      // 条目 [n] 链接回正文句子锚点；句子原文加粗便于扫读定位
      blocks.add(
        pw.Anchor(
          name: 'note-$number',
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(
                fontSize: 9.5,
                lineSpacing: 2.5,
                color: _inkColor,
              ),
              children: [
                pw.TextSpan(
                  text: '[$number]  ',
                  // 方括号字形上下超出字母，同字号显得偏大偏高；
                  // 缩小一号让视觉中心与句子对齐
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _mutedColor,
                  ),
                  annotation: pw.AnnotationLink('sent-${sentence.index}'),
                ),
                pw.TextSpan(
                  text: _sanitize(sentence.text),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
      if (sentence.vocabulary != null) {
        blocks.add(_analysisField(labels.vocabulary, sentence.vocabulary!));
      }
      if (sentence.listening != null) {
        blocks.add(_analysisField(labels.listening, sentence.listening!));
      }
      if (sentence.grammar != null) {
        blocks.add(_analysisField(labels.grammar, sentence.grammar!));
      }
      blocks.add(pw.SizedBox(height: 12));
    }
  }
  return blocks;
}

/// 附录条目里的一个解析字段：灰底 badge 标签 + 正文
///
/// 标签做成背景 badge 让语法/词汇/听力三段边界一眼可辨；
/// 正文里的 `引用片段` 转为背景高亮块（见 [_inlineHighlightSpans]）。
pw.Widget _analysisField(String label, String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 14, top: 5),
    child: pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(
          fontSize: 8.5,
          lineSpacing: 2.5,
          color: _inkColor,
        ),
        children: [
          // baseline = -(下内边距 + 字号×NotoSans descent 0.293)，
          // 使 badge 内文字基线与行文字基线对齐（视觉校准确认）
          pw.WidgetSpan(
            baseline: -3.0,
            child: _PaintIsolate(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: pw.BoxDecoration(
                  color: _fieldBadgeBgColor,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _fieldBadgeTextColor,
                  ),
                ),
              ),
            ),
          ),
          const pw.TextSpan(text: '  '),
          ..._inlineHighlightSpans(_sanitize(text)),
        ],
      ),
    ),
  );
}

/// 解析正文里的反引号引用（`` `...` ``）匹配
final _backtickPattern = RegExp('`([^`]+)`');

/// 解析正文里的音标（`/.../`）匹配：斜杠间只允许拉丁字母、IPA 区段
/// （ɐ-˿）、ŋ/æ/ð/θ、重音长音符及少量标点
final _phoneticPattern = RegExp(r"/[A-Za-zæðŋθɐ-ʯʰ-˿'’:. \-]+/");

/// 音标外的普通斜杠用法（如 and/or）不含非 ASCII 音标字符——
/// 仅当内容含 IPA 字符、或是 /z/ 这类超短纯字母时才当音标
bool _looksLikePhonetic(String inner) {
  if (RegExp(r'[^\x00-\x7F]').hasMatch(inner)) return true;
  return inner.length <= 4 && !inner.contains(' ');
}

/// 把普通解析文本按音标切分：`/.../` 渲染为斜体（与右栏音标一致）
List<pw.InlineSpan> _textWithPhonetics(String text) {
  final spans = <pw.InlineSpan>[];
  var cursor = 0;
  for (final match in _phoneticPattern.allMatches(text)) {
    final content = text.substring(match.start, match.end);
    if (!_looksLikePhonetic(content.substring(1, content.length - 1))) {
      continue;
    }
    if (match.start > cursor) {
      spans.add(pw.TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(
      pw.TextSpan(
        text: content,
        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(pw.TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

/// 把解析正文按反引号引用切分：引用片段渲染为灰底高亮块
/// （类似 badge，便于识别句中被讲解的原文），其余为普通文本
/// （音标再经 [_textWithPhonetics] 转斜体）。
///
/// 内联组件不可换行，超过 [_maxHighlightChars] 的引用退化为
/// 无底色粗体文本，防撑破版面。
List<pw.InlineSpan> _inlineHighlightSpans(String text) {
  final spans = <pw.InlineSpan>[];
  var cursor = 0;
  for (final match in _backtickPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.addAll(_textWithPhonetics(text.substring(cursor, match.start)));
    }
    cursor = match.end;
    final content = match.group(1)!.trim();
    if (content.isEmpty) continue;
    if (content.length <= _maxHighlightChars) {
      spans.add(
        pw.WidgetSpan(
          baseline: -3.3,
          child: _PaintIsolate(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 3,
                vertical: 1,
              ),
              decoration: pw.BoxDecoration(
                color: _inlineHighlightBgColor,
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Text(
                content,
                style: const pw.TextStyle(fontSize: 8, color: _inkColor),
              ),
            ),
          ),
        ),
      );
    } else {
      spans.add(
        pw.TextSpan(
          text: content,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      );
    }
  }
  if (cursor < text.length) {
    spans.addAll(_textWithPhonetics(text.substring(cursor)));
  }
  return spans;
}

/// 剥去音标首尾的斜杠/方括号与空白：不同词典源音标形态不一
/// （`/.../`、`[...]`、裸音标），统一后由渲染层补一层 `/.../`。
String _stripPhoneticSlashes(String phonetic) {
  return phonetic.replaceAll(RegExp(r'^[\s/\[\]]+|[\s/\[\]]+$'), '');
}

/// 文本清洗：剔除控制字符（如 SentenceAnalysis.fieldSeparator U+001F），
/// 并截断超长字段防单块超一页高度抛异常。
///
/// 控制字符替换为空格保持等长（收藏命中掩码按原文偏移计算，不能错位）。
String _sanitize(String text) {
  var cleaned = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
  if (cleaned.length > _maxFieldChars) {
    cleaned = '${cleaned.substring(0, _maxFieldChars)}…';
  }
  return cleaned;
}
