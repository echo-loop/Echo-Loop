/// 收藏导出的内容选项与格式
///
/// 选项是不可变值对象，导出流程只读它。新增导出内容 = 加一个字段（默认值保持
/// 现有行为）+ loader 中一处判断 + 弹窗或预览页中一行开关。
library;

/// 导出格式（新增格式 = 加枚举值；渲染分派为穷尽 switch，漏实现编译期报错）
enum FavoritesExportFormat { pdf }

/// 收藏导出选项（不可变）
class FavoritesExportOptions {
  /// 是否导出收藏句子（句子按来源材料分组）
  final bool includeSentences;

  /// 是否导出收藏词汇（单词与意群，平铺按字母排序）
  final bool includeWords;

  /// 句子是否附带译文（仅读本地翻译缓存，缓存未命中则不显示）
  final bool includeTranslation;

  /// 词汇是否附带释义与例句（仅读本地 AI 查词缓存与基础词典缓存）
  final bool includeDefinition;

  const FavoritesExportOptions({
    this.includeSentences = true,
    this.includeWords = true,
    this.includeTranslation = true,
    this.includeDefinition = true,
  });

  /// 至少选中一类内容才能导出
  bool get hasContent => includeSentences || includeWords;

  FavoritesExportOptions copyWith({
    bool? includeSentences,
    bool? includeWords,
    bool? includeTranslation,
    bool? includeDefinition,
  }) {
    return FavoritesExportOptions(
      includeSentences: includeSentences ?? this.includeSentences,
      includeWords: includeWords ?? this.includeWords,
      includeTranslation: includeTranslation ?? this.includeTranslation,
      includeDefinition: includeDefinition ?? this.includeDefinition,
    );
  }
}

/// 导出预览页的入参（经路由 extra 传递）
class FavoritesExportRequest {
  final FavoritesExportOptions options;
  final FavoritesExportFormat format;

  const FavoritesExportRequest({required this.options, required this.format});
}
