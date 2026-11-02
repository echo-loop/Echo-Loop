/// 可见词典源 + 生效默认源（派生 provider，单一真相源）
///
/// 切换器与设置页只消费 [visibleDictionarySources]；
/// 弹窗初始选中 [resolvedDefaultSourceId]（带兜底，避免默认源被禁用后无源可选）。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/dictionary/dictionary_settings.dart';
import '../../services/dictionary/dictionary_source.dart';
import 'dictionary_registry.dart';
import 'dictionary_settings_provider.dart';

part 'visible_sources_provider.g.dart';

/// 设置过滤后的可见源列表（顺序沿用注册表）
@riverpod
List<DictionarySource> visibleDictionarySources(Ref ref) {
  final all = ref.watch(dictionarySourcesProvider);
  final settings = ref.watch(dictionarySettingsProvider);
  return all
      .where((s) => !s.canBeDisabled || !settings.disabledIds.contains(s.id))
      .toList(growable: false);
}

/// 生效的默认源 id（默认源不可见时回退到第一个可见源）
@riverpod
String resolvedDefaultSourceId(Ref ref) {
  final visible = ref.watch(visibleDictionarySourcesProvider);
  final wanted = ref.watch(dictionarySettingsProvider).defaultSourceId;
  if (visible.any((s) => s.id == wanted)) return wanted;
  return visible.isNotEmpty ? visible.first.id : DictionarySettings.defaultId;
}
