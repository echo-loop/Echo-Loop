import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var speechPracticeHandler: MacSpeechPracticeHandler?
  private var textEmbeddingHandler: MacTextEmbeddingHandler?
  private var audioDecodeHandler: MacAudioDecodeHandler?
  private var notificationPermissionHandler: NotificationPermissionHandler?
  private var ttsSynthHandler: MacosTtsSynthHandler?
  private var deviceInfoHandler: MacDeviceInfoHandler?
  private var windowHandler: MacosWindowHandler?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    speechPracticeHandler = MacSpeechPracticeHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)
    textEmbeddingHandler = MacTextEmbeddingHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)
    audioDecodeHandler = MacAudioDecodeHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)
    notificationPermissionHandler = NotificationPermissionHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)
    ttsSynthHandler = MacosTtsSynthHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)
    deviceInfoHandler = MacDeviceInfoHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowHandler = MacosWindowHandler(binaryMessenger: flutterViewController.engine.binaryMessenger, window: self)

    // 设置最小窗口尺寸，避免内容过窄导致布局混乱
    self.minSize = NSSize(width: 400, height: 600)

    super.awakeFromNib()
  }
}
