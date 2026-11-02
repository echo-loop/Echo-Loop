// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CollectionList)
final collectionListProvider = CollectionListProvider._();

final class CollectionListProvider
    extends $NotifierProvider<CollectionList, CollectionState> {
  CollectionListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionListHash();

  @$internal
  @override
  CollectionList create() => CollectionList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CollectionState>(value),
    );
  }
}

String _$collectionListHash() => r'75b648dc7c6e90ba2950df8f76688ed2d45c0167';

abstract class _$CollectionList extends $Notifier<CollectionState> {
  CollectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CollectionState, CollectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CollectionState, CollectionState>,
              CollectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
