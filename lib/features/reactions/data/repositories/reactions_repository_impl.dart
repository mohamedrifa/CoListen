import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:colisten/features/reactions/domain/entities/reaction_entity.dart';
import 'package:colisten/features/reactions/domain/repositories/reactions_repository.dart';

class ReactionsRepositoryImpl implements ReactionsRepository {
  final FirebaseDatabase? _database;

  // ignore: prefer_initializing_formals
  ReactionsRepositoryImpl({FirebaseDatabase? database}) : _database = database;

  FirebaseDatabase? get _db {
    if (_database != null) return _database;
    if (Firebase.apps.isNotEmpty) return FirebaseDatabase.instance;
    return null;
  }

  @override
  Stream<List<ReactionEntity>> watchReactions(String roomId) {
    final db = _db;
    if (db == null) return Stream.value([]);

    // Listen to recent reactions in the room (last 20)
    return db
        .ref('rooms/$roomId/reactions')
        .limitToLast(20)
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value == null || value is! Map) return [];

      final list = <ReactionEntity>[];
      value.forEach((key, val) {
        if (val is Map) {
          list.add(ReactionEntity.fromMap(key.toString(), val));
        }
      });

      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  @override
  Future<void> sendReaction({
    required String roomId,
    required String uid,
    required String displayName,
    required String emoji,
  }) async {
    final db = _db;
    if (db == null) return;

    final ref = db.ref('rooms/$roomId/reactions').push();
    await ref.set({
      'uid': uid,
      'displayName': displayName,
      'emoji': emoji,
      'createdAt': ServerValue.timestamp,
    });

    // Lazy cleanup: prune reactions older than 30 seconds
    try {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 30)).millisecondsSinceEpoch;
      final oldSnaps = await db
          .ref('rooms/$roomId/reactions')
          .orderByChild('createdAt')
          .endAt(cutoff)
          .get();

      if (oldSnaps.exists && oldSnaps.value is Map) {
        final updates = <String, dynamic>{};
        (oldSnaps.value as Map).forEach((k, _) {
          updates['rooms/$roomId/reactions/$k'] = null;
        });
        if (updates.isNotEmpty) {
          await db.ref().update(updates);
        }
      }
    } catch (_) {}
  }
}
