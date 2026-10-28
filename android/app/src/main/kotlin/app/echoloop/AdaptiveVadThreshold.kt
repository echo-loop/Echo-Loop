package app.echoloop

/**
 * 自适应 VAD 门槛：按当前环境底噪动态决定「有声」判定门槛。
 *
 * 与 iOS/macOS `AdaptiveVadThreshold.swift` 算法、参数保持一致（三端同源，改动需同步）。
 *
 * 旧实现使用固定门槛 0.015（增益前原始 RMS），说话小声或麦克风灵敏度低的用户
 * 整句电平都贴着甚至低于该值，说话中途被判为静音，触发静音兜底提前结束录音。
 *
 * 算法：
 * - 底噪 = 最近 [WINDOW_SIZE] 个「判为静音」的非零 buffer RMS 的 [FLOOR_PERCENTILE] 分位数。
 *   判为有声的 buffer 不进入统计，连续长时间说话也不会把底噪抬到语音电平；
 *   低分位进一步压低贴近门槛的弱语音对底噪的影响。
 * - 门槛 = 底噪 × [NOISE_MULTIPLIER]，并限制在 [[MIN_THRESHOLD], [MAX_THRESHOLD]]。
 *   - 上限 = 旧固定门槛：嘈杂环境下门槛最多回到旧行为，判定不会比修复前更严格。
 *   - 下限：极安静环境下避免把微弱电流声/呼吸声当成说话，导致录音迟迟不停。
 * - 每个 buffer 用「加入本 buffer 之前」的门槛判定，自身不影响自身判定；
 *   尚无样本时使用上限门槛。
 *
 * 线程：由录音 IO 线程调用 [isVoiced]，主线程调用 [reset]/[describe]，方法均加锁。
 */
class AdaptiveVadThreshold {

    companion object {
        /** 最低门槛（原始 RMS ≈ -48 dBFS）。 */
        const val MIN_THRESHOLD = 0.004f

        /** 最高门槛，等于旧固定门槛。 */
        const val MAX_THRESHOLD = 0.015f

        /**
         * 门槛相对底噪的倍数（约 +8 dB）。
         *
         * 取向「宁可多录几秒，也不要截断」：倍数偏低，弱语音更容易判为有声；
         * 代价是中等嘈杂环境下自动停止略慢（最终由最大录音时长兜底）。
         */
        const val NOISE_MULTIPLIER = 2.5f

        /** 底噪统计窗口：1024 帧 @16kHz ≈ 64ms/buffer，470 个 ≈ 30s。 */
        const val WINDOW_SIZE = 470

        /** 底噪取窗口内的低分位数。 */
        const val FLOOR_PERCENTILE = 0.1
    }

    private val window = ArrayDeque<Float>()
    private var voicedCount = 0
    private var totalCount = 0

    /** 当前估计的底噪；尚无有效样本时为 null。 */
    var noiseFloor: Float? = null
        @Synchronized get
        private set

    /** 当前判定门槛。 */
    var threshold: Float = MAX_THRESHOLD
        @Synchronized get
        private set

    /** 判定本 buffer 是否有声，并用它更新底噪估计。 */
    @Synchronized
    fun isVoiced(rms: Float): Boolean {
        val voiced = rms >= threshold
        totalCount++
        if (voiced) voicedCount++
        // 只用静音 buffer 估计底噪；全零 buffer 是 AudioRecord 启动阶段的数字静音，不代表环境底噪。
        if (!voiced && rms > 0f) {
            window.addLast(rms)
            if (window.size > WINDOW_SIZE) window.removeFirst()
            updateThreshold()
        }
        return voiced
    }

    /** 新录音回合开始时重置。 */
    @Synchronized
    fun reset() {
        window.clear()
        noiseFloor = null
        threshold = MAX_THRESHOLD
        voicedCount = 0
        totalCount = 0
    }

    /** 诊断信息，随 stopSession 的 diagnostics 输出到 Dart 日志。 */
    @Synchronized
    fun describe(): String =
        "vadThreshold=${"%.4f".format(threshold)} " +
            "vadNoiseFloor=${noiseFloor?.let { "%.4f".format(it) } ?: "null"} " +
            "vadVoicedBuffers=$voicedCount/$totalCount"

    private fun updateThreshold() {
        val sorted = window.sorted()
        val index = ((sorted.size - 1) * FLOOR_PERCENTILE).toInt()
        val floor = sorted[index]
        noiseFloor = floor
        threshold = (floor * NOISE_MULTIPLIER).coerceIn(MIN_THRESHOLD, MAX_THRESHOLD)
    }
}
