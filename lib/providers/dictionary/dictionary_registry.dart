/// 词典数据源注册表
///
/// 全部已实现 source 的静态注册表——注册即「可插拔」的插槽。
/// 注册顺序 = 切换器默认排列顺序 + 默认源回退优先级（前者优先）。
/// 新增 source：实现 [DictionarySource] + 在 [dictionarySources] 列表加一行即接入。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/providers.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../services/dictionary/dictionary_source.dart';
import '../../services/dictionary/local_dictionary_source.dart';
import '../../services/dictionary/web_dictionary_source.dart';
import '../../services/dictionary_service.dart';
import '../../services/sentence_ai_api_client.dart';

part 'dictionary_registry.g.dart';

/// 本地词典源
@Riverpod(keepAlive: true)
LocalDictionarySource localDictionarySource(Ref ref) =>
    LocalDictionarySource(DictionaryService.instance);

/// AI 词典源
///
/// 依赖延迟解析（lookup 时才读），避免枚举注册表即初始化数据库/网络栈。
@Riverpod(keepAlive: true)
AiDictionarySource aiDictionarySource(Ref ref) => AiDictionarySource(
  cacheDao: () => ref.read(sentenceAiCacheDaoProvider),
  apiClient: () => ref.read(sentenceAiApiClientProvider),
);

/// 网页词典源列表（由 [kWebDictConfigs] 配置生成：Cambridge / Oxford / ...）
@Riverpod(keepAlive: true)
List<WebDictionarySource> webDictionarySources(Ref ref) =>
    kWebDictConfigs.map(WebDictionarySource.new).toList(growable: false);

/// 全部数据源（顺序即默认排列/回退优先级）
@Riverpod(keepAlive: true)
List<DictionarySource> dictionarySources(Ref ref) => [
  ref.watch(localDictionarySourceProvider),
  ref.watch(aiDictionarySourceProvider),
  ...ref.watch(webDictionarySourcesProvider),
];

/// id → source 查找表
@Riverpod(keepAlive: true)
Map<String, DictionarySource> dictionarySourcesById(Ref ref) => {
  for (final s in ref.watch(dictionarySourcesProvider)) s.id: s,
};
