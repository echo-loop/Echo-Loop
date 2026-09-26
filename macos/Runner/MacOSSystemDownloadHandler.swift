import Cocoa
import Darwin
import FlutterMacOS
import UserNotifications

/// 使用 URLSession 下载 macOS 文件，让系统网络栈处理代理和网络路由。
final class MacOSSystemDownloadHandler: NSObject, FlutterStreamHandler, URLSessionDownloadDelegate {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private lazy var session = URLSession(
    configuration: .default,
    delegate: self,
    delegateQueue: OperationQueue.main
  )
  private var eventSink: FlutterEventSink?
  private var tasks: [String: URLSessionDownloadTask] = [:]
  private var outcomes: [String: DownloadOutcome] = [:]

  init(binaryMessenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "top.echo-loop/system_download",
      binaryMessenger: binaryMessenger
    )
    eventChannel = FlutterEventChannel(
      name: "top.echo-loop/system_download/events",
      binaryMessenger: binaryMessenger
    )

    super.init()
    // 默认配置保留系统代理设置，由 URLSession 采用 macOS 当前网络配置。
    _ = session
    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startDownload":
      startDownload(call.arguments as? [String: Any], result: result)
    case "cancelDownload":
      cancelDownload(call.arguments as? [String: Any], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startDownload(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard
      let arguments,
      let taskID = arguments["taskId"] as? String,
      let rawURL = arguments["url"] as? String,
      let url = URL(string: rawURL),
      let rawPath = arguments["savePath"] as? String,
      let headers = arguments["headers"] as? [String: String]
    else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "System download arguments are invalid",
        details: nil
      ))
      return
    }

    var request = URLRequest(url: url)
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }

    let task = session.downloadTask(with: request)
    task.taskDescription = taskID
    tasks[taskID] = task
    let requestedName = arguments["displayName"] as? String
    let displayName = requestedName.flatMap { $0.isEmpty ? nil : $0 }
      ?? URL(fileURLWithPath: rawPath).lastPathComponent
    let completeNotificationTitle = arguments["completeNotificationTitle"] as? String
      ?? "Download complete"
    let failedNotificationTitle = arguments["failedNotificationTitle"] as? String
      ?? "Download failed"
    outcomes[taskID] = DownloadOutcome(
      targetPath: rawPath,
      displayName: displayName,
      completeNotificationTitle: completeNotificationTitle,
      failedNotificationTitle: failedNotificationTitle
    )
    task.resume()
    result(true)
  }

  private func cancelDownload(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let taskID = arguments?["taskId"] as? String else {
      result(false)
      return
    }
    guard let task = tasks[taskID] else {
      result(false)
      return
    }
    task.cancel()
    result(true)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard
      let taskID = downloadTask.taskDescription,
      totalBytesWritten >= 0
    else { return }

    var event: [String: Any] = [
      "taskId": taskID,
      "status": "progress",
      "receivedBytes": totalBytesWritten,
    ]
    if totalBytesExpectedToWrite >= 0 {
      event["totalBytes"] = totalBytesExpectedToWrite
    }
    eventSink?(event)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard
      let taskID = downloadTask.taskDescription,
      var outcome = outcomes[taskID]
    else { return }

    let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode
    outcome.statusCode = statusCode
    guard let statusCode, (200..<300).contains(statusCode) else {
      outcome.status = statusCode == 404 ? "notFound" : "failed"
      outcome.message = "The server rejected the file download."
      outcomes[taskID] = outcome
      return
    }

    do {
      let targetURL = URL(fileURLWithPath: outcome.targetPath)
      try FileManager.default.createDirectory(
        at: targetURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: targetURL.path) {
        try FileManager.default.removeItem(at: targetURL)
      }
      try FileManager.default.moveItem(at: location, to: targetURL)
      outcome.status = "complete"
    } catch {
      let fileError = error as NSError
      outcome.status = "failed"
      outcome.message = "Could not save the downloaded file."
      outcome.isStorageFailure = fileError.code == NSFileWriteOutOfSpaceError ||
        fileError.code == Int(ENOSPC)
    }
    outcomes[taskID] = outcome
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let taskID = task.taskDescription else { return }
    var outcome = outcomes.removeValue(forKey: taskID)
      ?? DownloadOutcome(
        targetPath: "",
        displayName: "",
        completeNotificationTitle: "Download complete",
        failedNotificationTitle: "Download failed"
      )
    tasks.removeValue(forKey: taskID)

    if let error {
      let urlError = error as NSError
      outcome.status = urlError.code == NSURLErrorCancelled ? "canceled" : "failed"
      outcome.message = outcome.status == "canceled"
        ? "Download canceled."
        : "System network request failed."
      outcome.isStorageFailure = urlError.code == NSFileWriteOutOfSpaceError ||
        urlError.code == Int(ENOSPC)
    } else if outcome.status == nil {
      outcome.status = "failed"
      outcome.message = "The system download ended without a result."
    }

    if outcome.status == "complete" || outcome.status == "failed" {
      postDownloadNotification(for: outcome)
    }

    var event: [String: Any] = [
      "taskId": taskID,
      "status": outcome.status ?? "failed",
      "receivedBytes": max(0, task.countOfBytesReceived),
    ]
    if task.countOfBytesExpectedToReceive >= 0 {
      event["expectedBytes"] = task.countOfBytesExpectedToReceive
    }
    if let response = task.response as? HTTPURLResponse,
      let contentType = response.value(forHTTPHeaderField: "Content-Type") {
      event["contentType"] = contentType
    }
    if let statusCode = outcome.statusCode {
      event["statusCode"] = statusCode
    }
    if let message = outcome.message {
      event["message"] = message
    }
    if outcome.isStorageFailure {
      event["isStorageFailure"] = true
    }
    if let error {
      let networkError = error as NSError
      event["errorDomain"] = networkError.domain
      event["errorCode"] = networkError.code
    }
    eventSink?(event)
  }

  private func postDownloadNotification(for outcome: DownloadOutcome) {
    guard !NSApp.isActive else { return }

    let content = UNMutableNotificationContent()
    content.title = outcome.status == "complete"
      ? outcome.completeNotificationTitle
      : outcome.failedNotificationTitle
    content.body = outcome.displayName
    content.sound = .default
    // flutter_local_notifications 接管系统 delegate；标记其通知字段以处理点击回调。
    content.userInfo = [
      "payload": outcome.displayName,
      "presentSound": true,
      "presentBadge": false,
      "presentAlert": true,
      "presentBanner": true,
      "presentList": true,
    ]

    let request = UNNotificationRequest(
      identifier: String(Int.random(in: 1...Int.max)),
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        NSLog(
          "[SystemDownload] Failed to post notification: %@",
          error.localizedDescription
        )
      }
    }
  }
}

private struct DownloadOutcome {
  let targetPath: String
  let displayName: String
  let completeNotificationTitle: String
  let failedNotificationTitle: String
  var status: String?
  var statusCode: Int?
  var message: String?
  var isStorageFailure = false
}
