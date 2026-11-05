/// 查词会话 controller（按单词建状态域，防竞态）
///
/// 持有「当前选中源 + 各源查词态缓存」。切源懒加载、已查过复用缓存。
/// 防竞态：每源一个序列号（同源新查覆盖旧查的回调）+ 每源一个 CancelToken
/// （切走/重查时取消在途 HTTP）。切词由 family(word) 天然隔离。
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/subscription/models/ai_quota_rejection.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../services/dictionary/dictionary_source.dart';
import '../settings_provider.dart';
import 'dictionary_registry.dart';
import 'visible_sources_provider.dart';

part 'lookup_controller.g.dart';

/// 词典数据层时序日志；仅 debug 构建输出，定位延迟位于触发前还是请求内。
void _traceDictionaryLookup(String message) {
  if (!kDebugMode) return;
  final timestamp = DateTime.now().toIso8601String();
  debugPrint('[DictionaryTrace][$timestamp][lookup] $message');
}

/// 单个源的查词态
sealed class SourceLookupState {
  const SourceLookupState();
}

/// 加载中
class LookupLoading extends SourceLookupState {
  const LookupLoading();
}

/// 查询完成但未收录
class LookupNotFound extends SourceLookupState {
  const LookupNotFound();
}

/// 查询成功
class LookupLoaded extends SourceLookupState {
  final DictionaryLookupResult result;
  const LookupLoaded(this.result);
}

/// 流式查询中：已到达的部分结果，随帧更新（仅流式源如 AI 会经过此态）。
///
/// 视图据当前部分结果逐块渲染；字段随后续帧渐显，完成后转 [LookupLoaded]。
class LookupStreaming extends SourceLookupState {
  final DictionaryLookupResult result;
  const LookupStreaming(this.result);
}

/// 需要登录
class LookupAuthRequired extends SourceLookupState {
  const LookupAuthRequired();
}

/// 查询词组过长（后端拒绝，重试无意义）
class LookupPhraseTooLong extends SourceLookupState {
  const LookupPhraseTooLong();
}

/// 本月免费额度用尽（后端返回 402）——由 UI 引导订阅升级。
class LookupQuotaExceeded extends SourceLookupState {
  const LookupQuotaExceeded({this.reason = AiQuotaRejectionReason.exhausted});

  final AiQuotaRejectionReason reason;
}

/// 查询失败（网络/服务端等）
class LookupError extends SourceLookupState {
  final Object error;
  const LookupError(this.error);
}

/// 弹窗整体查词状态
class DictionaryLookupState {
  /// 当前选中的源 id
  final String selectedSourceId;

  /// 各源对该词的查询态（已查过的留存，切回不重查）
  final Map<String, SourceLookupState> bySource;

  const DictionaryLookupState({
    required this.selectedSourceId,
    required this.bySource,
  });

  /// 当前选中源的查询态
  SourceLookupState? get current => bySource[selectedSourceId];

  DictionaryLookupState copyWith({
    String? selectedSourceId,
    Map<String, SourceLookupState>? bySource,
  }) => DictionaryLookupState(
    selectedSourceId: selectedSourceId ?? this.selectedSourceId,
    bySource: bySource ?? this.bySource,
  );
}

/// 查词请求上下文（鉴权 + 目标语言），收敛为单一 provider 便于测试覆盖
@riverpod
DictionaryLookupContext dictionaryLookupContext(Ref ref) {
  final accessToken = ref
      .watch(supabaseSessionProvider)
      .value
      ?.accessToken;
  final targetLanguage = ref.watch(
    appSettingsProvider.select((s) => s.nativeLanguage),
  );
  return DictionaryLookupContext(
    accessToken: accessToken,
    targetLanguage: targetLanguage,
  );
}

/// 查词上下文
class DictionaryLookupContext {
  final String? accessToken;
  final String? targetLanguage;
  const DictionaryLookupContext({this.accessToken, this.targetLanguage});
}

/// 会话内粘滞源：词典面板打开期间用户手动选中的源 id（null = 未手动选过）。
///
/// 同一面板会话内切词/重新选词组时，新词的查词 controller 沿用该源，
/// 不回退默认源；面板关闭时由 [DictionaryPanel] 清除，下次打开恢复默认。
/// keepAlive——family 查词 controller 是 autoDispose（切词即销毁重建），
/// 粘滞选择必须跨 controller 存活。
@Riverpod(keepAlive: true)
class DictionarySessionSource extends _$DictionarySessionSource {
  @override
  String? build() => null;

