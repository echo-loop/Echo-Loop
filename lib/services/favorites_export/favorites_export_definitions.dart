/// 收藏词汇的释义提取（只读本地缓存的结果，纯函数，不触发请求）
///
/// 释义取「第一个义项 + 其第一个例句」，与收藏复习页的 AI 词典展示口径一致。
library;

import '../../models/dict_entry.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../models/favorites_export/favorites_export_data.dart';

/// 收藏词汇的释义（全部可选，缺失的字段渲染层直接省略）
class WordDefinition {
  final String? phonetic;

  /// 第一个义项，含词性前缀（如 `n. 小猫`）
  final String? definition;

  /// 第一个义项的第一个例句
  final FavoriteExample? example;

  const WordDefinition({this.phonetic, this.definition, this.example});
}

/// 收藏词汇的查找单元：展示词形 + 查询键 + 来源
class VocabularySeed {
  /// 展示词形（意群保留原始大小写）
  final String term;

  /// 查询键（收藏的表面词形 / 归一化意群，与缓存键契约一致）
  final String lookupKey;

  final bool isPhrase;

  /// 来源材料 ID（材料已清除时为 null）
  final String? audioItemId;

  /// 来源句原文（已清除时为 null）
  final String? sentenceText;

  const VocabularySeed({
    required this.term,
    required this.lookupKey,
    required this.isPhrase,
    required this.audioItemId,
    required this.sentenceText,
  });

  /// 单词与意群分开计键：同名的单词与意群互不覆盖
  String get key => '${isPhrase ? 'p' : 'w'}|$lookupKey';
}

/// 去首尾空白，空串视为缺失
String? nonEmptyOrNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// 从 AI 查词结果取第一个义项与其第一个例句
///
/// 义项译文为空时回落到英文释义；义项列表为空返回 null。
WordDefinition? definitionFromAiEntry(AiDictionaryEntry entry) {
  switch (entry) {
    case DictionaryEntry():
      if (entry.meanings.isEmpty) return null;
      final meaning = entry.meanings.first;
      final gloss =
          nonEmptyOrNull(_joinTranslations(meaning.translation)) ??
          nonEmptyOrNull(meaning.definition);
      final pos = nonEmptyOrNull(meaning.partOfSpeech);
      final pronunciation =
          nonEmptyOrNull(entry.pronunciation.us) ??
          nonEmptyOrNull(entry.pronunciation.uk);
      return WordDefinition(
        phonetic: pronunciation,
        definition: gloss == null
            ? null
            : [if (pos != null) pos, gloss].join(' '),
        example: _firstExample(
          meaning.examples.map(
            (e) =>
                FavoriteExample(text: e.sentence, translation: e.translation),
          ),
        ),
      );
    case MultiWordDictionaryEntry():
      if (entry.meanings.isEmpty) return null;
      final meaning = entry.meanings.first;
      return WordDefinition(
        definition: nonEmptyOrNull(_joinTranslations(meaning.translation)),
        example: _firstExample(
          meaning.examples.map(
            (e) =>
                FavoriteExample(text: e.sentence, translation: e.translation),
          ),
        ),
      );
  }
}

/// 从基础词典缓存取第一行释义（每个义项一行，行首带词性，如 `n. 小猫`）
///
/// 基础词典不含例句。无释义且无音标时返回 null。
WordDefinition? definitionFromLocalEntry(DictEntry entry) {
  final firstLine = (entry.translation ?? '')
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  final phonetic = nonEmptyOrNull(entry.phonetic);
  final definition = nonEmptyOrNull(firstLine);
  if (definition == null && phonetic == null) return null;
  return WordDefinition(phonetic: phonetic, definition: definition);
}

String _joinTranslations(List<String> translations) =>
    translations.map((t) => t.trim()).where((t) => t.isNotEmpty).join('；');

FavoriteExample? _firstExample(Iterable<FavoriteExample> examples) {
  for (final example in examples) {
    final text = nonEmptyOrNull(example.text);
    if (text != null) {
      return FavoriteExample(
        text: text,
        translation: nonEmptyOrNull(example.translation),
      );
    }
  }
  return null;
}
