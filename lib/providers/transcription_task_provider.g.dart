// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 文件操作 Provider（测试时可覆盖）

@ProviderFor(transcriptionFileOps)
final transcriptionFileOpsProvider = TranscriptionFileOpsProvider._();

/// 文件操作 Provider（测试时可覆盖）

final class TranscriptionFileOpsProvider
    extends
        $FunctionalProvider<
          TranscriptionFileOps,
          TranscriptionFileOps,
          TranscriptionFileOps
        >
    with $Provider<TranscriptionFileOps> {
  /// 文件操作 Provider（测试时可覆盖）
  TranscriptionFileOpsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptionFileOpsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptionFileOpsHash();

  @$internal
  @override
  $ProviderElement<TranscriptionFileOps> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptionFileOps create(Ref ref) {
    return transcriptionFileOps(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptionFileOps value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptionFileOps>(value),
    );
  }
}

String _$transcriptionFileOpsHash() =>
    r'2a992d1eefd0d638205b7007933d572ea5179243';

/// 转录成功后把原始音频转码为 m4a 的服务 Provider（测试时可覆盖）

@ProviderFor(transcriptionFinalizationService)
final transcriptionFinalizationServiceProvider =
    TranscriptionFinalizationServiceProvider._();

/// 转录成功后把原始音频转码为 m4a 的服务 Provider（测试时可覆盖）

final class TranscriptionFinalizationServiceProvider
    extends
        $FunctionalProvider<
          AudioFinalizationService,
          AudioFinalizationService,
          AudioFinalizationService
        >
    with $Provider<AudioFinalizationService> {
  /// 转录成功后把原始音频转码为 m4a 的服务 Provider（测试时可覆盖）
  TranscriptionFinalizationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptionFinalizationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptionFinalizationServiceHash();

  @$internal
  @override
  $ProviderElement<AudioFinalizationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioFinalizationService create(Ref ref) {
    return transcriptionFinalizationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioFinalizationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioFinalizationService>(value),
    );
  }
}

String _$transcriptionFinalizationServiceHash() =>
    r'1c8c504327eccadbea4c5f5cf5174eac23e63fb2';

/// 视频转录前抽取音轨的服务 Provider（测试时可覆盖）

@ProviderFor(transcriptionAudioExtractor)
final transcriptionAudioExtractorProvider =
    TranscriptionAudioExtractorProvider._();

/// 视频转录前抽取音轨的服务 Provider（测试时可覆盖）

final class TranscriptionAudioExtractorProvider
    extends
        $FunctionalProvider<
          TranscriptionAudioExtractor,
          TranscriptionAudioExtractor,
          TranscriptionAudioExtractor
        >
    with $Provider<TranscriptionAudioExtractor> {
  /// 视频转录前抽取音轨的服务 Provider（测试时可覆盖）
  TranscriptionAudioExtractorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptionAudioExtractorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptionAudioExtractorHash();

  @$internal
  @override
  $ProviderElement<TranscriptionAudioExtractor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptionAudioExtractor create(Ref ref) {
    return transcriptionAudioExtractor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptionAudioExtractor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptionAudioExtractor>(value),
    );
  }
}

String _$transcriptionAudioExtractorHash() =>
    r'f4d087712d3fdddc5b60868ca95c4be7684e77f0';

/// 转录任务管理器
///
/// keepAlive: 弹窗关闭后任务仍在后台运行。
/// state: `Map<String, TranscriptionTaskState>`（audioId -> state）

@ProviderFor(TranscriptionTaskManager)
final transcriptionTaskManagerProvider = TranscriptionTaskManagerProvider._();

/// 转录任务管理器
///
/// keepAlive: 弹窗关闭后任务仍在后台运行。
/// state: `Map<String, TranscriptionTaskState>`（audioId -> state）
final class TranscriptionTaskManagerProvider
    extends
        $NotifierProvider<
          TranscriptionTaskManager,
          Map<String, TranscriptionTaskState>
        > {
  /// 转录任务管理器
  ///
  /// keepAlive: 弹窗关闭后任务仍在后台运行。
  /// state: `Map<String, TranscriptionTaskState>`（audioId -> state）
  TranscriptionTaskManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptionTaskManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptionTaskManagerHash();

  @$internal
  @override
  TranscriptionTaskManager create() => TranscriptionTaskManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, TranscriptionTaskState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, TranscriptionTaskState>>(
        value,
      ),
    );
  }
}

String _$transcriptionTaskManagerHash() =>
    r'94a131e206d816b776d31f9083ba2ef3b8b38cce';

/// 转录任务管理器
///
/// keepAlive: 弹窗关闭后任务仍在后台运行。
/// state: `Map<String, TranscriptionTaskState>`（audioId -> state）

abstract class _$TranscriptionTaskManager
    extends $Notifier<Map<String, TranscriptionTaskState>> {
  Map<String, TranscriptionTaskState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, TranscriptionTaskState>,
              Map<String, TranscriptionTaskState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, TranscriptionTaskState>,
                Map<String, TranscriptionTaskState>
              >,
              Map<String, TranscriptionTaskState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
