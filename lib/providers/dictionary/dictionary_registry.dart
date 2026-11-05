/// 词典数据源注册表
///
/// 全部已实现 source 的静态注册表——注册即「可插拔」的插槽。
/// 注册顺序 = 切换器默认排列顺序 + 默认源回退优先级（前者优先）。
/// 新增 source：实现 [DictionarySource] + 在 [dictionarySources] 列表加一行即接入。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config/api_config.dart';
import '../../database/providers.dart';
import '../../services/backend_dio.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../services/dictionary/dictionary_source.dart';
import '../../services/dictionary/local_dictionary_source.dart';
import '../../services/dictionary/web_dictionary_source.dart';
import '../../services/dictionary_service.dart';
import '../../services/runtime_endpoint_router.dart';
import '../../services/sentence_ai_api_client.dart';
import '../package_info_provider.dart';
import '../settings_provider.dart';

part 'dictionary_registry.g.dart';

/// 在线词典服务：随母语切换重建（词典 ID 由母语决定）
@Riverpod(keepAlive: true)
DictionaryService dictionaryService(Ref ref) {
  final nativeLanguage = ref.watch(
    appSettingsProvider.select((s) => s.nativeLanguage),
  );
  // 免登录接口，不携带鉴权 token；但仍需 client-info 头与端点路由
  final dio = createBackendDio(
    baseUrl: apiBaseUrl,
    endpointRouter: runtimeEndpointRouter,
    appVersion: readAppVersion(ref),
    apiLogTag: 'DICT',
  );
  ref.onDispose(dio.close);
  return DictionaryService(
    cacheDao: ref.watch(dictionaryCacheDaoProvider),
    dio: dio,
    dictId: 'en_$nativeLanguage',
  );
}

/// 本地（在线）词典源
@Riverpod(keepAlive: true)
LocalDictionarySource localDictionarySource(Ref ref) =>
    LocalDictionarySource(ref.watch(dictionaryServiceProvider));

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
