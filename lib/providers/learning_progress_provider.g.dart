// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_progress_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 学习进度管理 Provider
///
/// 管理所有音频的学习进度，提供加载、创建、推进、设置难度等操作。
/// 推进子步骤时同时写入 stage_completions 历史记录。

@ProviderFor(LearningProgressNotifier)
final learningProgressProvider = LearningProgressNotifierProvider._();

/// 学习进度管理 Provider
///
/// 管理所有音频的学习进度，提供加载、创建、推进、设置难度等操作。
/// 推进子步骤时同时写入 stage_completions 历史记录。
final class LearningProgressNotifierProvider
    extends $NotifierProvider<LearningProgressNotifier, LearningProgressState> {
  /// 学习进度管理 Provider
  ///
  /// 管理所有音频的学习进度，提供加载、创建、推进、设置难度等操作。
  /// 推进子步骤时同时写入 stage_completions 历史记录。
  LearningProgressNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningProgressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningProgressNotifierHash();

  @$internal
  @override
  LearningProgressNotifier create() => LearningProgressNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningProgressState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningProgressState>(value),
    );
  }
}

String _$learningProgressNotifierHash() =>
    r'91ae0603e9b7cb121d54c4b13c4c01e296ce4fd5';

/// 学习进度管理 Provider
///
/// 管理所有音频的学习进度，提供加载、创建、推进、设置难度等操作。
/// 推进子步骤时同时写入 stage_completions 历史记录。

abstract class _$LearningProgressNotifier
    extends $Notifier<LearningProgressState> {
  LearningProgressState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LearningProgressState, LearningProgressState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LearningProgressState, LearningProgressState>,
              LearningProgressState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
