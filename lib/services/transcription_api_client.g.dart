// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_api_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 转录 API 客户端单例 Provider

@ProviderFor(transcriptionApiClient)
final transcriptionApiClientProvider = TranscriptionApiClientProvider._();

/// 转录 API 客户端单例 Provider

final class TranscriptionApiClientProvider
    extends
        $FunctionalProvider<
          TranscriptionApiClient,
          TranscriptionApiClient,
          TranscriptionApiClient
        >
    with $Provider<TranscriptionApiClient> {
  /// 转录 API 客户端单例 Provider
  TranscriptionApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptionApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptionApiClientHash();

  @$internal
  @override
  $ProviderElement<TranscriptionApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptionApiClient create(Ref ref) {
    return transcriptionApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptionApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptionApiClient>(value),
    );
  }
}

String _$transcriptionApiClientHash() =>
    r'80dcafe5a4dbec9e8e1091575d6646b030060bd3';
