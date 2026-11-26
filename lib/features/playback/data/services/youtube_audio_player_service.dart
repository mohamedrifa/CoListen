import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../domain/services/player_service.dart';

class YoutubeAudioPlayerService implements PlayerService {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final AudioPlayer _audioPlayer = AudioPlayer(
    userAgent: _userAgent,
  );
  final YoutubeExplode _yt = YoutubeExplode();

  String? _trackId;
  PlayerStatus _currentStatus = PlayerStatus.idle;
  Duration _currentPosition = Duration.zero;

  final _statusController = StreamController<PlayerStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;

  @override
  bool get isBackgroundPlaySupported => true;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  PlayerStatus get currentStatus => _currentStatus;

  @override
  String? get currentTrackId => _trackId;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<PlayerStatus> get statusStream => _statusController.stream;

  @override
  Future<void> initialize() async {
    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      _currentPosition = pos;
      _positionController.add(pos);
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      PlayerStatus newStatus;
      if (state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading) {
        newStatus = PlayerStatus.buffering;
      } else if (state.processingState == ProcessingState.completed) {
        newStatus = PlayerStatus.ended;
      } else if (state.playing) {
        newStatus = PlayerStatus.playing;
      } else {
        newStatus = PlayerStatus.paused;
      }

      _currentStatus = newStatus;
      _statusController.add(newStatus);
    });
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

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(trackId);
      final audioStreams = manifest.audioOnly.sortByBitrate().reversed.toList();
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for $trackId');
      }

      bool loaded = false;
      dynamic lastError;

      // Try streams in priority order (highest bitrate first, fallback to others)
      for (final stream in audioStreams) {
        try {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              stream.url,
              headers: {
                'User-Agent': _userAgent,
                'Referer': 'https://www.youtube.com/',
              },
            ),
            initialPosition: startPosition > Duration.zero ? startPosition : null,
          );
          loaded = true;
          break;
        } catch (e) {
          lastError = e;
        }
      }

      if (!loaded) {
        throw lastError ?? Exception('Failed to load audio stream');
      }

      if (autoPlay) {
        await _audioPlayer.play();
      }
    } catch (e) {
      _currentStatus = PlayerStatus.error;
      _statusController.add(PlayerStatus.error);
    }
  }

  @override
  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    try {
      await _audioPlayer.seek(position);
    } catch (_) {}
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    try {
      await _audioPlayer.setSpeed(rate);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _statusController.close();
    await _positionController.close();
    await _audioPlayer.dispose();
    _yt.close();
  }
}
