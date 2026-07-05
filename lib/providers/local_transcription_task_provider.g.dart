// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_transcription_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localTranscriptionEngineFactoryHash() =>
    r'847316f36d5c3ba2b76eb38a3b5e91d0a9bc346b';

/// 专用转录引擎工厂（测试时覆盖为 mock 引擎）。
///
/// 每个转录任务用一个独立引擎实例，用后 dispose，不复用评分共享引擎，
/// 以免切换档位时 dispose/reload 扰乱评分已加载的模型。
///
/// Copied from [localTranscriptionEngineFactory].
@ProviderFor(localTranscriptionEngineFactory)
final localTranscriptionEngineFactoryProvider =
    Provider<OfflineAsrEngine Function()>.internal(
      localTranscriptionEngineFactory,
      name: r'localTranscriptionEngineFactoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$localTranscriptionEngineFactoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalTranscriptionEngineFactoryRef =
    ProviderRef<OfflineAsrEngine Function()>;
String _$localTranscriptionTranscodeServiceHash() =>
    r'a095e3f487fafec84f9037a00f4574caad74bc35';

/// 转录用转码服务 Provider（测试时可覆盖）。
///
/// Copied from [localTranscriptionTranscodeService].
@ProviderFor(localTranscriptionTranscodeService)
final localTranscriptionTranscodeServiceProvider =
    Provider<AudioTranscodeService>.internal(
      localTranscriptionTranscodeService,
      name: r'localTranscriptionTranscodeServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$localTranscriptionTranscodeServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalTranscriptionTranscodeServiceRef =
    ProviderRef<AudioTranscodeService>;
String _$localTranscriptionTaskManagerHash() =>
    r'407e75eb7bea39ffb152a0040d393bb212440d3a';

/// 本地转录任务管理器。
///
/// keepAlive：弹窗关闭后任务仍在后台运行。
/// state：`Map<String, LocalTranscriptionState>`（audioId -> state）。
///
/// Copied from [LocalTranscriptionTaskManager].
@ProviderFor(LocalTranscriptionTaskManager)
final localTranscriptionTaskManagerProvider =
    NotifierProvider<
      LocalTranscriptionTaskManager,
      Map<String, LocalTranscriptionState>
    >.internal(
      LocalTranscriptionTaskManager.new,
      name: r'localTranscriptionTaskManagerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$localTranscriptionTaskManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LocalTranscriptionTaskManager =
    Notifier<Map<String, LocalTranscriptionState>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
