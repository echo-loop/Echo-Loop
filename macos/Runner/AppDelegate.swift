import AVFoundation
import Cocoa
import CoreAudio
import FlutterMacOS
import NaturalLanguage
import Speech

enum SpeechPracticeMacError: String {
  case permissionDenied
  case notAvailable
  case noSpeech
  case invalidArguments
  case recordingFailed
}

private let trimLeadingPaddingMs = 120.0
private let trimTrailingPaddingMs = 180.0
private let autoAlignTargetSampleRate = 1000.0

final class MacSpeechPracticeHandler: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  // 引擎级资源（页面常驻，warmup 创建，shutdown 释放）
  private var audioEngine: AVAudioEngine?
  private var cachedRecognizer: SFSpeechRecognizer?
  private var configChangeObserver: NSObjectProtocol?
  private var configChangeRestartWorkItem: DispatchWorkItem?
  private var warmupPendingResult: FlutterResult?
  private var warmupTimeoutWorkItem: DispatchWorkItem?
  private var isEngineRunning = false
  private var isRecording = false

  /// 是否启用平台语音识别（默认 false，纯录音 + VAD）。
  /// Dart 层通过 `setRecognitionEnabled` 在 warmup 前设置。
  private var recognitionEnabled = false

  // 句子级资源（每次录音创建/释放）
  private var audioFile: AVAudioFile?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var currentFileURL: URL?
  private var currentPromptId: String?
  private var hasDetectedSpeech = false
  private var silenceStartAt: Date?
  private var lastReportedSilenceMs = -1
  private var recordedDurationMs = 0.0
  private var firstDetectedSpeechMs: Double?
  private var lastDetectedSpeechMs: Double?
  private var sessionGeneration: Int = 0

  init(binaryMessenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "top.echo-loop/speech_practice",
      binaryMessenger: binaryMessenger
    )
    eventChannel = FlutterEventChannel(
      name: "top.echo-loop/speech_practice/events",
      binaryMessenger: binaryMessenger
    )
    super.init()
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
    case "getPermissionStatus":
      result(permissionMap())
    case "requestPermissions":
      let args = call.arguments as? [String: Any]
      let onlyMic = (args?["onlyMic"] as? Bool) ?? false
      requestPermissions(onlyMic: onlyMic, result: result)
    case "warmup":
      warmup(call.arguments as? [String: Any], result: result)
    case "startSession":
      startSession(call.arguments as? [String: Any], result: result)
    case "stopSession":
      stopSession(result: result)
    case "cancelSession":
      cancelSession(result: result)
    case "shutdown":
      shutdown(result: result)
    case "deleteRecording":
      deleteRecording(call.arguments as? [String: Any], result: result)
    case "getDeviceInfo":
      result(["ramBytes": ProcessInfo.processInfo.physicalMemory])
    case "setRecognitionEnabled":
      let args = call.arguments as? [String: Any]
      recognitionEnabled = (args?["enabled"] as? Bool) ?? false
      result([:])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func permissionMap() -> [String: String] {
    [
      "microphoneStatus": microphonePermissionStatus(),
      "speechStatus": speechPermissionStatus()
    ]
  }

  private func microphonePermissionStatus() -> String {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return "granted"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "denied"
    }
  }

  private func speechPermissionStatus() -> String {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      return "granted"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "denied"
    }
  }

  /// 依次请求麦克风权限和语音识别权限（先麦克风，更符合用户直觉）。
  ///
  /// `onlyMic=true` 时只请求麦克风，不触发 SFSpeechRecognizer 系统弹窗——
  /// 用户关闭 ASR / 选择 Echo Loop 离线后端时不需要平台语音识别权限，
  /// 遵循 App Store 5.1.1 数据最小化原则。
  private func requestPermissions(onlyMic: Bool, result: @escaping FlutterResult) {
    AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
      guard let self = self else { return }
      if onlyMic {
        DispatchQueue.main.async {
          result(self.permissionMap())
        }
        return
      }
      SFSpeechRecognizer.requestAuthorization { _ in
        DispatchQueue.main.async {
          result(self.permissionMap())
        }
      }
    }
  }

  /// 预热引擎：创建 AVAudioEngine + installTap + start，页面进入时调用。
  ///
  /// 检测到蓝牙输出设备时，会等待 BT 完成 A2DP→HFP 模式切换并重启引擎后
  /// 才返回成功，确保后续 startSession 在引擎稳定状态下执行。
  /// 非蓝牙设备立即返回。
  private func warmup(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    let micStatus = microphonePermissionStatus()

    // 纯录音模式只需要麦克风权限；识别模式还需要语音识别权限。
    let needsSpeech = recognitionEnabled
    let speechStatus = needsSpeech ? speechPermissionStatus() : "granted"

    // notDetermined 时自动请求权限，请求完成后重新进入 warmup。
    // 纯录音模式不请求 SFSpeechRecognizer，避免无意义弹窗（onlyMic=true）。
    if micStatus == "notDetermined" || speechStatus == "notDetermined" {
      requestPermissions(onlyMic: !needsSpeech) { [weak self] _ in
        self?.warmup(arguments, result: result)
      }
      return
    }

    guard micStatus == "granted", speechStatus == "granted" else {
      result(FlutterError(
        code: SpeechPracticeMacError.permissionDenied.rawValue,
        message: "Microphone or speech permission denied",
        details: nil
      ))
      return
    }

    // 上一次 warmup 还在等 BT 稳定时又被调用，先 resolve 旧 result 避免 Dart 挂起。
    if let oldResult = warmupPendingResult {
      warmupPendingResult = nil
      warmupTimeoutWorkItem?.cancel()
      warmupTimeoutWorkItem = nil
      oldResult(FlutterError(
        code: SpeechPracticeMacError.recordingFailed.rawValue,
        message: "Warmup superseded by a new warmup call",
        details: nil
      ))
    }

    // 已在运行且引擎实际可用则直接返回。
    if isEngineRunning, let engine = audioEngine, engine.isRunning {
      result([:])
      return
    }

    // 标记不一致时修正。
    if isEngineRunning {
      cleanupEngine()
    }

    let localeIdentifier = (arguments?["locale"] as? String) ?? "en-US"
    if recognitionEnabled {
      cachedRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    do {
      let engine = AVAudioEngine()
      installInputTap(on: engine)

      engine.prepare()
      try engine.start()
      audioEngine = engine
      isEngineRunning = true

      // 监听 IO 配置变更（蓝牙设备模式切换等），自动重启引擎。
      configChangeObserver = NotificationCenter.default.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: engine,
        queue: .main
      ) { [weak self] _ in
        self?.handleEngineConfigurationChange()
      }

      // 蓝牙输出设备会触发 A2DP→HFP 模式切换，导致引擎被系统 stop。
      // 此时延迟返回，等引擎重启稳定后再通知 Dart 端。
      if isBluetoothAudioActive() {
        warmupPendingResult = result
        // 安全超时：3 秒内 BT 未稳定则返回错误。
        let timeout = DispatchWorkItem { [weak self] in
          self?.resolveWarmup()
        }
        warmupTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: timeout)
      } else {
        result([:])
      }
    } catch {
      cleanupEngine()
      result(FlutterError(
        code: SpeechPracticeMacError.recordingFailed.rawValue,
        message: "Failed to warmup audio engine",
        details: error.localizedDescription
      ))
    }
  }

  /// 解决待返回的 warmup result。
  private func resolveWarmup() {
    warmupTimeoutWorkItem?.cancel()
    warmupTimeoutWorkItem = nil
    guard let result = warmupPendingResult else { return }
    warmupPendingResult = nil

    if isEngineRunning, let engine = audioEngine, engine.isRunning {
      result([:])
    } else {
      cleanupEngine()
      result(FlutterError(
        code: SpeechPracticeMacError.recordingFailed.rawValue,
        message: "Audio engine failed to stabilize (Bluetooth mode switch timeout)",
        details: nil
      ))
    }
  }

  /// 检测默认输入或输出设备是否为蓝牙设备。
  ///
  /// 蓝牙设备无论作为输入还是输出，开启麦克风时都可能触发 A2DP→HFP 模式切换。
  private func isBluetoothAudioActive() -> Bool {
    return isBluetoothDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
      || isBluetoothDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
  }

  private func isBluetoothDevice(selector: AudioObjectPropertySelector) -> Bool {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
    ) == noErr else { return false }

    var transportType: UInt32 = 0
    size = UInt32(MemoryLayout<UInt32>.size)
    address.mSelector = kAudioDevicePropertyTransportType
    guard AudioObjectGetPropertyData(
      deviceID, &address, 0, nil, &size, &transportType
    ) == noErr else { return false }

    return transportType == kAudioDeviceTransportTypeBluetooth
      || transportType == kAudioDeviceTransportTypeBluetoothLE
  }

  /// 处理 AVAudioEngine IO 配置变更。
  ///
  /// 蓝牙设备在开启麦克风输入时会从 A2DP 切换到 HFP 模式，
  /// 触发 IO 配置变更导致引擎被系统自动 stop。
  /// 使用 debounce（500ms）等 BT 设备稳定后再重启引擎，
  /// 避免在模式切换过程中反复重启。
  private func handleEngineConfigurationChange() {
    guard isEngineRunning, let engine = audioEngine else { return }

    // 引擎仍在运行说明无需处理（某些无害的配置变更不会 stop 引擎）。
    guard !engine.isRunning else { return }

    // 取消之前的重启计划（debounce）。
    configChangeRestartWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      self?.performEngineRestart()
    }
    configChangeRestartWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
  }

  /// 重启被系统 stop 的引擎。
  ///
  /// 重新安装 tap（配置变更后 inputNode 格式可能改变）并 start 引擎。
  /// 重启成功后如果有待返回的 warmup result，一并解决。
  private func performEngineRestart() {
    configChangeRestartWorkItem = nil
    guard isEngineRunning, let engine = audioEngine, !engine.isRunning else {
      resolveWarmup()
      return
    }

    engine.inputNode.removeTap(onBus: 0)
    installInputTap(on: engine)

    engine.prepare()
    do {
      try engine.start()
      resolveWarmup()
    } catch {
      // 重启失败，标记引擎已停止，后续 startSession 会走完整初始化路径。
      isEngineRunning = false
      resolveWarmup()
      if isRecording {
        isRecording = false
        emitError(
          code: SpeechPracticeMacError.recordingFailed.rawValue,
          message: "Failed to restart engine after configuration change: \(error.localizedDescription)"
        )
        cleanupSentenceState(cancelRecognition: true)
      }
    }
  }

  private func startSession(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard
      let promptId = arguments?["promptId"] as? String,
      !promptId.isEmpty
    else {
      result(FlutterError(
        code: SpeechPracticeMacError.invalidArguments.rawValue,
        message: "Missing promptId",
        details: nil
      ))
      return
    }

    let localeIdentifier = (arguments?["locale"] as? String) ?? "en-US"

    // 引擎已常驻且实际运行中：轻量启动，只创建句子级资源。
    // 额外检查 engine.isRunning 防止 IO 配置变更导致引擎已被系统 stop
    // 但 isEngineRunning 标记尚未同步的情况。
    if isEngineRunning, let engine = audioEngine, engine.isRunning {
      do {
        try startSessionLightweight(engine: engine, promptId: promptId, locale: localeIdentifier, result: result)
      } catch {
        cleanupSentenceState(cancelRecognition: true)
        result(FlutterError(
          code: SpeechPracticeMacError.recordingFailed.rawValue,
          message: "Failed to start lightweight session",
          details: error.localizedDescription
        ))
      }
      return
    }

    // 标记不一致时修正，确保完整初始化路径正确清理旧资源。
    if isEngineRunning {
      cleanupEngine()
    }

    // 引擎未就绪：回退到完整初始化。
    startSessionFull(promptId: promptId, locale: localeIdentifier, result: result)
  }

  /// 轻量启动：engine 已 running，只建句子级资源。
  ///
  /// `recognitionEnabled=true` 时创建 recognitionTask + audioFile。
  /// `recognitionEnabled=false` 时只创建 audioFile（纯录音 + VAD）。
  private func startSessionLightweight(engine: AVAudioEngine, promptId: String, locale: String, result: @escaping FlutterResult) throws {
    cleanupSentenceState(cancelRecognition: true)

    let fileName = sanitizedFileName(promptId)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(fileName)-\(Int(Date().timeIntervalSince1970 * 1000)).caf")

    let inputFormat = engine.inputNode.outputFormat(forBus: 0)
    let file = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)

    var request: SFSpeechAudioBufferRecognitionRequest?

    if recognitionEnabled {
      let recognizer = cachedRecognizer ?? SFSpeechRecognizer(locale: Locale(identifier: locale))
      guard let recognizer, recognizer.isAvailable else {
        result(FlutterError(
          code: SpeechPracticeMacError.notAvailable.rawValue,
          message: "Speech recognizer unavailable",
          details: nil
        ))
        return
      }

      let req = SFSpeechAudioBufferRecognitionRequest()
      req.shouldReportPartialResults = true
      request = req
    }

    // 必须先 resetSentenceState（递增 generation），再创建 recognitionTask（capture generation）
    resetSentenceState(promptId: promptId, fileURL: fileURL, audioFile: file, request: request)

    if recognitionEnabled, let req = request {
      let recognizer = cachedRecognizer ?? SFSpeechRecognizer(locale: Locale(identifier: locale))
      let generation = sessionGeneration
      recognitionTask = recognizer!.recognitionTask(with: req) { [weak self] recognitionResult, error in
        guard let self, self.sessionGeneration == generation else { return }
        self.handleRecognitionCallback(recognitionResult: recognitionResult, error: error)
      }
    }

    isRecording = true
    result(["filePath": fileURL.path])
  }

  /// 完整初始化：warmup 未完成时的回退路径。
  ///
  /// 如果权限尚未请求（notDetermined），会自动触发系统权限弹窗。
  private func startSessionFull(promptId: String, locale: String, result: @escaping FlutterResult) {
    let micStatus = microphonePermissionStatus()
    let speechStatus = speechPermissionStatus()

    if micStatus == "notDetermined" || speechStatus == "notDetermined" {
      requestPermissions(onlyMic: !recognitionEnabled) { [weak self] _ in
        self?.startSessionFull(promptId: promptId, locale: locale, result: result)
      }
      return
    }

    guard micStatus == "granted", speechStatus == "granted" else {
      result(FlutterError(
        code: SpeechPracticeMacError.permissionDenied.rawValue,
        message: "Microphone or speech permission denied",
        details: nil
      ))
      return
    }

    if recognitionEnabled {
      guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
            recognizer.isAvailable
      else {
        result(FlutterError(
          code: SpeechPracticeMacError.notAvailable.rawValue,
          message: "Speech recognizer unavailable",
          details: nil
        ))
        return
      }
      cachedRecognizer = recognizer
    }

    cleanupSentenceState(cancelRecognition: true)
    cleanupEngine()

    let fileName = sanitizedFileName(promptId)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(fileName)-\(Int(Date().timeIntervalSince1970 * 1000)).caf")

    do {
      let engine = AVAudioEngine()
      let inputNode = engine.inputNode
      let inputFormat = inputNode.outputFormat(forBus: 0)

      var request: SFSpeechAudioBufferRecognitionRequest?

      let file = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)

      if recognitionEnabled, let recognizer = cachedRecognizer {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req
      }

      // 必须先 resetSentenceState（递增 generation），再创建 recognitionTask
      resetSentenceState(promptId: promptId, fileURL: fileURL, audioFile: file, request: request)
      audioEngine = engine

      if recognitionEnabled, let recognizer = cachedRecognizer, let req = request {
        let generation = sessionGeneration
        recognitionTask = recognizer.recognitionTask(with: req) { [weak self] recognitionResult, error in
          guard let self, self.sessionGeneration == generation else { return }
          self.handleRecognitionCallback(recognitionResult: recognitionResult, error: error)
        }
      }

      installInputTap(on: engine)

      engine.prepare()
      try engine.start()
      isEngineRunning = true
      isRecording = true

      // startSessionFull 创建了新引擎，也需要监听 IO 配置变更。
      configChangeObserver = NotificationCenter.default.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: engine,
        queue: .main
      ) { [weak self] _ in
        self?.handleEngineConfigurationChange()
      }

      result(["filePath": fileURL.path])
    } catch {
      cleanupSentenceState(cancelRecognition: true)
      cleanupEngine()
      result(FlutterError(
        code: SpeechPracticeMacError.recordingFailed.rawValue,
        message: "Failed to start live recording",
        details: error.localizedDescription
      ))
    }
  }

  private func stopSession(result: @escaping FlutterResult) {
    isRecording = false
    recognitionRequest?.endAudio()
    audioFile = nil
    if let fileURL = currentFileURL {
      trimRecordingIfNeeded(fileURL: fileURL)
    }
    result(["filePath": currentFileURL?.path as Any])

    // 纯录音模式（无 ASR）：手动发空 finalTranscriptReady，与 Android 行为对齐。
    if !recognitionEnabled, let promptId = currentPromptId {
      emitEvent([
        "type": "finalTranscriptReady",
        "promptId": promptId,
        "transcript": "",
      ])
    }
  }

  private func cancelSession(result: @escaping FlutterResult) {
    isRecording = false
    cleanupSentenceState(cancelRecognition: true)
    result([:])
  }

  /// 彻底释放硬件资源，页面退出时调用。
  private func shutdown(result: @escaping FlutterResult) {
    isRecording = false
    cleanupSentenceState(cancelRecognition: true)
    cleanupEngine()
    result([:])
  }

  private func deleteRecording(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let filePath = arguments?["filePath"] as? String, !filePath.isEmpty else {
      result([:])
      return
    }

    let url = URL(fileURLWithPath: filePath)
    if FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.removeItem(at: url)
    }
    if currentFileURL?.path == filePath {
      currentFileURL = nil
    }
    result([:])
  }

  private func handleRecognitionCallback(
    recognitionResult: SFSpeechRecognitionResult?,
    error: Error?
  ) {
    guard let promptId = currentPromptId else { return }

    if let error {
      emitEvent([
        "type": "error",
        "promptId": promptId,
        "errorCode": SpeechPracticeMacError.noSpeech.rawValue,
        "errorMessage": error.localizedDescription
      ])
      isRecording = false
      cleanupSentenceState(cancelRecognition: true)
      return
    }

    guard let recognitionResult else {
      return
    }

    let transcript = recognitionResult.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
    if recognitionResult.isFinal {
      // isFinal 时无论 transcript 是否为空都必须发送，否则 Dart 端 completer 永远收不到完成事件
      emitEvent([
        "type": "finalTranscriptReady",
        "promptId": promptId,
        "transcript": transcript
      ])
      isRecording = false
      cleanupSentenceState(cancelRecognition: false)
    } else if !transcript.isEmpty {
      emitEvent([
        "type": "partialTranscriptUpdated",
        "promptId": promptId,
        "transcript": transcript
      ])
    }
  }

  private func emitError(code: String, message: String) {
    guard let promptId = currentPromptId else { return }
    emitEvent([
      "type": "error",
      "promptId": promptId,
      "errorCode": code,
      "errorMessage": message
    ])
  }

  private func emitEvent(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(event)
    }
  }

  private func handleVoiceActivity(buffer: AVAudioPCMBuffer) {
    guard let promptId = currentPromptId else { return }
    let bufferDurationMs = (Double(buffer.frameLength) / buffer.format.sampleRate) * 1000
    let bufferStartMs = recordedDurationMs
    let bufferEndMs = bufferStartMs + bufferDurationMs

    if isSpeechDetected(in: buffer) {
      if !hasDetectedSpeech {
        hasDetectedSpeech = true
        emitEvent([
          "type": "speechStarted",
          "promptId": promptId
        ])
      }
      firstDetectedSpeechMs = firstDetectedSpeechMs ?? bufferStartMs
      lastDetectedSpeechMs = bufferEndMs

      if silenceStartAt != nil || lastReportedSilenceMs > 0 {
        emitEvent([
          "type": "silenceProgress",
          "promptId": promptId,
          "silenceMs": 0
        ])
      }
      silenceStartAt = nil
      lastReportedSilenceMs = 0
      recordedDurationMs = bufferEndMs
      return
    }

    recordedDurationMs = bufferEndMs
    guard hasDetectedSpeech else { return }

    let now = Date()
    if silenceStartAt == nil {
      silenceStartAt = now
    }
    let silenceMs = Int(now.timeIntervalSince(silenceStartAt ?? now) * 1000)
    if silenceMs == 0 || silenceMs - lastReportedSilenceMs >= 200 {
      lastReportedSilenceMs = silenceMs
      emitEvent([
        "type": "silenceProgress",
        "promptId": promptId,
        "silenceMs": silenceMs
      ])
    }
  }

  private func isSpeechDetected(in buffer: AVAudioPCMBuffer) -> Bool {
    let threshold: Float = 0.015

    if let channelData = buffer.floatChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return false }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let sample = channel[frame]
        sum += sample * sample
      }
      let rms = sqrt(sum / Float(frameLength))
      return rms >= threshold
    }

    if let channelData = buffer.int16ChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return false }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let normalized = Float(channel[frame]) / Float(Int16.max)
        sum += normalized * normalized
      }
      let rms = sqrt(sum / Float(frameLength))
      return rms >= threshold
    }

    return false
  }

  private func trimRecordingIfNeeded(fileURL: URL) {
    do {
      let sourceFile = try AVAudioFile(forReading: fileURL)
      guard let trimRange = detectSpeechRange(in: sourceFile) else {
        return
      }

      let sampleRate = sourceFile.processingFormat.sampleRate
      let startMs = max(0, trimRange.startMs - trimLeadingPaddingMs)
      let endMs = min(trimRange.endMs + trimTrailingPaddingMs, (Double(sourceFile.length) / sampleRate) * 1000.0)
      guard endMs - startMs > 120 else {
        return
      }

      let startFrame = AVAudioFramePosition((startMs / 1000.0) * sampleRate)
      let endFrame = AVAudioFramePosition((endMs / 1000.0) * sampleRate)
      let totalFrames = sourceFile.length
      let safeStartFrame = max(0, min(startFrame, totalFrames))
      let safeEndFrame = max(safeStartFrame, min(endFrame, totalFrames))
      let framesToCopy = safeEndFrame - safeStartFrame
      guard framesToCopy > 0 else { return }

      let tempURL = fileURL.deletingLastPathComponent()
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("caf")
      let outputFile = try AVAudioFile(
        forWriting: tempURL,
        settings: sourceFile.fileFormat.settings
      )

      sourceFile.framePosition = safeStartFrame
      let chunkSize: AVAudioFrameCount = 4096
      while sourceFile.framePosition < safeEndFrame {
        let remainingFrames = safeEndFrame - sourceFile.framePosition
        let framesThisPass = AVAudioFrameCount(min(Int64(chunkSize), remainingFrames))
        guard let buffer = AVAudioPCMBuffer(
          pcmFormat: sourceFile.processingFormat,
          frameCapacity: framesThisPass
        ) else {
          break
        }
        try sourceFile.read(into: buffer, frameCount: framesThisPass)
        if buffer.frameLength == 0 {
          break
        }
        try outputFile.write(from: buffer)
      }

      try FileManager.default.removeItem(at: fileURL)
      try FileManager.default.moveItem(at: tempURL, to: fileURL)
    } catch {
      // 保留原始录音即可，不阻塞识别结果返回。
    }
  }

  private func detectSpeechRange(in audioFile: AVAudioFile) -> (startMs: Double, endMs: Double)? {
    let chunkSize: AVAudioFrameCount = 2048
    let threshold: Float = 0.022
    let sampleRate = audioFile.processingFormat.sampleRate
    var firstSpeechFrame: AVAudioFramePosition?
    var lastSpeechFrame: AVAudioFramePosition?

    audioFile.framePosition = 0

    while audioFile.framePosition < audioFile.length {
      let remainingFrames = audioFile.length - audioFile.framePosition
      let framesThisPass = AVAudioFrameCount(min(Int64(chunkSize), remainingFrames))
      guard let buffer = AVAudioPCMBuffer(
        pcmFormat: audioFile.processingFormat,
        frameCapacity: framesThisPass
      ) else {
        break
      }

      let chunkStartFrame = audioFile.framePosition
      try? audioFile.read(into: buffer, frameCount: framesThisPass)
      if buffer.frameLength == 0 {
        break
      }

      if rmsLevel(of: buffer) >= threshold {
        firstSpeechFrame = firstSpeechFrame ?? chunkStartFrame
        lastSpeechFrame = chunkStartFrame + AVAudioFramePosition(buffer.frameLength)
      }
    }

    audioFile.framePosition = 0

    guard let firstSpeechFrame, let lastSpeechFrame, lastSpeechFrame > firstSpeechFrame else {
      return nil
    }

    return (
      startMs: (Double(firstSpeechFrame) / sampleRate) * 1000.0,
      endMs: (Double(lastSpeechFrame) / sampleRate) * 1000.0
    )
  }

  private func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
    if let channelData = buffer.floatChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return 0 }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let sample = channel[frame]
        sum += sample * sample
      }
      return sqrt(sum / Float(frameLength))
    }

    if let channelData = buffer.int16ChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return 0 }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let normalized = Float(channel[frame]) / Float(Int16.max)
        sum += normalized * normalized
      }
      return sqrt(sum / Float(frameLength))
    }

    return 0
  }

  private func makeAmplifiedBuffer(from buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
    guard let copy = AVAudioPCMBuffer(
      pcmFormat: buffer.format,
      frameCapacity: buffer.frameCapacity
    ) else {
      return buffer
    }
    copy.frameLength = buffer.frameLength

    if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
      for channel in 0..<Int(buffer.format.channelCount) {
        let sourceChannel = source[channel]
        let destinationChannel = destination[channel]
        for frame in 0..<Int(buffer.frameLength) {
          let amplified = sourceChannel[frame] * gain
          destinationChannel[frame] = max(-1.0, min(1.0, amplified))
        }
      }
      return copy
    }

    if let source = buffer.int16ChannelData, let destination = copy.int16ChannelData {
      for channel in 0..<Int(buffer.format.channelCount) {
        let sourceChannel = source[channel]
        let destinationChannel = destination[channel]
        for frame in 0..<Int(buffer.frameLength) {
          let amplified = Float(sourceChannel[frame]) * gain
          let clamped = max(Float(Int16.min), min(Float(Int16.max), amplified))
          destinationChannel[frame] = Int16(clamped)
        }
      }
      return copy
    }

    return buffer
  }

  /// 句子级清理：释放 recognitionTask/request/file/VAD 状态，不动 engine。
  private func cleanupSentenceState(cancelRecognition: Bool) {
    audioFile = nil

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    if cancelRecognition {
      recognitionTask?.cancel()
    }
    recognitionTask = nil
    currentPromptId = nil
    hasDetectedSpeech = false
    silenceStartAt = nil
    lastReportedSilenceMs = -1
    recordedDurationMs = 0
    firstDetectedSpeechMs = nil
    lastDetectedSpeechMs = nil
  }

  /// 引擎级清理：removeTap + engine.stop + 释放全部引擎资源。
  private func cleanupEngine() {
    configChangeRestartWorkItem?.cancel()
    configChangeRestartWorkItem = nil
    warmupTimeoutWorkItem?.cancel()
    warmupTimeoutWorkItem = nil
    // 必须在置 nil 前调用 pending result，否则 Dart 端 await warmup() 永远挂起。
    if let pendingResult = warmupPendingResult {
      warmupPendingResult = nil
      pendingResult(FlutterError(
        code: SpeechPracticeMacError.recordingFailed.rawValue,
        message: "Audio engine was shut down during warmup",
        details: nil
      ))
    }
    if let observer = configChangeObserver {
      NotificationCenter.default.removeObserver(observer)
      configChangeObserver = nil
    }
    if let engine = audioEngine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    audioEngine = nil
    cachedRecognizer = nil
    isEngineRunning = false
    isRecording = false
  }

  /// 重置句子级状态变量。
  private func resetSentenceState(promptId: String, fileURL: URL, audioFile: AVAudioFile, request: SFSpeechAudioBufferRecognitionRequest?) {
    sessionGeneration += 1
    currentPromptId = promptId
    currentFileURL = fileURL
    hasDetectedSpeech = false
    silenceStartAt = nil
    lastReportedSilenceMs = -1
    recordedDurationMs = 0
    firstDetectedSpeechMs = nil
    lastDetectedSpeechMs = nil
    self.audioFile = audioFile
    recognitionRequest = request
  }

  /// 在 inputNode 上安装音频 tap，统一处理录音数据写入和语音识别。
  private func installInputTap(on engine: AVAudioEngine) {
    let inputNode = engine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
      guard let self, self.isRecording else { return }
      self.handleVoiceActivity(buffer: buffer)
      self.recognitionRequest?.append(buffer)
      do {
        let playbackBuffer = self.makeAmplifiedBuffer(from: buffer, gain: 2.2)
        try self.audioFile?.write(from: playbackBuffer)
      } catch {
        self.emitError(
          code: SpeechPracticeMacError.recordingFailed.rawValue,
          message: "Failed to write recording buffer"
        )
      }
    }
  }

  private func sanitizedFileName(_ promptId: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let unicodeScalars = promptId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
    return String(unicodeScalars)
  }
}

