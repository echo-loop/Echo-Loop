/// 学习材料导出 PDF 的数据模型
///
/// 由 `StudyPdfLoader` 聚合产出、`study_pdf_builder` 消费渲染。
/// 只含基础类型（String/int/bool/List），可安全跨 isolate 传递
/// （PDF 生成在 compute isolate 中执行）。
library;

/// 音频时长格式化：mm:ss（≥1 小时为 h:mm:ss），locale 无关
String formatStudyPdfDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// PDF 内的本地化文案（跨 isolate 传递，均为已解析的纯字符串）
///
/// builder 在 compute isolate 内运行、拿不到 BuildContext，
/// 由调用方（pdf_preview_screen）用 `AppLocalizations` 组装后传入。
class StudyPdfLabels {
  /// 元信息行：时长（已含前缀与格式化值，如 `时长 05:32` / `Duration 05:32`）
  final String metaDuration;

  /// 元信息行：句数（如 `24 句` / `24 sentences`）
  final String metaSentences;

  /// 元信息行：词数（如 `386 词` / `386 words`）
  final String metaWords;

  /// 附录标题（`附录 · 句子解析` / `Appendix · Sentence Analysis`）
  final String appendixTitle;

  /// 附录解析字段徽章：语法 / 词汇 / 听力（复用 App 内 AI 解析面板文案）
  final String grammar;
  final String vocabulary;
  final String listening;

  const StudyPdfLabels({
    required this.metaDuration,
    required this.metaSentences,
    required this.metaWords,
    required this.appendixTitle,
    required this.grammar,
    required this.vocabulary,
    required this.listening,
  });
}

/// 一份待导出的学习材料文档
class StudyPdfDocument {
  /// 文档标题（音频名称）
  final String title;

  /// 段落列表，每个段落是若干连续句子
  ///
  /// 分段复用 `groupSentencesIntoParagraphs` 的结果，用于版式上的段间距。
  final List<List<StudyPdfSentence>> paragraphs;

  /// 音频总时长（秒）
  ///
  /// loader 优先取音频元数据，缺失时回退为字幕末句结束时间；0 表示未知，
  /// builder 不渲染时长。
  final int durationSeconds;

  /// 全文单词总数（按 App 统一分词器统计，只计 isWord token）
  final int wordCount;

  const StudyPdfDocument({
    required this.title,
    required this.paragraphs,
    this.durationSeconds = 0,
    this.wordCount = 0,
  });

  /// 文档内句子总数
  int get sentenceCount => paragraphs.fold(0, (sum, p) => sum + p.length);
}

/// 一个句子及其关联的笔记内容
class StudyPdfSentence {
  /// 句子在字幕中的索引
  final int index;

  /// 句子原文
  final String text;

  /// 是否为收藏句（导出时在句末加书签图标）
  final bool isBookmarked;

  /// 收藏词/词组/意群在句中命中的字符区间 [start, end) 列表
  ///
  /// 由 loader 用 `savedCharRanges` 计算（与 App 正文橙色下划线语义一致），
  /// builder 据此给命中片段加橙色下划线。int 记录可安全跨 isolate。
  final List<(int, int)> savedRanges;

  /// 句子翻译（缓存命中才有，否则为 null 不渲染）
  final String? translation;

  /// AI 解析：语法分析（缓存命中才有）
  final String? grammar;

  /// AI 解析：词汇分析（缓存命中才有）
  final String? vocabulary;

  /// AI 解析：听力分析（缓存命中才有）
  final String? listening;

  /// 该句关联的词汇笔记（收藏词 / 收藏意群），渲染在右栏
  final List<StudyPdfVocabNote> vocabNotes;

  /// 本句正文的词条标号插入点：(命中区间末尾字符位置, 词条标号) 升序列表
  ///
  /// 由 loader 用**全文档**词条逐句计算——同一收藏词在任何句子出现
  /// 都标同一个号（不限于收藏来源句），builder 据此在词后放上标标号。
  final List<(int, int)> vocabMarkers;

  const StudyPdfSentence({
    required this.index,
    required this.text,
    this.isBookmarked = false,
    this.savedRanges = const [],
    this.translation,
    this.grammar,
    this.vocabulary,
    this.listening,
    this.vocabNotes = const [],
    this.vocabMarkers = const [],
  });

  /// 是否有任一 AI 解析字段（决定正文尾注标记与附录条目）
  bool get hasAnalysis =>
      grammar != null || vocabulary != null || listening != null;
}

/// 一条词汇笔记（收藏词或收藏意群）
class StudyPdfVocabNote {
  /// 全文档统一词条标号（1..m，按正文出现顺序由 loader 分配）
  ///
  /// 正文标号 / 右栏词条 / `vocab-{n}` 锚点共用。0 表示未分配（仅测试）。
  final int number;

  /// 词条展示文本（单词原形 / 意群原始大小写文本）
  final String term;

  /// 音标（AI 词典 us 优先，其次在线词典；无则空串不渲染）
  final String phonetic;

  /// 释义列表，每条一个 bullet
  ///
  /// AI 词典命中时为各义项「词性 + 目标语翻译」；
  /// 否则为在线词典 translation 按行拆分（行首词性剥入 [StudyPdfGloss.pos]）。
  /// loader 保证非空——无任何词典结果的收藏词不产出笔记。
  final List<StudyPdfGloss> glosses;

  /// 词条在所属句子中命中的字符区间 [start, end) 列表
  ///
  /// 由 loader 用单词条索引经 `savedCharRanges` 计算，builder 据首个
  /// 区间末尾放置词条标号（正文 ↔ 右栏对应 + 内部导航）。
  /// 变形词（收藏 lemma、正文变形）可能匹配不到，为空时正文不放标号。
  final List<(int, int)> ranges;

  const StudyPdfVocabNote({
    this.number = 0,
    required this.term,
    this.phonetic = '',
    this.glosses = const [],
    this.ranges = const [],
  });

  /// 带标号复制（loader 排序后统一分配标号用）
  StudyPdfVocabNote withNumber(int number) => StudyPdfVocabNote(
    number: number,
    term: term,
    phonetic: phonetic,
    glosses: glosses,
    ranges: ranges,
  );
}

/// 一条释义（词性与释义文本分离，词性渲染为斜体）
class StudyPdfGloss {
  /// 词性缩写（如 `n.` / `vt.`），无法解析时为空串不渲染
  final String pos;

  /// 释义文本（目标语翻译）
  final String text;

  const StudyPdfGloss({this.pos = '', required this.text});
}
