import Foundation

/// 自适应 VAD 门槛：按当前环境底噪动态决定「有声」判定门槛。
///
/// 与 Android `AdaptiveVadThreshold.kt` 算法、参数保持一致（三端同源，改动需同步）。
///
/// 旧实现使用固定门槛 0.015（增益前原始 RMS），说话小声或麦克风灵敏度低的用户
/// 整句电平都贴着甚至低于该值，说话中途被判为静音，触发静音兜底提前结束录音。
///
/// 算法：
/// - 底噪 = 最近 `windowSize` 个「判为静音」的非零 buffer RMS 的 `floorPercentile` 分位数。
///   判为有声的 buffer 不进入统计，连续长时间说话也不会把底噪抬到语音电平。
/// - 门槛 = 底噪 × `noiseMultiplier`，限制在 [`minThreshold`, `maxThreshold`]。
///   - 上限 = 旧固定门槛：嘈杂环境下最多回到旧行为，判定不会比修复前更严格。
///   - 下限：极安静环境下避免把微弱电流声/呼吸声当成说话，导致录音迟迟不停。
/// - 每个 buffer 用加入它之前的门槛判定；尚无样本时使用上限门槛。
///
/// 线程：音频 tap 线程调用 `isVoiced`，主线程调用 `reset`/`describe`，内部加锁。
final class AdaptiveVadThreshold {
  /// 最低门槛（原始 RMS ≈ -48 dBFS）。
  static let minThreshold: Float = 0.004
  /// 最高门槛，等于旧固定门槛。
  static let maxThreshold: Float = 0.015
  /// 门槛相对底噪的倍数（约 +8 dB）。
  ///
  /// 取向「宁可多录几秒，也不要截断」：倍数偏低，弱语音更容易判为有声；
  /// 代价是中等嘈杂环境下自动停止略慢（最终由最大录音时长兜底）。
  static let noiseMultiplier: Float = 2.5
  /// 底噪统计窗口（buffer 个数）。
  static let windowSize = 470
  /// 底噪取窗口内的低分位数。
  static let floorPercentile = 0.1

  private let lock = NSLock()
  private var window: [Float] = []
  private var currentThreshold: Float = AdaptiveVadThreshold.maxThreshold
  private var currentNoiseFloor: Float?
  private var voicedCount = 0
  private var totalCount = 0

  /// 当前判定门槛。
  var threshold: Float {
    lock.lock()
    defer { lock.unlock() }
    return currentThreshold
  }

  /// 当前估计的底噪；尚无有效样本时为 nil。
  var noiseFloor: Float? {
    lock.lock()
    defer { lock.unlock() }
    return currentNoiseFloor
  }

  /// 判定本 buffer 是否有声，并用它更新底噪估计。
  func isVoiced(rms: Float) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let voiced = rms >= currentThreshold
    totalCount += 1
    if voiced { voicedCount += 1 }
    // 只用静音 buffer 估计底噪；全零 buffer 是启动阶段的数字静音，不代表环境底噪。
    if !voiced && rms > 0 {
      window.append(rms)
      if window.count > Self.windowSize { window.removeFirst() }
      updateThreshold()
    }
    return voiced
  }

  /// 新录音回合开始时重置。
  func reset() {
    lock.lock()
    defer { lock.unlock() }
    window.removeAll()
    currentNoiseFloor = nil
    currentThreshold = Self.maxThreshold
    voicedCount = 0
    totalCount = 0
  }

  /// 诊断信息，用于录音结束时输出日志。
  func describe() -> String {
    lock.lock()
    defer { lock.unlock() }
    let floorText = currentNoiseFloor.map { String(format: "%.4f", $0) } ?? "null"
    return "vadThreshold=\(String(format: "%.4f", currentThreshold)) "
      + "vadNoiseFloor=\(floorText) vadVoicedBuffers=\(voicedCount)/\(totalCount)"
  }

  private func updateThreshold() {
    let sorted = window.sorted()
    let index = Int(Double(sorted.count - 1) * Self.floorPercentile)
    let floor = sorted[index]
    currentNoiseFloor = floor
    currentThreshold = min(max(floor * Self.noiseMultiplier, Self.minThreshold), Self.maxThreshold)
  }
}
