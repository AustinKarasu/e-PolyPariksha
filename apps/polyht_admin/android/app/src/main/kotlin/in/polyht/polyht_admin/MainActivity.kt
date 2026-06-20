package `in`.polyht.polyht_admin

import android.content.res.Configuration
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.media.AudioManager
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "polyht/exam_security"
    private var channel: MethodChannel? = null
    private var examMode = false
    private var previousMusicVolume: Int? = null
    private var previousInterruptionFilter: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterExamMode" -> {
                    examMode = true
                    applyExamMode()
                    result.success(null)
                }
                "reassertExamMode" -> {
                    if (examMode) applyExamMode()
                    result.success(null)
                }
                "exitExamMode" -> {
                    examMode = false
                    clearExamMode()
                    result.success(null)
                }
                "isInMultiWindowMode" -> result.success(isInMultiWindowOrPip())
                else -> result.notImplemented()
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!examMode) return
        applyExamMode()
        channel?.invokeMethod("windowFocusChanged", hasFocus)
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        if (examMode) {
            channel?.invokeMethod("multiWindowModeChanged", isInMultiWindowMode)
        }
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (examMode) {
            channel?.invokeMethod("multiWindowModeChanged", isInMultiWindowMode)
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        if (examMode) {
            channel?.invokeMethod("pictureInPictureModeChanged", isInPictureInPictureMode)
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (examMode) {
            channel?.invokeMethod("pictureInPictureModeChanged", isInPictureInPictureMode)
        }
    }

    @Suppress("DEPRECATION")
    private fun applyExamMode() {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        silenceDeviceForExam()
    }

    @Suppress("DEPRECATION")
    private fun clearExamMode() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        restoreDeviceAudio()
    }

    private fun silenceDeviceForExam() {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (previousMusicVolume == null) {
            previousMusicVolume = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
        }
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
        val notifications = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notifications.isNotificationPolicyAccessGranted) {
            if (previousInterruptionFilter == null) previousInterruptionFilter = notifications.currentInterruptionFilter
            notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        }
    }

    private fun restoreDeviceAudio() {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        previousMusicVolume?.let { audio.setStreamVolume(AudioManager.STREAM_MUSIC, it, 0) }
        previousMusicVolume = null
        val notifications = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notifications.isNotificationPolicyAccessGranted) {
            previousInterruptionFilter?.let { notifications.setInterruptionFilter(it) }
        }
        previousInterruptionFilter = null
    }

    private fun isInMultiWindowOrPip(): Boolean {
        val multiWindow = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) isInMultiWindowMode else false
        val pip = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) isInPictureInPictureMode else false
        return multiWindow || pip
    }
}
