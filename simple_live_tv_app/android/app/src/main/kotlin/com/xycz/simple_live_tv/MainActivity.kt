package com.xycz.simple_live_tv

import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var appWindowChannel: MethodChannel? = null
    private var lastWindowState: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appWindowChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_WINDOW_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "finishAndRemoveTask" -> {
                        val finishing = try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                finishAndRemoveTask()
                            } else {
                                finish()
                            }
                            isFinishing
                        } catch (_: Throwable) {
                            false
                        }
                        result.success(finishing)
                    }

                    "getWindowState" -> result.success(buildWindowState())
                    else -> result.notImplemented()
                }
            }
        }
        emitWindowState(force = true)
    }

    override fun onResume() {
        super.onResume()
        emitWindowState()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        emitWindowState()
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        emitWindowState()
    }

    override fun onMultiWindowModeChanged(
        isInMultiWindowMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        emitWindowState()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        emitWindowState()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        emitWindowState()
    }

    private fun emitWindowState(force: Boolean = false) {
        val channel = appWindowChannel ?: return
        val state = buildWindowState()
        if (!force && state == lastWindowState) {
            return
        }
        lastWindowState = state
        runOnUiThread {
            channel.invokeMethod("windowStateChanged", state)
        }
    }

    private fun buildWindowState(): Map<String, Any> {
        val inPip = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            isInPictureInPictureMode
        val inMultiWindow = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
            isInMultiWindowMode
        return mapOf(
            "inPip" to inPip,
            "inMultiWindow" to inMultiWindow,
            "isFreeform" to isFreeformWindow(inPip, inMultiWindow),
        )
    }

    private fun isFreeformWindow(inPip: Boolean, inMultiWindow: Boolean): Boolean {
        if (inPip) {
            return false
        }

        val reflectedMode = try {
            val windowConfiguration = resources.configuration.javaClass
                .getMethod("getWindowConfiguration")
                .invoke(resources.configuration)
            windowConfiguration?.javaClass
                ?.getMethod("getWindowingMode")
                ?.invoke(windowConfiguration) as? Int
        } catch (_: Throwable) {
            null
        }
        if (reflectedMode != null) {
            return reflectedMode == WINDOWING_MODE_FREEFORM
        }

        if (!inMultiWindow) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val current = windowManager.currentWindowMetrics.bounds
            val maximum = windowManager.maximumWindowMetrics.bounds
            return current.width() < maximum.width() &&
                current.height() < maximum.height()
        }
        return false
    }

    companion object {
        private const val APP_WINDOW_CHANNEL = "simple_live_tv/app_window"
        private const val WINDOWING_MODE_FREEFORM = 5
    }
}
