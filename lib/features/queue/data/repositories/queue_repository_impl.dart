import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:colisten/features/playback/domain/entities/playback_state_entity.dart';
import 'package:colisten/features/queue/domain/entities/queue_item_entity.dart';
import 'package:colisten/features/queue/domain/repositories/queue_repository.dart';
import 'package:colisten/features/queue/domain/services/youtube_suggestion_pool.dart';

class QueueRepositoryImpl implements QueueRepository {
  final FirebaseDatabase? _database;

  // ignore: prefer_initializing_formals
  QueueRepositoryImpl({FirebaseDatabase? database}) : _database = database;

  FirebaseDatabase? get _db {
    if (_database != null) return _database;
    if (Firebase.apps.isNotEmpty) return FirebaseDatabase.instance;
    return null;
  }

  @override
  Stream<List<QueueItemEntity>> watchQueue(String roomId) {
    final db = _db;
    if (db == null) return Stream.value([]);

    return db
        .ref('rooms/$roomId/queue')
        .orderByChild('order')
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value == null) return [];

      final items = <QueueItemEntity>[];
      if (value is Map) {
        value.forEach((key, val) {
          if (val is Map) {
            items.add(QueueItemEntity.fromMap(key.toString(), val));
          }
        });
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          final val = value[i];
          if (val is Map) {
            items.add(QueueItemEntity.fromMap(i.toString(), val));
          }
        }
      }

      items.sort((a, b) => a.compareTo(b));
      return items;
    });
  }

  @override
  Future<void> addSong({
    required String roomId,
    required QueueItemEntity item,
  }) async {
    final db = _db;
    if (db == null) return;

    // Check if playback currently has an active song
    final playbackSnap = await db.ref('rooms/$roomId/playback').get();
    final playbackMap = playbackSnap.value as Map?;
    final currentTrackId = playbackMap?['trackId'] as String? ?? '';

    // If no song is playing, make this the active song immediately!
    if (currentTrackId.isEmpty) {
      final newPlayback = PlaybackStateEntity(
        currentItemId: 'initial',
        trackId: item.trackId,
        sourceType: item.sourceType,
        title: item.title,
        artist: item.artist,
        thumbnailUrl: item.thumbnailUrl,
        durationMs: item.durationMs,
        status: 'playing',
        positionMs: 0,
        updatedAt: DateTime.now(),
        updatedBy: item.addedBy,
      );

      final map = newPlayback.toMap();
      map['updatedAt'] = ServerValue.timestamp;
      await db.ref('rooms/$roomId/playback').set(map);
      return;
    }

    // Otherwise, append to the queue with fractional ordering
    final queueSnap = await db.ref('rooms/$roomId/queue').get();
    double highestOrder = 0.0;
    if (queueSnap.exists) {
      final val = queueSnap.value;
      if (val is Map) {
        val.forEach((_, v) {
          if (v is Map && v['order'] is num) {
            final o = (v['order'] as num).toDouble();
            if (o > highestOrder) highestOrder = o;
          }
        });
      } else if (val is List) {
        for (final v in val) {
          if (v is Map && v['order'] is num) {
            final o = (v['order'] as num).toDouble();
            if (o > highestOrder) highestOrder = o;
          }
        }
      }
    }

    final newOrder = highestOrder > 0.0 ? highestOrder + 1.0 : 1.0;
    final newItem = item.copyWith(order: newOrder);

    final queueRef = db.ref('rooms/$roomId/queue').push();
    await queueRef.set(newItem.toMap());
  }

  @override
  Future<void> removeSong({
    required String roomId,
    required String itemId,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.ref('rooms/$roomId/queue/$itemId').remove();
  }

  @override
  Future<void> reorderQueue({
    required String roomId,
    required String itemId,
    required double newOrder,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.ref('rooms/$roomId/queue/$itemId/order').set(newOrder);
  }

  @override
  Future<void> voteSkip({
    required String roomId,
    required String itemId,
    required String uid,
    required bool vote,
  }) async {
    final db = _db;
    if (db == null) return;

    final voteRef = db.ref('rooms/$roomId/queue/$itemId/voteSkipUids/$uid');
    if (vote) {
      await voteRef.set(true);
    } else {
      await voteRef.remove();
    }

    // Check consensus threshold
    final roomSnap = await db.ref('rooms/$roomId').get();
    if (!roomSnap.exists || roomSnap.value is! Map) return;

    final roomMap = roomSnap.value as Map;
    final membersMap = roomMap['members'] as Map? ?? {};
    final totalMembers = membersMap.length;
    final settingsMap = roomMap['settings'] as Map? ?? {};
    final thresholdPercent =
        settingsMap['voteSkipThresholdPercent'] as int? ?? 50;

    final itemSnap = await db.ref('rooms/$roomId/queue/$itemId').get();
    if (!itemSnap.exists || itemSnap.value is! Map) return;

    final queueItem =
        QueueItemEntity.fromMap(itemId, itemSnap.value as Map);
    if (queueItem.shouldSkip(totalMembers, thresholdPercent)) {
      await skipToNextSong(roomId, uid);
    }
  }

  @override
  Future<void> toggleUpvote({
    required String roomId,
    required String itemId,
    required String uid,
    required bool upvote,
  }) async {
    final db = _db;
    if (db == null) return;

    final voteRef = db.ref('rooms/$roomId/queue/$itemId/upvoteUids/$uid');
    if (upvote) {
      await voteRef.set(true);
    } else {
      await voteRef.remove();
    }
  }

  @override
  Future<void> skipToNextSong(String roomId, [String? currentUid]) async {
    final db = _db;
    if (db == null) return;

    try {
      final currentPlaybackSnap = await db.ref('rooms/$roomId/playback').get();
      final pbData = currentPlaybackSnap.exists && currentPlaybackSnap.value is Map
          ? PlaybackStateEntity.fromMap(currentPlaybackSnap.value as Map)
          : null;

      // Cooldown check for automatic background sync: prevent duplicate rapid skips
      if (pbData != null) {
        final elapsedSinceLastUpdate =
            DateTime.now().difference(pbData.updatedAt).inMilliseconds;
        if (elapsedSinceLastUpdate >= 0 && elapsedSinceLastUpdate < 1200) {
          return;
        }
      }

      final queueSnap =
          await db.ref('rooms/$roomId/queue').orderByChild('order').get();

      final items = <QueueItemEntity>[];
      if (queueSnap.exists) {
        final qVal = queueSnap.value;
        if (qVal is Map) {
          qVal.forEach((k, v) {
            if (v is Map) {
              items.add(QueueItemEntity.fromMap(k.toString(), v));
            }
          });
        } else if (qVal is List) {
          for (var i = 0; i < qVal.length; i++) {
            final v = qVal[i];
            if (v is Map) {
              items.add(QueueItemEntity.fromMap(i.toString(), v));
            }
          }
        }
        items.sort((a, b) => a.compareTo(b));
      }

      if (items.isNotEmpty) {
        QueueItemEntity? nextItem = items.first;

        // If the top queue item is the track that was already playing, pop it and advance
        if (pbData != null && nextItem.trackId == pbData.trackId) {
          try {
            await db.ref('rooms/$roomId/queue/${nextItem.id}').remove();
          } catch (_) {}
          if (items.length > 1) {
            nextItem = items[1];
          } else {
            nextItem = null;
          }
        }

        if (nextItem != null) {
          final map = {
            'currentItemId': nextItem.id,
            'trackId': nextItem.trackId,
            'sourceType': nextItem.sourceType.name,
            'title': nextItem.title,
            'artist': nextItem.artist,
            'thumbnailUrl': nextItem.thumbnailUrl,
            'durationMs': nextItem.durationMs,
            'status': 'playing',
            'positionMs': 0,
            'updatedAt': ServerValue.timestamp,
            'updatedBy': currentUid ?? 'system',
          };

          // Remove item from queue immediately so it cannot be selected again
          try {
            await db.ref('rooms/$roomId/queue/${nextItem.id}').remove();
          } catch (_) {}
          await db.ref('rooms/$roomId/playback').set(map);
          return;
        }
      }

      // Queue is empty: Autoplay from YouTube suggestions / playlist
      final suggestion = YouTubeSuggestionPool.getNextAutoplayTrack(
        currentTrackId: pbData?.trackId,
        currentArtist: pbData?.artist,
        currentTitle: pbData?.title,
      );

      if (suggestion != null) {
        final autoplayMap = {
          'currentItemId': 'yt_auto_${DateTime.now().millisecondsSinceEpoch}',
          'trackId': suggestion.trackId,
          'sourceType': suggestion.sourceType.name,
          'title': suggestion.title,
          'artist': suggestion.artist.contains('YouTube')
              ? suggestion.artist
              : '${suggestion.artist} • YouTube Autoplay',
          'thumbnailUrl': suggestion.thumbnailUrl,
          'durationMs': suggestion.durationMs,
          'status': 'playing',
          'positionMs': 0,
          'updatedAt': ServerValue.timestamp,
          'updatedBy': 'youtube_autoplay',
        };

        await db.ref('rooms/$roomId/playback').set(autoplayMap);
        return;
      }

      // If queue is empty and no suggestion, reset playback to empty
      await db.ref('rooms/$roomId/playback').set(PlaybackStateEntity.empty().toMap());
    } catch (_) {
      // Gracefully handle if permission rules or network temporarily prevents write;
      // host or another controller member device will synchronize playback state.
    }
  }
}
