import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/invite_entity.dart';
import '../../domain/repositories/invite_repository.dart';

class InviteRepositoryImpl implements InviteRepository {
  final FirebaseDatabase _database;

  InviteRepositoryImpl({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  @override
  Stream<List<InviteEntity>> watchMyPendingInvites(String uid) {
    return _database.ref('userInvites/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final list = <InviteEntity>[];
      data.forEach((key, val) {
        if (val is Map) {
          final invite = InviteEntity.fromMap(key.toString(), val);
          if (invite.status == 'pending') {
            list.add(invite);
          }
        }
      });
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> sendInvite({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String roomId,
    required String roomName,
    required String roomCode,
  }) async {
    final inviteRef = _database.ref('userInvites/$toUid').push();
    await inviteRef.set({
      'fromUid': fromUid,
      'fromName': fromName,
      'roomId': roomId,
      'roomName': roomName,
      'roomCode': roomCode,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
    });
  }

  @override
  Future<void> acceptInvite(String uid, String inviteId) async {
    await _database.ref('userInvites/$uid/$inviteId').update({
      'status': 'accepted',
    });
  }

  @override
  Future<void> declineInvite(String uid, String inviteId) async {
    await _database.ref('userInvites/$uid/$inviteId').update({
      'status': 'declined',
    });
  }
}
