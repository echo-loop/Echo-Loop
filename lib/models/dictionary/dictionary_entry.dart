/// AI 词典条目模型
///
/// 镜像后端 `POST /api/v2/ai/dictionary` 返回的 `analysis` 结构，
/// 不做二次设计。所有字段防御性解析：缺字段/类型不符一律回退空串或空列表，
/// 渲染层据此把空字段整段隐藏。
library;

/// 安全读取字符串：非字符串或缺失回退空串
String _str(Object? raw) => raw is String ? raw : '';

/// 安全读取字符串列表：过滤非字符串元素
List<String> _strList(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList(growable: false);
}

/// 安全读取对象 Map
Map<String, dynamic> _map(Object? raw) =>
    raw is Map<String, dynamic> ? raw : const {};

/// AI 词典条目类型
enum AiDictionaryQueryType {
  /// 单词词典释义
  singleWord,

  /// 多词表达分析
  multiWord,
}

/// AI 词典结果联合类型。
///
/// 后端 `analysis.queryType` 区分单词与多词表达。旧缓存没有 `queryType`，
/// 默认按单词条目解析，保证历史缓存仍可读取。
sealed class AiDictionaryEntry {
  /// 查询类型
  AiDictionaryQueryType get queryType;

  /// 词头 / 表达本体
  String get headword;

  /// 是否无可展示内容
  bool get isEmpty;

  /// 序列化为后端 `analysis` 同构 JSON
  Map<String, dynamic> toJson();

  /// 从后端 `analysis` 对象反序列化（防御性）
  factory AiDictionaryEntry.fromJson(Map<String, dynamic> json) {
    if (json['queryType'] == 'multi_word' ||
        json.containsKey('originalExpression')) {
      return MultiWordDictionaryEntry.fromJson(json);
    }
    return DictionaryEntry.fromJson(json);
  }
}

/// AI 词典完整条目
class DictionaryEntry implements AiDictionaryEntry {
  @override
  AiDictionaryQueryType get queryType => AiDictionaryQueryType.singleWord;

  /// 词典词头（原形）
  @override
  final String headword;

  /// 英美音标
  final Pronunciation pronunciation;

  /// 各词义（按常用度排序）
  final List<WordMeaning> meanings;

  /// 常见搭配 / 固定短语 / 习语 / 短语动词
  final List<CommonExpression> commonExpressions;

  /// 词族（派生词、相关词形）
  final List<WordFamilyItem> wordFamily;

  /// 词形变化（屈折形式：第三人称单数、过去式、复数、比较级…）
  final List<WordForm> forms;

  /// 词源简注
  final String etymology;

  /// 学习者提示（易错点、用法），每条一项
  final List<String> learnerTips;

  const DictionaryEntry({
    required this.headword,
    required this.pronunciation,
    required this.meanings,
    required this.commonExpressions,
    required this.wordFamily,
    required this.forms,
    required this.etymology,
    required this.learnerTips,
  });

  /// 从后端 `analysis` 对象反序列化（防御性）
  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    final meanings = json['meanings'];
    final expressions = json['commonExpressions'];
    final family = json['wordFamily'];
    final forms = json['forms'];
    return DictionaryEntry(
      headword: _str(json['headword']),
      pronunciation: Pronunciation.fromJson(_map(json['pronunciation'])),
      meanings: meanings is List
          ? meanings
                .whereType<Map<String, dynamic>>()
                .map(WordMeaning.fromJson)
                .toList(growable: false)
          : const [],
      commonExpressions: expressions is List
          ? expressions
                .whereType<Map<String, dynamic>>()
                .map(CommonExpression.fromJson)
                .toList(growable: false)
          : const [],
      wordFamily: family is List
          ? family
                .whereType<Map<String, dynamic>>()
                .map(WordFamilyItem.fromJson)
                .toList(growable: false)
          : const [],
      forms: forms is List
          ? forms
                .whereType<Map<String, dynamic>>()
                .map(WordForm.fromJson)
                .toList(growable: false)
          : const [],
      etymology: _str(json['etymology']),
      learnerTips: _strList(json['learnerTips']),
    );
  }

  /// 序列化（用于本地 SQLite 缓存存储，保持与后端 `analysis` 同构）
  @override
  Map<String, dynamic> toJson() => {
    'queryType': 'single_word',
    'headword': headword,
    'pronunciation': pronunciation.toJson(),
    'meanings': meanings.map((m) => m.toJson()).toList(),
    'commonExpressions': commonExpressions.map((e) => e.toJson()).toList(),
    'wordFamily': wordFamily.map((w) => w.toJson()).toList(),
    'forms': forms.map((f) => f.toJson()).toList(),
    'etymology': etymology,
    'learnerTips': learnerTips,
  };

  /// 是否无任何可展示内容（用于空态判断）
  @override
  bool get isEmpty =>
      meanings.isEmpty &&
      commonExpressions.isEmpty &&
      wordFamily.isEmpty &&
      forms.isEmpty &&
      etymology.isEmpty &&
      learnerTips.isEmpty &&
      pronunciation.isEmpty;
}

