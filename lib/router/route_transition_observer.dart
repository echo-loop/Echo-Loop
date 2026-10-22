import 'dart:async';

import 'package:flutter/widgets.dart';

/// 为调用方提供 root Navigator 指定路由的退场动画完成信号。
class RouteTransitionObserver extends RouteObserver<ModalRoute<void>> {
  final Set<RoutePopTransition> _pendingTransitions = {};

  /// 监听下一次推入路由的弹出，调用方应在 push 之前创建并在 finally 中取消。
  RoutePopTransition watchNextPop() {
    final transition = RoutePopTransition._(this);
    _pendingTransitions.add(transition);
    return transition;
  }

  void _remove(RoutePopTransition transition) {
    _pendingTransitions.remove(transition);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    for (final transition in List<RoutePopTransition>.of(_pendingTransitions)) {
      transition._onPush(route);
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    for (final transition in List<RoutePopTransition>.of(_pendingTransitions)) {
      transition._onPop(route, previousRoute);
    }
    super.didPop(route, previousRoute);
  }
}

/// 表示一次 root 路由退场动画的等待句柄。
class RoutePopTransition {
  RoutePopTransition._(this._observer);

  final RouteTransitionObserver _observer;
  final Completer<Route<dynamic>> _poppedRoute = Completer<Route<dynamic>>();
  Route<dynamic>? _observedRoute;
  Route<dynamic>? _previousRoute;

  /// 路由弹出且退场动画完成时结束。
  Future<void> get completed async {
    final route = await _poppedRoute.future;
    if (route case final TransitionRoute<dynamic> transitionRoute) {
      await transitionRoute.completed;
    }
  }

  /// 退场完成后，原先被覆盖的 root 路由是否仍处于顶层。
  bool get returnedToPreviousRoute => _previousRoute?.isCurrent ?? false;

  /// 移除尚未完成的监听，避免导航取消或异常后保留等待器。
  void cancel() => _observer._remove(this);

  void _onPush(Route<dynamic> route) {
    _observedRoute ??= route;
  }

  void _onPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(_observedRoute, route) && !_poppedRoute.isCompleted) {
      _previousRoute = previousRoute;
      _poppedRoute.complete(route);
    }
  }
}
