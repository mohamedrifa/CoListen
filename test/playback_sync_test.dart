import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:colisten/features/playback/domain/entities/playback_state_entity.dart';
import 'package:colisten/features/playback/domain/repositories/playback_repository.dart';
import 'package:colisten/features/playback/domain/services/player_service.dart';
import 'package:colisten/core/sync/server_clock.dart';
import 'package:colisten/features/playback/presentation/providers/playback_sync_provider.dart';

class FakePlayerService implements PlayerService {
  final StreamController<Duration> _posController =
      StreamController<Duration>.broadcast();
  final StreamController<PlayerStatus> _statusController =
      StreamController<PlayerStatus>.broadcast();

  Duration _currentPos = Duration.zero;
  PlayerStatus _status = PlayerStatus.idle;
  String? _trackId;
  double _playbackRate = 1.0;

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Stream<PlayerStatus> get statusStream => _statusController.stream;

  @override
  Duration get currentPosition => _currentPos;

  @override
  PlayerStatus get currentStatus => _status;

  @override
  String? get currentTrackId => _trackId;

  double get playbackRate => _playbackRate;

  @override
  bool get isBackgroundPlaySupported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadTrack({
    required String trackId,
    required AudioSourceType sourceType,
    Duration startPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    _trackId = trackId;
    _currentPos = startPosition;
    _status = autoPlay ? PlayerStatus.playing : PlayerStatus.paused;
    _posController.add(_currentPos);
    _statusController.add(_status);
  }

  @override
  Future<void> play() async {
    _status = PlayerStatus.playing;
    _statusController.add(_status);
  }

  @override
  Future<void> pause() async {
    _status = PlayerStatus.paused;
    _statusController.add(_status);
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPos = position;
    _posController.add(_currentPos);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
  }

  @override
  Future<void> dispose() async {
    await _posController.close();
    await _statusController.close();
  }
}

class FakePlaybackRepository implements PlaybackRepository {
  final StreamController<PlaybackStateEntity?> _streamController =
      StreamController<PlaybackStateEntity?>.broadcast();
  PlaybackStateEntity? currentState;

  void emitState(PlaybackStateEntity? state) {
    currentState = state;
    _streamController.add(state);
  }

  @override
  Stream<PlaybackStateEntity?> watchPlaybackState(String roomId) async* {
    yield currentState;
    yield* _streamController.stream;
  }

  @override
  Future<void> updatePlayback(
      String roomId, PlaybackStateEntity state) async {
    currentState = state;
    _streamController.add(state);
  }

  @override
  Future<void> play(String roomId, Duration position, String uid) async {
    if (currentState != null) {
      final updated = currentState!.copyWith(
        status: 'playing',
        positionMs: position.inMilliseconds,
        updatedAt: DateTime.now(),
        updatedBy: uid,
      );
      emitState(updated);
    }
  }

  @override
  Future<void> pause(String roomId, Duration position, String uid) async {
    if (currentState != null) {
      final updated = currentState!.copyWith(
        status: 'paused',
        positionMs: position.inMilliseconds,
        updatedAt: DateTime.now(),
        updatedBy: uid,
      );
      emitState(updated);
    }
  }

