import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}

/// AdaptiveVadThreshold 单元测试（与 Android AdaptiveVadThresholdTest 用例一致）。
/// RMS 数值均为增益前的原始电平。
final class AdaptiveVadThresholdTests: XCTestCase {

  @discardableResult
  private func feed(_ vad: AdaptiveVadThreshold, _ rms: Float, _ count: Int) -> [Bool] {
    (0..<count).map { _ in vad.isVoiced(rms: rms) }
  }

  func testNoSamplesUsesMaxThreshold() {
    let vad = AdaptiveVadThreshold()
    XCTAssertEqual(vad.threshold, AdaptiveVadThreshold.maxThreshold)
    XCTAssertFalse(vad.isVoiced(rms: 0.014))
    XCTAssertTrue(AdaptiveVadThreshold().isVoiced(rms: 0.015))
  }

  /// 回归：小声用户整段电平低于旧固定门槛 0.015，说话中途被判为静音而截断录音。
  func testQuietSpeechInQuietRoomIsVoiced() {
    let vad = AdaptiveVadThreshold()
    feed(vad, 0.0015, 8)
    XCTAssertTrue(feed(vad, 0.008, 30).allSatisfy { $0 })
    XCTAssertLessThan(vad.threshold, 0.008)
  }

  func testNoisyRoomThresholdIsCappedAtMax() {
    let vad = AdaptiveVadThreshold()
    feed(vad, 0.012, 20)
    XCTAssertEqual(vad.threshold, AdaptiveVadThreshold.maxThreshold)
    XCTAssertFalse(vad.isVoiced(rms: 0.012))
    XCTAssertTrue(vad.isVoiced(rms: 0.02))
  }

  func testVeryQuietRoomThresholdNotBelowMin() {
    let vad = AdaptiveVadThreshold()
    feed(vad, 0.0003, 20)
    XCTAssertEqual(vad.threshold, AdaptiveVadThreshold.minThreshold)
    XCTAssertFalse(vad.isVoiced(rms: 0.003))
  }

  func testZeroBuffersIgnoredForNoiseFloor() {
    let vad = AdaptiveVadThreshold()
    feed(vad, 0, 5)
    feed(vad, 0.003, 10)
    XCTAssertEqual(vad.threshold, 0.0075, accuracy: 1e-6)
  }

  /// 取向「宁可多录几秒，也不要截断」：中等底噪下，略高于门槛的弱语音仍判为有声。
  func testWeakSpeechWithModerateNoiseIsVoiced() {
    let vad = AdaptiveVadThreshold()
    feed(vad, 0.004, 10)
    XCTAssertEqual(vad.threshold, 0.010, accuracy: 1e-6)
    XCTAssertTrue(vad.isVoiced(rms: 0.011))
    XCTAssertFalse(vad.isVoiced(rms: 0.004))
  }

  func testLongContinuousSpeechDoesNotRaiseThreshold() {
    let vad = AdaptiveVadThreshold()
    feed(vad, 0.0015, 8)
    XCTAssertTrue(feed(vad, 0.008, 300).allSatisfy { $0 })
  }

  func testResetRestoresInitialState() {
    let vad = AdaptiveVadThreshold()
    feed(vad, 0.0015, 10)
    vad.reset()
    XCTAssertEqual(vad.threshold, AdaptiveVadThreshold.maxThreshold)
    XCTAssertNil(vad.noiseFloor)
  }
}
