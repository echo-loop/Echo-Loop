package app.echoloop

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * AdaptiveVadThreshold 的 JVM 单元测试。
 *
 * RMS 数值均为增益前的原始电平（与 WavRecorder.onBuffer 回调一致）。
 */
class AdaptiveVadThresholdTest {

    private fun AdaptiveVadThreshold.feed(rms: Float, count: Int): List<Boolean> =
        List(count) { isVoiced(rms) }

    @Test
    fun `没有任何样本时使用最高门槛（等同旧固定门槛）`() {
        val vad = AdaptiveVadThreshold()
        assertEquals(AdaptiveVadThreshold.MAX_THRESHOLD, vad.threshold, 0f)
        assertFalse(vad.isVoiced(0.014f))
        assertTrue(AdaptiveVadThreshold().isVoiced(0.015f))
    }

    // 回归：用户日志中整段原始 RMS 仅约 0.007–0.011，旧固定门槛 0.015
    // 把正在说话的小声用户判成静音，5s 兜底提前结束录音。
    @Test
    fun `安静环境下小声说话被判为有声`() {
        val vad = AdaptiveVadThreshold()
        vad.feed(0.0015f, 8) // 开口前约 0.5s 环境底噪

        val voiced = vad.feed(0.008f, 30)

        assertTrue("小声语音应全部判为有声", voiced.all { it })
        assertTrue(vad.threshold < 0.008f)
    }

    @Test
    fun `嘈杂环境门槛封顶在最高值，不会无限升高`() {
        val vad = AdaptiveVadThreshold()
        vad.feed(0.012f, 20) // 底噪 × 倍数 = 0.036，远超上限

        assertEquals(AdaptiveVadThreshold.MAX_THRESHOLD, vad.threshold, 0f)
        assertFalse("底噪本身不应判为有声", vad.isVoiced(0.012f))
        assertTrue("达到旧门槛的语音必须判为有声", vad.isVoiced(0.02f))
    }

    @Test
    fun `极安静环境门槛不低于最低值，避免微弱噪声被当成说话`() {
        val vad = AdaptiveVadThreshold()
        vad.feed(0.0003f, 20)

        assertEquals(AdaptiveVadThreshold.MIN_THRESHOLD, vad.threshold, 0f)
        assertFalse(vad.isVoiced(0.003f))
    }

    @Test
    fun `录音启动时的全零 buffer 不参与底噪估计`() {
        val vad = AdaptiveVadThreshold()
        vad.feed(0f, 5)
        vad.feed(0.003f, 10)

        // 底噪按 0.003 估计：门槛 = 0.0075，而不是被全零拉到最低值
        assertEquals(0.0075f, vad.threshold, 1e-6f)
    }

    // 取向「宁可多录几秒，也不要截断」：中等底噪下，略高于门槛的弱语音仍判为有声。
    @Test
    fun `中等底噪下弱语音仍判为有声`() {
        val vad = AdaptiveVadThreshold()
        vad.feed(0.004f, 10)

        assertEquals(0.010f, vad.threshold, 1e-6f)
        assertTrue(vad.isVoiced(0.011f))
        assertFalse(vad.isVoiced(0.004f))
    }

    @Test
    fun `开口后长时间连续说话门槛不会被语音抬高`() {
        val vad = AdaptiveVadThreshold()
        vad.feed(0.0015f, 8)

        // 约 19s 连续语音（无明显停顿）
        val voiced = vad.feed(0.008f, 300)

        assertTrue(voiced.all { it })
    }

    @Test
    fun `reset 后恢复初始门槛`() {
        val vad = AdaptiveVadThreshold()
        vad.feed(0.0015f, 10)
        vad.reset()

        assertEquals(AdaptiveVadThreshold.MAX_THRESHOLD, vad.threshold, 0f)
        assertEquals(null, vad.noiseFloor)
    }
}
