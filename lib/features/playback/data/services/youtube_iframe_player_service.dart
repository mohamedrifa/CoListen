import 'dart:async';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../domain/services/player_service.dart';

class YoutubeIframePlayerService implements PlayerService {
  YoutubePlayerController? _controller;
  String? _trackId;
  PlayerStatus _currentStatus = PlayerStatus.idle;
  Duration _currentPosition = Duration.zero;

  final _statusController = StreamController<PlayerStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  Timer? _positionTimer;
  StreamSubscription? _playerStateSubscription;
  double _cachedDurationSec = 0.0;

  YoutubePlayerController get controller {
    _controller ??= YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        mute: false,
        enableCaption: true,
        enableJavaScript: true,
        playsInline: true,
        origin: 'https://www.youtube-nocookie.com',
      ),
    );
    return _controller!;
  }

  @override
  Future<void> initialize() async {
    controller;
    _listenToPlayerEvents();
  }

  void _listenToPlayerEvents() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = controller.stream.listen((value) {
      if (value.hasError) {
        _currentStatus = PlayerStatus.error;
        _stopPositionPolling();
        _statusController.add(_currentStatus);
        return;
      }

      switch (value.playerState) {
        case PlayerState.playing:
          _currentStatus = PlayerStatus.playing;
          _startPositionPolling();
          _injectAdBlockerScript();
          _injectBackgroundPlaybackScript();
          _statusController.add(_currentStatus);
          break;
        case PlayerState.paused:
          _handlePausedEvent();
          break;
        case PlayerState.buffering:
          _currentStatus = PlayerStatus.buffering;
          _injectAdBlockerScript();
          _statusController.add(_currentStatus);
          break;
        case PlayerState.ended:
          _currentStatus = PlayerStatus.ended;
          _stopPositionPolling();
          _statusController.add(_currentStatus);
          break;
        default:
          _currentStatus = PlayerStatus.idle;
          _statusController.add(_currentStatus);
          break;
      }
    });
  }

  Future<void> _handlePausedEvent() async {
    try {
      final seconds = await controller.currentTime;
      if (_cachedDurationSec <= 0) {
        final dur = await controller.duration;
        if (dur > 0) _cachedDurationSec = dur;
      }
      // If paused within 2.0s of end of track, mobile YouTube reached endscreen
      if (_cachedDurationSec > 3 && seconds >= (_cachedDurationSec - 2.0)) {
        if (_currentStatus != PlayerStatus.ended) {
          _currentStatus = PlayerStatus.ended;
          _stopPositionPolling();
          _statusController.add(_currentStatus);
          return;
        }
      }
    } catch (_) {}

    _currentStatus = PlayerStatus.paused;
    _stopPositionPolling();
    _statusController.add(_currentStatus);
  }

  void _startPositionPolling() {
    _positionTimer?.cancel();
    // Poll position every 1 second to minimize JS bridge overhead on Android UI thread
    _positionTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (_controller != null && _currentStatus == PlayerStatus.playing) {
        try {
          final seconds = await _controller!.currentTime;
          _currentPosition = Duration(milliseconds: (seconds * 1000).toInt());
          _positionController.add(_currentPosition);

          if (_cachedDurationSec <= 0) {
            final dur = await _controller!.duration;
            if (dur > 0) _cachedDurationSec = dur;
          }

          // Position-based End of Track Detection: ensures smooth queue progression
          // even if YouTube mobile player pauses at the end instead of firing ended event
          if (_cachedDurationSec > 3 && seconds >= (_cachedDurationSec - 1.5)) {
            if (_currentStatus != PlayerStatus.ended) {
              _currentStatus = PlayerStatus.ended;
              _stopPositionPolling();
              _statusController.add(_currentStatus);
            }
          }
        } catch (_) {
          // JS bridge busy or uninitialized
        }
      }
    });
  }

  void _stopPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _injectAdBlockerScript() {
    try {
      // ignore: invalid_use_of_internal_member
      controller.webViewController.runJavaScript('''
        (function() {
          if (window._adBlockerActive) return;
          window._adBlockerActive = true;
          function skipAndRemoveAds() {
            // Click skip ad button if visible
            const skipButtons = document.querySelectorAll(
              '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, .ytp-ad-overlay-close-button'
            );
            skipButtons.forEach(btn => {
              try { btn.click(); } catch(e) {}
            });

            // Hide banner overlay ads
            const adOverlays = document.querySelectorAll(
              '.ytp-ad-overlay-container, .ytp-ad-message-container, .video-ads, .ytp-ad-module'
            );
            adOverlays.forEach(el => {
              el.style.display = 'none';
            });

            // Fast forward video ads
            const adShowing = document.querySelector('.ad-showing, .ad-interrupting');
            if (adShowing) {
              const video = document.querySelector('video');
              if (video && isFinite(video.duration) && video.duration > 0) {
                video.currentTime = video.duration;
              }
            }
          }
          // Relaxed 2s interval to avoid CPU starvation and skipped Choreographer frames
          setInterval(skipAndRemoveAds, 2000);
        })();
      ''');
    } catch (_) {
      // Ignore if webview not ready
    }
  }

  void _injectBackgroundPlaybackScript() {
    try {
      // ignore: invalid_use_of_internal_member
      controller.webViewController.runJavaScript('''
        (function() {
          if (window._bgPlaybackInjected) return;
          window._bgPlaybackInjected = true;

          // 1. Spoof visibility properties so YouTube never treats the document as hidden
          try {
            Object.defineProperties(document, {
              hidden: { value: false, writable: false },
              visibilityState: { value: 'visible', writable: false },
              webkitHidden: { value: false, writable: false },
              webkitVisibilityState: { value: 'visible', writable: false }
            });
          } catch(e) {}

          // 2. Suppress visibilitychange events so YouTube does not pause on backgrounding
          window.addEventListener('visibilitychange', function(e) {
            e.stopImmediatePropagation();
          }, true);

          document.addEventListener('visibilitychange', function(e) {
            e.stopImmediatePropagation();
          }, true);

          // 3. Continuous End-of-Track Watcher & HTML5 Ended Event Binding
          setInterval(function() {
            try {
              if (typeof player !== 'undefined' && player && typeof player.getCurrentTime === 'function') {
                var cur = player.getCurrentTime();
                var dur = player.getDuration();
                if (dur > 3 && cur >= (dur - 1.2)) {
                  if (typeof sendMessage === 'function') {
                    sendMessage('StateChange', 0);
                  }
                }
              }
              var v = document.querySelector('video');
              if (v && !v._endedBound) {
                v._endedBound = true;
                v.addEventListener('ended', function() {
                  if (typeof sendMessage === 'function') {
                    sendMessage('StateChange', 0);
                  }
                });
              }
            } catch(e) {}
          }, 500);
        })();
      ''');
    } catch (_) {
      // Ignore if webview not ready
    }
  }

  @override
  Future<void> loadTrack({
    required String trackId,
    required AudioSourceType sourceType,
    Duration startPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    _trackId = trackId;
    _currentPosition = startPosition;
    _cachedDurationSec = 0.0;

    try {
      if (autoPlay) {
        await controller.loadVideoById(
          videoId: trackId,
          startSeconds: startPosition.inSeconds.toDouble(),
        );
      } else {
        await controller.cueVideoById(
          videoId: trackId,
          startSeconds: startPosition.inSeconds.toDouble(),
        );
      }
    } catch (_) {
      // Ignore if webview is currently loading
    }
  }

  @override
  Future<void> play() async {
    try {
      await controller.playVideo();
    } catch (_) {
      // Ignore if webview is currently loading
    }
  }

  @override
  Future<void> pause() async {
    try {
      await controller.pauseVideo();
    } catch (_) {
      // Ignore if webview is currently loading
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    try {
      await controller.seekTo(
        seconds: position.inSeconds.toDouble(),
        allowSeekAhead: true,
      );
    } catch (_) {
      // Ignore if webview is currently loading
    }
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    await controller.setPlaybackRate(rate);
  }

  @override
  Future<void> dispose() async {
    _stopPositionPolling();
    await _playerStateSubscription?.cancel();
    await _controller?.close();
    await _statusController.close();
    await _positionController.close();
  }

  @override
  Duration get currentPosition => _currentPosition;

  @override
  PlayerStatus get currentStatus => _currentStatus;

  @override
  String? get currentTrackId => _trackId;

  @override
  bool get isBackgroundPlaySupported => false;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<PlayerStatus> get statusStream => _statusController.stream;
}
