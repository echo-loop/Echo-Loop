/// 跟读会话阶段状态机
///
/// 表达跟读流程的顶层阶段，每个阶段互斥。
/// 流程：PlayingPrompt → Recording → (ReviewingRecording) → WaitingInterval → 下一遍/句
///
/// 关键设计：
/// - **倒计时只在 WaitingInterval**：播放/录音/回放时没有倒计时
/// - **Interrupted 统一处理打断**：区分 manualPause（恢复剩余时间）和其他打断（恢复后重置 T）
/// - **flowToken 防异步竞态**：所有异步回调校验 token，过期直接丢弃
library;

/// 跟读流程阶段
sealed class ShadowingPhase {
  const ShadowingPhase();
}

/// 空闲（未开始或已停止）
class Idle extends ShadowingPhase {
  const Idle();
}

/// 播放原句中
class PlayingPrompt extends ShadowingPhase {
  const PlayingPrompt();
}

/// 录音中（用户跟读）
class ShadowingRecording extends ShadowingPhase {
  const ShadowingRecording();
}

/// 播放录音回放中
class ReviewingRecording extends ShadowingPhase {
  const ReviewingRecording();
}

/// 遍间等待（倒计时 T 秒，唯一可以有倒计时的阶段）
class WaitingInterval extends ShadowingPhase {
  const WaitingInterval();
}

/// 等待用户操作
///
/// 录音失败/超时需要重试、用户点了翻译/解析/查词、打开设置弹窗等场景。
/// 不自动推进，等用户主动操作（录音/播放/切句）后恢复自动流程。
/// 与 [WaitingInterval] 的区别：没有倒计时。
class WaitingForUser extends ShadowingPhase {
  const WaitingForUser();
}

/// 当前句子所有遍数完成（短暂过渡，自动推进到下一句或完成）
class SentenceCompleted extends ShadowingPhase {
  const SentenceCompleted();
}

/// 整个会话完成（所有句子全部跟读完）
class SessionCompleted extends ShadowingPhase {
  const SessionCompleted();
}

