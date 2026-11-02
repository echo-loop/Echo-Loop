import 'package:flutter_riverpod/misc.dart';

/// 判断异常是否来自「provider 未在 ProviderScope 中 override」。
///
/// 启动期依赖（如 `sharedPreferencesProvider`）默认 `throw UnimplementedError`，
/// 读取方靠捕获该异常降级（单测 / 宿主环境未注入时用默认值）。Riverpod 3 会把
/// provider 内抛出的异常包装为 [ProviderException]，跨 provider 读取时必须解包，
/// 否则降级分支失效，异常会直接冒泡。
///
/// 调用方应在 catch 中先判断本函数，非该类异常一律 `rethrow`，不得静默吞掉。
bool isProviderNotOverriddenError(Object error) {
  // 嵌套的 ProviderException（provider 读取另一个已出错 provider）需逐层解包。
  var current = error;
  while (current is ProviderException) {
    current = current.exception;
  }
  return current is UnimplementedError;
}
