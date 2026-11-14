package com.xycz.simple_live

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle

class BackgroundPlaybackService : Service() {

    private lateinit var notificationManager: NotificationManager
    private var mediaSession: MediaSessionCompat? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private lateinit var audioManager: AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null
    private var focusRequested = false

    /// 关闭后不再向系统申请音频焦点，可与其它应用同时出声。
    private var requestAudioFocusEnabled = true

    private var currentState = STATE_PLAYING
    private var currentTitle = ""
    private var currentSubtitle = ""

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        // 用户选择了“与其他应用同时播放”时忽略焦点回调，不暂停、不闪避。
        if (requestAudioFocusEnabled) {
            emit(EVENT_AUDIO_FOCUS, mapOf("state" to focusStateOf(change)))
        }
    }

    private fun focusStateOf(change: Int): String = when (change) {
        AudioManager.AUDIOFOCUS_GAIN -> "gain"
        AudioManager.AUDIOFOCUS_LOSS -> "loss"
        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> "loss_transient"
        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> "can_duck"
        else -> "unknown"
    }

    private val sessionCallback = object : MediaSessionCompat.Callback() {
        override fun onPlay() {
            emit(EVENT_MEDIA_BUTTON, mapOf("action" to "play"))
        }

        override fun onPause() {
            emit(EVENT_MEDIA_BUTTON, mapOf("action" to "pause"))
        }

        override fun onStop() {
            emit(EVENT_MEDIA_BUTTON, mapOf("action" to "stop"))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(NotificationManager::class.java)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
        createMediaSession()
        acquireWifiLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            it.getStringExtra(EXTRA_MEDIA_ACTION)?.let { action ->
                emit(EVENT_MEDIA_BUTTON, mapOf("action" to action))
            }
            applyExtras(it)
        }
        promoteToForeground(buildNotification())
        applyAudioFocusPolicy()
        return START_NOT_STICKY
    }

    private fun applyExtras(intent: Intent) {
        intent.getStringExtra(EXTRA_STATE)?.let { currentState = it }
        intent.getStringExtra(EXTRA_TITLE)?.let { currentTitle = it }
        intent.getStringExtra(EXTRA_SUBTITLE)?.let { currentSubtitle = it }
        if (intent.hasExtra(EXTRA_REQUEST_AUDIO_FOCUS)) {
            requestAudioFocusEnabled =
                intent.getBooleanExtra(EXTRA_REQUEST_AUDIO_FOCUS, true)
        }
        updateMediaSession()
    }

    private fun promoteToForeground(notification: android.app.Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            // ForegroundServiceStartNotAllowedException (API 31) or other
            // platform rejections. Keep the service running as long as the
            // system allows; Dart side logs the degraded state.
            Log.w(TAG, "startForeground failed: ${t.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "后台播放",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "直播后台播放保活"
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun createMediaSession() {
        if (mediaSession != null) {
            return
        }
        mediaSession = MediaSessionCompat(this, "SimpleLiveBackground").apply {
            setCallback(sessionCallback, Handler(Looper.getMainLooper()))
            setSessionActivity(buildContentPendingIntent())
            isActive = true
        }
    }

    private fun acquireWifiLock() {
        try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifiLock = wifiManager.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                "simple_live:background_playback",
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "acquireWifiLock failed: ${t.message}")
        }
    }

    private fun applyAudioFocusPolicy() {
        if (requestAudioFocusEnabled) {
            requestAudioFocus()
        } else {
            abandonAudioFocus()
        }
    }

    private fun requestAudioFocus() {
        if (focusRequested) {
            return
        }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(attributes)
                    .setWillPauseWhenDucked(false)
                    .setOnAudioFocusChangeListener(focusListener)
                    .build()
                audioFocusRequest = request
                audioManager.requestAudioFocus(request)
            } else {
                @Suppress("DEPRECATION")
                audioManager.requestAudioFocus(
                    focusListener,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN,
                )
            }
            focusRequested = true
        } catch (t: Throwable) {
            Log.w(TAG, "requestAudioFocus failed: ${t.message}")
        }
    }

    private fun abandonAudioFocus() {
        if (!focusRequested) {
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(focusListener)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "abandonAudioFocus failed: ${t.message}")
        }
        audioFocusRequest = null
        focusRequested = false
    }

    private fun updateMediaSession() {
        val session = mediaSession ?: return
        val playbackState = when (currentState) {
            STATE_PLAYING -> PlaybackStateCompat.STATE_PLAYING
            STATE_RECONNECTING -> PlaybackStateCompat.STATE_BUFFERING
            STATE_PAUSED -> PlaybackStateCompat.STATE_PAUSED
            else -> PlaybackStateCompat.STATE_PLAYING
        }
        val actions = PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_STOP or
            PlaybackStateCompat.ACTION_PLAY_PAUSE
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(actions)
                .setState(playbackState, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1f)
                .build(),
        )
        val title = currentTitle.ifBlank { "Simple Live" }
        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(
                    MediaMetadataCompat.METADATA_KEY_ARTIST,
                    currentSubtitle.ifBlank { stateText() },
                )
                .build(),
        )
        session.isActive = true
    }

    private fun buildNotification(): android.app.Notification {
        val session = mediaSession
        val title = currentTitle.ifBlank { "Simple Live" }
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(stateText())
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(buildContentPendingIntent())
        if (session != null) {
            if (currentState == STATE_PAUSED) {
                builder.addAction(
                    android.R.drawable.ic_media_play,
                    "播放",
                    buildMediaActionIntent("play"),
                )
            } else {
                builder.addAction(
                    android.R.drawable.ic_media_pause,
                    "暂停",
                    buildMediaActionIntent("pause"),
                )
            }
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "停止",
                buildMediaActionIntent("stop"),
            )
            builder.setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0)
                    .setCancelButtonIntent(buildMediaActionIntent("stop")),
            )
        }
        return builder.build()
    }

    private fun stateText(): String = when (currentState) {
        STATE_PLAYING -> "正在后台播放直播"
        STATE_RECONNECTING -> "直播中断，正在重新连接…"
        STATE_PAUSED -> "已暂停"
        else -> "正在后台播放直播"
    }

    private fun buildContentPendingIntent(): PendingIntent {
        return PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildMediaActionIntent(action: String): PendingIntent {
        val intent = Intent(this, BackgroundPlaybackService::class.java).apply {
            putExtra(EXTRA_MEDIA_ACTION, action)
        }
        return PendingIntent.getService(
            this,
            mediaActionRequestCode(action),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun mediaActionRequestCode(action: String): Int = when (action) {
        "play" -> REQUEST_CODE_PLAY
        "pause" -> REQUEST_CODE_PAUSE
        "stop" -> REQUEST_CODE_STOP
        else -> 0
    }

    private fun emit(event: String, payload: Map<String, Any> = emptyMap()) {
        eventListener?.invoke(event, payload)
    }

    override fun onDestroy() {
        abandonAudioFocus()
        try {
            wifiLock?.let { if (it.isHeld) it.release() }
        } catch (_: Throwable) {
        }
        wifiLock = null
        mediaSession?.run {
            isActive = false
            release()
        }
        mediaSession = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "BackgroundPlayback"

        const val STATE_PLAYING = "playing"
        const val STATE_RECONNECTING = "reconnecting"
        const val STATE_PAUSED = "paused"

        const val EXTRA_STATE = "state"
        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_MEDIA_ACTION = "media_action"
        const val EXTRA_REQUEST_AUDIO_FOCUS = "requestAudioFocus"

        const val EVENT_MEDIA_BUTTON = "mediaButton"
        const val EVENT_AUDIO_FOCUS = "audioFocus"

        private const val CHANNEL_ID = "simple_live_background_playback"
        private const val NOTIFICATION_ID = 1001

        private const val REQUEST_CODE_PLAY = 11
        private const val REQUEST_CODE_PAUSE = 12
        private const val REQUEST_CODE_STOP = 13

        /// Native -> Flutter bridge. Set by MainActivity.
        @JvmStatic
        var eventListener: ((String, Map<String, Any>) -> Unit)? = null
    }
}
