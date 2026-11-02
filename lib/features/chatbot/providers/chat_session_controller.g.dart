// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
///
/// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
/// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
/// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
/// 不再依赖 autoDispose 的 onDispose。
///
/// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
/// 异常映射抽 [_mapRunError]。

@ProviderFor(ChatSessionController)
final chatSessionControllerProvider = ChatSessionControllerFamily._();

/// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
///
/// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
/// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
/// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
/// 不再依赖 autoDispose 的 onDispose。
///
/// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
/// 异常映射抽 [_mapRunError]。
final class ChatSessionControllerProvider
    extends $NotifierProvider<ChatSessionController, ChatSessionState> {
  /// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
  ///
  /// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
  /// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
  /// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
  /// 不再依赖 autoDispose 的 onDispose。
  ///
  /// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
  /// 异常映射抽 [_mapRunError]。
  ChatSessionControllerProvider._({
    required ChatSessionControllerFamily super.from,
    required ChatbotConfig super.argument,
  }) : super(
         retry: null,
         name: r'chatSessionControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatSessionControllerHash();

  @override
  String toString() {
    return r'chatSessionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatSessionController create() => ChatSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatSessionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSessionControllerHash() =>
    r'9490558f90a1300fa1c0e29cdf8a01a3012eda90';

/// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
///
/// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
/// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
/// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
/// 不再依赖 autoDispose 的 onDispose。
///
/// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
/// 异常映射抽 [_mapRunError]。

final class ChatSessionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatSessionController,
          ChatSessionState,
          ChatSessionState,
          ChatSessionState,
          ChatbotConfig
        > {
  ChatSessionControllerFamily._()
    : super(
        retry: null,
        name: r'chatSessionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
  ///
  /// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
  /// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
  /// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
  /// 不再依赖 autoDispose 的 onDispose。
  ///
  /// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
  /// 异常映射抽 [_mapRunError]。

  ChatSessionControllerProvider call(ChatbotConfig config) =>
      ChatSessionControllerProvider._(argument: config, from: this);

  @override
  String toString() => r'chatSessionControllerProvider';
}

/// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
///
/// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
/// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
/// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
/// 不再依赖 autoDispose 的 onDispose。
///
/// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
/// 异常映射抽 [_mapRunError]。

abstract class _$ChatSessionController extends $Notifier<ChatSessionState> {
  late final _$args = ref.$arg as ChatbotConfig;
  ChatbotConfig get config => _$args;

  ChatSessionState build(ChatbotConfig config);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChatSessionState, ChatSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatSessionState, ChatSessionState>,
              ChatSessionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