  /// 记录用户手动选中的源（面板切源入口调用）
  void remember(String id) {
    if (!ref.mounted) return;
    state = id;
  }

  /// 会话结束（面板关闭）时清除，下次打开恢复默认源
  void clear() {
    if (!ref.mounted) return;
    state = null;
  }
}

/// 查词会话 controller（family by word，autoDispose）
@riverpod
class DictionaryLookupController extends _$DictionaryLookupController {
  /// 每源序列号：同源发起新查询即自增，旧查询回调发现序号过期则丢弃
  final Map<String, int> _seq = {};

  /// 每源在途请求的取消令牌
  final Map<String, CancelToken> _tokens = {};

  /// 是否已销毁。销毁后在途请求回调一律丢弃，避免写已销毁的 Notifier 抛错。
  /// （取消是异步的：cancel 到流真正抛 DioException 之间仍有窗口，回调可能到达）
  bool _disposed = false;

  @override
  DictionaryLookupState build(String word, {String? preferredSourceId}) {
    ref.onDispose(() {
      _disposed = true;
      // 取消在途请求（关闭面板即取消查询）：网页源（如 Cambridge）据此中断抓取；
      // AI 流式源据此关流 → 后端 request.signal abort → 中断 LLM，止损 token，
      // 未完成不落缓存（流式已不再支持「后台跑完」，区别于旧同步 API）。
      for (final t in _tokens.values) {
        if (!t.isCancelled) t.cancel('controller disposed');
      }
    });
    // 登录前停在 AI 登录引导的当前查询，在认证态转为有效后自动续跑。
    // 只恢复仍被用户选中的 AI 源，避免用户已切词/切源后后台发起旧请求。
    ref.listen(supabaseSessionProvider, (previous, next) {
      final session = next.value;
      final wasAnonymous = previous?.value == null;
      if (session == null || !wasAnonymous) return;
      if (state.selectedSourceId != AiDictionarySource.sourceId ||
          state.current is! LookupAuthRequired) {
        return;
      }
      _traceDictionaryLookup(
        'resume-after-sign-in word="$word" source=${AiDictionarySource.sourceId}',
      );
      // 认证事件中的 token 比异步刷新的查词上下文更及时，避免刚登录便再次落入
      // LookupAuthRequired；目标语言仍从当前设置读取。
      _lookup(
        AiDictionarySource.sourceId,
        accessTokenOverride: session.accessToken,
      );
    });
    final defaultId = _resolveInitialSourceId(preferredSourceId);
    _traceDictionaryLookup(
      'build word="$word" preferred=$preferredSourceId source=$defaultId',
    );
    // 进入即查默认源；其它源懒加载（切到才查）
    Future.microtask(() => _lookup(defaultId));
    return DictionaryLookupState(
      selectedSourceId: defaultId,
      bySource: const {},
    );
  }

  /// 初始选中源，优先级：
  /// 1. 调用方显式指定的初始源（如意群快捷 lookup 强制 AI），且该源仍可见；
  /// 2. 会话粘滞源（本次面板会话内用户手动选过且仍可见）——切词不回退默认源；
  /// 3. 词组（含空格的多词查询）优先 AI 源——在线词典对多词短语覆盖有限；
  /// 4. 全局默认源。
  String _resolveInitialSourceId(String? preferredSourceId) {
    if (preferredSourceId != null && preferredSourceId.isNotEmpty) {
      final visible = ref.read(visibleDictionarySourcesProvider);
      if (visible.any((s) => s.id == preferredSourceId)) {
        return preferredSourceId;
      }
    }
    final session = ref.read(dictionarySessionSourceProvider);
    if (session != null) {
      final visible = ref.read(visibleDictionarySourcesProvider);
      if (visible.any((s) => s.id == session)) return session;
    }
    final isPhrase = word.contains(' ');
    if (isPhrase) {
      final visible = ref.read(visibleDictionarySourcesProvider);
      if (visible.any((s) => s.id == AiDictionarySource.sourceId)) {
        return AiDictionarySource.sourceId;
      }
    }
    return ref.read(resolvedDefaultSourceIdProvider);
  }

