package app.echoloop

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

/**
 * Android 语音练习平台桥接。
 *
 * 通过 MethodChannel/EventChannel 与 Dart 侧通信，
 * 使用 AudioRecord（WAV 录音 + VAD）实现
 * 与 iOS 侧 IOSSpeechPracticeHandler 相同的协议。
 *
 * 语音识别由 Dart 侧的离线 ASR 引擎（sherpa-onnx）负责，
 * 原生层仅负责录音和 VAD。
 */
class AndroidSpeechPracticeHandler(
    private val activity: Activity,
    binaryMessenger: io.flutter.plugin.common.BinaryMessenger,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {

    private val methodChannel = MethodChannel(binaryMessenger, "top.echo-loop/speech_practice")
    private val eventChannel = EventChannel(binaryMessenger, "top.echo-loop/speech_practice/events")
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null

    // 引擎级资源（warmup 创建，shutdown 释放）
    private val wavRecorder = WavRecorder()
    private var isEngineReady = false

    // 句子级状态
    private var isRecording = false
    private var currentPromptId: String? = null
    private var currentFilePath: String? = null
    private var sessionGeneration = 0
    private var finalTranscriptEmitted = false

    // VAD 状态
    private var hasDetectedSpeech = false
    private var silenceStartAt: Long = 0L
    private var lastReportedSilenceMs = -1
    private var recordedDurationMs: Double = 0.0
    private var firstDetectedSpeechMs: Double? = null
    private var lastDetectedSpeechMs: Double? = null

    // 权限请求回调
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val TAG = "SpeechPractice"
        private const val PERMISSION_REQUEST_CODE = 9001
        private const val RMS_THRESHOLD = 0.015f
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        wavRecorder.onBuffer = { rms, frameCount -> handleVoiceActivity(rms, frameCount) }
    }

    // region StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // endregion

    // region MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> result.success(permissionMap())
            "requestPermissions" -> requestPermissions(result)
            "warmup" -> warmup(result)
            "startSession" -> startSession(call, result)
            "stopSession" -> stopSession(result)
            "cancelSession" -> cancelSession(result)
            "shutdown" -> shutdown(result)
            "deleteRecording" -> deleteRecording(call, result)
            "getDeviceInfo" -> {
                val runtime = Runtime.getRuntime()
                val memInfo = android.app.ActivityManager.MemoryInfo()
                (activity.getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager)
                    .getMemoryInfo(memInfo)
                result.success(mapOf("ramBytes" to memInfo.totalMem))
            }
            "setRecognitionEnabled" -> result.success(emptyMap<String, Any>()) // Android 纯录音，ASR 由 Dart 层处理
            else -> result.notImplemented()
        }
    }

    // endregion

    // region 权限

    private fun permissionMap(): Map<String, String> {
        val status = microphonePermissionStatus()
        // Android 只有 RECORD_AUDIO 一个权限，两个字段返回相同值。
        return mapOf("microphoneStatus" to status, "speechStatus" to status)
    }

    private fun microphonePermissionStatus(): String {
        return when {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED -> "granted"
            ActivityCompat.shouldShowRequestPermissionRationale(
                activity, Manifest.permission.RECORD_AUDIO
            ) -> "denied"
            else -> "notDetermined"
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(permissionMap())
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        pendingPermissionResult?.success(permissionMap())
        pendingPermissionResult = null
        return true
    }

    // endregion

    // region warmup / shutdown

    private fun warmup(result: MethodChannel.Result) {
        if (isEngineReady) {
            result.success(emptyMap<String, Any>())
            return
        }

        // AudioRecord 需要权限，若未授予则延迟到 startSession 再初始化。
        if (microphonePermissionStatus() == "granted") {
            initWavRecorder()
        }

        isEngineReady = true
        result.success(emptyMap<String, Any>())
    }

    private fun shutdown(result: MethodChannel.Result) {
        isRecording = false
        cleanupSentenceState()
        cleanupEngine()
        result.success(emptyMap<String, Any>())
    }

    private fun initWavRecorder() {
        if (!wavRecorder.isInitialized) {
            val ok = wavRecorder.initialize()
            if (!ok) Log.w(TAG, "WavRecorder initialization failed")
        }
        // release() 会清空 onBuffer，重新初始化后必须恢复。
        wavRecorder.onBuffer = { rms, frameCount -> handleVoiceActivity(rms, frameCount) }
    }

    private fun cleanupEngine() {
        wavRecorder.release()
        isEngineReady = false
        isRecording = false
    }

    // endregion

    // region startSession / stopSession / cancelSession

    private fun startSession(call: MethodCall, result: MethodChannel.Result) {
        val promptId = call.argument<String>("promptId")
        if (promptId.isNullOrEmpty()) {
            result.error("invalidArguments", "Missing promptId", null)
            return
        }
        val locale = call.argument<String>("locale") ?: "en-US"

        if (!isEngineReady) {
            warmup(object : MethodChannel.Result {
                override fun success(r: Any?) {
                    doStartSession(promptId, result)
                }
                override fun error(code: String, msg: String?, details: Any?) {
                    result.error(code, msg, details)
                }
                override fun notImplemented() {}
            })
            return
        }

        doStartSession(promptId, result)
    }

    private fun doStartSession(promptId: String, result: MethodChannel.Result) {
        wavRecorder.resetCaptureDiagnostics()
        cleanupSentenceState()
        resetSentenceState(promptId)

        val fileName = sanitizeFileName(promptId)
        val file = File(activity.cacheDir, "$fileName-${System.currentTimeMillis()}.wav")
        currentFilePath = file.absolutePath

        // 延迟初始化 AudioRecord（权限可能在 warmup 之后才授予）。
        if (!wavRecorder.isInitialized) initWavRecorder()
        if (wavRecorder.isInitialized) {
            wavRecorder.startRecording(file.absolutePath)
        }

        isRecording = true
        result.success(mapOf("filePath" to file.absolutePath))
    }

    private fun stopSession(result: MethodChannel.Result) {
        isRecording = false
        val promptId = currentPromptId ?: ""

        val filePath = if (wavRecorder.isInitialized) {
            wavRecorder.stopRecording()
        } else {
            currentFilePath
        }

        val wavBeforeTrim = filePath?.let(wavRecorder::wavFileMetrics)

        // 裁剪首尾静音（对齐 iOS/macOS）。
        if (!filePath.isNullOrEmpty()) {
            wavRecorder.trimSilence(filePath)
        }
        val wavAfterTrim = filePath?.let(wavRecorder::wavFileMetrics)
        val diagnostics = buildString {
            append(wavRecorder.captureDiagnostics())
            append(" wavBeforeTrim=$wavBeforeTrim")
            append(" wavAfterTrim=$wavAfterTrim")
        }

        // 确保 Dart 侧总能收到 finalTranscriptReady，避免等超时。
        if (!finalTranscriptEmitted) {
            finalTranscriptEmitted = true
            emitEvent(mapOf(
                "type" to "finalTranscriptReady",
                "promptId" to promptId,
                "transcript" to "",
            ))
        }

        result.success(
            mapOf(
                "filePath" to (filePath ?: ""),
                "diagnostics" to diagnostics,
            ),
        )
    }

    private fun cancelSession(result: MethodChannel.Result) {
        isRecording = false
        cleanupSentenceState()
        result.success(emptyMap<String, Any>())
    }

    // endregion

    // region deleteRecording

    private fun deleteRecording(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (!filePath.isNullOrEmpty()) {
            try { File(filePath).delete() } catch (_: Exception) {}
        }
        if (currentFilePath == filePath) {
            currentFilePath = null
        }
        result.success(emptyMap<String, Any>())
    }

    // endregion

    // region VAD

    /** 在 IO 线程被 WavRecorder 调用，处理 VAD 逻辑并发事件到主线程。 */
    private fun handleVoiceActivity(rms: Float, frameCount: Int) {
        if (!isRecording) return
        val promptId = currentPromptId ?: return

        val bufferDurationMs = (frameCount.toDouble() / 16000.0) * 1000.0
        val bufferStartMs = recordedDurationMs
        val bufferEndMs = bufferStartMs + bufferDurationMs

        if (rms >= RMS_THRESHOLD) {
            if (!hasDetectedSpeech) {
                hasDetectedSpeech = true
                emitEvent(mapOf("type" to "speechStarted", "promptId" to promptId))
            }
            if (firstDetectedSpeechMs == null) firstDetectedSpeechMs = bufferStartMs
            lastDetectedSpeechMs = bufferEndMs

            if (silenceStartAt > 0 || lastReportedSilenceMs > 0) {
                emitEvent(mapOf(
                    "type" to "silenceProgress",
                    "promptId" to promptId,
                    "silenceMs" to 0,
                ))
            }
            silenceStartAt = 0L
            lastReportedSilenceMs = 0
            recordedDurationMs = bufferEndMs
            return
        }

        recordedDurationMs = bufferEndMs
        if (!hasDetectedSpeech) return

        val now = System.currentTimeMillis()
        if (silenceStartAt == 0L) silenceStartAt = now
        val silenceMs = (now - silenceStartAt).toInt()
        if (silenceMs == 0 || silenceMs - lastReportedSilenceMs >= 200) {
            lastReportedSilenceMs = silenceMs
            emitEvent(mapOf(
                "type" to "silenceProgress",
                "promptId" to promptId,
                "silenceMs" to silenceMs,
            ))
        }
    }

    // endregion

    // region 内部工具

    private fun resetSentenceState(promptId: String) {
        sessionGeneration++
        currentPromptId = promptId
        currentFilePath = null
        finalTranscriptEmitted = false
        hasDetectedSpeech = false
        silenceStartAt = 0L
        lastReportedSilenceMs = -1
        recordedDurationMs = 0.0
        firstDetectedSpeechMs = null
        lastDetectedSpeechMs = null
    }

    private fun cleanupSentenceState() {
        if (wavRecorder.isInitialized) {
            try { wavRecorder.stopRecording() } catch (_: Exception) {}
        }
        currentPromptId = null
        hasDetectedSpeech = false
        silenceStartAt = 0L
        lastReportedSilenceMs = -1
        finalTranscriptEmitted = false
        recordedDurationMs = 0.0
        firstDetectedSpeechMs = null
        lastDetectedSpeechMs = null
    }

    private fun emitEvent(event: Map<String, Any>) {
        mainHandler.post { eventSink?.success(event) }
    }

    private fun sanitizeFileName(promptId: String): String {
        return promptId.replace(Regex("[^a-zA-Z0-9\\-_]"), "-")
    }

    // endregion

    /** 页面退出时由 MainActivity 调用。 */
    fun dispose() {
        isRecording = false
        cleanupSentenceState()
        cleanupEngine()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
