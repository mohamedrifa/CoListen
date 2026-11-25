import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/room_entity.dart';
import '../../domain/entities/room_history_entity.dart';
import '../../domain/repositories/room_repository.dart';
import '../../data/repositories/room_repository_impl.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepositoryImpl();
});

final currentRoomProvider =
    StreamProvider.family<RoomEntity?, String>((ref, roomId) {
  final repo = ref.watch(roomRepositoryProvider);
  return repo.watchRoom(roomId);
});

final userRoomHistoryProvider =
    StreamProvider.family<List<RoomHistoryEntity>, String>((ref, uid) {
  final repo = ref.watch(roomRepositoryProvider);
  return repo.watchUserRoomHistory(uid);
});

final roomControllerProvider =
    StateNotifierProvider<RoomController, AsyncValue<String?>>((ref) {
  final repo = ref.watch(roomRepositoryProvider);
  return RoomController(repo);
});

class RoomController extends StateNotifier<AsyncValue<String?>> {
  final RoomRepository _repo;

  RoomController(this._repo) : super(const AsyncValue.data(null));

  Future<String?> createRoom({
    required String name,
    required String adminId,
    required String adminName,
    required RoomSettings settings,
  }) async {
    state = const AsyncValue.loading();
    try {
      final room = await _repo.createRoom(
        name: name,
        adminId: adminId,
        adminName: adminName,
        settings: settings,
      );
      state = AsyncValue.data(room.id);
      return room.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<String?> joinRoomByCode({
    required String code,
    required String uid,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final roomId = await _repo.joinRoomByCode(
        code: code,
        uid: uid,
        displayName: displayName,
      );
      state = AsyncValue.data(roomId);
      return roomId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> toggleControllerRole({
    required String roomId,
    required String targetUid,
    required bool isController,
  }) async {
    await _repo.toggleControllerRole(
      roomId: roomId,
      targetUid: targetUid,
      isController: isController,
    );
  }

  Future<void> removeMember({
    required String roomId,
    required String targetUid,
  }) async {
    await _repo.removeMember(
      roomId: roomId,
      targetUid: targetUid,
    );
  }

  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) async {
    await _repo.leaveRoom(
      roomId: roomId,
      uid: uid,
    );
  }

  Future<void> removeRoomFromHistory({
    required String uid,
    required String roomId,
  }) async {
    await _repo.removeRoomFromHistory(
      uid: uid,
      roomId: roomId,
    );
  }

  Future<void> recordRoomVisit({
    required String uid,
    required String roomId,
    required String displayName,
  }) async {
    await _repo.recordRoomVisit(
      uid: uid,
      roomId: roomId,
      displayName: displayName,
    );
  }
}
