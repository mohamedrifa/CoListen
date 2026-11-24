import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:colisten/features/playback/domain/entities/playback_state_entity.dart';
import 'package:colisten/features/queue/domain/entities/queue_item_entity.dart';
import 'package:colisten/features/queue/domain/repositories/queue_repository.dart';

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
      if (value == null || value is! Map) return [];

      final items = <QueueItemEntity>[];
      value.forEach((key, val) {
        if (val is Map) {
          items.add(QueueItemEntity.fromMap(key.toString(), val));
        }
      });

      items.sort((a, b) => a.order.compareTo(b.order));
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
    if (queueSnap.exists && queueSnap.value is Map) {
      (queueSnap.value as Map).forEach((_, v) {
        if (v is Map && v['order'] is num) {
          final o = (v['order'] as num).toDouble();
          if (o > highestOrder) highestOrder = o;
        }
      });
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
  Future<void> skipToNextSong(String roomId, [String? currentUid]) async {
    final db = _db;
    if (db == null) return;

    final queueSnap =
        await db.ref('rooms/$roomId/queue').orderByChild('order').get();

    if (queueSnap.exists && queueSnap.value is Map) {
      final items = <QueueItemEntity>[];
      (queueSnap.value as Map).forEach((k, v) {
        if (v is Map) {
          items.add(QueueItemEntity.fromMap(k.toString(), v));
        }
      });
      items.sort((a, b) => a.order.compareTo(b.order));

      if (items.isNotEmpty) {
        final nextItem = items.first;

        // Atomically set playback to the next item
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

        await db.ref('rooms/$roomId/playback').set(map);
        // Remove item from queue
        await db.ref('rooms/$roomId/queue/${nextItem.id}').remove();
        return;
      }
    }

    // If queue is empty, reset playback to empty
    await db.ref('rooms/$roomId/playback').set(PlaybackStateEntity.empty().toMap());
  }
}
