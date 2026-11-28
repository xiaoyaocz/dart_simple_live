package com.xycz.simple_live

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Proxy
import android.os.Build
import android.hardware.display.DisplayManager
import android.view.Display

class MainActivity: FlutterActivity() {
    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "live_online_alerts"
        private const val EXTRA_SITE_ID = "simple_live_site_id"
        private const val EXTRA_ROOM_ID = "simple_live_room_id"
        private const val REQUEST_POST_NOTIFICATIONS = 4102
    }

    private var networkChannel: MethodChannel? = null
    private var notificationChannel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var initialNotificationPayload: Map<String, String>? = null
    private var pipChannel: EventChannel? = null
    private var pipEvents: EventChannel.EventSink? = null
    private var refreshChannel: MethodChannel? = null
    private var refreshManager: DisplayManager? = null
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(id: Int) {}
        override fun onDisplayRemoved(id: Int) {}
        override fun onDisplayChanged(id: Int) {
            refreshChannel?.invokeMethod("displayChanged", null)
        }
    }
    private var proxyReceiverRegistered = false
    private val proxyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            networkChannel?.invokeMethod("proxyChanged", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialNotificationPayload = extractNotificationPayload(intent)
        ensureNotificationChannel()

        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_live/notification")
        notificationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(true)
                    } else if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingPermissionResult?.success(false)
                        pendingPermissionResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_POST_NOTIFICATIONS)
                    }
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "Simple Live"
                    val body = call.argument<String>("body") ?: ""
                    val siteId = call.argument<String>("siteId") ?: ""
                    val roomId = call.argument<String>("roomId") ?: ""
                    showLiveNotification(title, body, siteId, roomId)
                    result.success(null)
                }
                "getInitialNotification" -> {
                    result.success(initialNotificationPayload)
                    initialNotificationPayload = null
                }
                else -> result.notImplemented()
            }
        }

        pipChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_live/pip")
        pipChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                pipEvents = events
                events.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode)
            }

            override fun onCancel(arguments: Any?) {
                pipEvents = null
            }
        })
        refreshChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_live/display_refresh")
        refreshChannel?.setMethodCallHandler { call, result ->
            try {
                val screen = currentScreen()
                when (call.method) {
                    "capabilities" -> {
                        // Observe only: preferredDisplayModeId may trigger a non-seamless switch.
                        result.success(mapOf("current" to screen.refreshRate.toDouble()))
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("DISPLAY_REFRESH", "Display mode unavailable", null)
            }
        }
        refreshManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        refreshManager?.registerDisplayListener(displayListener, android.os.Handler(mainLooper))
        networkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_live/network")
        networkChannel?.setMethodCallHandler { call, result ->
            if (call.method != "getSystemProxy") {
                result.notImplemented()
            } else {
                try {
                    val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val proxy = manager.defaultProxy
                    result.success(if (proxy == null) null else mapOf(
                        "host" to proxy.host,
                        "port" to proxy.port,
                        "exclusions" to proxy.exclusionList.toList()
                    ))
                } catch (error: Exception) {
                    result.error("SYSTEM_PROXY", "Could not read system HTTP proxy", null)
                }
            }
        }
        val filter = IntentFilter(Proxy.PROXY_CHANGE_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(proxyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(proxyReceiver, filter)
        }
        proxyReceiverRegistered = true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractNotificationPayload(intent)
        if (payload != null) {
            notificationChannel?.invokeMethod("onNotificationClick", payload)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun extractNotificationPayload(intent: Intent?): Map<String, String>? {
        val siteId = intent?.getStringExtra(EXTRA_SITE_ID) ?: return null
        val roomId = intent.getStringExtra(EXTRA_ROOM_ID) ?: return null
        if (siteId.isEmpty() || roomId.isEmpty()) return null
        return mapOf("siteId" to siteId, "roomId" to roomId)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "主播开播提醒",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        manager.createNotificationChannel(channel)
    }

    @Suppress("DEPRECATION")
    private fun showLiveNotification(title: String, body: String, siteId: String, roomId: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        ensureNotificationChannel()
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_SITE_ID, siteId)
            putExtra(EXTRA_ROOM_ID, roomId)
        }
        val notificationId = ("$siteId:$roomId").hashCode() and 0x7FFFFFFF
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getActivity(this, notificationId, launchIntent, pendingFlags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
    }

    override fun onDestroy() {
        pendingPermissionResult = null
        notificationChannel?.setMethodCallHandler(null)
        notificationChannel = null
        pipEvents = null
        pipChannel?.setStreamHandler(null)
        pipChannel = null
        refreshManager?.unregisterDisplayListener(displayListener)
        refreshChannel?.setMethodCallHandler(null)
        refreshChannel = null
        if (proxyReceiverRegistered) unregisterReceiver(proxyReceiver)
        networkChannel?.setMethodCallHandler(null)
        networkChannel = null
        super.onDestroy()
    }

    override fun onPictureInPictureModeChanged(inPip: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(inPip, newConfig)
        pipEvents?.success(inPip)
    }

    @Suppress("DEPRECATION")
    private fun currentScreen(): Display =
        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null) ?: windowManager.defaultDisplay

}
