/// 词典结果分发视图
///
/// 按选中源 id 路由到对应渲染视图（各源状态 UX 不同）。
/// 默认分支用 sealed [DictionaryLookupResult] 的穷尽 switch 兜底——
/// 新增源若返回新结果子类，此处编译期报「未覆盖」，强制补渲染。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../providers/dictionary/lookup_controller.dart';
import '../../providers/dictionary/dictionary_settings_provider.dart';
import '../../services/dictionary/web_dictionary_ad_block_rules.dart';
import 'ai_dict_result_view.dart';
import 'local_dict_result_view.dart';
import 'web_dictionary_view.dart';

/// 结果分发视图
class DictionaryResultView extends ConsumerWidget {
  /// 当前选中源 id
  final String sourceId;

  /// 该源查询态
  final SourceLookupState? state;

  /// 查询词
  final String word;

  /// 重试回调
  final VoidCallback onRetry;

  /// 去登录回调
  final VoidCallback onSignIn;

  /// 升级订阅回调（AI 源本月额度用尽态）
  final VoidCallback onUpgrade;

  const DictionaryResultView({
    super.key,
    required this.sourceId,
    required this.state,
    required this.word,
    required this.onRetry,
    required this.onSignIn,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (sourceId) {
      case 'local':
        return LocalDictResultView(state: state, word: word);
      case 'ai':
        return AiDictResultView(
          state: state,
          onRetry: onRetry,
          onSignIn: onSignIn,
          onUpgrade: onUpgrade,
        );
      default:
        final adFilteringEnabled = ref
            .watch(dictionarySettingsNotifierProvider)
            .adFilteringEnabled;
        final adFilterBlockers = adFilteringEnabled
            ? webDictionaryCommonAdBlockers
            : const <ContentBlocker>[];
        // 其余源（含全部网页词典 cambridge/oxford/... ）走结果子类穷尽 switch
        // 兜底——新增结果子类需在此补分支。
        if (state case LookupLoaded(:final result)) {
          return _loadedFallback(result, adFilterBlockers, adFilteringEnabled);
        }
        return const _Loading();
    }
  }

  /// sealed 结果穷尽分发（新增源安全网）
  Widget _loadedFallback(
    DictionaryLookupResult result,
    List<ContentBlocker> adFilterBlockers,
    bool adFilteringEnabled,
  ) => switch (result) {
    LocalDictResult() => LocalDictResultView(state: state, word: word),
    AiDictResult() => AiDictResultView(
      state: state,
      onRetry: onRetry,
      onSignIn: onSignIn,
      onUpgrade: onUpgrade,
    ),
    // 切换词典源或过滤开关时重建 WebView，让初始过滤规则立即生效。
    WebDictResult(:final sourceId, :final url) => WebDictionaryView(
      key: ValueKey('web_${sourceId}_$adFilteringEnabled'),
      sourceId: sourceId,
      url: url,
      contentBlockers: adFilterBlockers,
    ),
  };
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator.adaptive()),
  );
}
