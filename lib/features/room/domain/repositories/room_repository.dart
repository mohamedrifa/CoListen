import '../entities/room_entity.dart';
import '../entities/room_history_entity.dart';

abstract class RoomRepository {
  Future<RoomEntity> createRoom({
    required String name,
    required String adminId,
    required String adminName,
    required RoomSettings settings,
  });

  Future<String> joinRoomByCode({
    required String code,
    required String uid,
    required String displayName,
  });

  Stream<RoomEntity?> watchRoom(String roomId);

  Stream<List<RoomHistoryEntity>> watchUserRoomHistory(String uid);

  Future<void> removeRoomFromHistory({
    required String uid,
    required String roomId,
  });

  Future<void> recordRoomVisit({
    required String uid,
    required String roomId,
    required String displayName,
  });

  Future<void> toggleControllerRole({
    required String roomId,
    required String targetUid,
    required bool isController,
  });

  Future<void> removeMember({
    required String roomId,
    required String targetUid,
  });

  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  });
}
