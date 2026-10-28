import AVFoundation
import Darwin
import Flutter
import NaturalLanguage
import PostHog
import Speech
import StoreKit
import UIKit
import UserNotifications

private enum SpeechPracticeError: String {
  case permissionDenied
  case notAvailable
  case noSpeech
  case invalidArguments
  case recordingFailed
  case finalTimeout
}

private let trimLeadingPaddingMs = 120.0
private let trimTrailingPaddingMs = 180.0
private let autoAlignTargetSampleRate = 1000.0

private final class IOSSpeechPracticeHandler: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  // 引擎级资源（页面常驻，warmup 创建，shutdown 释放）
  private var audioEngine: AVAudioEngine?
  private var cachedRecognizer: SFSpeechRecognizer?
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
  /// 有声判定门槛，按环境底噪自适应（替代旧固定门槛 0.015）。
  private let vadThreshold = AdaptiveVadThreshold()
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
    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted:
      return "granted"
    case .denied:
      return "denied"
    case .undetermined:
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
    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] _ in
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
  /// 如果权限尚未请求（notDetermined），会自动触发系统权限弹窗。
  private func warmup(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    let micStatus = microphonePermissionStatus()

    // 纯录音模式只需要麦克风权限；识别模式还需要语音识别权限。
    let needsSpeech = recognitionEnabled
    let speechStatus = needsSpeech ? speechPermissionStatus() : "granted"

    if micStatus == "notDetermined" || speechStatus == "notDetermined" {
      requestPermissions(onlyMic: !needsSpeech) { [weak self] _ in
        self?.warmup(arguments, result: result)
      }
      return
    }

    guard micStatus == "granted", speechStatus == "granted" else {
      result(FlutterError(
        code: SpeechPracticeError.permissionDenied.rawValue,
        message: "Microphone or speech permission denied",
        details: nil
      ))
      return
    }

    // 已在运行则直接返回。
    if isEngineRunning {
      result([:])
      return
    }

    let localeIdentifier = (arguments?["locale"] as? String) ?? "en-US"
    if recognitionEnabled {
      cachedRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    do {
      try configureRecordingSession()

      let engine = AVAudioEngine()
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
            code: SpeechPracticeError.recordingFailed.rawValue,
            message: "Failed to write recording buffer"
          )
        }
      }

      engine.prepare()
      try engine.start()
      audioEngine = engine
      isEngineRunning = true
      result([:])
    } catch {
      cleanupEngine()
      result(FlutterError(
        code: SpeechPracticeError.recordingFailed.rawValue,
        message: "Failed to warmup audio engine",
        details: error.localizedDescription
      ))
    }
  }

  private func startSession(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard
      let promptId = arguments?["promptId"] as? String,
      !promptId.isEmpty
    else {
      result(FlutterError(
        code: SpeechPracticeError.invalidArguments.rawValue,
        message: "Missing promptId",
        details: nil
      ))
      return
    }

    let localeIdentifier = (arguments?["locale"] as? String) ?? "en-US"

    // 引擎已常驻：轻量启动，只创建句子级资源。
    if isEngineRunning, let engine = audioEngine {
      do {
        try startSessionLightweight(engine: engine, promptId: promptId, locale: localeIdentifier, result: result)
      } catch {
        cleanupSentenceState(cancelRecognition: true)
        result(FlutterError(
          code: SpeechPracticeError.recordingFailed.rawValue,
          message: "Failed to start lightweight session",
          details: error.localizedDescription
        ))
      }
      return
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
          code: SpeechPracticeError.notAvailable.rawValue,
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
        code: SpeechPracticeError.permissionDenied.rawValue,
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
          code: SpeechPracticeError.notAvailable.rawValue,
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
      try configureRecordingSession()

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

      inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
        guard let self, self.isRecording else { return }
        self.handleVoiceActivity(buffer: buffer)
        self.recognitionRequest?.append(buffer)
        do {
          let playbackBuffer = self.makeAmplifiedBuffer(from: buffer, gain: 2.2)
          try self.audioFile?.write(from: playbackBuffer)
        } catch {
          self.emitError(
            code: SpeechPracticeError.recordingFailed.rawValue,
            message: "Failed to write recording buffer"
          )
        }
      }

      engine.prepare()
      try engine.start()
      isEngineRunning = true
      isRecording = true
      result(["filePath": fileURL.path])
    } catch {
      cleanupSentenceState(cancelRecognition: true)
      cleanupEngine()
      result(FlutterError(
        code: SpeechPracticeError.recordingFailed.rawValue,
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
    result([
      "filePath": currentFileURL?.path as Any,
      "diagnostics": vadThreshold.describe(),
    ])

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
        "errorCode": SpeechPracticeError.noSpeech.rawValue,
        "errorMessage": error.localizedDescription
      ])
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

  /// 有声判定：buffer 原始 RMS 与自适应门槛比较（见 `AdaptiveVadThreshold`）。
  private func isSpeechDetected(in buffer: AVAudioPCMBuffer) -> Bool {
    vadThreshold.isVoiced(rms: rmsLevel(of: buffer))
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
    vadThreshold.reset()
  }

  /// 引擎级清理：removeTap + engine.stop + 释放全部引擎资源 + 恢复 playback session。
  private func cleanupEngine() {
    if let engine = audioEngine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    audioEngine = nil
    cachedRecognizer = nil
    isEngineRunning = false
    isRecording = false
    restorePlaybackSession()
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
    vadThreshold.reset()
    self.audioFile = audioFile
    recognitionRequest = request
  }

  private func configureRecordingSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
    try session.setActive(true)
  }

  private func restorePlaybackSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true)
    } catch {
      // Flutter 侧已有播放配置兜底，这里静默失败即可。
    }
  }

  private func sanitizedFileName(_ promptId: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let unicodeScalars = promptId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
    return String(unicodeScalars)
  }
}

