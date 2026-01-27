package com.example.territory_fitness

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "territory_fitness/pip"
    private var isInPipMode = false
    private var methodChannel: MethodChannel? = null
    private var isPipEnabledForCurrentScreen = false
    private var currentScreen = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPipMode" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(9, 16))
                            .build()
                        val success = enterPictureInPictureMode(params)
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                "isPipSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                   packageManager.hasSystemFeature("android.software.picture_in_picture")
                    result.success(supported)
                }
                "isInPipMode" -> {
                    result.success(isInPipMode)
                }
                "enablePipForScreen" -> {
                    // Only enable auto-enter for specific screens
                    val screenName = call.arguments as? String ?: ""
                    currentScreen = screenName
                    // Only enable auto-enter PiP for map screen
                    isPipEnabledForCurrentScreen = screenName == "map"
                    result.success(true)
                }
                "disablePip" -> {
                    isPipEnabledForCurrentScreen = false
                    currentScreen = ""
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isInPipMode = isInPictureInPictureMode

        // Notify Flutter about PiP state change
        methodChannel?.invokeMethod("onPipModeChanged", mapOf(
            "isInPip" to isInPictureInPictureMode,
            "screen" to currentScreen
        ))
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Only auto-enter PiP if explicitly enabled for current screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPipEnabledForCurrentScreen) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(9, 16))
                .build()
            enterPictureInPictureMode(params)
        }
    }
}
