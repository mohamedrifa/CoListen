package com.colisten.app

import android.app.Notification
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
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle

class CoListenMediaService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: android.net.wifi.WifiManager.WifiLock? = null
    private var mediaSession: MediaSessionCompat? = null

    private var currentTitle = "CoListen Track"
    private var currentArtist = "Synchronized Listening"
    private var isPlayingState = true
    private var currentPositionMs = 0L
    private var currentDurationMs = 0L
    private var currentSpeed = 1.0f
    private var currentThumbnailUrl: String? = null
    private var currentArtworkBitmap: android.graphics.Bitmap? = null

    companion object {
        const val CHANNEL_ID = "colisten_playback_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "ACTION_START"
        const val ACTION_UPDATE = "ACTION_UPDATE"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_PLAY = "ACTION_PLAY"
        const val ACTION_PAUSE = "ACTION_PAUSE"
        const val ACTION_NEXT = "ACTION_NEXT"
        const val ACTION_PREV = "ACTION_PREV"
        const val ACTION_NOTIFICATION_DISMISSED = "ACTION_NOTIFICATION_DISMISSED"

        const val EXTRA_TITLE = "EXTRA_TITLE"
        const val EXTRA_ARTIST = "EXTRA_ARTIST"
        const val EXTRA_IS_PLAYING = "EXTRA_IS_PLAYING"
        const val EXTRA_POSITION_MS = "EXTRA_POSITION_MS"
        const val EXTRA_DURATION_MS = "EXTRA_DURATION_MS"
        const val EXTRA_SPEED = "EXTRA_SPEED"
        const val EXTRA_THUMBNAIL_URL = "EXTRA_THUMBNAIL_URL"

        var mediaActionListener: ((action: String) -> Unit)? = null

        fun startService(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean,
            positionMs: Long = 0L,
            durationMs: Long = 0L,
            speed: Float = 1.0f,
            thumbnailUrl: String? = null
        ) {
            val intent = Intent(context, CoListenMediaService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_ARTIST, artist)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
                putExtra(EXTRA_POSITION_MS, positionMs)
                putExtra(EXTRA_DURATION_MS, durationMs)
                putExtra(EXTRA_SPEED, speed)
                putExtra(EXTRA_THUMBNAIL_URL, thumbnailUrl)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean,
            positionMs: Long = 0L,
            durationMs: Long = 0L,
            speed: Float = 1.0f,
            thumbnailUrl: String? = null
        ) {
            val intent = Intent(context, CoListenMediaService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_ARTIST, artist)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
                putExtra(EXTRA_POSITION_MS, positionMs)
                putExtra(EXTRA_DURATION_MS, durationMs)
                putExtra(EXTRA_SPEED, speed)
                putExtra(EXTRA_THUMBNAIL_URL, thumbnailUrl)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, CoListenMediaService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initMediaSession()
        acquireWakeLock()
    }

    private fun initMediaSession() {
        mediaSession = MediaSessionCompat(this, "CoListenMediaSession").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    isPlayingState = true
                    acquireWakeLock()
                    updateMediaSessionState()
                    postNotification()
                    mediaActionListener?.invoke("play")
                }

                override fun onPause() {
                    isPlayingState = false
                    updateMediaSessionState()
                    postNotification()
                    mediaActionListener?.invoke("pause")
                }

                override fun onSkipToNext() {
                    mediaActionListener?.invoke("next")
                }

                override fun onSkipToPrevious() {
                    mediaActionListener?.invoke("prev")
                }

                override fun onSeekTo(pos: Long) {
                    currentPositionMs = pos
                    updateMediaSessionState()
                    mediaActionListener?.invoke("seek:$pos")
                }

                override fun onStop() {
                    mediaActionListener?.invoke("stop_local")
                    stopForegroundPlayback()
                    stopSelf()
                }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        when (action) {
            ACTION_PLAY -> {
                isPlayingState = true
                acquireWakeLock()
                updateMediaSessionState()
                postNotification()
                mediaActionListener?.invoke("play")
            }
            ACTION_PAUSE -> {
                isPlayingState = false
                updateMediaSessionState()
                postNotification()
                mediaActionListener?.invoke("pause")
            }
            ACTION_NEXT -> {
                mediaActionListener?.invoke("next")
            }
            ACTION_PREV -> {
                mediaActionListener?.invoke("prev")
            }
            ACTION_NOTIFICATION_DISMISSED -> {
                mediaActionListener?.invoke("stop_local")
                stopForegroundPlayback()
                stopSelf()
            }
            ACTION_START, ACTION_UPDATE -> {
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                currentArtist = intent.getStringExtra(EXTRA_ARTIST) ?: currentArtist
                isPlayingState = intent.getBooleanExtra(EXTRA_IS_PLAYING, isPlayingState)
                
                val pos = intent.getLongExtra(EXTRA_POSITION_MS, -1L)
                if (pos >= 0L) {
                    currentPositionMs = pos
                }
                val dur = intent.getLongExtra(EXTRA_DURATION_MS, 0L)
                if (dur > 0L) {
                    currentDurationMs = dur
                }
                currentSpeed = intent.getFloatExtra(EXTRA_SPEED, currentSpeed)

                val thumb = intent.getStringExtra(EXTRA_THUMBNAIL_URL)
                if (!thumb.isNullOrEmpty() && thumb != currentThumbnailUrl) {
                    currentThumbnailUrl = thumb
                    loadArtworkBitmap(thumb)
                }

                updateMediaSessionState()

                if (isPlayingState) {
                    acquireWakeLock()
                }

                postNotification()
            }
            ACTION_STOP -> {
                mediaActionListener?.invoke("stop_local")
                stopForegroundPlayback()
                stopSelf()
            }
        }

        return START_STICKY
    }

    private fun postNotification() {
        val notification = buildNotification(currentTitle, currentArtist, isPlayingState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateMediaSessionState() {
        val state = if (isPlayingState) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }

        val playbackSpeed = if (isPlayingState) currentSpeed else 0.0f

        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_STOP
            )
            .setState(
                state,
                currentPositionMs,
                playbackSpeed,
                android.os.SystemClock.elapsedRealtime()
            )
            .build()

        mediaSession?.setPlaybackState(playbackState)

        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "CoListen Room")
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, currentTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, currentArtist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDurationMs).apply {
                currentArtworkBitmap?.let { bmp ->
                    putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bmp)
                    putBitmap(MediaMetadataCompat.METADATA_KEY_ART, bmp)
                }
            }
            .build()

        mediaSession?.setMetadata(metadata)
    }

    private fun loadArtworkBitmap(urlStr: String) {
        Thread {
            try {
                val url = java.net.URL(urlStr)
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.doInput = true
                connection.connectTimeout = 4000
                connection.readTimeout = 4000
                connection.connect()
                val input = connection.inputStream
                val bitmap = android.graphics.BitmapFactory.decodeStream(input)
                if (bitmap != null) {
                    currentArtworkBitmap = bitmap
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        updateMediaSessionState()
                        postNotification()
                    }
                }
            } catch (_: Exception) {}
        }.start()
    }

    private fun buildNotification(title: String, artist: String, isPlaying: Boolean): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Previous Track Action PendingIntent
        val prevIntent = Intent(this, CoListenMediaService::class.java).apply {
            this.action = ACTION_PREV
        }
        val prevPendingIntent = PendingIntent.getService(
            this,
            3,
            prevIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Play / Pause Action PendingIntent
        val playPauseIntent = Intent(this, CoListenMediaService::class.java).apply {
            this.action = if (isPlaying) ACTION_PAUSE else ACTION_PLAY
        }
        val playPausePendingIntent = PendingIntent.getService(
            this,
            1,
            playPauseIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Skip / Next Track Action PendingIntent
        val nextIntent = Intent(this, CoListenMediaService::class.java).apply {
            this.action = ACTION_NEXT
        }
        val nextPendingIntent = PendingIntent.getService(
            this,
            2,
            nextIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Notification Swiped Away / Dismissed PendingIntent
        val deleteIntent = Intent(this, CoListenMediaService::class.java).apply {
            this.action = ACTION_NOTIFICATION_DISMISSED
        }
        val deletePendingIntent = PendingIntent.getService(
            this,
            4,
            deleteIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val playPauseIcon = if (isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val playPauseTitle = if (isPlaying) "Pause" else "Play"

        val style = MediaStyle()
            .setShowActionsInCompactView(0, 1, 2)
            .setShowCancelButton(true)
            .setCancelButtonIntent(deletePendingIntent)

        mediaSession?.sessionToken?.let { token ->
            style.setMediaSession(token)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(artist)
            .setSubText("CoListen")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(contentPendingIntent)
            .setDeleteIntent(deletePendingIntent)
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevPendingIntent)
            .addAction(playPauseIcon, playPauseTitle, playPausePendingIntent)
            .addAction(android.R.drawable.ic_media_next, "Next", nextPendingIntent)
            .setStyle(style)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        currentArtworkBitmap?.let { bmp ->
            builder.setLargeIcon(bmp)
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CoListen Music Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows synchronized room playback and media controls"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "CoListen::BackgroundPlaybackWakeLock"
            )?.apply {
                setReferenceCounted(false)
                acquire(60 * 60 * 1000L /* 60 minutes continuous locked playback */)
            }
        }
        if (wifiLock == null) {
            try {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                @Suppress("DEPRECATION")
                wifiLock = wifiManager?.createWifiLock(
                    android.net.wifi.WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                    "CoListen::WifiLock"
                )?.apply {
                    setReferenceCounted(false)
                    acquire()
                }
            } catch (_: Exception) {}
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        wakeLock = null

        try {
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
            }
        } catch (_: Exception) {}
        wifiLock = null
    }

    private fun stopForegroundPlayback() {
        releaseWakeLock()
        mediaSession?.isActive = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        stopForegroundPlayback()
        mediaSession?.release()
        mediaSession = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
