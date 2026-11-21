package com.xycz.simple_live

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
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
    private var networkChannel: MethodChannel? = null
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

    override fun onDestroy() {
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
