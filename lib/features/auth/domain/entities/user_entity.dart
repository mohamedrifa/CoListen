class UserEntity {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? email;
  final bool isAnonymous;

  const UserEntity({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.email,
    this.isAnonymous = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'email': email,
      'isAnonymous': isAnonymous,
    };
  }

  factory UserEntity.fromMap(Map<dynamic, dynamic> map, String uid) {
    return UserEntity(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Listener',
      photoUrl: map['photoUrl'] as String?,
      email: map['email'] as String?,
      isAnonymous: map['isAnonymous'] as bool? ?? false,
    );
  }

  UserEntity copyWith({
    String? displayName,
    String? photoUrl,
    String? email,
  }) {
    return UserEntity(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      isAnonymous: isAnonymous,
    );
  }
}