/// 英美音标
class Pronunciation {
  /// 英式 IPA（可空串）
  final String uk;

  /// 美式 IPA（可空串）
  final String us;

  const Pronunciation({required this.uk, required this.us});

  factory Pronunciation.fromJson(Map<String, dynamic> json) =>
      Pronunciation(uk: _str(json['uk']), us: _str(json['us']));

  Map<String, dynamic> toJson() => {'uk': uk, 'us': us};

  /// 英美音标均为空
  bool get isEmpty => uk.isEmpty && us.isEmpty;
}

/// 单条词义
class WordMeaning {
  /// 词性缩写（n./v./adj.… 由后端枚举约束）
  final String partOfSpeech;

  /// 目标语言对应词（该义项的自然对译，每条一项；后端 v2 新增）
  final List<String> translation;

  /// 英文单语释义（monolingual gloss）
  final String definition;

  /// 用法注记（语域/语法/地区/易混，可空串）
  final String usageNote;

  /// 例句（中英对照）
  final List<ExampleSentence> examples;

  /// 同义词
  final List<String> synonyms;

  /// 反义词
  final List<String> antonyms;

  const WordMeaning({
    required this.partOfSpeech,
    required this.translation,
    required this.definition,
    required this.usageNote,
    required this.examples,
    required this.synonyms,
    required this.antonyms,
  });

  factory WordMeaning.fromJson(Map<String, dynamic> json) {
    final examples = json['examples'];
    return WordMeaning(
      partOfSpeech: _str(json['partOfSpeech']),
      translation: _strList(json['translation']),
      definition: _str(json['definition']),
      usageNote: _str(json['usageNote']),
      examples: examples is List
          ? examples
                .whereType<Map<String, dynamic>>()
                .map(ExampleSentence.fromJson)
                .toList(growable: false)
          : const [],
      synonyms: _strList(json['synonyms']),
      antonyms: _strList(json['antonyms']),
    );
  }

  Map<String, dynamic> toJson() => {
    'partOfSpeech': partOfSpeech,
    'translation': translation,
    'definition': definition,
    'usageNote': usageNote,
    'examples': examples.map((e) => e.toJson()).toList(),
    'synonyms': synonyms,
    'antonyms': antonyms,
  };
}

/// 例句（中英对照）
class ExampleSentence {
  /// 英文例句
  final String sentence;

  /// 译文
  final String translation;

  const ExampleSentence({required this.sentence, required this.translation});

  factory ExampleSentence.fromJson(Map<String, dynamic> json) =>
      ExampleSentence(
        sentence: _str(json['sentence']),
        translation: _str(json['translation']),
      );

  Map<String, dynamic> toJson() => {
    'sentence': sentence,
    'translation': translation,
  };
}

/// 常见搭配 / 习语 / 短语动词
class CommonExpression {
  /// 表达本体
  final String expression;

  /// 类型（collocation / idiom / phrasal verb / slang …）
  final String type;

  /// 含义或用法注记
  final String meaning;

  /// 例句
  final ExampleSentence example;

  const CommonExpression({
    required this.expression,
    required this.type,
    required this.meaning,
    required this.example,
  });

  factory CommonExpression.fromJson(Map<String, dynamic> json) =>
      CommonExpression(
        expression: _str(json['expression']),
        type: _str(json['type']),
        meaning: _str(json['meaning']),
        example: ExampleSentence.fromJson(_map(json['example'])),
      );

  Map<String, dynamic> toJson() => {
    'expression': expression,
    'type': type,
    'meaning': meaning,
    'example': example.toJson(),
  };
}

/// 词族条目（派生词 / 相关词形）
class WordFamilyItem {
  /// 相关词
  final String word;

  /// 词性缩写
  final String partOfSpeech;

  /// 简明释义（与词头含义不同处由后端点明）
  final String meaning;

  /// 例句
  final ExampleSentence example;

  const WordFamilyItem({
    required this.word,
    required this.partOfSpeech,
    required this.meaning,
    required this.example,
  });

  factory WordFamilyItem.fromJson(Map<String, dynamic> json) => WordFamilyItem(
    word: _str(json['word']),
    partOfSpeech: _str(json['partOfSpeech']),
    meaning: _str(json['meaning']),
    example: ExampleSentence.fromJson(_map(json['example'])),
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'partOfSpeech': partOfSpeech,
    'meaning': meaning,
    'example': example.toJson(),
  };
}

