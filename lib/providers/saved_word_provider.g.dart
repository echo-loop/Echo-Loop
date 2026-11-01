// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_word_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$savedTextIndexHash() => r'cfc62bb903b206a791b069fe000e1b69009f5ff0';

/// 收藏文本匹配索引（正文收藏标记的唯一消费入口）
///
/// 合并两张收藏表的 key 并统一归一化分桶（见 [SavedTextIndex]）。
/// keepAlive + 派生自两个流 provider：索引只在收藏集合变化时重建，
/// 被所有可见句子共享（避免每个句子组件各自重复归一化全部 key）。
///
/// Copied from [savedTextIndex].
@ProviderFor(savedTextIndex)
final savedTextIndexProvider = Provider<SavedTextIndex>.internal(
  savedTextIndex,
  name: r'savedTextIndexProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$savedTextIndexHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SavedTextIndexRef = ProviderRef<SavedTextIndex>;
String _$savedWordDictEntriesHash() =>
    r'b03f0c8cf56f1fea9824c349a06c1f8b1bd7b8b4';

/// 收藏单词列表的批量字典条目
///
/// 监听 [savedWordListProvider]，当单词列表变化时批量查询所有字典释义。
/// 避免每个列表项独立异步查询导致释义延迟闪烁。
///
/// Copied from [savedWordDictEntries].
@ProviderFor(savedWordDictEntries)
final savedWordDictEntriesProvider =
    AutoDisposeFutureProvider<Map<String, DictEntry>>.internal(
      savedWordDictEntries,
      name: r'savedWordDictEntriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedWordDictEntriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SavedWordDictEntriesRef =
    AutoDisposeFutureProviderRef<Map<String, DictEntry>>;
String _$savedWordListHash() => r'cb11e75f8d45b8d48f06db9fe5a3b60dfac492bf';

/// 收藏单词列表 Provider（流式）
///
/// 监听所有收藏单词的变化，按收藏时间倒序。
///
/// Copied from [SavedWordList].
@ProviderFor(SavedWordList)
final savedWordListProvider =
    StreamNotifierProvider<SavedWordList, List<SavedWord>>.internal(
      SavedWordList.new,
      name: r'savedWordListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedWordListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SavedWordList = StreamNotifier<List<SavedWord>>;
String _$savedWordTextsHash() => r'9d8fcb202a309691e435ee15c706744678dec049';

/// 监听已收藏单词的 key 集合（用于正文收藏词下划线标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏词」。
///
/// Copied from [SavedWordTexts].
@ProviderFor(SavedWordTexts)
final savedWordTextsProvider =
    StreamNotifierProvider<SavedWordTexts, Set<String>>.internal(
      SavedWordTexts.new,
      name: r'savedWordTextsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedWordTextsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SavedWordTexts = StreamNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
