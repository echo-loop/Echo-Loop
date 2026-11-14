import 'dart:async';

import 'package:flutter/widgets.dart';

/// 等待进场路由转场动画结束（无动画 / 已完成 / 被中断时立即返回）
///
/// 导出类页面的加载会 spawn isolate 并序列化大对象，若在转场动画期间开工，
/// 会让转场与 loading 动画掉帧，因此等页面稳定后再启动。
Future<void> awaitRouteEntranceTransition(BuildContext context) {
  final animation = ModalRoute.of(context)?.animation;
  if (animation == null || animation.isCompleted) return Future<void>.value();
  final completer = Completer<void>();
  void listener(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      animation.removeStatusListener(listener);
      if (!completer.isCompleted) completer.complete();
    }
  }

  animation.addStatusListener(listener);
  return completer.future;
}
