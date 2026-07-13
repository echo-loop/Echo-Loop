/// AI 句子翻译与解析结果模型
///
/// 用于存储后端 AI 返回的翻译和语法/词汇/听力解析结果。
/// 解析结果为结构化嵌套数组（对齐后端 `/api/v1/stream/analyze`），支持流式渐显：
/// 每一帧 [SentenceAnalysis.fromJson] 都作用在「半成品累积快照」上，故所有反序列化
/// 必须防御性、缺字段回退空值、**永不抛**。
library;

/// 防御性读字符串：非字符串（含 null）回退空串。
String _str(Object? v) => v is String ? v : '';

/// 防御性把 JSON 数组映射为强类型列表：过滤 null / 非 Map 元素（流式累积时数组
/// 可能被 null 占位扩容），每个元素用 [fromJson] 解析。非数组回退空列表。
List<T> _mapList<T>(Object? v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map<String, dynamic>) fromJson(e),
  ];
}

/// 把 (标签, 详解) 列表拍平成多行文本（供 PDF 导出复用现有字符串渲染）。
/// 每条一行 `标签: 详解`；标签为空则只输出详解；两者皆空则跳过。
String _joinPairs(List<(String, String)> pairs) {
  final lines = <String>[];
  for (final (key, value) in pairs) {
    final k = key.trim();
    final val = value.trim();
    if (k.isEmpty && val.isEmpty) continue;
    if (k.isEmpty) {
      lines.add(val);
    } else if (val.isEmpty) {
      lines.add(k);
    } else {
      lines.add('$k: $val');
    }
  }
  return lines.join('\n');
}

/// AI 翻译结果
class SentenceTranslation {
  /// 翻译文本
  final String translation;

  const SentenceTranslation({required this.translation});

  /// 从 API 响应 JSON 反序列化
  ///
  /// 防御式读取：流式渐显时每帧作用于「半成品累积快照」，`translation` 字段可能
  /// 尚未到齐（缺失/非字符串），用 [_str] 回退空串，**永不抛**（同 [SentenceAnalysis]）。
  factory SentenceTranslation.fromJson(Map<String, dynamic> json) =>
      SentenceTranslation(translation: _str(json['translation']));
}

/// 语法要点：一条句子结构分析。
class GrammarPoint {
  /// 结构或句型的短标签
  final String point;

  /// 该结构在本句中如何运作的通俗说明
  final String note;

  const GrammarPoint({required this.point, required this.note});

  factory GrammarPoint.fromJson(Map<String, dynamic> json) =>
      GrammarPoint(point: _str(json['point']), note: _str(json['note']));

  Map<String, dynamic> toJson() => {'point': point, 'note': note};

  bool get isEmpty => point.trim().isEmpty && note.trim().isEmpty;
}

/// 词汇要点：一条关键词/表达。
class VocabularyItem {
  /// 取自原句的单词或短语
  final String term;

  /// 在本句中的含义、常见搭配或相关表达
  final String note;

  const VocabularyItem({required this.term, required this.note});

  factory VocabularyItem.fromJson(Map<String, dynamic> json) =>
      VocabularyItem(term: _str(json['term']), note: _str(json['note']));

  Map<String, dynamic> toJson() => {'term': term, 'note': note};

  bool get isEmpty => term.trim().isEmpty && note.trim().isEmpty;
}

/// 听力要点：一条发音/听力难点。
class ListeningPoint {
  /// 取自原句的单词或短语
  final String phrase;

  /// 通俗的发音/听力难点说明
  final String note;

  const ListeningPoint({required this.phrase, required this.note});

  factory ListeningPoint.fromJson(Map<String, dynamic> json) =>
      ListeningPoint(phrase: _str(json['phrase']), note: _str(json['note']));

  Map<String, dynamic> toJson() => {'phrase': phrase, 'note': note};

  bool get isEmpty => phrase.trim().isEmpty && note.trim().isEmpty;
}

/// AI 解析结果（结构化）
///
/// 三段各为一组要点对象，无 `label: value` 文本分隔解析。既用于流式累积快照的逐帧
/// 反序列化，也用于 L2 缓存（`toJson`/`fromJson` 对称）。
class SentenceAnalysis {
  /// 语法分析（1~3 条）
  final List<GrammarPoint> grammar;

  /// 词汇分析（0~4 条）
  final List<VocabularyItem> vocabulary;

  /// 听力分析（连读、弱读、缩读等语音现象，1~3 条）
  final List<ListeningPoint> listening;

  const SentenceAnalysis({
    this.grammar = const [],
    this.vocabulary = const [],
    this.listening = const [],
  });

  /// 从结构化 entry 反序列化（流式累积快照 / L2 缓存共用）。
  ///
  /// 期望顶层 `{ "grammar": [...], "vocabulary": [...], "listening": [...] }`
  /// （对齐后端 stream/analyze 的字段级增量路径 `["grammar",0,"point"]` 等）。
  /// 防御性：缺字段/类型不符回退空列表，永不抛——每帧作用于半成品快照。
  factory SentenceAnalysis.fromJson(Map<String, dynamic> json) =>
      SentenceAnalysis(
        grammar: _mapList(json['grammar'], GrammarPoint.fromJson),
        vocabulary: _mapList(json['vocabulary'], VocabularyItem.fromJson),
        listening: _mapList(json['listening'], ListeningPoint.fromJson),
      );

  /// 序列化为结构化 JSON（供 L2 缓存写入）。
  Map<String, dynamic> toJson() => {
    'grammar': [for (final g in grammar) g.toJson()],
    'vocabulary': [for (final v in vocabulary) v.toJson()],
    'listening': [for (final l in listening) l.toJson()],
  };

  /// 是否三段全空（首帧未到齐时为 true，UI 据此显示 shimmer）。
  bool get isEmpty =>
      grammar.every((g) => g.isEmpty) &&
      vocabulary.every((v) => v.isEmpty) &&
      listening.every((l) => l.isEmpty);

  bool get isNotEmpty => !isEmpty;

  /// PDF 文本投影：把结构化要点拍平成多行 `标签: 详解` 文本，供 PDF 导出复用
  /// 现有字符串渲染（PDF 侧不感知结构化）。
  String get grammarText =>
      _joinPairs([for (final g in grammar) (g.point, g.note)]);
  String get vocabularyText =>
      _joinPairs([for (final v in vocabulary) (v.term, v.note)]);
  String get listeningText =>
      _joinPairs([for (final l in listening) (l.phrase, l.note)]);
}
