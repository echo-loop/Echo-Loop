// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 查词请求上下文（鉴权 + 目标语言），收敛为单一 provider 便于测试覆盖

@ProviderFor(dictionaryLookupContext)
final dictionaryLookupContextProvider = DictionaryLookupContextProvider._();

/// 查词请求上下文（鉴权 + 目标语言），收敛为单一 provider 便于测试覆盖

final class DictionaryLookupContextProvider
    extends
        $FunctionalProvider<
          DictionaryLookupContext,
          DictionaryLookupContext,
          DictionaryLookupContext
        >
    with $Provider<DictionaryLookupContext> {
  /// 查词请求上下文（鉴权 + 目标语言），收敛为单一 provider 便于测试覆盖
  DictionaryLookupContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionaryLookupContextProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionaryLookupContextHash();

  @$internal
  @override
  $ProviderElement<DictionaryLookupContext> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DictionaryLookupContext create(Ref ref) {
    return dictionaryLookupContext(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DictionaryLookupContext value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DictionaryLookupContext>(value),
    );
  }
}

String _$dictionaryLookupContextHash() =>
    r'0b8f0263d035d6c7425f5e549db4f2bd28eb639d';

/// 会话内粘滞源：词典面板打开期间用户手动选中的源 id（null = 未手动选过）。
///
/// 同一面板会话内切词/重新选词组时，新词的查词 controller 沿用该源，
/// 不回退默认源；面板关闭时由 [DictionaryPanel] 清除，下次打开恢复默认。
/// keepAlive——family 查词 controller 是 autoDispose（切词即销毁重建），
/// 粘滞选择必须跨 controller 存活。

@ProviderFor(DictionarySessionSource)
final dictionarySessionSourceProvider = DictionarySessionSourceProvider._();

/// 会话内粘滞源：词典面板打开期间用户手动选中的源 id（null = 未手动选过）。
///
/// 同一面板会话内切词/重新选词组时，新词的查词 controller 沿用该源，
/// 不回退默认源；面板关闭时由 [DictionaryPanel] 清除，下次打开恢复默认。
/// keepAlive——family 查词 controller 是 autoDispose（切词即销毁重建），
/// 粘滞选择必须跨 controller 存活。
final class DictionarySessionSourceProvider
    extends $NotifierProvider<DictionarySessionSource, String?> {
  /// 会话内粘滞源：词典面板打开期间用户手动选中的源 id（null = 未手动选过）。
  ///
  /// 同一面板会话内切词/重新选词组时，新词的查词 controller 沿用该源，
  /// 不回退默认源；面板关闭时由 [DictionaryPanel] 清除，下次打开恢复默认。
  /// keepAlive——family 查词 controller 是 autoDispose（切词即销毁重建），
  /// 粘滞选择必须跨 controller 存活。
  DictionarySessionSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionarySessionSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionarySessionSourceHash();

  @$internal
  @override
  DictionarySessionSource create() => DictionarySessionSource();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$dictionarySessionSourceHash() =>
    r'd857a35f599f920b4ef9a1b07761f07fce5eb631';

/// 会话内粘滞源：词典面板打开期间用户手动选中的源 id（null = 未手动选过）。
///
/// 同一面板会话内切词/重新选词组时，新词的查词 controller 沿用该源，
/// 不回退默认源；面板关闭时由 [DictionaryPanel] 清除，下次打开恢复默认。
/// keepAlive——family 查词 controller 是 autoDispose（切词即销毁重建），
/// 粘滞选择必须跨 controller 存活。

abstract class _$DictionarySessionSource extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 查词会话 controller（family by word，autoDispose）

@ProviderFor(DictionaryLookupController)
final dictionaryLookupControllerProvider = DictionaryLookupControllerFamily._();

/// 查词会话 controller（family by word，autoDispose）
final class DictionaryLookupControllerProvider
    extends
        $NotifierProvider<DictionaryLookupController, DictionaryLookupState> {
  /// 查词会话 controller（family by word，autoDispose）
  DictionaryLookupControllerProvider._({
    required DictionaryLookupControllerFamily super.from,
    required (String, {String? preferredSourceId}) super.argument,
  }) : super(
         retry: null,
         name: r'dictionaryLookupControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dictionaryLookupControllerHash();

  @override
  String toString() {
    return r'dictionaryLookupControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  DictionaryLookupController create() => DictionaryLookupController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DictionaryLookupState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DictionaryLookupState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DictionaryLookupControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dictionaryLookupControllerHash() =>
    r'b7b63d78af19b04fded11952210bace31ecc56e1';

/// 查词会话 controller（family by word，autoDispose）

final class DictionaryLookupControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          DictionaryLookupController,
          DictionaryLookupState,
          DictionaryLookupState,
          DictionaryLookupState,
          (String, {String? preferredSourceId})
        > {
  DictionaryLookupControllerFamily._()
    : super(
        retry: null,
        name: r'dictionaryLookupControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 查词会话 controller（family by word，autoDispose）

  DictionaryLookupControllerProvider call(
    String word, {
    String? preferredSourceId,
  }) => DictionaryLookupControllerProvider._(
    argument: (word, preferredSourceId: preferredSourceId),
    from: this,
  );

  @override
  String toString() => r'dictionaryLookupControllerProvider';
}

/// 查词会话 controller（family by word，autoDispose）

abstract class _$DictionaryLookupController
    extends $Notifier<DictionaryLookupState> {
  late final _$args = ref.$arg as (String, {String? preferredSourceId});
  String get word => _$args.$1;
  String? get preferredSourceId => _$args.preferredSourceId;

  DictionaryLookupState build(String word, {String? preferredSourceId});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DictionaryLookupState, DictionaryLookupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DictionaryLookupState, DictionaryLookupState>,
              DictionaryLookupState,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(_$args.$1, preferredSourceId: _$args.preferredSourceId),
    );
  }
}
