import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/server_clock.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../queue/domain/repositories/queue_repository.dart';
import '../../../queue/presentation/providers/queue_providers.dart';
import '../../domain/entities/playback_state_entity.dart';
import '../../domain/repositories/playback_repository.dart';
import '../../domain/services/player_service.dart';
import '../../data/repositories/playback_repository_impl.dart';
import '../../data/services/youtube_iframe_player_service.dart';

final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = YoutubeIframePlayerService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return PlaybackRepositoryImpl();
});

final playbackSyncNotifierProvider = StateNotifierProvider.autoDispose.family<
    PlaybackSyncNotifier, AsyncValue<PlaybackStateEntity?>, String>(
  (ref, roomId) {
    final player = ref.watch(playerServiceProvider);
    final clock = ref.watch(serverClockProvider);
    final repo = ref.watch(playbackRepositoryProvider);
    final queueRepo = ref.watch(queueRepositoryProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    return PlaybackSyncNotifier(roomId, player, clock, repo, queueRepo, authUser?.uid);
  },
);

class PlaybackSyncNotifier extends StateNotifier<AsyncValue<PlaybackStateEntity?>> {
  final String roomId;
  final PlayerService _player;
  final ServerClock _clock;
  final PlaybackRepository _repo;
  final QueueRepository? _queueRepo;
  final String? _currentUid;

  StreamSubscription? _remoteSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _driftTimer;
  DateTime? _lastSeekTime;
  bool _isDisposed = false;

  PlaybackSyncNotifier(
    this.roomId,
    this._player,
    this._clock,
    this._repo, [
    this._queueRepo,
    this._currentUid,
  ]) : super(const AsyncValue.loading()) {
    _initSync();
  }

  void _initSync() {
    _remoteSubscription = _repo.watchPlaybackState(roomId).listen(
      (remoteState) async {
        if (_isDisposed) return;
        state = AsyncValue.data(remoteState);
        if (remoteState != null) {
          await _applyRemoteState(remoteState);
        }
      },
      onError: (err, st) {
        if (!_isDisposed) {
          state = AsyncValue.error(err, st);
        }
      },
    );

    // Auto-advance queue when track ends naturally or fails with embedding error (Req 15)
    _statusSubscription = _player.statusStream.listen((status) async {
      if (_isDisposed) return;
      if (status == PlayerStatus.ended && _queueRepo != null) {
        try {
          await _queueRepo.skipToNextSong(roomId, _currentUid);
        } catch (_) {}
      } else if (status == PlayerStatus.error && _queueRepo != null) {
        // Auto-skip unplayable/restricted video after short grace period
        Future.delayed(const Duration(seconds: 2), () async {
          if (!_isDisposed && _player.currentStatus == PlayerStatus.error) {
            try {
              await _queueRepo.skipToNextSong(roomId, _currentUid);
            } catch (_) {}
          }
        });
      }
    });

    _startDriftMonitoring();
  }

  Future<void> _applyRemoteState(PlaybackStateEntity remote) async {
    final serverNow = _clock.currentServerTime;
    final targetPosition = remote.computeExpectedPosition(serverNow);

    // If new track or not loaded
    if (_player.currentTrackId != remote.trackId && remote.hasTrack) {
      _lastSeekTime = DateTime.now(); // Cooldown grace period on new track
      await _player.loadTrack(
        trackId: remote.trackId,
        sourceType: remote.sourceType,
        startPosition: targetPosition,
        autoPlay: remote.isPlaying,
      );
      return;
    }

    // Align play/pause state safely without interrupting active buffering
    if (remote.isPlaying &&
        _player.currentStatus != PlayerStatus.playing &&
        _player.currentStatus != PlayerStatus.buffering) {
      await _player.play();
    } else if (remote.isPaused && _player.currentStatus != PlayerStatus.paused) {
      await _player.pause();
    }
  }

  void _startDriftMonitoring() {
    _driftTimer?.cancel();
    // Requirement 4.3: Sample drift every ~5 seconds to prevent decoder thrashing
    _driftTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isDisposed) return;
      final current = state.valueOrNull;
      if (current == null || !current.isPlaying || !current.hasTrack) return;

      // Only evaluate drift while actively playing (never while buffering or paused)
      if (_player.currentStatus != PlayerStatus.playing) return;

      // If the local user is the controller who initiated play/seek, they are the clock source
      if (_currentUid != null && current.updatedBy == _currentUid) return;

      final serverNow = _clock.currentServerTime;
      final expected = current.computeExpectedPosition(serverNow);
      final actual = _player.currentPosition;
      final driftMs = expected.inMilliseconds - actual.inMilliseconds;

      // Tier 1: Drift < 400ms -> Silent zone, keep normal 1.0x rate
      if (driftMs.abs() < 400) {
        await _player.setPlaybackRate(1.0);
      }
      // Tier 2: 400ms <= Drift <= 2500ms -> Micro-rate adjustment (preserves pitch & video decoder)
      else if (driftMs.abs() <= 2500) {
        final rate = driftMs > 0 ? 1.05 : 0.95;
        await _player.setPlaybackRate(rate);
      }
      // Tier 3: Drift > 2500ms -> Hard seek to expected position only after cooldown
      else {
        final now = DateTime.now();
        final canSeek = _lastSeekTime == null ||
            now.difference(_lastSeekTime!) > const Duration(seconds: 10);
        if (canSeek) {
          _lastSeekTime = now;
          await _player.seek(expected);
          await _player.setPlaybackRate(1.0);
        } else {
          // Inside 10-second cooldown window: accelerate/decelerate rather than flushing decoder
          final rate = driftMs > 0 ? 1.05 : 0.95;
          await _player.setPlaybackRate(rate);
        }
      }
    });
  }

  // DJ Controller Methods
  Future<void> play(String uid) async {
    final pos = _player.currentPosition;
    await _repo.play(roomId, pos, uid);
  }

  Future<void> pause(String uid) async {
    final pos = _player.currentPosition;
    await _repo.pause(roomId, pos, uid);
  }

  Future<void> seek(Duration targetPosition, String uid) async {
    await _player.seek(targetPosition);
    await _repo.seek(roomId, targetPosition, uid);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _remoteSubscription?.cancel();
    _statusSubscription?.cancel();
    _driftTimer?.cancel();
    super.dispose();
  }
}
