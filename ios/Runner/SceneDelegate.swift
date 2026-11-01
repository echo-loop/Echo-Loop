import Flutter
import UIKit

/// Flutter 的 Scene 入口，负责把 iPadOS 窗口控件样式交给系统决定。
///
/// 由 Info.plist 的 `UIApplicationSceneManifest` 指定为场景代理。
/// 覆盖 `preferredWindowingControlStyle` 为 `.minimal`，让 iPadOS 26 把三色窗口控件
/// 放在应用工具栏上方，避免压住 Flutter `AppBar` 的左上角按钮。
/// 旧系统（iOS 26 以下）不调用该方法，行为保持不变。
class SceneDelegate: FlutterSceneDelegate {
  /// 返回窗口控件样式：`.minimal` 使控件位于工具栏上方。
  @available(iOS 26.0, *)
  override func preferredWindowingControlStyle(
    for windowScene: UIWindowScene
  ) -> UIWindowScene.WindowingControlStyle {
    return .minimal
  }
}
