import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _systemProxyChannel = MethodChannel('top.echo-loop/system_proxy');

/// 系统 HTTP(S) 代理端点（CONNECT 代理的地址与端口）。
@immutable
class SystemProxyEndpoint {
  const SystemProxyEndpoint({required this.host, required this.port});

  final String host;
  final int port;

  /// 解析原生侧返回值。字段缺失或非法时返回 null：残缺配置不能当作有效代理使用，
  /// 否则下载会静默走到一个不存在的地址。
  static SystemProxyEndpoint? fromChannelValue(Object? value) {
    if (value is! Map) return null;
    final host = value['host'];
    final port = value['port'];
    if (host is! String || host.isEmpty) return null;
    if (port is! int || port <= 0 || port > 65535) return null;
    return SystemProxyEndpoint(host: host, port: port);
  }

  @override
  bool operator ==(Object other) =>
      other is SystemProxyEndpoint && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'SystemProxyEndpoint($host:$port)';
}

/// 读取当前系统手动代理。未启用或当前平台不支持时返回 null。
///
/// 仅 macOS 有实现：沙盒应用不能启动 `scutil`，原生侧改用 SystemConfiguration 读取。
/// PAC 自动配置与 SOCKS-only 代理不在支持范围内，返回 null。
Future<SystemProxyEndpoint?> readSystemProxy() async {
  if (!Platform.isMacOS) return null;
  final value = await _systemProxyChannel.invokeMethod<Object?>(
    'getSystemProxy',
  );
  return SystemProxyEndpoint.fromChannelValue(value);
}
