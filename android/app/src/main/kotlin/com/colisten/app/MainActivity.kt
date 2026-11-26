package com.colisten.app

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Rect
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Rational
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "colisten/media_service"
    private var channel: MethodChannel? = null
    private var isPlaying = false
    private var isActivityPaused = false
    private var isReceiverRegistered = false
    private var isScreenReceiverRegistered = false

    private val mediaKeepAliveHandler = Handler(Looper.getMainLooper())
    private val keepAliveRunnable = object : Runnable {
        override fun run() {
            if (isPlaying && isActivityPaused) {
                keepMediaAlive()
                mediaKeepAliveHandler.postDelayed(this, 1500)
            }
        }
    }

    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra("action") ?: return
            when (action) {
                "play" -> {
                    isPlaying = true
                    if (isActivityPaused) startKeepAliveLoop()
                    updatePipParams()
                    channel?.invokeMethod("onNotificationAction", "play")
                }
                "pause" -> {
                    isPlaying = false
                    stopKeepAliveLoop()
                    updatePipParams()
                    channel?.invokeMethod("onNotificationAction", "pause")
                }
                "next" -> {
                    channel?.invokeMethod("onNotificationAction", "next")
                }
                "prev" -> {
                    channel?.invokeMethod("onNotificationAction", "prev")
                }
            }
        }
    }

    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            if (action == Intent.ACTION_SCREEN_OFF) {
                if (isPlaying) {
                    startKeepAliveLoop()
                    keepMediaAlive()
                }
            } else if (action == Intent.ACTION_SCREEN_ON) {
                if (!isActivityPaused) {
                    stopKeepAliveLoop()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermission()

        if (!isScreenReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            registerReceiver(screenStateReceiver, filter)
            isScreenReceiverRegistered = true
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1010)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val mChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = mChannel

        if (!isReceiverRegistered) {
            val filter = IntentFilter("com.colisten.app.PIP_ACTION")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(pipActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(pipActionReceiver, filter)
            }
            isReceiverRegistered = true
        }

        CoListenMediaService.mediaActionListener = { action ->
            runOnUiThread {
                if (action == "play") {
                    isPlaying = true
                    startKeepAliveLoop()
                    updatePipParams()
                } else if (action == "pause" || action == "stop_local") {
                    isPlaying = false
                    stopKeepAliveLoop()
                    updatePipParams()
                }
                channel?.invokeMethod("onNotificationAction", action)
            }
        }

        mChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundPlayback" -> {
                    requestNotificationPermission()
                    val title = call.argument<String>("title") ?: "CoListen Track"
                    val artist = call.argument<String>("artist") ?: "Synchronized Listening"
                    val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    val durationMs = (call.argument<Number>("durationMs"))?.toLong() ?: 0L
                    val speed = (call.argument<Number>("speed"))?.toFloat() ?: 1.0f
                    isPlaying = call.argument<Boolean>("isPlaying") ?: true
                    if (isPlaying && isActivityPaused) {
                        startKeepAliveLoop()
                    } else {
                        stopKeepAliveLoop()
                    }
                    updatePipParams()
                    CoListenMediaService.startService(this, title, artist, isPlaying, positionMs, durationMs, speed)
                    result.success(true)
                }
                "updatePlaybackState" -> {
                    val title = call.argument<String>("title") ?: "CoListen Track"
                    val artist = call.argument<String>("artist") ?: "Synchronized Listening"
                    val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    val durationMs = (call.argument<Number>("durationMs"))?.toLong() ?: 0L
                    val speed = (call.argument<Number>("speed"))?.toFloat() ?: 1.0f
                    isPlaying = call.argument<Boolean>("isPlaying") ?: true
                    if (isPlaying && isActivityPaused) {
                        startKeepAliveLoop()
                    } else {
                        stopKeepAliveLoop()
                    }
                    updatePipParams()
                    CoListenMediaService.update(this, title, artist, isPlaying, positionMs, durationMs, speed)
                    result.success(true)
                }
                "stopForegroundPlayback" -> {
                    isPlaying = false
                    stopKeepAliveLoop()
                    updatePipParams()
                    CoListenMediaService.stopService(this)
                    result.success(true)
                }
                "isPipMode" -> {
                    val inPip = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        isInPictureInPictureMode
                    } else false
                    result.success(inPip)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startKeepAliveLoop() {
        stopKeepAliveLoop()
        mediaKeepAliveHandler.post(keepAliveRunnable)
    }

    private fun stopKeepAliveLoop() {
        mediaKeepAliveHandler.removeCallbacks(keepAliveRunnable)
    }

    private fun findWebView(view: View?): WebView? {
        if (view == null) return null
        if (view is WebView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findWebView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun buildPipParams(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val actions = ArrayList<RemoteAction>()

                // 1. Previous Track Action
                val prevIntent = Intent("com.colisten.app.PIP_ACTION").apply {
                    setPackage(packageName)
                    putExtra("action", "prev")
                }
                val prevPendingIntent = PendingIntent.getBroadcast(
                    this,
                    101,
                    prevIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                actions.add(
                    RemoteAction(
                        Icon.createWithResource(this, android.R.drawable.ic_media_previous),
                        "Previous",
                        "Previous",
                        prevPendingIntent
                    )
                )

                // 2. Play / Pause Action
                val playPauseIntent = Intent("com.colisten.app.PIP_ACTION").apply {
                    setPackage(packageName)
                    putExtra("action", if (isPlaying) "pause" else "play")
                }
                val playPausePendingIntent = PendingIntent.getBroadcast(
                    this,
                    102,
                    playPauseIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                val iconRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
                val label = if (isPlaying) "Pause" else "Play"
                actions.add(
                    RemoteAction(
                        Icon.createWithResource(this, iconRes),
                        label,
                        label,
                        playPausePendingIntent
                    )
                )

                // 3. Next Track Action
                val nextIntent = Intent("com.colisten.app.PIP_ACTION").apply {
                    setPackage(packageName)
                    putExtra("action", "next")
                }
                val nextPendingIntent = PendingIntent.getBroadcast(
                    this,
                    103,
                    nextIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                actions.add(
                    RemoteAction(
                        Icon.createWithResource(this, android.R.drawable.ic_media_next),
                        "Next",
                        "Next",
                        nextPendingIntent
                    )
                )

                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .setActions(actions)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    builder.setAutoEnterEnabled(true)
                }

                // Focus PiP transition animation on the video view if visible
                findWebView(window.decorView)?.let { wv ->
                    val rect = Rect()
                    wv.getGlobalVisibleRect(rect)
                    if (!rect.isEmpty && rect.width() > 100 && rect.height() > 100) {
                        builder.setSourceRectHint(rect)
                    }
                }

                return builder.build()
            } catch (_: Exception) {}
        }
        return null
    }

    private fun updatePipParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val params = buildPipParams() ?: return
                setPictureInPictureParams(params)
            } catch (_: Exception) {}
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val params = buildPipParams()
                if (params != null) {
                    enterPictureInPictureMode(params)
                }
            } catch (_: Exception) {}
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        runOnUiThread {
            channel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
        }
    }

    override fun finish() {
        // When user swipes away / closes the floating PiP window, move task to background
        // instead of destroying MainActivity, so audio playback continues uninterrupted in background!
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) {
            moveTaskToBack(true)
            if (isPlaying) {
                isActivityPaused = true
                startKeepAliveLoop()
                keepMediaAlive()
                mediaKeepAliveHandler.postDelayed({
                    if (isPlaying) {
                        keepMediaAlive()
                        findWebView(window.decorView)?.evaluateJavascript(
                            "if (typeof player !== 'undefined' && !window._intentionalPause) { player.playVideo(); }",
                            null
                        )
                    }
                }, 150)
                mediaKeepAliveHandler.postDelayed({
                    if (isPlaying) {
                        keepMediaAlive()
                        findWebView(window.decorView)?.evaluateJavascript(
                            "if (typeof player !== 'undefined' && !window._intentionalPause) { player.playVideo(); }",
                            null
                        )
                    }
                }, 500)
            }
            return
        }
        super.finish()
    }

    override fun onResume() {
        super.onResume()
        isActivityPaused = false
        stopKeepAliveLoop()
    }

    override fun onPause() {
        super.onPause()
        isActivityPaused = true
        if (isPlaying) {
            startKeepAliveLoop()
            keepMediaAlive()
        }
    }

    override fun onStop() {
        super.onStop()
        isActivityPaused = true
        if (isPlaying) {
            startKeepAliveLoop()
            keepMediaAlive()
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus && isPlaying) {
            keepMediaAlive()
        }
    }



    private fun keepMediaAlive() {
        try {
            resumeWebViews(window.decorView)
        } catch (_: Exception) {}
    }

    private fun resumeWebViews(view: View?) {
        if (view == null) return
        if (view is WebView) {
            view.onResume()
            view.resumeTimers()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                view.onVisibilityAggregated(true)
            }
            view.dispatchWindowVisibilityChanged(View.VISIBLE)
            // Send JS heartbeat to ensure video element remains playing
            view.evaluateJavascript(
                "if (typeof player !== 'undefined' && player.getPlayerState() === 2 && !window._intentionalPause) { player.playVideo(); }",
                null
            )
        } else if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                resumeWebViews(view.getChildAt(i))
            }
        }
    }

    override fun onDestroy() {
        stopKeepAliveLoop()
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(pipActionReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }
        if (isScreenReceiverRegistered) {
            try {
                unregisterReceiver(screenStateReceiver)
            } catch (_: Exception) {}
            isScreenReceiverRegistered = false
        }
        CoListenMediaService.mediaActionListener = null
        channel = null
        super.onDestroy()
    }
}
