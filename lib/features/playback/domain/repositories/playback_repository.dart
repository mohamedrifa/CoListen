import '../entities/playback_state_entity.dart';

abstract class PlaybackRepository {
  Stream<PlaybackStateEntity?> watchPlaybackState(String roomId);
  Future<void> updatePlayback(String roomId, PlaybackStateEntity state);
  Future<void> play(String roomId, Duration position, String uid);
  Future<void> pause(String roomId, Duration position, String uid);
  Future<void> seek(String roomId, Duration position, String uid);
}
