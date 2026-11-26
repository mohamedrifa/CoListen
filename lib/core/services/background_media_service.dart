import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pipModeProvider = StateProvider<bool>((ref) => false);

final backgroundMediaServiceProvider = Provider<BackgroundMediaService>((ref) {
  final service = BackgroundMediaService(ref);
  service.initChannel();
  return service;
});

class BackgroundMediaService {
  static const MethodChannel _channel = MethodChannel('colisten/media_service');
  final Ref? _ref;

  bool _isServiceActive = false;
  String _currentTitle = '';
  String _currentArtist = '';
  bool _currentPlaying = false;

  VoidCallback? onPlayRequested;
  VoidCallback? onPauseRequested;
  VoidCallback? onNextRequested;
  VoidCallback? onPreviousRequested;
  VoidCallback? onStopLocalRequested;

  BackgroundMediaService([this._ref]);

  bool get isServiceActive => _isServiceActive;

  /// Queries the native platform to determine if the app is currently in Picture-in-Picture mode.
  Future<bool> checkPipMode() async {
    if (kIsWeb) return false;
    try {
      final inPip = await _channel.invokeMethod<bool>('isPipMode') ?? false;
      if (_ref != null) {
        _ref.read(pipModeProvider.notifier).state = inPip;
      }
      return inPip;
    } catch (_) {
      return false;
    }
  }

  void initChannel() {
    if (kIsWeb) return;
    try {
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onPipModeChanged':
            final inPip = call.arguments as bool? ?? false;
            if (_ref != null) {
              _ref.read(pipModeProvider.notifier).state = inPip;
            }
            break;
          case 'onNotificationAction':
            final action = call.arguments as String? ?? '';
            if (action == 'play') {
              onPlayRequested?.call();
            } else if (action == 'pause') {
              onPauseRequested?.call();
            } else if (action == 'next') {
              onNextRequested?.call();
            } else if (action == 'prev' || action == 'previous') {
              onPreviousRequested?.call();
            } else if (action == 'stop_local') {
              onStopLocalRequested?.call();
            }
            break;
        }
      });
    } catch (_) {}
  }

  /// Starts the Android foreground service with a persistent media notification
  /// and acquires a CPU WakeLock so audio plays continuously in Recents and background.
  Future<void> startForeground({
    required String title,
    required String artist,
    bool isPlaying = true,
  }) async {
    if (kIsWeb) return;
    _currentTitle = title.isEmpty ? 'CoListen Track' : title;
    _currentArtist = artist.isEmpty ? 'Synchronized Music Room' : artist;
    _currentPlaying = isPlaying;

    try {
      await _channel.invokeMethod('startForegroundPlayback', {
        'title': _currentTitle,
        'artist': _currentArtist,
        'isPlaying': _currentPlaying,
      });
      _isServiceActive = true;
    } on MissingPluginException {
      // Running on unsupported platform (web/test/desktop)
    } catch (_) {}
  }

  /// Updates notification title, artist, and play/pause state without restarting the service
  Future<void> updateState({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {
    if (kIsWeb || !_isServiceActive) {
      if (isPlaying) {
        await startForeground(title: title, artist: artist, isPlaying: isPlaying);
      }
      return;
    }

    _currentTitle = title.isEmpty ? _currentTitle : title;
    _currentArtist = artist.isEmpty ? _currentArtist : artist;
    _currentPlaying = isPlaying;

    try {
      await _channel.invokeMethod('updatePlaybackState', {
        'title': _currentTitle,
        'artist': _currentArtist,
        'isPlaying': _currentPlaying,
      });
    } catch (_) {}
  }

  /// Gracefully stops the foreground service and releases WakeLock
  Future<void> stopForeground() async {
    if (kIsWeb || !_isServiceActive) return;
    try {
      await _channel.invokeMethod('stopForegroundPlayback');
      _isServiceActive = false;
    } catch (_) {}
  }
}