  /// 切换选中源（懒加载：未查过/上次失败才发起查询）。
  /// 调用方均为用户手动切源（源切换器/AI 快捷按钮），故同时记入会话粘滞源，
  /// 使本次面板会话内后续切词保持该源。
  void selectSource(String id) {
    ref.read(dictionarySessionSourceProvider.notifier).remember(id);
    if (state.selectedSourceId != id) {
      state = state.copyWith(selectedSourceId: id);
    }
    final cur = state.bySource[id];
    if (cur == null || cur is LookupError || cur is LookupAuthRequired) {
      _lookup(id);
    }
  }

  /// 重试当前选中源
  void retry() => _lookup(state.selectedSourceId);

  Future<void> _lookup(String id, {String? accessTokenOverride}) async {
    final source = ref.read(dictionarySourcesByIdProvider)[id];
    if (source == null) {
      _traceDictionaryLookup('skip word="$word" source=$id reason=missing');
      return;
    }

    final seq = (_seq[id] ?? 0) + 1;
    _seq[id] = seq;
    _traceDictionaryLookup(
      'start word="$word" source=$id seq=$seq network=${source.requiresNetwork}',
    );

    // 取消该源上一次在途请求
    final prev = _tokens[id];
    if (prev != null && !prev.isCancelled) prev.cancel('restart');
    final token = CancelToken();
    _tokens[id] = token;

    _setState(id, const LookupLoading());

    final request = _buildRequest(
      source,
      accessTokenOverride: accessTokenOverride,
    );
    try {
      if (source is AiDictionarySource) {
        // AI 源：流式逐帧渲染，完成后转 Loaded。每帧套用防竞态守卫。
        DictionaryLookupResult? last;
        await for (final r in source.lookupStream(
          request,
          cancelToken: token,
        )) {
          if (_dropResult(id, seq)) return;
          last = r;
          if (r != null) _setState(id, LookupStreaming(r));
        }
        if (_dropResult(id, seq)) return;
        _setState(
          id,
          last == null ? const LookupNotFound() : LookupLoaded(last),
        );
        // AI 词典成功返回可用结果：记录成功次数（用于评价/付费提醒；含缓存命中）
        if (last != null) {
          ref
              .read(usageTrackerProvider)
              .record(UsageEvent.aiWordAnalysisSucceeded);
        }
      } else {
        // 非流式源（本地/网页）：保持原请求-响应路径不变。
        final result = await source.lookup(request, cancelToken: token);
        if (_dropResult(id, seq)) return;
        _setState(
          id,
          result == null ? const LookupNotFound() : LookupLoaded(result),
        );
      }
    } on DictionaryAuthRequiredException {
      if (_dropResult(id, seq)) return;
      _setState(id, const LookupAuthRequired());
    } on DictionaryPhraseTooLongException {
      if (_dropResult(id, seq)) return;
      _setState(id, const LookupPhraseTooLong());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // 主动取消不报错
      if (_dropResult(id, seq)) return;
      // 后端本月免费额度用尽 → 由 UI 引导订阅（区别于普通网络错误）。
      if (e.response?.statusCode == 402) {
        final rejection = AiQuotaRejection.fromResponseData(e.response?.data);
        _setState(id, LookupQuotaExceeded(reason: rejection.reason));
        return;
      }
      _setState(id, LookupError(e));
    } catch (e) {
      if (_dropResult(id, seq)) return;
      _setState(id, LookupError(e));
    }
  }

  /// 回调是否应丢弃：controller 已销毁，或该源已发起更新的查询（序号过期）
  bool _dropResult(String id, int seq) => _disposed || _isStale(id, seq);

  /// 回调过期判定：该源已发起更新的查询
  bool _isStale(String id, int seq) => _seq[id] != seq;

  DictionaryLookupRequest _buildRequest(
    DictionarySource source, {
    String? accessTokenOverride,
  }) {
    // word（= family key）已由调用方清洗一次（剥首尾标点、弯撇号归一、
    // 空白折叠）。此处不再改写；需要小写缓存键的源自行派生。
    if (!source.requiresNetwork) {
      return DictionaryLookupRequest(word: word);
    }
    final ctx = ref.read(dictionaryLookupContextProvider);
    return DictionaryLookupRequest(
      word: word,
      accessToken: accessTokenOverride ?? ctx.accessToken,
      targetLanguage: ctx.targetLanguage,
    );
  }

  void _setState(String id, SourceLookupState s) {
    _traceDictionaryLookup(
      'state word="$word" source=$id value=${s.runtimeType}',
    );
    state = state.copyWith(bySource: {...state.bySource, id: s});
  }
}
