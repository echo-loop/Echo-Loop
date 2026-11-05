// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_word_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 监听已收藏单词的 key 集合（用于正文收藏词下划线标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏词」。

@ProviderFor(SavedWordTexts)
final savedWordTextsProvider = SavedWordTextsProvider._();

/// 监听已收藏单词的 key 集合（用于正文收藏词下划线标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏词」。
final class SavedWordTextsProvider
    extends $StreamNotifierProvider<SavedWordTexts, Set<String>> {
  /// 监听已收藏单词的 key 集合（用于正文收藏词下划线标记）
  ///
  /// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
  /// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
  /// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
  /// 真实 DB 故障伪装成「用户没有收藏词」。
  SavedWordTextsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedWordTextsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedWordTextsHash();

  @$internal
  @override
  SavedWordTexts create() => SavedWordTexts();
}

String _$savedWordTextsHash() => r'9d8fcb202a309691e435ee15c706744678dec049';

/// 监听已收藏单词的 key 集合（用于正文收藏词下划线标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏词」。

abstract class _$SavedWordTexts extends $StreamNotifier<Set<String>> {
  Stream<Set<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 收藏文本匹配索引（正文收藏标记的唯一消费入口）
///
/// 合并两张收藏表的 key 并统一归一化分桶（见 [SavedTextIndex]）。
/// keepAlive + 派生自两个流 provider：索引只在收藏集合变化时重建，
/// 被所有可见句子共享（避免每个句子组件各自重复归一化全部 key）。

@ProviderFor(savedTextIndex)
final savedTextIndexProvider = SavedTextIndexProvider._();

/// 收藏文本匹配索引（正文收藏标记的唯一消费入口）
///
/// 合并两张收藏表的 key 并统一归一化分桶（见 [SavedTextIndex]）。
/// keepAlive + 派生自两个流 provider：索引只在收藏集合变化时重建，
/// 被所有可见句子共享（避免每个句子组件各自重复归一化全部 key）。

final class SavedTextIndexProvider
    extends $FunctionalProvider<SavedTextIndex, SavedTextIndex, SavedTextIndex>
    with $Provider<SavedTextIndex> {
  /// 收藏文本匹配索引（正文收藏标记的唯一消费入口）
  ///
  /// 合并两张收藏表的 key 并统一归一化分桶（见 [SavedTextIndex]）。
  /// keepAlive + 派生自两个流 provider：索引只在收藏集合变化时重建，
  /// 被所有可见句子共享（避免每个句子组件各自重复归一化全部 key）。
  SavedTextIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedTextIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedTextIndexHash();

  @$internal
  @override
  $ProviderElement<SavedTextIndex> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SavedTextIndex create(Ref ref) {
    return savedTextIndex(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedTextIndex value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedTextIndex>(value),
    );
  }
}

String _$savedTextIndexHash() => r'365bc1ae31a38cc929447026465750d5564fe3d3';

/// 收藏单词列表的批量字典条目
///
/// 监听 [savedWordListProvider]，当单词列表变化时批量查询所有字典释义。
/// 避免每个列表项独立异步查询导致释义延迟闪烁。

@ProviderFor(savedWordDictEntries)
final savedWordDictEntriesProvider = SavedWordDictEntriesProvider._();

/// 收藏单词列表的批量字典条目
///
/// 监听 [savedWordListProvider]，当单词列表变化时批量查询所有字典释义。
/// 避免每个列表项独立异步查询导致释义延迟闪烁。

final class SavedWordDictEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, DictEntry>>,
          Map<String, DictEntry>,
          FutureOr<Map<String, DictEntry>>
        >
    with
        $FutureModifier<Map<String, DictEntry>>,
        $FutureProvider<Map<String, DictEntry>> {
  /// 收藏单词列表的批量字典条目
  ///
  /// 监听 [savedWordListProvider]，当单词列表变化时批量查询所有字典释义。
  /// 避免每个列表项独立异步查询导致释义延迟闪烁。
  SavedWordDictEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedWordDictEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedWordDictEntriesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, DictEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, DictEntry>> create(Ref ref) {
    return savedWordDictEntries(ref);
  }
}

String _$savedWordDictEntriesHash() =>
    r'957ac836e9afd801f18b99ab9316b4c86d63026e';
