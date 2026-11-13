import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 绑定发起评分的页面，供异步评分检查重新确认展示位置和应用前台状态。
///
/// 分支 Navigator 的路由在切换 Tab 后仍可能 isCurrent，必须同时比较
/// GoRouter 的当前位置。调用方应在路由退场完成后再构造。
class RatingPromptPresentationGuard {
  RatingPromptPresentationGuard({required BuildContext context})
    : _context = context,
      _router = GoRouter.maybeOf(context),
      _sourceUri = GoRouter.maybeOf(context)
          ?.routerDelegate
          .currentConfiguration
          .uri,
      _sourceRoute = ModalRoute.of(context);

  final BuildContext _context;
  // 无 GoRouter 的测试环境无法确认当前位置，此时保守地不展示。
  final GoRouter? _router;
  final Uri? _sourceUri;
  final ModalRoute<Object?>? _sourceRoute;

  /// 仅允许在原页面可见且应用处于前台时发起原生评分请求。
  bool get canPresent {
    final router = _router;
    return _context.mounted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        (_sourceRoute?.isCurrent ?? false) &&
        router != null &&
        router.routerDelegate.currentConfiguration.uri == _sourceUri;
  }
}
