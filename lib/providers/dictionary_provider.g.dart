// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dictionaryHash() => r'bfe1722f2d29a23552a31e716b34a60f28e33509';

/// 词典状态管理 Provider
///
/// 监听母语设置变化，自动管理词典的下载和数据库连接。
///
/// Copied from [Dictionary].
@ProviderFor(Dictionary)
final dictionaryProvider =
    NotifierProvider<Dictionary, DictionaryState>.internal(
      Dictionary.new,
      name: r'dictionaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dictionaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Dictionary = Notifier<DictionaryState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
