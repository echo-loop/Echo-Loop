// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptionFileOpsHash() =>
    r'2a992d1eefd0d638205b7007933d572ea5179243';

/// 文件操作 Provider（测试时可覆盖）
///
/// Copied from [transcriptionFileOps].
@ProviderFor(transcriptionFileOps)
final transcriptionFileOpsProvider = Provider<TranscriptionFileOps>.internal(
  transcriptionFileOps,
  name: r'transcriptionFileOpsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transcriptionFileOpsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TranscriptionFileOpsRef = ProviderRef<TranscriptionFileOps>;
String _$transcriptionFinalizationServiceHash() =>
    r'1c8c504327eccadbea4c5f5cf5174eac23e63fb2';

/// 转录成功后把原始音频转码为 m4a 的服务 Provider（测试时可覆盖）
///
/// Copied from [transcriptionFinalizationService].
@ProviderFor(transcriptionFinalizationService)
final transcriptionFinalizationServiceProvider =
    Provider<AudioFinalizationService>.internal(
      transcriptionFinalizationService,
      name: r'transcriptionFinalizationServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptionFinalizationServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TranscriptionFinalizationServiceRef =
    ProviderRef<AudioFinalizationService>;
String _$transcriptionAudioExtractorHash() =>
    r'f4d087712d3fdddc5b60868ca95c4be7684e77f0';

/// 视频转录前抽取音轨的服务 Provider（测试时可覆盖）
///
/// Copied from [transcriptionAudioExtractor].
@ProviderFor(transcriptionAudioExtractor)
final transcriptionAudioExtractorProvider =
    Provider<TranscriptionAudioExtractor>.internal(
      transcriptionAudioExtractor,
      name: r'transcriptionAudioExtractorProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptionAudioExtractorHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TranscriptionAudioExtractorRef =
    ProviderRef<TranscriptionAudioExtractor>;
String _$transcriptionTaskManagerHash() =>
    r'802b045e04b1de3f73bb64efba642a0e0b78d979';

/// 转录任务管理器
///
/// keepAlive: 弹窗关闭后任务仍在后台运行。
/// state: `Map<String, TranscriptionTaskState>`（audioId -> state）
///
/// Copied from [TranscriptionTaskManager].
@ProviderFor(TranscriptionTaskManager)
final transcriptionTaskManagerProvider =
    NotifierProvider<
      TranscriptionTaskManager,
      Map<String, TranscriptionTaskState>
    >.internal(
      TranscriptionTaskManager.new,
      name: r'transcriptionTaskManagerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptionTaskManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptionTaskManager =
    Notifier<Map<String, TranscriptionTaskState>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
