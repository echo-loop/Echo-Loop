// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 学习会话 Provider
///
/// 作为播放器之上的学习流程控制层。
/// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
/// 退出时停止盲听播放、恢复 LP 监听。

@ProviderFor(LearningSession)
final learningSessionProvider = LearningSessionProvider._();

/// 学习会话 Provider
///
/// 作为播放器之上的学习流程控制层。
/// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
/// 退出时停止盲听播放、恢复 LP 监听。
final class LearningSessionProvider
    extends $NotifierProvider<LearningSession, LearningSessionState> {
  /// 学习会话 Provider
  ///
  /// 作为播放器之上的学习流程控制层。
  /// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
  /// 退出时停止盲听播放、恢复 LP 监听。
  LearningSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningSessionHash();

  @$internal
  @override
  LearningSession create() => LearningSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningSessionState>(value),
    );
  }
}

String _$learningSessionHash() => r'32fd06934e1e6709cbac3c7ba64cd4ac4bfb9967';

/// 学习会话 Provider
///
/// 作为播放器之上的学习流程控制层。
/// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
/// 退出时停止盲听播放、恢复 LP 监听。

abstract class _$LearningSession extends $Notifier<LearningSessionState> {
  LearningSessionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LearningSessionState, LearningSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LearningSessionState, LearningSessionState>,
              LearningSessionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
