class InviteEntity {
  final String id;
  final String fromUid;
  final String fromName;
  final String roomId;
  final String roomName;
  final String roomCode;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime createdAt;

  const InviteEntity({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.roomId,
    required this.roomName,
    required this.roomCode,
    this.status = 'pending',
    required this.createdAt,
  });

  factory InviteEntity.fromMap(String id, Map<dynamic, dynamic> map) {
    return InviteEntity(
      id: id,
      fromUid: map['fromUid'] as String? ?? '',
      fromName: map['fromName'] as String? ?? 'A friend',
      roomId: map['roomId'] as String? ?? '',
      roomName: map['roomName'] as String? ?? 'Music Room',
      roomCode: map['roomCode'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }
}
