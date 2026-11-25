class RoomHistoryEntity {
  final String roomId;
  final String code;
  final String name;
  final String adminId;
  final String adminName;
  final String role; // 'Host' or 'Listener'
  final DateTime joinedAt;
  final DateTime lastVisitedAt;

  const RoomHistoryEntity({
    required this.roomId,
    required this.code,
    required this.name,
    required this.adminId,
    required this.adminName,
    required this.role,
    required this.joinedAt,
    required this.lastVisitedAt,
  });

  bool get isHost => role.toLowerCase() == 'host';

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'code': code,
      'name': name,
      'adminId': adminId,
      'adminName': adminName,
      'role': role,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'lastVisitedAt': lastVisitedAt.millisecondsSinceEpoch,
    };
  }

  factory RoomHistoryEntity.fromMap(String id, Map<dynamic, dynamic> map) {
    return RoomHistoryEntity(
      roomId: map['roomId'] as String? ?? id,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? 'Music Room',
      adminId: map['adminId'] as String? ?? '',
      adminName: map['adminName'] as String? ?? 'Host',
      role: map['role'] as String? ?? 'Listener',
      joinedAt: map['joinedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int)
          : DateTime.now(),
      lastVisitedAt: map['lastVisitedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastVisitedAt'] as int)
          : DateTime.now(),
    );
  }
}
