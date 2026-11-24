import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/room_entity.dart';
import '../../domain/repositories/room_repository.dart';

class RoomRepositoryImpl implements RoomRepository {
  final FirebaseDatabase _database;
  final Random _random;

  RoomRepositoryImpl({FirebaseDatabase? database, Random? random})
      : _database = database ?? FirebaseDatabase.instance,
        _random = random ?? Random.secure();

  String _generateRoomCode() {
    final chars = AppConstants.roomCodeCharset;
    return List.generate(
      AppConstants.roomCodeLength,
      (index) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  @override
  Future<RoomEntity> createRoom({
    required String name,
    required String adminId,
    required String adminName,
    required RoomSettings settings,
  }) async {
    // Generate unique 6-character code with collision check
    String code = '';
    String? existingRoom;
    int attempts = 0;

    do {
      code = _generateRoomCode();
      final codeSnap = await _database.ref('roomCodes/$code').get();
      existingRoom = codeSnap.value as String?;
      attempts++;
    } while (existingRoom != null && attempts < 5);

    if (existingRoom != null) {
      throw Exception('Failed to generate a unique room code. Please try again.');
    }

    final roomRef = _database.ref('rooms').push();
    final roomId = roomRef.key!;
    final now = DateTime.now();

    final updates = <String, dynamic>{
      'roomCodes/$code': roomId,
      'rooms/$roomId': {
        'code': code,
        'name': name.trim().isEmpty ? 'Late Night Music Room' : name.trim(),
        'adminId': adminId,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
        'settings': settings.toMap(),
        'members': {
          adminId: {
            'displayName': adminName,
            'isController': true,
            'joinedAt': ServerValue.timestamp,
          },
        },
        'playback': {
          'status': 'paused',
          'positionMs': 0,
          'trackId': '',
          'updatedAt': ServerValue.timestamp,
          'updatedBy': adminId,
        },
      },
    };

    await _database.ref().update(updates);

    return RoomEntity(
      id: roomId,
      code: code,
      name: name.trim().isEmpty ? 'Late Night Music Room' : name.trim(),
      adminId: adminId,
      createdAt: now,
      isActive: true,
      settings: settings,
      members: {
        adminId: RoomMemberEntity(
          uid: adminId,
          displayName: adminName,
          isController: true,
          joinedAt: now,
        ),
      },
    );
  }

  @override
  Future<String> joinRoomByCode({
    required String code,
    required String uid,
    required String displayName,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != AppConstants.roomCodeLength) {
      throw Exception('Invalid room code length. Must be 6 characters.');
    }

    final codeSnap = await _database.ref('roomCodes/$cleanCode').get();
    final roomId = codeSnap.value as String?;

    if (roomId == null) {
      throw Exception('Room code "$cleanCode" was not found.');
    }

    final roomSnap = await _database.ref('rooms/$roomId').get();
    if (!roomSnap.exists) {
      throw Exception('This room is no longer available.');
    }

    final roomData = roomSnap.value as Map<dynamic, dynamic>;
    final isActive = roomData['isActive'] as bool? ?? false;
    if (!isActive) {
      throw Exception('This room has ended.');
    }

    // Add user as listener member
    await _database.ref('rooms/$roomId/members/$uid').update({
      'displayName': displayName,
      'isController': false,
      'joinedAt': ServerValue.timestamp,
    });

    return roomId;
  }

  @override
  Stream<RoomEntity?> watchRoom(String roomId) {
    return _database.ref('rooms/$roomId').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null || val is! Map) return null;
      return RoomEntity.fromMap(roomId, val);
    });
  }

  @override
  Future<void> toggleControllerRole({
    required String roomId,
    required String targetUid,
    required bool isController,
  }) async {
    await _database.ref('rooms/$roomId/members/$targetUid/isController').set(isController);
  }

  @override
  Future<void> removeMember({
    required String roomId,
    required String targetUid,
  }) async {
    await _database.ref('rooms/$roomId/members/$targetUid').remove();
    await _database.ref('presence/$roomId/$targetUid').remove();
  }

  @override
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) async {
    final roomSnap = await _database.ref('rooms/$roomId').get();
    if (!roomSnap.exists) return;

    final roomData = roomSnap.value as Map<dynamic, dynamic>;
    final adminId = roomData['adminId'] as String?;
    final members = roomData['members'] as Map<dynamic, dynamic>? ?? {};

    // Remove user from room and presence
    await _database.ref('rooms/$roomId/members/$uid').remove();
    await _database.ref('presence/$roomId/$uid').remove();

    // If leaving user is the host/admin
    if (adminId == uid) {
      // Find remaining members
      final remaining = members.keys.where((k) => k != uid).toList();
      if (remaining.isEmpty) {
        // No members left -> end room
        await _database.ref('rooms/$roomId/isActive').set(false);
      } else {
        // Transfer host to first remaining member
        final newAdminId = remaining.first.toString();
        await _database.ref('rooms/$roomId').update({
          'adminId': newAdminId,
          'members/$newAdminId/isController': true,
        });
      }
    }
  }
}
