import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserPresence {
  final String uid;
  final String displayName;
  final bool isOnline;
  final DateTime lastSeen;
  final String clientState;

  const UserPresence({
    required this.uid,
    required this.displayName,
    required this.isOnline,
    required this.lastSeen,
    this.clientState = 'idle',
  });

  factory UserPresence.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserPresence(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Listener',
      isOnline: map['online'] as bool? ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int)
          : DateTime.now(),
      clientState: map['clientState'] as String? ?? 'idle',
    );
  }
}

class PresenceService {
  final FirebaseDatabase? _database;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  String? _activeRoomId;
  String? _activeUid;
  String? _activeDisplayName;

  // ignore: prefer_initializing_formals
  PresenceService({FirebaseDatabase? database}) : _database = database;

  FirebaseDatabase? get _db {
    if (_database != null) return _database;
    if (Firebase.apps.isNotEmpty) return FirebaseDatabase.instance;
    return null;
  }

  void startHeartbeat({
    required String roomId,
    required String uid,
    required String displayName,
  }) {
    _activeRoomId = roomId;
    _activeUid = uid;
    _activeDisplayName = displayName;

    final db = _db;
    if (db == null) return;

    _connectedSubscription?.cancel();
    _connectedSubscription = db.ref('.info/connected').onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (isConnected && _activeRoomId != null && _activeUid != null) {
        final presenceRef = db.ref('presence/$_activeRoomId/$_activeUid');

        // On disconnect, mark offline
        presenceRef.onDisconnect().update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });

        // Set online
        presenceRef.update({
          'online': true,
          'displayName': _activeDisplayName,
          'lastSeen': ServerValue.timestamp,
          'clientState': 'playing',
        });
      }
    });
  }

  Future<void> stopHeartbeat() async {
    final db = _db;
    if (db != null && _activeRoomId != null && _activeUid != null) {
      final presenceRef = db.ref('presence/$_activeRoomId/$_activeUid');
      await presenceRef.onDisconnect().cancel();
      await presenceRef.update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
    }

    await _connectedSubscription?.cancel();
    _connectedSubscription = null;
    _activeRoomId = null;
    _activeUid = null;
    _activeDisplayName = null;
  }

  Stream<Map<String, UserPresence>> watchRoomPresence(String roomId) {
    final db = _db;
    if (db == null) return Stream.value({});
    return db.ref('presence/$roomId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return {};

      final result = <String, UserPresence>{};
      data.forEach((key, val) {
        if (val is Map) {
          result[key.toString()] = UserPresence.fromMap(key.toString(), val);
        }
      });
      return result;
    });
  }
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService();
});

final roomPresenceProvider =
    StreamProvider.family<Map<String, UserPresence>, String>((ref, roomId) {
  final service = ref.watch(presenceServiceProvider);
  return service.watchRoomPresence(roomId);
});