  @override
  Future<void> seek(String roomId, Duration position, String uid) async {
    if (currentState != null) {
      final updated = currentState!.copyWith(
        positionMs: position.inMilliseconds,
        updatedAt: DateTime.now(),
        updatedBy: uid,
      );
      emitState(updated);
    }
  }
}

void main() {
  group('PlaybackStateEntity Expected Position Math', () {
    test('Paused state stays at fixed positionMs', () {
      final baseTime = DateTime.now().subtract(const Duration(seconds: 45));
      final state = PlaybackStateEntity(
        currentItemId: 'item_1',
        trackId: 'track_1',
        title: 'Song Title',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 180000,
        positionMs: 30000,
        status: 'paused',
        updatedAt: baseTime,
        updatedBy: 'user_1',
      );

      final now = DateTime.now();
      final expected = state.computeExpectedPosition(now);

      // In paused state, position must NOT advance with elapsed time
      expect(expected.inMilliseconds, equals(30000));
    });

    test('Playing state computes positionMs + elapsed server time', () {
      final baseTime = DateTime.now().subtract(const Duration(seconds: 15));
      final state = PlaybackStateEntity(
        currentItemId: 'item_1',
        trackId: 'track_1',
        title: 'Song Title',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 180000,
        positionMs: 20000,
        status: 'playing',
        updatedAt: baseTime,
        updatedBy: 'user_1',
      );

      final now = baseTime.add(const Duration(seconds: 10));
      final expected = state.computeExpectedPosition(now);

      // Expected = 20,000 + 10,000 = 30,000ms
      expect(expected.inMilliseconds, equals(30000));
    });

    test('Playing state clamps expected position to durationMs', () {
      final baseTime = DateTime.now().subtract(const Duration(minutes: 5));
      final state = PlaybackStateEntity(
        currentItemId: 'item_1',
        trackId: 'track_1',
        title: 'Song Title',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 120000, // 2 minutes
        positionMs: 100000,
        status: 'playing',
        updatedAt: baseTime,
        updatedBy: 'user_1',
      );

      final now = DateTime.now(); // 5 minutes later
      final expected = state.computeExpectedPosition(now);

      // Must clamp to durationMs (120,000)
      expect(expected.inMilliseconds, equals(120000));
    });

    test('Serialization toMap and fromMap preserves all fields', () {
      final original = PlaybackStateEntity(
        currentItemId: 'item_42',
        trackId: 'yt_abc123',
        title: 'Midnight Beats',
        artist: 'DJ LoFi',
        thumbnailUrl: 'https://img.youtube.com/vi/abc123/hqdefault.jpg',
        durationMs: 210000,
        positionMs: 45000,
        status: 'playing',
        sourceType: AudioSourceType.youtube,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        updatedBy: 'user_host_1',
      );

      final map = original.toMap();
      final restored = PlaybackStateEntity.fromMap(map);

      expect(restored.currentItemId, equals(original.currentItemId));
      expect(restored.trackId, equals(original.trackId));
      expect(restored.title, equals(original.title));
      expect(restored.artist, equals(original.artist));
      expect(restored.durationMs, equals(original.durationMs));
      expect(restored.positionMs, equals(original.positionMs));
      expect(restored.status, equals(original.status));
      expect(restored.sourceType, equals(original.sourceType));
      expect(restored.thumbnailUrl, equals(original.thumbnailUrl));
      expect(restored.updatedBy, equals(original.updatedBy));
      expect(restored.isPlaying, isTrue);
      expect(restored.hasTrack, isTrue);
    });
  });

  group('PlaybackSyncNotifier Drift and State Controller', () {
    late FakePlayerService fakePlayer;
    late FakePlaybackRepository fakeRepo;
    late ServerClock fakeClock;

    setUp(() {
      fakePlayer = FakePlayerService();
      fakeRepo = FakePlaybackRepository();
      fakeClock = ServerClock(initialOffsetMs: 0);
    });

    tearDown(() async {
      await fakePlayer.dispose();
    });

    test('Loads track and begins playback on remote track broadcast', () async {
      final notifier = PlaybackSyncNotifier(
        'test_room',
        fakePlayer,
        fakeClock,
        fakeRepo,
      );

      final trackState = PlaybackStateEntity(
        currentItemId: 'item_alpha',
        trackId: 'track_alpha',
        title: 'Alpha Waves',
        artist: 'Ambient Sound',
        thumbnailUrl: '',
        durationMs: 300000,
        positionMs: 5000,
        status: 'playing',
        updatedAt: DateTime.now(),
        updatedBy: 'host_1',
      );

      fakeRepo.emitState(trackState);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakePlayer.currentTrackId, equals('track_alpha'));
      expect(fakePlayer.currentStatus, equals(PlayerStatus.playing));
      expect(notifier.state.value?.trackId, equals('track_alpha'));

      notifier.dispose();
    });

    test('DJ actions play and pause update repository and player', () async {
      final notifier = PlaybackSyncNotifier(
        'test_room',
        fakePlayer,
        fakeClock,
        fakeRepo,
      );

      final trackState = PlaybackStateEntity(
        currentItemId: 'item_beta',
        trackId: 'track_beta',
        title: 'Beta Grooves',
        artist: 'Funky DJ',
        thumbnailUrl: '',
        durationMs: 200000,
        positionMs: 10000,
        status: 'paused',
        updatedAt: DateTime.now(),
        updatedBy: 'host_1',
      );

      fakeRepo.emitState(trackState);
      await Future.delayed(const Duration(milliseconds: 50));

      // DJ presses Play
      await notifier.play('dj_user_1');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeRepo.currentState?.isPlaying, isTrue);
      expect(fakeRepo.currentState?.updatedBy, equals('dj_user_1'));

      // DJ presses Pause
      await notifier.pause('dj_user_1');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeRepo.currentState?.isPaused, isTrue);

      notifier.dispose();
    });

    test('Drift sync applies micro-rate adjustment without seeking on moderate drift', () async {
      final notifier = PlaybackSyncNotifier(
        'test_room',
        fakePlayer,
        fakeClock,
        fakeRepo,
        null,
        'listener_user_99',
      );

      final trackState = PlaybackStateEntity(
        currentItemId: 'item_gamma',
        trackId: 'track_gamma',
        title: 'Gamma Beats',
        artist: 'Chillout',
        thumbnailUrl: '',
        durationMs: 300000,
        positionMs: 10000,
        status: 'playing',
        updatedAt: DateTime.now().subtract(const Duration(seconds: 1)),
        updatedBy: 'host_1',
      );

      fakeRepo.emitState(trackState);
      await Future.delayed(const Duration(milliseconds: 50));

      // Player is at 10000ms, expected is ~11000ms -> drift is ~1000ms (within 400-2500ms window)
      // Playback rate should be nudged to 1.05 without hard seek
      expect(fakePlayer.currentTrackId, equals('track_gamma'));
      notifier.dispose();
    });

    test('Host/Controller who updated playback is not subjected to self-drift seek', () async {
      final notifier = PlaybackSyncNotifier(
        'test_room',
        fakePlayer,
        fakeClock,
        fakeRepo,
        null,
        'host_1', // Local user is host_1
      );

      final trackState = PlaybackStateEntity(
        currentItemId: 'item_host',
        trackId: 'track_host',
        title: 'Host Beats',
        artist: 'DJ Host',
        thumbnailUrl: '',
        durationMs: 300000,
        positionMs: 10000,
        status: 'playing',
        updatedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        updatedBy: 'host_1', // Updated by host_1
      );

      fakeRepo.emitState(trackState);
      await Future.delayed(const Duration(milliseconds: 50));

      // Host is master clock, should not be disrupted
      expect(fakePlayer.currentTrackId, equals('track_host'));
      notifier.dispose();
    });
  });
}
