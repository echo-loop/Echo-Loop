import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 绑定发起练习的页面，供异步评分检查重新确认展示位置和应用前台状态。
///
/// 分支 Navigator 的路由在切换 Tab 后仍可能 isCurrent，必须同时比较
/// GoRouter 的当前位置；root 覆盖情况由路由退场等待器提供。
class RatingPromptPresentationGuard {
  RatingPromptPresentationGuard({
    required BuildContext context,
    required bool Function() isRootRouteCurrent,
  }) : _context = context,
       _router = GoRouter.of(context),
       _sourceUri = GoRouter.of(
         context,
       ).routerDelegate.currentConfiguration.uri,
       _sourceRoute = ModalRoute.of(context),
       _isRootRouteCurrent = isRootRouteCurrent;

  final BuildContext _context;
  final GoRouter _router;
  final Uri _sourceUri;
  final ModalRoute<Object?>? _sourceRoute;
  final bool Function() _isRootRouteCurrent;

  /// 仅允许在原页面可见且应用处于前台时发起原生评分请求。
  bool get canPresent =>
      _context.mounted &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      (_sourceRoute?.isCurrent ?? false) &&
      _isRootRouteCurrent() &&
      _router.routerDelegate.currentConfiguration.uri == _sourceUri;
}