/// NLEmbedding 文本 embedding 桥接，提供句子级 embedding 向量计算。
final class MacTextEmbeddingHandler: NSObject {
  private let methodChannel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "top.echo-loop/text_embedding",
      binaryMessenger: binaryMessenger
    )
    super.init()
    methodChannel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "embed":
      guard #available(macOS 11.0, *) else {
        result(FlutterError(
          code: "notAvailable",
          message: "Sentence embedding requires macOS 11.0 or newer",
          details: nil
        ))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String
      else {
        result(FlutterError(
          code: "invalidArguments",
          message: "Missing 'text' parameter",
          details: nil
        ))
        return
      }
      guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
        result(FlutterError(
          code: "notAvailable",
          message: "Sentence embedding model is not available",
          details: nil
        ))
        return
      }
      guard let vector = embedding.vector(for: text) else {
        result(FlutterError(
          code: "embeddingFailed",
          message: "Failed to compute embedding for the given text",
          details: nil
        ))
        return
      }
      result(vector)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Apple 原生音频解码桥接，为 Flutter 字幕自动校准提供低采样率 PCM 数据。
private struct MacAudioDecodeError: Error {
  let code: String
  let message: String
  let details: Any?

  func asFlutterError() -> FlutterError {
    FlutterError(code: code, message: message, details: details)
  }
}

