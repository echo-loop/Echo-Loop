/// 词典查询结果（密封类）
///
/// 各数据源返回形态差异巨大，不强行统一为超集模型，而是各自一个 final 子类，
/// 渲染层 `switch` 表达式编译期穷尽检查——新增数据源若漏写渲染分支即编译报错，
/// 是「可插拔」框架的类型安全网。
library;

import '../dict_entry.dart';
import 'dictionary_entry.dart';

/// 词典查询结果基类
sealed class DictionaryLookupResult {
  const DictionaryLookupResult();

  /// 用于展示/收藏的词形（各源自行决定，通常取返回的原形）
  String get headword;
}

/// 在线词典结果（包装 [DictEntry]）
final class LocalDictResult extends DictionaryLookupResult {
  /// 在线词典条目
  final DictEntry entry;

  const LocalDictResult(this.entry);

  @override
  String get headword => entry.word;
}

/// AI 词典结果（包装后端 v2 [AiDictionaryEntry]）
final class AiDictResult extends DictionaryLookupResult {
  /// AI 词典条目
  final AiDictionaryEntry entry;

  const AiDictResult(this.entry);

  @override
  String get headword => entry.headword;
}

/// 网页型词典结果（如 Cambridge / Oxford / Longman 等），
/// 只携带待加载的网页 URL，实际内容由 WebView 渲染。
final class WebDictResult extends DictionaryLookupResult {
  /// 来源源 id（区分是哪个网页词典，供视图选注入脚本、保活按源复用）
  final String sourceId;

  /// 待加载的词典网页地址
  final Uri url;

  /// 查询词（headword 兜底，URL 无法解析原形时使用）
  final String word;

  const WebDictResult({
    required this.sourceId,
    required this.url,
    required this.word,
  });

  @override
  String get headword => word;
}
