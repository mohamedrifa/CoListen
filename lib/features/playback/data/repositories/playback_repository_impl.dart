import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/playback_state_entity.dart';
import '../../domain/repositories/playback_repository.dart';

class PlaybackRepositoryImpl implements PlaybackRepository {
  final FirebaseDatabase _database;

  PlaybackRepositoryImpl({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  @override
  Stream<PlaybackStateEntity?> watchPlaybackState(String roomId) {
    return _database.ref('rooms/$roomId/playback').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return null;
      return PlaybackStateEntity.fromMap(val);
    });
  }

  @override
  Future<void> updatePlayback(String roomId, PlaybackStateEntity state) async {
    try {
      final currentSnap = await _database.ref('rooms/$roomId/playback').get();
      if (currentSnap.exists && currentSnap.value is Map) {
        final currentPb = PlaybackStateEntity.fromMap(currentSnap.value as Map);
        if (currentPb.hasTrack &&
            currentPb.trackId != state.trackId &&
            state.hasTrack) {
          final histKey = DateTime.now().millisecondsSinceEpoch.toString();
          await _database.ref('rooms/$roomId/history/$histKey').set({
            'currentItemId': currentPb.currentItemId,
            'trackId': currentPb.trackId,
            'sourceType': currentPb.sourceType.name,
            'title': currentPb.title,
            'artist': currentPb.artist,
            'thumbnailUrl': currentPb.thumbnailUrl,
            'durationMs': currentPb.durationMs,
            'playedAt': ServerValue.timestamp,
          });
        }
      }
    } catch (_) {}
    await _database.ref('rooms/$roomId/playback').update(state.toMap());
  }

  @override
  Future<void> play(String roomId, Duration position, String uid) async {
    await _database.ref('rooms/$roomId/playback').update({
      'status': 'playing',
      'positionMs': position.inMilliseconds,
      'updatedAt': ServerValue.timestamp,
      'updatedBy': uid,
    });
  }

  @override
  Future<void> pause(String roomId, Duration position, String uid) async {
    await _database.ref('rooms/$roomId/playback').update({
      'status': 'paused',
      'positionMs': position.inMilliseconds,
      'updatedAt': ServerValue.timestamp,
      'updatedBy': uid,
    });
  }

  @override
  Future<void> seek(String roomId, Duration position, String uid) async {
    await _database.ref('rooms/$roomId/playback').update({
      'positionMs': position.inMilliseconds,
      'updatedAt': ServerValue.timestamp,
      'updatedBy': uid,
    });
  }
}
