// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatSessionControllerHash() =>
    r'c99f50d2fca1919b36e171d0827f076eae87a9ff';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ChatSessionController
    extends BuildlessNotifier<ChatSessionState> {
  late final ChatbotConfig config;

  ChatSessionState build(ChatbotConfig config);
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
///
/// Copied from [ChatSessionController].
@ProviderFor(ChatSessionController)
const chatSessionControllerProvider = ChatSessionControllerFamily();

/// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
///
/// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
/// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
/// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
/// 不再依赖 autoDispose 的 onDispose。
///
/// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
/// 异常映射抽 [_mapRunError]。
///
/// Copied from [ChatSessionController].
class ChatSessionControllerFamily extends Family<ChatSessionState> {
  /// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
  ///
  /// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
  /// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
  /// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
  /// 不再依赖 autoDispose 的 onDispose。
  ///
  /// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
  /// 异常映射抽 [_mapRunError]。
  ///
  /// Copied from [ChatSessionController].
  const ChatSessionControllerFamily();

  /// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
  ///
  /// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
  /// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
  /// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
  /// 不再依赖 autoDispose 的 onDispose。
  ///
  /// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
  /// 异常映射抽 [_mapRunError]。
  ///
  /// Copied from [ChatSessionController].
  ChatSessionControllerProvider call(ChatbotConfig config) {
    return ChatSessionControllerProvider(config);
  }

  @override
  ChatSessionControllerProvider getProviderOverride(
    covariant ChatSessionControllerProvider provider,
  ) {
    return call(provider.config);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatSessionControllerProvider';
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
///
/// Copied from [ChatSessionController].
class ChatSessionControllerProvider
    extends NotifierProviderImpl<ChatSessionController, ChatSessionState> {
  /// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
  ///
  /// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
  /// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
  /// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
  /// 不再依赖 autoDispose 的 onDispose。
  ///
  /// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
  /// 异常映射抽 [_mapRunError]。
  ///
  /// Copied from [ChatSessionController].
  ChatSessionControllerProvider(ChatbotConfig config)
    : this._internal(
        () => ChatSessionController()..config = config,
        from: chatSessionControllerProvider,
        name: r'chatSessionControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chatSessionControllerHash,
        dependencies: ChatSessionControllerFamily._dependencies,
        allTransitiveDependencies:
            ChatSessionControllerFamily._allTransitiveDependencies,
        config: config,
      );

  ChatSessionControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.config,
  }) : super.internal();

  final ChatbotConfig config;

  @override
  ChatSessionState runNotifierBuild(covariant ChatSessionController notifier) {
    return notifier.build(config);
  }

  @override
  Override overrideWith(ChatSessionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatSessionControllerProvider._internal(
        () => create()..config = config,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        config: config,
      ),
    );
  }

  @override
  NotifierProviderElement<ChatSessionController, ChatSessionState>
  createElement() {
    return _ChatSessionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionControllerProvider && other.config == config;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, config.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatSessionControllerRef on NotifierProviderRef<ChatSessionState> {
  /// The parameter `config` of this provider.
  ChatbotConfig get config;
}

class _ChatSessionControllerProviderElement
    extends NotifierProviderElement<ChatSessionController, ChatSessionState>
    with ChatSessionControllerRef {
  _ChatSessionControllerProviderElement(super.provider);

  @override
  ChatbotConfig get config => (origin as ChatSessionControllerProvider).config;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
