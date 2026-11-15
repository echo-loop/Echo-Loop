import 'package:flutter/material.dart';

/// 媒体启动阶段；由 [ManagedMediaVisualSurface] 维护，展示组件只读取。
enum ManagedMediaPhase { loading, ready, failure, cancelled }

/// 托管组件暴露给使用方的启动状态。使用方据此决定加载占位画在哪里，
/// 失败后通过 [retry] 原地重新加载。
class MediaStartupStatus {
  const MediaStartupStatus({required this.phase, required this.retry});

  final ManagedMediaPhase phase;

  /// 重新发起一次加载；仅在失败态下有意义，其他阶段调用同样安全。
  final VoidCallback retry;

  bool get isReady => phase == ManagedMediaPhase.ready;
}
