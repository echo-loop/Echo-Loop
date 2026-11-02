// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_ai_api_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AI API 客户端单例 Provider

@ProviderFor(sentenceAiApiClient)
final sentenceAiApiClientProvider = SentenceAiApiClientProvider._();

/// AI API 客户端单例 Provider

final class SentenceAiApiClientProvider
    extends
        $FunctionalProvider<
          SentenceAiApiClient,
          SentenceAiApiClient,
          SentenceAiApiClient
        >
    with $Provider<SentenceAiApiClient> {
  /// AI API 客户端单例 Provider
  SentenceAiApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sentenceAiApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sentenceAiApiClientHash();

  @$internal
  @override
  $ProviderElement<SentenceAiApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SentenceAiApiClient create(Ref ref) {
    return sentenceAiApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SentenceAiApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SentenceAiApiClient>(value),
    );
  }
}

String _$sentenceAiApiClientHash() =>
    r'5db772d5be52678f2300c01414cc259dafe11c2b';
