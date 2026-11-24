import 'dart:async';

enum AudioSourceType {
  youtube;

  String get label {
    switch (this) {
      case AudioSourceType.youtube:
        return 'YouTube';
    }
  }

  static AudioSourceType fromString(String? type) {
    return AudioSourceType.youtube;
  }
}

enum PlayerStatus {
  idle,
  playing,
  paused,
  buffering,
  ended,
  error;
}

abstract class PlayerService {
  Future<void> initialize();
  Future<void> loadTrack({
    required String trackId,
    required AudioSourceType sourceType,
    Duration startPosition = Duration.zero,
    bool autoPlay = true,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setPlaybackRate(double rate);
  Future<void> dispose();

  Stream<PlayerStatus> get statusStream;
  Stream<Duration> get positionStream;
  Duration get currentPosition;
  String? get currentTrackId;
  PlayerStatus get currentStatus;
  bool get isBackgroundPlaySupported;
}
