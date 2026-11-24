import '../entities/invite_entity.dart';

abstract class InviteRepository {
  Stream<List<InviteEntity>> watchMyPendingInvites(String uid);
  Future<void> sendInvite({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String roomId,
    required String roomName,
    required String roomCode,
  });
  Future<void> acceptInvite(String uid, String inviteId);
  Future<void> declineInvite(String uid, String inviteId);
}
