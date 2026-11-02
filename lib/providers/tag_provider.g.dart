// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TagList)
final tagListProvider = TagListProvider._();

final class TagListProvider extends $NotifierProvider<TagList, TagState> {
  TagListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagListHash();

  @$internal
  @override
  TagList create() => TagList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TagState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TagState>(value),
    );
  }
}

String _$tagListHash() => r'de86c71849cbe6bfc1137a246b71e09ec6400ac9';

abstract class _$TagList extends $Notifier<TagState> {
  TagState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TagState, TagState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TagState, TagState>,
              TagState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