/// NLEmbedding 文本 embedding 桥接，提供句子级 embedding 向量计算。
private final class IOSTextEmbeddingHandler: NSObject {
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
      guard #available(iOS 14.0, *) else {
        result(FlutterError(
          code: "notAvailable",
          message: "Sentence embedding requires iOS 14.0 or newer",
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
private struct IOSAudioDecodeError: Error {
  let code: String
  let message: String
  let details: Any?

  func asFlutterError() -> FlutterError {
    FlutterError(code: code, message: message, details: details)
  }
}

private final class IOSAudioDecodeHandler: NSObject {
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
        } catch let error as IOSAudioDecodeError {
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
      throw IOSAudioDecodeError(
        code: "fileNotFound",
        message: "Audio file does not exist",
        details: audioPath
      )
    }

    let asset = AVURLAsset(url: fileURL)
    guard let track = asset.tracks(withMediaType: .audio).first else {
      throw IOSAudioDecodeError(
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
      throw IOSAudioDecodeError(
        code: "notAvailable",
        message: "Failed to attach audio track output",
        details: nil
      )
    }
    reader.add(output)
    guard reader.startReading() else {
      throw IOSAudioDecodeError(
        code: "decodeFailed",
        message: reader.error?.localizedDescription ?? "Failed to start asset reader",
        details: nil
      )
    }

    guard let formatDescription = track.formatDescriptions.first else {
      throw IOSAudioDecodeError(
        code: "notAvailable",
        message: "Audio track missing format description",
        details: nil
      )
    }
    guard let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(
      formatDescription as! CMAudioFormatDescription
    ) else {
      throw IOSAudioDecodeError(
        code: "notAvailable",
        message: "Failed to read audio stream description",
        details: nil
      )
    }

    let inputSampleRate = streamDescription.pointee.mSampleRate
    let channelCount = Int(streamDescription.pointee.mChannelsPerFrame)
    guard channelCount > 0 else {
      throw IOSAudioDecodeError(
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
        throw IOSAudioDecodeError(
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
        throw IOSAudioDecodeError(
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
      throw IOSAudioDecodeError(
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
@objc class AppDelegate: FlutterAppDelegate {
  private var speechPracticeHandler: IOSSpeechPracticeHandler?
  private var textEmbeddingHandler: IOSTextEmbeddingHandler?
  private var audioDecodeHandler: IOSAudioDecodeHandler?
  private var notificationPermissionHandler: NotificationPermissionHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // PostHog 必须在 Flutter 插件注册前完成 setup，原因有二：
    // 1. SDK 需要在 didBecomeActive 通知到达前注册 NotificationCenter observer，
    //    否则首次 Application Opened 必丢（observer 不追溯历史通知）。
    // 2. posthog_flutter 插件自带的 plist 自动 init（initPlugin）不支持 sessionReplay 配置，
    //    且 PostHog iOS SDK 二次 setup 是 no-op，会让 Dart 端 sessionReplay=true 失效。
    // 因此 Info.plist 设置 com.posthog.posthog.AUTO_INIT=false 关闭插件自动 init，
    // 这里直接用完整配置（含 sessionReplay）启动 SDK。
    setupPostHogNative()

    GeneratedPluginRegistrant.register(with: self)

    // flutter_local_notifications 要求显式设置 delegate，
    // 否则通知点击回调不会转发到插件（iOS 端不会自动设置）。
    UNUserNotificationCenter.current().delegate = self

    let controller = window?.rootViewController as! FlutterViewController
    let networkChannel = FlutterMethodChannel(
      name: "top.echo-loop/network",
      binaryMessenger: controller.binaryMessenger
    )
    networkChannel.setMethodCallHandler { (call, result) in
      if call.method == "triggerNetworkPermission" {
        guard let args = call.arguments as? [String: String],
              let urlString = args["url"],
              let url = URL(string: urlString) else {
          result(["ok": false, "reason": "invalid_url"])
          return
        }
        // method channel result 只允许回一次（参考 CLAUDE.md §7.2 flutter_tts 踩坑）。
        // dataTask 回调与 5s 超时回调存在竞争，用 hasResponded 守护避免双发。
        var hasResponded = false
        let respond: ([String: Any]) -> Void = { payload in
          DispatchQueue.main.async {
            if hasResponded { return }
            hasResponded = true
            result(payload)
          }
        }
        URLSession.shared.dataTask(with: url) { _, _, error in
          respond(["ok": error == nil])
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
          respond(["ok": false, "reason": "timeout"])
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let subscriptionManagementChannel = FlutterMethodChannel(
      name: "top.echo-loop/subscription_management",
      binaryMessenger: controller.binaryMessenger
    )
    subscriptionManagementChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "openManageSubscriptions" {
        self?.openManageSubscriptions(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let deviceInfoChannel = FlutterMethodChannel(
      name: "top.echo-loop/device_info",
      binaryMessenger: controller.binaryMessenger
    )
    deviceInfoChannel.setMethodCallHandler { (call, result) in
      if call.method == "getDeviceInfo" {
        result(self.deviceInfo())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    speechPracticeHandler = IOSSpeechPracticeHandler(binaryMessenger: controller.binaryMessenger)
    textEmbeddingHandler = IOSTextEmbeddingHandler(binaryMessenger: controller.binaryMessenger)
    audioDecodeHandler = IOSAudioDecodeHandler(binaryMessenger: controller.binaryMessenger)
    notificationPermissionHandler = NotificationPermissionHandler(binaryMessenger: controller.binaryMessenger)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func deviceInfo() -> [String: Any] {
    let device = UIDevice.current
    return [
      "deviceName": device.name,
      "deviceModel": device.model,
      "modelIdentifier": modelIdentifier(),
      "systemName": device.systemName,
      "systemVersion": device.systemVersion,
      "isPhysicalDevice": !isSimulator()
    ]
  }

  private func modelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifier = mirror.children.reduce(into: "") { result, element in
      guard let value = element.value as? Int8, value != 0 else { return }
      result.append(String(UnicodeScalar(UInt8(value))))
    }
    return identifier
  }

  private func isSimulator() -> Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }

  /// 打开 iOS 系统订阅管理页。
  ///
  /// 使用 StoreKit 原生入口而不是浏览器 URL；Dart 侧会在本方法不可用或失败时回退
  /// App Store 订阅管理链接，兼容旧系统与异常场景。
  private func openManageSubscriptions(result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *) else {
      result(FlutterError(
        code: "unsupported",
        message: "StoreKit subscription management requires iOS 15 or later",
        details: nil
      ))
      return
    }

    let foregroundScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }

    guard let scene = foregroundScene else {
      result(FlutterError(
        code: "no_scene",
        message: "No foreground UIWindowScene for subscription management",
        details: nil
      ))
      return
    }

    Task { @MainActor in
      do {
        try await AppStore.showManageSubscriptions(in: scene)
        result(true)
      } catch {
        result(FlutterError(
          code: "open_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  /// 从 Info.plist 读取 API Key/Host，构造完整 PostHog 配置（含 Session Replay）并启动 SDK。
  ///
  /// 与 posthog_flutter 插件 initPlugin 的差异：插件版本不支持 sessionReplay 配置项，
  /// 这里手动启用 sessionReplay=true 才能让 iOS 录制生效。
  ///
  /// 配置项需与 lib/analytics/channels/posthog_channel.dart 保持一致：
  /// SDK 已 init 后 Dart 端二次 setup 是 no-op（PostHogSDK.swift:90-96），
  /// 所以 personProfiles / flushAt / flushIntervalSeconds 必须在这里就设上。
  private func setupPostHogNative() {
    let bundle = Bundle.main
    guard
      let apiKey = bundle.object(forInfoDictionaryKey: "com.posthog.posthog.API_KEY") as? String,
      !apiKey.isEmpty
    else {
      return
    }
    let host = (bundle.object(forInfoDictionaryKey: "com.posthog.posthog.POSTHOG_HOST") as? String)
      ?? PostHogConfig.defaultHost
    let captureLifecycle = (bundle.object(
      forInfoDictionaryKey: "com.posthog.posthog.CAPTURE_APPLICATION_LIFECYCLE_EVENTS"
    ) as? Bool) ?? true

    // 必须在 PostHogSDK.shared.setup 之前设置：
    // PostHogReplayIntegration.install() 内部立即调 start()，start() 用 isNotFlutter()
    // （检查 postHogSdkName != "posthog-flutter"）决定是否启动原生 viewLayoutPublisher
    // 截图通路。该判断只在 start() 中执行一次，订阅后无法撤销。如果此处不预设 sdkName，
    // 默认值是 "posthog-ios"，会导致原生 + Dart PostHogWidget 同时发 $snapshot，重复采集。
    postHogSdkName = "posthog-flutter"

    let config = PostHogConfig(apiKey: apiKey, host: host)
    config.captureScreenViews = false
    config.captureApplicationLifecycleEvents = captureLifecycle
    config.personProfiles = .always
    config.flushAt = 5
    config.flushIntervalSeconds = 3
    config.sessionReplay = true
    // Flutter 端走 dart:io HttpClient 而非 iOS URLSession，关闭网络遥测避免误报。
    config.sessionReplayConfig.captureNetworkTelemetry = false

    PostHogSDK.shared.setup(config)
  }
}
