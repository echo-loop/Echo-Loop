// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 词典状态管理 Provider
///
/// 监听母语设置变化，自动管理词典的下载和数据库连接。

@ProviderFor(Dictionary)
final dictionaryProvider = DictionaryProvider._();

/// 词典状态管理 Provider
///
/// 监听母语设置变化，自动管理词典的下载和数据库连接。
final class DictionaryProvider
    extends $NotifierProvider<Dictionary, DictionaryState> {
  /// 词典状态管理 Provider
  ///
  /// 监听母语设置变化，自动管理词典的下载和数据库连接。
  DictionaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionaryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionaryHash();

  @$internal
  @override
  Dictionary create() => Dictionary();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DictionaryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DictionaryState>(value),
    );
  }
}

String _$dictionaryHash() => r'bfe1722f2d29a23552a31e716b34a60f28e33509';

/// 词典状态管理 Provider
///
/// 监听母语设置变化，自动管理词典的下载和数据库连接。

abstract class _$Dictionary extends $Notifier<DictionaryState> {
  DictionaryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DictionaryState, DictionaryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DictionaryState, DictionaryState>,
              DictionaryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