final class MacAudioDecodeHandler: NSObject {
  private let methodChannel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "top.echo-loop/audio_decode",
      binaryMessenger: binaryMessenger
    )
    super.init()
    methodChannel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "decode":
      guard let args = call.arguments as? [String: Any],
            let audioPath = args["audioPath"] as? String,
            !audioPath.isEmpty
      else {
        result(FlutterError(
          code: "invalidArguments",
          message: "Missing 'audioPath' parameter",
          details: nil
        ))
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let payload = try self.decodeAudio(atPath: audioPath)
          DispatchQueue.main.async {
            result(payload)
          }
        } catch let error as MacAudioDecodeError {
          DispatchQueue.main.async {
            result(error.asFlutterError())
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "decodeFailed",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func decodeAudio(atPath audioPath: String) throws -> [String: Any] {
    let fileURL = URL(fileURLWithPath: audioPath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw MacAudioDecodeError(
        code: "fileNotFound",
        message: "Audio file does not exist",
        details: audioPath
      )
    }

    let asset = AVURLAsset(url: fileURL)
    guard let track = asset.tracks(withMediaType: .audio).first else {
      throw MacAudioDecodeError(
        code: "notAvailable",
        message: "Audio asset has no readable audio track",
        details: nil
      )
    }

    let reader = try AVAssetReader(asset: asset)
    let outputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false
    ]
    let output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: outputSettings
    )
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else {
      throw MacAudioDecodeError(
        code: "notAvailable",
        message: "Failed to attach audio track output",
        details: nil
      )
    }
    reader.add(output)
    guard reader.startReading() else {
      throw MacAudioDecodeError(
        code: "decodeFailed",
        message: reader.error?.localizedDescription ?? "Failed to start asset reader",
        details: nil
      )
    }

    guard let formatDescription = track.formatDescriptions.first else {
      throw MacAudioDecodeError(
        code: "notAvailable",
        message: "Audio track missing format description",
        details: nil
      )
    }
    guard let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(
      formatDescription as! CMAudioFormatDescription
    ) else {
      throw MacAudioDecodeError(
        code: "notAvailable",
        message: "Failed to read audio stream description",
        details: nil
      )
    }

    let inputSampleRate = streamDescription.pointee.mSampleRate
    let channelCount = Int(streamDescription.pointee.mChannelsPerFrame)
    guard channelCount > 0 else {
      throw MacAudioDecodeError(
        code: "notAvailable",
        message: "Audio file has no channels",
        details: nil
      )
    }

    var outputSamples = [Float]()
    let estimatedFrames = max(
      0,
      Int(CMTimeGetSeconds(asset.duration) * inputSampleRate)
    )
    let estimatedOutputSamples = max(
      1,
      Int(Double(estimatedFrames) * autoAlignTargetSampleRate / inputSampleRate)
    )
    outputSamples.reserveCapacity(estimatedOutputSamples)

    let resampleRatio = inputSampleRate / autoAlignTargetSampleRate
    var nextOutputSourceFrame = 0.0
    var processedSourceFrames = 0.0

    while true {
      guard let sampleBuffer = output.copyNextSampleBuffer() else {
        break
      }

      guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
        CMSampleBufferInvalidate(sampleBuffer)
        throw MacAudioDecodeError(
          code: "decodeFailed",
          message: "Decoded sample buffer missing block buffer",
          details: nil
        )
      }

      let blockLength = CMBlockBufferGetDataLength(blockBuffer)
      var bytes = [UInt8](repeating: 0, count: blockLength)
      let copyStatus = CMBlockBufferCopyDataBytes(
        blockBuffer,
        atOffset: 0,
        dataLength: blockLength,
        destination: &bytes
      )
      if copyStatus != noErr {
        CMSampleBufferInvalidate(sampleBuffer)
        throw MacAudioDecodeError(
          code: "decodeFailed",
          message: "Failed to copy decoded PCM bytes: \(copyStatus)",
          details: nil
        )
      }

      let frameLength = blockLength / (MemoryLayout<Float>.size * channelCount)
      let chunkStartFrame = processedSourceFrames
      let chunkEndFrame = chunkStartFrame + Double(frameLength)

      bytes.withUnsafeBytes { rawBuffer in
        let samples = rawBuffer.bindMemory(to: Float.self)
        while nextOutputSourceFrame < chunkEndFrame {
          let localFrame = min(
            max(0, Int(nextOutputSourceFrame - chunkStartFrame)),
            frameLength - 1
          )
          let frameOffset = localFrame * channelCount
          var mixed = 0.0 as Float
          for channel in 0..<channelCount {
            mixed += samples[frameOffset + channel]
          }
          outputSamples.append(mixed / Float(channelCount))
          nextOutputSourceFrame += resampleRatio
        }
      }

      processedSourceFrames = chunkEndFrame
      CMSampleBufferInvalidate(sampleBuffer)
    }

    if reader.status == .failed {
      throw MacAudioDecodeError(
        code: "decodeFailed",
        message: reader.error?.localizedDescription ?? "Asset reader failed",
        details: nil
      )
    }

    guard !outputSamples.isEmpty else {
      return [
        "sampleRate": Int(autoAlignTargetSampleRate.rounded()),
        "pcmBytes": FlutterStandardTypedData(bytes: Data())
      ]
    }

    var pcmBytes = Data(capacity: outputSamples.count * MemoryLayout<UInt32>.size)
    for sample in outputSamples {
      var bits = sample.bitPattern.littleEndian
      withUnsafeBytes(of: &bits) { rawBuffer in
        pcmBytes.append(contentsOf: rawBuffer)
      }
    }

    return [
      "sampleRate": Int(autoAlignTargetSampleRate.rounded()),
      "pcmBytes": FlutterStandardTypedData(bytes: pcmBytes)
    ]
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private var speechPracticeHandler: MacSpeechPracticeHandler?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    // 注意：MethodChannel 的实际注册在 MainFlutterWindow.awakeFromNib 中完成，
    // 因为 Dart 使用的是 window 的 FlutterEngine，而非 AppDelegate 的。
    // 此处的注册绑定的 engine 不是 Dart 端使用的，属于无效代码，已移除 textEmbeddingHandler。
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      speechPracticeHandler = MacSpeechPracticeHandler(binaryMessenger: controller.engine.binaryMessenger)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
