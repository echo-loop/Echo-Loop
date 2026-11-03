import Cocoa
import FlutterMacOS
import SystemConfiguration

/// 读取 macOS 系统手动代理，供后台下载插件使用。
///
/// 沙盒应用不能启动 `scutil`，因此通过 SystemConfiguration 读取代理设置。
/// 只处理手动代理：HTTPS 优先，其次 HTTP。PAC 与 SOCKS-only 不在支持范围内，返回 nil。
final class MacosSystemProxyHandler: NSObject {
  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "top.echo-loop/system_proxy",
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler { call, result in
      guard call.method == "getSystemProxy" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Self.currentManualProxy())
    }
  }

  /// 返回 `{host, port}`；没有启用的手动代理时返回 nil。
  static func currentManualProxy() -> [String: Any]? {
    guard let settings = SCDynamicStoreCopyProxies(nil) as? [String: Any] else {
      return nil
    }
    if let proxy = endpoint(
      settings,
      enableKey: kSCPropNetProxiesHTTPSEnable,
      hostKey: kSCPropNetProxiesHTTPSProxy,
      portKey: kSCPropNetProxiesHTTPSPort
    ) {
      return proxy
    }
    return endpoint(
      settings,
      enableKey: kSCPropNetProxiesHTTPEnable,
      hostKey: kSCPropNetProxiesHTTPProxy,
      portKey: kSCPropNetProxiesHTTPPort
    )
  }

  private static func endpoint(
    _ settings: [String: Any],
    enableKey: CFString,
    hostKey: CFString,
    portKey: CFString
  ) -> [String: Any]? {
    guard
      (settings[enableKey as String] as? NSNumber)?.intValue == 1,
      let host = settings[hostKey as String] as? String,
      !host.isEmpty,
      let port = (settings[portKey as String] as? NSNumber)?.intValue,
      port > 0
    else {
      return nil
    }
    return ["host": host, "port": port]
  }
}
