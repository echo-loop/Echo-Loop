// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_transcription_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 专用转录引擎工厂（测试时覆盖为 mock 引擎）。
///
/// 每个转录任务用一个独立引擎实例，用后 dispose，不复用评分共享引擎，
/// 以免切换档位时 dispose/reload 扰乱评分已加载的模型。

@ProviderFor(localTranscriptionEngineFactory)
final localTranscriptionEngineFactoryProvider =
    LocalTranscriptionEngineFactoryProvider._();

/// 专用转录引擎工厂（测试时覆盖为 mock 引擎）。
///
/// 每个转录任务用一个独立引擎实例，用后 dispose，不复用评分共享引擎，
/// 以免切换档位时 dispose/reload 扰乱评分已加载的模型。

final class LocalTranscriptionEngineFactoryProvider
    extends
        $FunctionalProvider<
          OfflineAsrEngine Function(),
          OfflineAsrEngine Function(),
          OfflineAsrEngine Function()
        >
    with $Provider<OfflineAsrEngine Function()> {
  /// 专用转录引擎工厂（测试时覆盖为 mock 引擎）。
  ///
  /// 每个转录任务用一个独立引擎实例，用后 dispose，不复用评分共享引擎，
  /// 以免切换档位时 dispose/reload 扰乱评分已加载的模型。
  LocalTranscriptionEngineFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localTranscriptionEngineFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localTranscriptionEngineFactoryHash();

  @$internal
  @override
  $ProviderElement<OfflineAsrEngine Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineAsrEngine Function() create(Ref ref) {
    return localTranscriptionEngineFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineAsrEngine Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineAsrEngine Function()>(value),
    );
  }
}

String _$localTranscriptionEngineFactoryHash() =>
    r'847316f36d5c3ba2b76eb38a3b5e91d0a9bc346b';

/// 转录用转码服务 Provider（测试时可覆盖）。

@ProviderFor(localTranscriptionTranscodeService)
final localTranscriptionTranscodeServiceProvider =
    LocalTranscriptionTranscodeServiceProvider._();

/// 转录用转码服务 Provider（测试时可覆盖）。

final class LocalTranscriptionTranscodeServiceProvider
    extends
        $FunctionalProvider<
          AudioTranscodeService,
          AudioTranscodeService,
          AudioTranscodeService
        >
    with $Provider<AudioTranscodeService> {
  /// 转录用转码服务 Provider（测试时可覆盖）。
  LocalTranscriptionTranscodeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localTranscriptionTranscodeServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$localTranscriptionTranscodeServiceHash();

  @$internal
  @override
  $ProviderElement<AudioTranscodeService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioTranscodeService create(Ref ref) {
    return localTranscriptionTranscodeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioTranscodeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioTranscodeService>(value),
    );
  }
}

String _$localTranscriptionTranscodeServiceHash() =>
    r'a095e3f487fafec84f9037a00f4574caad74bc35';

/// 本地转录任务管理器。
///
/// keepAlive：弹窗关闭后任务仍在后台运行。
/// state：`Map<String, LocalTranscriptionState>`（audioId -> state）。

@ProviderFor(LocalTranscriptionTaskManager)
final localTranscriptionTaskManagerProvider =
    LocalTranscriptionTaskManagerProvider._();

/// 本地转录任务管理器。
///
/// keepAlive：弹窗关闭后任务仍在后台运行。
/// state：`Map<String, LocalTranscriptionState>`（audioId -> state）。
final class LocalTranscriptionTaskManagerProvider
    extends
        $NotifierProvider<
          LocalTranscriptionTaskManager,
          Map<String, LocalTranscriptionState>
        > {
  /// 本地转录任务管理器。
  ///
  /// keepAlive：弹窗关闭后任务仍在后台运行。
  /// state：`Map<String, LocalTranscriptionState>`（audioId -> state）。
  LocalTranscriptionTaskManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localTranscriptionTaskManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localTranscriptionTaskManagerHash();

  @$internal
  @override
  LocalTranscriptionTaskManager create() => LocalTranscriptionTaskManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, LocalTranscriptionState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<String, LocalTranscriptionState>>(value),
    );
  }
}

String _$localTranscriptionTaskManagerHash() =>
    r'f10ecaf4ca8eea714a61fec04c3e750634b1506a';

/// 本地转录任务管理器。
///
/// keepAlive：弹窗关闭后任务仍在后台运行。
/// state：`Map<String, LocalTranscriptionState>`（audioId -> state）。

abstract class _$LocalTranscriptionTaskManager
    extends $Notifier<Map<String, LocalTranscriptionState>> {
  Map<String, LocalTranscriptionState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, LocalTranscriptionState>,
              Map<String, LocalTranscriptionState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, LocalTranscriptionState>,
                Map<String, LocalTranscriptionState>
              >,
              Map<String, LocalTranscriptionState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
