package app.echoloop

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * AudioRecord + WAV 文件录制模块。
 *
 * 职责：管理 AudioRecord 生命周期、将 PCM 数据写入 WAV 文件、
 * 计算每个 buffer 的 RMS 值（供外部 VAD 使用）。
 */
class WavRecorder {

    data class WavFileMetrics(val fileBytes: Long, val audioDurationMs: Long)

    /** 每个 buffer 的回调（RMS, 帧数），在 IO 线程上调用。 */
    var onBuffer: ((Float, Int) -> Unit)? = null

    private var audioRecord: AudioRecord? = null
    private var recordingJob: Job? = null
    private var wavFile: RandomAccessFile? = null
    private var currentFilePath: String? = null
    @Volatile private var totalDataBytes: Int = 0
    private val positiveReadFrames = AtomicLong(0)
    private val zeroReadCount = AtomicLong(0)
    private val errorReadCount = AtomicLong(0)
    @Volatile private var lastNonPositiveReadResult: Int? = null
    @Volatile private var recordingStartElapsedMs: Long? = null
    @Volatile private var recordingStartState: Int? = null
    @Volatile private var recordingStartAttempted = false
    @Volatile private var recordingStarted = false
    @Volatile private var stopJoinTimedOut = false

    /** 是否已初始化 AudioRecord。 */
    val isInitialized: Boolean get() = audioRecord != null

    companion object {
        private const val TAG = "WavRecorder"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BUFFER_SIZE_FRAMES = 1024
        private const val GAIN = 2.2f
        private const val BYTES_PER_SAMPLE = 2
        private const val NUM_CHANNELS = 1

        // 录音后裁剪参数（对齐 iOS/macOS）。
        private const val TRIM_RMS_THRESHOLD = 0.022f
        private const val TRIM_LEADING_PADDING_MS = 120.0
        private const val TRIM_TRAILING_PADDING_MS = 180.0
        private const val MIN_TRIM_DURATION_MS = 120.0
        private const val DETECT_CHUNK_FRAMES = 2048
        private const val WAV_HEADER_SIZE = 44
    }

