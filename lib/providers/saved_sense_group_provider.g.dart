// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_sense_group_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 监听已收藏意群的归一化文本集合（用于 badge 染色与正文收藏标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏意群」。

@ProviderFor(SavedSenseGroupTexts)
final savedSenseGroupTextsProvider = SavedSenseGroupTextsProvider._();

/// 监听已收藏意群的归一化文本集合（用于 badge 染色与正文收藏标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏意群」。
final class SavedSenseGroupTextsProvider
    extends $StreamNotifierProvider<SavedSenseGroupTexts, Set<String>> {
  /// 监听已收藏意群的归一化文本集合（用于 badge 染色与正文收藏标记）
  ///
  /// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
  /// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
  /// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
  /// 真实 DB 故障伪装成「用户没有收藏意群」。
  SavedSenseGroupTextsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedSenseGroupTextsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedSenseGroupTextsHash();

  @$internal
  @override
  SavedSenseGroupTexts create() => SavedSenseGroupTexts();
}

String _$savedSenseGroupTextsHash() =>
    r'503e0e742a707ad0c8e12871dd5647356fb58764';

/// 监听已收藏意群的归一化文本集合（用于 badge 染色与正文收藏标记）
///
/// 收藏标记是辅助功能：数据库未初始化（如宿主 widget 测试环境）时
/// 降级为空集，不崩宿主页（CLAUDE.md §7.18 默认值降级规则）。
/// 降级必须留日志——keepAlive 会把空集缓存整个会话，静默降级会把
/// 真实 DB 故障伪装成「用户没有收藏意群」。

abstract class _$SavedSenseGroupTexts extends $StreamNotifier<Set<String>> {
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

/// 监听单个意群是否已收藏

@ProviderFor(isSenseGroupSaved)
final isSenseGroupSavedProvider = IsSenseGroupSavedFamily._();

/// 监听单个意群是否已收藏

final class IsSenseGroupSavedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// 监听单个意群是否已收藏
  IsSenseGroupSavedProvider._({
    required IsSenseGroupSavedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isSenseGroupSavedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isSenseGroupSavedHash();

  @override
  String toString() {
    return r'isSenseGroupSavedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as String;
    return isSenseGroupSaved(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsSenseGroupSavedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isSenseGroupSavedHash() => r'22981f6015544409ed137aa83ea151d85fa0164a';

/// 监听单个意群是否已收藏

final class IsSenseGroupSavedFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  IsSenseGroupSavedFamily._()
    : super(
        retry: null,
        name: r'isSenseGroupSavedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 监听单个意群是否已收藏

  IsSenseGroupSavedProvider call(String phraseText) =>
      IsSenseGroupSavedProvider._(argument: phraseText, from: this);

  @override
  String toString() => r'isSenseGroupSavedProvider';
}
