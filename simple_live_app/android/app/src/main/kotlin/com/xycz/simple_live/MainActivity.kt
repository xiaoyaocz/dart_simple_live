package com.xycz.simple_live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "simple_live/background_playback",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startService()
                    result.success(null)
                }

                "stop" -> {
                    stopService(Intent(this, BackgroundPlaybackService::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "simple_live/live_notifications",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showLiveStart" -> {
                    showLiveStartNotification(
                        notificationId = call.argument<Int>("notificationId") ?: 1002,
                        title = call.argument<String>("title") ?: "特别关注开播了",
                        body = call.argument<String>("body") ?: "点击回到 Simple Live",
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
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
            "isFreeform" to isFreeformWindow(inPip),
        )
    }

    private fun isFreeformWindow(inPip: Boolean): Boolean {
        if (inPip) {
            return false
        }

        // Configuration.windowConfiguration is hidden from the public SDK, but
        // OEMs that implement freeform windows expose its standard getter.
        // Use it when available and retain a public-API bounds fallback below.
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
        if (reflectedMode == WINDOWING_MODE_FREEFORM) {
            // WindowConfiguration.WINDOWING_MODE_FREEFORM is 5.
            return true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val current = windowManager.currentWindowMetrics.bounds
            val maximum = windowManager.maximumWindowMetrics.bounds
            // Some OEM "small window" implementations do not expose the
            // standard freeform mode (and occasionally do not set
            // isInMultiWindowMode), but their task is constrained on both
            // axes. Keep the threshold below normal system-bar/cutout insets
            // while recognising a genuinely floating task.
            val constrainedOnBothAxes =
                current.width() * 100 < maximum.width() * 95 &&
                    current.height() * 100 < maximum.height() * 95
            return constrainedOnBothAxes
        }
        return false
    }

    private fun startService() {
        val intent = Intent(this, BackgroundPlaybackService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun showLiveStartNotification(notificationId: Int, title: String, body: String) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        createLiveStartNotificationChannel(manager)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, LIVE_START_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    notificationId,
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .build()
        manager.notify(notificationId, notification)
    }

    private fun createLiveStartNotificationChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            LIVE_START_CHANNEL_ID,
            "开播提醒",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        channel.description = "特别关注主播开播提醒"
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val APP_WINDOW_CHANNEL = "simple_live/app_window"
        private const val LIVE_START_CHANNEL_ID = "simple_live_live_start"
        private const val WINDOWING_MODE_FREEFORM = 5
    }
}