    /**
     * 初始化 AudioRecord 实例。不开始录音。
     * @return true 表示初始化成功。
     */
    fun initialize(): Boolean {
        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "AudioRecord.getMinBufferSize failed: $minBufferSize")
            return false
        }
        val bufferSize = max(minBufferSize, BUFFER_SIZE_FRAMES * BYTES_PER_SAMPLE)
        return try {
            val recorder = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize,
            )
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize, state=${recorder.state}")
                recorder.release()
                return false
            }
            audioRecord = recorder
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "RECORD_AUDIO permission not granted", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord init failed", e)
            false
        }
    }

    /**
     * 开始录音并写入 WAV 文件。
     * @param filePath WAV 输出路径。
     */
    fun startRecording(filePath: String) {
        recordingStartAttempted = true
        val recorder = audioRecord ?: return
        currentFilePath = filePath
        totalDataBytes = 0

        val raf = RandomAccessFile(File(filePath), "rw")
        writeWavHeader(raf)
        wavFile = raf

        recorder.startRecording()
        recordingStarted = true
        recordingStartState = recorder.recordingState
        recordingStartElapsedMs = SystemClock.elapsedRealtime()

        recordingJob = CoroutineScope(Dispatchers.IO).launch {
            val buffer = ShortArray(BUFFER_SIZE_FRAMES)
            while (isActive) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read == 0) {
                    zeroReadCount.incrementAndGet()
                    lastNonPositiveReadResult = read
                    continue
                }
                if (read < 0) {
                    errorReadCount.incrementAndGet()
                    lastNonPositiveReadResult = read
                    continue
                }
                positiveReadFrames.addAndGet(read.toLong())

                val rms = computeRms(buffer, read)
                onBuffer?.invoke(rms, read)

                applyGainAndWrite(buffer, read)
            }
        }
    }

    /**
     * 停止录音，回填 WAV 头中的文件大小。
     * @return 录音文件路径。
     */
    fun stopRecording(): String? {
        // 先等录音协程真正退出，再操作 AudioRecord 和文件，避免 read() 与 stop() 并发。
        // 录音中 read() 最多阻塞一个 buffer 周期（~64ms）必然返回，join 不会卡死；
        // withTimeoutOrNull 兜底：极端情况（麦克风 hang）超时后退回原 stop() 行为，不劣于现状。
        val job = recordingJob
        val recordingJobJoined = runBlocking {
            if (job == null) {
                true
            } else {
                withTimeoutOrNull(500) {
                    job.cancelAndJoin()
                    true
                } ?: false
            }
        }
        stopJoinTimedOut = !recordingJobJoined
        recordingJob = null

        try {
            audioRecord?.stop()
        } catch (e: IllegalStateException) {
            Log.w(TAG, "AudioRecord.stop() failed", e)
        }

        patchWavHeader()
        wavFile?.close()
        wavFile = null

        return currentFilePath
    }

    /** 返回本轮采集统计，不包含录音内容。 */
    fun captureDiagnostics(): String {
        val readFrames = positiveReadFrames.get()
        val writtenBytes = totalDataBytes.toLong()
        val elapsedMs = recordingStartElapsedMs?.let {
            (SystemClock.elapsedRealtime() - it).coerceAtLeast(0L)
        }
        val writtenDurationMs =
            (writtenBytes / BYTES_PER_SAMPLE * 1000L) / SAMPLE_RATE

        return "audioRecordInitialized=${isInitialized} " +
            "startAttempted=$recordingStartAttempted " +
            "startSucceeded=$recordingStarted " +
            "recordingStateAtStart=${recordingStartState ?: "unknown"} " +
            "stopJoinTimedOut=$stopJoinTimedOut " +
            "positiveReadFrames=$readFrames " +
            "zeroReadCount=${zeroReadCount.get()} " +
            "errorReadCount=${errorReadCount.get()} " +
            "lastNonPositiveRead=$lastNonPositiveReadResult " +
            "writtenDataBytes=$writtenBytes " +
            "writtenDurationMs=$writtenDurationMs " +
            "captureElapsedMs=${elapsedMs ?: -1}"
    }

    /** 读取 WAV 文件大小与 PCM 时长，供录音结束诊断使用。 */
    fun wavFileMetrics(filePath: String): WavFileMetrics? {
        val file = File(filePath)
        if (!file.exists()) return null

        val fileBytes = file.length()
        val dataBytes = (fileBytes - WAV_HEADER_SIZE).coerceAtLeast(0L)
        val frames = dataBytes / BYTES_PER_SAMPLE
        val durationMs = frames * 1000L / SAMPLE_RATE
        return WavFileMetrics(fileBytes = fileBytes, audioDurationMs = durationMs)
    }

    /** 新会话开始时清空上轮统计，即使本轮 AudioRecord 初始化失败也不会复用旧数据。 */
    fun resetCaptureDiagnostics() {
        totalDataBytes = 0
        positiveReadFrames.set(0)
        zeroReadCount.set(0)
        errorReadCount.set(0)
        lastNonPositiveReadResult = null
        recordingStartElapsedMs = null
        recordingStartState = null
        recordingStartAttempted = false
        recordingStarted = false
        stopJoinTimedOut = false
    }

    /** 释放 AudioRecord 和所有资源。 */
    fun release() {
        // 同 stopRecording：先 join 录音协程，消除与 stop()/release() 的并发。
        runBlocking {
            withTimeoutOrNull(500) { recordingJob?.cancelAndJoin() }
        }
        recordingJob = null

        try {
            audioRecord?.stop()
        } catch (_: IllegalStateException) {
            // 可能还没 start，忽略。
        }
        audioRecord?.release()
        audioRecord = null

        wavFile?.close()
        wavFile = null
        currentFilePath = null
        onBuffer = null
    }

    /** 计算 16bit PCM buffer 的 RMS（归一化到 0.0~1.0）。 */
    private fun computeRms(buffer: ShortArray, length: Int): Float {
        if (length <= 0) return 0f
        var sum = 0.0
        for (i in 0 until length) {
            val normalized = buffer[i].toDouble() / Short.MAX_VALUE
            sum += normalized * normalized
        }
        return sqrt(sum / length).toFloat()
    }

    /** 对 buffer 应用增益并写入 WAV 文件。 */
    private fun applyGainAndWrite(buffer: ShortArray, length: Int) {
        val raf = wavFile ?: return
        val byteBuffer = ByteArray(length * BYTES_PER_SAMPLE)
        for (i in 0 until length) {
            val amplified = (buffer[i] * GAIN).toInt()
            val clamped = max(Short.MIN_VALUE.toInt(), min(Short.MAX_VALUE.toInt(), amplified))
            // WAV 使用 little-endian。
            byteBuffer[i * 2] = (clamped and 0xFF).toByte()
            byteBuffer[i * 2 + 1] = (clamped shr 8 and 0xFF).toByte()
        }
        try {
            raf.write(byteBuffer)
            totalDataBytes += byteBuffer.size
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write WAV data", e)
        }
    }

    /** 写 44 字节 RIFF/WAV 头（data size 用占位值）。 */
    private fun writeWavHeader(raf: RandomAccessFile) {
        val byteRate = SAMPLE_RATE * NUM_CHANNELS * BYTES_PER_SAMPLE
        val blockAlign = NUM_CHANNELS * BYTES_PER_SAMPLE

        raf.writeBytes("RIFF")
        raf.writeIntLE(0) // 文件总大小占位
        raf.writeBytes("WAVE")

        // fmt 子块
        raf.writeBytes("fmt ")
        raf.writeIntLE(16) // PCM fmt chunk size
        raf.writeShortLE(1) // PCM format
        raf.writeShortLE(NUM_CHANNELS)
        raf.writeIntLE(SAMPLE_RATE)
        raf.writeIntLE(byteRate)
        raf.writeShortLE(blockAlign)
        raf.writeShortLE(BYTES_PER_SAMPLE * 8)

        // data 子块
        raf.writeBytes("data")
        raf.writeIntLE(0) // data size 占位
    }

    /** 回填 WAV 头中的文件总大小和 data chunk 大小。 */
    private fun patchWavHeader() {
        val raf = wavFile ?: return
        try {
            // data chunk size at byte 40
            raf.seek(40)
            raf.writeIntLE(totalDataBytes)
            // RIFF chunk size at byte 4
            raf.seek(4)
            raf.writeIntLE(36 + totalDataBytes)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to patch WAV header", e)
        }
    }
    // region 录音后裁剪

    /**
     * 裁剪 WAV 文件的首尾静音。
     *
     * 以 [TRIM_RMS_THRESHOLD] 检测语音范围，前后各保留 padding，
     * 原地替换文件。全静音或时长不足 [MIN_TRIM_DURATION_MS] 则跳过。
     */
    fun trimSilence(filePath: String) {
        try {
            val range = detectSpeechRange(filePath) ?: return

            val totalDataBytes = File(filePath).length() - WAV_HEADER_SIZE
            val totalFrames = totalDataBytes / BYTES_PER_SAMPLE
            val totalDurationMs = (totalFrames.toDouble() / SAMPLE_RATE) * 1000.0

            val startMs = max(0.0, range.first - TRIM_LEADING_PADDING_MS)
            val endMs = min(range.second + TRIM_TRAILING_PADDING_MS, totalDurationMs)
            if (endMs - startMs < MIN_TRIM_DURATION_MS) return

            val startFrame = ((startMs / 1000.0) * SAMPLE_RATE).toLong()
            val endFrame = ((endMs / 1000.0) * SAMPLE_RATE).toLong()
            val safeStart = max(0, min(startFrame, totalFrames))
            val safeEnd = max(safeStart, min(endFrame, totalFrames))
            val framesToCopy = (safeEnd - safeStart).toInt()
            if (framesToCopy <= 0) return

            val sourceFile = File(filePath)
            val tempFile = File(sourceFile.parent, "${sourceFile.nameWithoutExtension}_trimmed.wav")

            RandomAccessFile(sourceFile, "r").use { src ->
                RandomAccessFile(tempFile, "rw").use { dst ->
                    writeWavHeader(dst)
                    val dataBytes = framesToCopy * BYTES_PER_SAMPLE
                    src.seek((WAV_HEADER_SIZE + safeStart * BYTES_PER_SAMPLE))
                    val chunkBytes = DETECT_CHUNK_FRAMES * BYTES_PER_SAMPLE
                    val buf = ByteArray(chunkBytes)
                    var remaining = dataBytes
                    while (remaining > 0) {
                        val toRead = min(chunkBytes, remaining)
                        val read = src.read(buf, 0, toRead)
                        if (read <= 0) break
                        dst.write(buf, 0, read)
                        remaining -= read
                    }
                    // 回填 WAV 头。
                    val writtenDataBytes = dataBytes - remaining
                    dst.seek(40)
                    dst.writeIntLE(writtenDataBytes)
                    dst.seek(4)
                    dst.writeIntLE(36 + writtenDataBytes)
                }
            }

            // 原地替换。
            tempFile.renameTo(sourceFile)
        } catch (e: Exception) {
            Log.w(TAG, "trimSilence failed, keeping original file", e)
        }
    }

    /**
     * 检测 WAV 文件中的语音起止时间（毫秒）。
     * @return (startMs, endMs) 或 null（全静音）。
     */
    private fun detectSpeechRange(filePath: String): Pair<Double, Double>? {
        var firstSpeechFrame: Long? = null
        var lastSpeechFrame: Long? = null

        RandomAccessFile(File(filePath), "r").use { raf ->
            val fileLength = raf.length()
            val dataBytes = fileLength - WAV_HEADER_SIZE
            if (dataBytes <= 0) return null

            raf.seek(WAV_HEADER_SIZE.toLong())
            val totalFrames = dataBytes / BYTES_PER_SAMPLE
            var frameOffset = 0L

            val chunkFrames = DETECT_CHUNK_FRAMES
            val buf = ShortArray(chunkFrames)
            val byteBuf = ByteArray(chunkFrames * BYTES_PER_SAMPLE)

            while (frameOffset < totalFrames) {
                val framesToRead = min(chunkFrames.toLong(), totalFrames - frameOffset).toInt()
                val bytesToRead = framesToRead * BYTES_PER_SAMPLE
                val bytesRead = raf.read(byteBuf, 0, bytesToRead)
                if (bytesRead <= 0) break
                val framesRead = bytesRead / BYTES_PER_SAMPLE

                // little-endian bytes → Short
                for (i in 0 until framesRead) {
                    val lo = byteBuf[i * 2].toInt() and 0xFF
                    val hi = byteBuf[i * 2 + 1].toInt()
                    buf[i] = ((hi shl 8) or lo).toShort()
                }

                val rms = computeRms(buf, framesRead)
                if (rms >= TRIM_RMS_THRESHOLD) {
                    if (firstSpeechFrame == null) firstSpeechFrame = frameOffset
                    lastSpeechFrame = frameOffset + framesRead
                }

                frameOffset += framesRead
            }
        }

        val first = firstSpeechFrame ?: return null
        val last = lastSpeechFrame ?: return null
        if (last <= first) return null

        return Pair(
            (first.toDouble() / SAMPLE_RATE) * 1000.0,
            (last.toDouble() / SAMPLE_RATE) * 1000.0,
        )
    }

    // endregion
}

/** 以 little-endian 写入 4 字节整数。 */
private fun RandomAccessFile.writeIntLE(value: Int) {
    write(value and 0xFF)
    write(value shr 8 and 0xFF)
    write(value shr 16 and 0xFF)
    write(value shr 24 and 0xFF)
}

/** 以 little-endian 写入 2 字节短整数。 */
private fun RandomAccessFile.writeShortLE(value: Int) {
    write(value and 0xFF)
    write(value shr 8 and 0xFF)
}
