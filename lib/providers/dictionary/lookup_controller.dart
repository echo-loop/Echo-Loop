/// 查词会话 controller（按单词建状态域，防竞态）
///
/// 持有「当前选中源 + 各源查词态缓存」。切源懒加载、已查过复用缓存。
/// 防竞态：每源一个序列号（同源新查覆盖旧查的回调）+ 每源一个 CancelToken
/// （切走/重查时取消在途 HTTP）。切词由 family(word) 天然隔离。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../services/dictionary/ai_dictionary_source.dart';
import '../../services/dictionary/dictionary_source.dart';
import '../settings_provider.dart';
import 'dictionary_registry.dart';
import 'visible_sources_provider.dart';

part 'lookup_controller.g.dart';

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

/// 需要登录
class LookupAuthRequired extends SourceLookupState {
  const LookupAuthRequired();
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
      .valueOrNull
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

/// 查词会话 controller（family by word，autoDispose）
@riverpod
class DictionaryLookupController extends _$DictionaryLookupController {
  /// 每源序列号：同源发起新查询即自增，旧查询回调发现序号过期则丢弃
  final Map<String, int> _seq = {};

  /// 每源在途请求的取消令牌
  final Map<String, CancelToken> _tokens = {};

  /// 是否已销毁。销毁后在途请求回调一律丢弃，避免写已销毁的 Notifier 抛错。
  /// （AI 源忽略 token、请求在后台跑完，其回调会晚于 dispose 到达）
  bool _disposed = false;

  @override
  DictionaryLookupState build(String word) {
    ref.onDispose(() {
      _disposed = true;
      // 取消在途请求：网页源（如 Cambridge）据此中断抓取；
      // AI 源忽略 token，仍在后台跑完并落缓存，供下次重查复用。
      for (final t in _tokens.values) {
        if (!t.isCancelled) t.cancel('controller disposed');
      }
    });
    final defaultId = _resolveInitialSourceId();
    // 进入即查默认源；其它源懒加载（切到才查）
    Future.microtask(() => _lookup(defaultId));
    return DictionaryLookupState(
      selectedSourceId: defaultId,
      bySource: const {},
    );
  }

  /// 初始选中源：词组（含空格的多词查询）优先 AI 源——本地词典对多词短语
  /// 覆盖有限，AI 释义最可用；其余场景沿用全局默认源。用户仍可手动切源。
  String _resolveInitialSourceId() {
    final isPhrase = word.contains(' ');
    if (isPhrase) {
      final visible = ref.read(visibleDictionarySourcesProvider);
      if (visible.any((s) => s.id == AiDictionarySource.sourceId)) {
        return AiDictionarySource.sourceId;
      }
    }
    return ref.read(resolvedDefaultSourceIdProvider);
  }

  /// 切换选中源（懒加载：未查过/上次失败才发起查询）
  void selectSource(String id) {
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

  Future<void> _lookup(String id) async {
    final source = ref.read(dictionarySourcesByIdProvider)[id];
    if (source == null) return;

    final seq = (_seq[id] ?? 0) + 1;
    _seq[id] = seq;

    // 取消该源上一次在途请求
    final prev = _tokens[id];
    if (prev != null && !prev.isCancelled) prev.cancel('restart');
    final token = CancelToken();
    _tokens[id] = token;

    _setState(id, const LookupLoading());

    final request = _buildRequest(source);
    try {
      final result = await source.lookup(request, cancelToken: token);
      if (_dropResult(id, seq)) return;
      _setState(
        id,
        result == null ? const LookupNotFound() : LookupLoaded(result),
      );
    } on DictionaryAuthRequiredException {
      if (_dropResult(id, seq)) return;
      _setState(id, const LookupAuthRequired());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // 主动取消不报错
      if (_dropResult(id, seq)) return;
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

  DictionaryLookupRequest _buildRequest(DictionarySource source) {
    // word（= family key）已由调用方归一化一次（见 DictionaryLookupRequest.word
    // 「已清洗」契约 + dictionary_panel._normalizedWord）。此处及各源均不再归一，
    // 保证「查一次词只归一化一次」，各端共用同一清洗结果。
    if (!source.requiresNetwork) {
      return DictionaryLookupRequest(word: word);
    }
    final ctx = ref.read(dictionaryLookupContextProvider);
    return DictionaryLookupRequest(
      word: word,
      accessToken: ctx.accessToken,
      targetLanguage: ctx.targetLanguage,
    );
  }

  void _setState(String id, SourceLookupState s) {
    state = state.copyWith(bySource: {...state.bySource, id: s});
  }
}
