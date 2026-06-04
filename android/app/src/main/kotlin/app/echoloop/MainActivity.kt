package app.echoloop

import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var googleServicesChannel: MethodChannel? = null
    private var speechPracticeHandler: AndroidSpeechPracticeHandler? = null
    private var audioDecodeHandler: AndroidAudioDecodeHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i("AuthGMS", "register google services availability channel")
        googleServicesChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "top.echo-loop/google_services",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGooglePlayServicesAvailable" -> result.success(isGooglePlayServicesAvailable())
                    else -> result.notImplemented()
                }
            }
        }
        speechPracticeHandler = AndroidSpeechPracticeHandler(
            this, flutterEngine.dartExecutor.binaryMessenger,
        )
        audioDecodeHandler = AndroidAudioDecodeHandler(
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        googleServicesChannel?.setMethodCallHandler(null)
        googleServicesChannel = null
        speechPracticeHandler?.dispose()
        speechPracticeHandler = null
        audioDecodeHandler?.dispose()
        audioDecodeHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        speechPracticeHandler?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun isGooglePlayServicesAvailable(): Boolean {
        val status = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this)
        val available = status == ConnectionResult.SUCCESS
        Log.i("AuthGMS", "Google Play services status=${statusName(status)}($status) available=$available")
        return available
    }

    private fun statusName(status: Int): String {
        return when (status) {
            ConnectionResult.SUCCESS -> "SUCCESS"
            ConnectionResult.SERVICE_MISSING -> "SERVICE_MISSING"
            ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED -> "SERVICE_VERSION_UPDATE_REQUIRED"
            ConnectionResult.SERVICE_DISABLED -> "SERVICE_DISABLED"
            ConnectionResult.SERVICE_INVALID -> "SERVICE_INVALID"
            else -> "UNKNOWN"
        }
    }
}
