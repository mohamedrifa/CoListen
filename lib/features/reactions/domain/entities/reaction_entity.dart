class ReactionEntity {
  final String id;
  final String uid;
  final String displayName;
  final String emoji;
  final DateTime createdAt;

  const ReactionEntity({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.emoji,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'emoji': emoji,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ReactionEntity.fromMap(String id, Map<dynamic, dynamic> map) {
    return ReactionEntity(
      id: id,
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Listener',
      emoji: map['emoji'] as String? ?? '🔥',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }
}