/// 词形变化条目（屈折形式）
class WordForm {
  /// 屈折形式（英文，如 does / did / done / doing）
  final String form;

  /// 形式名称（目标语言，如「过去式」「复数」）
  final String label;

  const WordForm({required this.form, required this.label});

  factory WordForm.fromJson(Map<String, dynamic> json) =>
      WordForm(form: _str(json['form']), label: _str(json['label']));

  Map<String, dynamic> toJson() => {'form': form, 'label': label};
}

/// AI 多词表达分析条目
class MultiWordDictionaryEntry implements AiDictionaryEntry {
  @override
  AiDictionaryQueryType get queryType => AiDictionaryQueryType.multiWord;

  /// 表达本体
  final String originalExpression;

  /// 表达不自然、错误或受限时的纠正说明；自然时为空。
  final String naturalness;

  /// 表达类别（短语动词、搭配、习语、术语等）。
  final String category;

  /// 发音提示（连读、弱读、重音等），每条一项，无明显提示时为空列表。
  final List<String> pronunciationTips;

  /// 核心要点：学习者最该掌握的信息，每条一项，最重要在前。
  final List<String> keyPoints;

  /// 各含义与对应场景用法。
  final List<MultiWordMeaning> meanings;

  /// 相近、替代或易混表达。
  final List<SimilarExpression> similarExpressions;

  /// 补充背景。
  final String background;

  @override
  String get headword => originalExpression;

  const MultiWordDictionaryEntry({
    required this.originalExpression,
    required this.naturalness,
    required this.category,
    required this.pronunciationTips,
    required this.keyPoints,
    required this.meanings,
    required this.similarExpressions,
    required this.background,
  });

  factory MultiWordDictionaryEntry.fromJson(Map<String, dynamic> json) {
    final meanings = json['meanings'];
    final similarExpressions = json['similarExpressions'];
    return MultiWordDictionaryEntry(
      originalExpression: _str(json['originalExpression']).isNotEmpty
          ? _str(json['originalExpression'])
          : _str(json['headword']),
      naturalness: _str(json['naturalness']),
      category: _str(json['category']),
      pronunciationTips: _strList(json['pronunciationTips']),
      keyPoints: _strList(json['keyPoints']),
      meanings: meanings is List
          ? meanings
                .whereType<Map<String, dynamic>>()
                .map(MultiWordMeaning.fromJson)
                .toList(growable: false)
          : const [],
      similarExpressions: similarExpressions is List
          ? similarExpressions
                .whereType<Map<String, dynamic>>()
                .map(SimilarExpression.fromJson)
                .toList(growable: false)
          : const [],
      background: _str(json['background']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'queryType': 'multi_word',
    'originalExpression': originalExpression,
    'naturalness': naturalness,
    'category': category,
    'pronunciationTips': pronunciationTips,
    'keyPoints': keyPoints,
    'meanings': meanings.map((m) => m.toJson()).toList(),
    'similarExpressions': similarExpressions.map((e) => e.toJson()).toList(),
    'background': background,
  };

  @override
  bool get isEmpty =>
      naturalness.isEmpty &&
      category.isEmpty &&
      pronunciationTips.isEmpty &&
      keyPoints.isEmpty &&
      meanings.isEmpty &&
      similarExpressions.isEmpty &&
      background.isEmpty;
}

/// 多词表达义项
class MultiWordMeaning {
  /// 目标语言自然对译
  final List<String> translation;

  /// 例句
  final List<ExampleSentence> examples;

  const MultiWordMeaning({
    required this.translation,
    required this.examples,
  });

  factory MultiWordMeaning.fromJson(Map<String, dynamic> json) {
    final examples = json['examples'];
    return MultiWordMeaning(
      translation: _strList(json['translation']),
      examples: examples is List
          ? examples
                .whereType<Map<String, dynamic>>()
                .map(ExampleSentence.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'translation': translation,
    'examples': examples.map((e) => e.toJson()).toList(),
  };

  bool get isEmpty => translation.isEmpty && examples.isEmpty;
}

/// 相近、替代或易混表达
class SimilarExpression {
  final String expression;
  final String difference;
  final String sentence;
  final String translation;

  const SimilarExpression({
    required this.expression,
    required this.difference,
    required this.sentence,
    required this.translation,
  });

  factory SimilarExpression.fromJson(Map<String, dynamic> json) =>
      SimilarExpression(
        expression: _str(json['expression']),
        difference: _str(json['difference']),
        sentence: _str(json['sentence']),
        translation: _str(json['translation']),
      );

  Map<String, dynamic> toJson() => {
    'expression': expression,
    'difference': difference,
    'sentence': sentence,
    'translation': translation,
  };
}
