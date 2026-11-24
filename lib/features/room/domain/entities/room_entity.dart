enum UserRole {
  host,
  controller,
  listener;

  String get label {
    switch (this) {
      case UserRole.host:
        return 'Host';
      case UserRole.controller:
        return 'DJ / Controller';
      case UserRole.listener:
        return 'Listener';
    }
  }

  String get icon {
    switch (this) {
      case UserRole.host:
        return '👑';
      case UserRole.controller:
        return '🎛️';
      case UserRole.listener:
        return '🎧';
    }
  }
}

class RoomSettings {
  final bool membersCanAddSongs;
  final bool membersCanVoteSkip;
  final int voteSkipThresholdPercent;
  final bool isPrivate;

  const RoomSettings({
    this.membersCanAddSongs = true,
    this.membersCanVoteSkip = true,
    this.voteSkipThresholdPercent = 50,
    this.isPrivate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'membersCanAddSongs': membersCanAddSongs,
      'membersCanVoteSkip': membersCanVoteSkip,
      'voteSkipThresholdPercent': voteSkipThresholdPercent,
      'isPrivate': isPrivate,
    };
  }

  factory RoomSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const RoomSettings();
    return RoomSettings(
      membersCanAddSongs: map['membersCanAddSongs'] as bool? ?? true,
      membersCanVoteSkip: map['membersCanVoteSkip'] as bool? ?? true,
      voteSkipThresholdPercent:
          map['voteSkipThresholdPercent'] as int? ?? 50,
      isPrivate: map['isPrivate'] as bool? ?? false,
    );
  }
}

class RoomMemberEntity {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final bool isController;
  final DateTime joinedAt;

  const RoomMemberEntity({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.isController = false,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isController': isController,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }

  factory RoomMemberEntity.fromMap(String uid, Map<dynamic, dynamic> map) {
    return RoomMemberEntity(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Listener',
      photoUrl: map['photoUrl'] as String?,
      isController: map['isController'] as bool? ?? false,
      joinedAt: map['joinedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int)
          : DateTime.now(),
    );
  }
}

class RoomEntity {
  final String id;
  final String code;
  final String name;
  final String adminId;
  final DateTime createdAt;
  final bool isActive;
  final RoomSettings settings;
  final Map<String, RoomMemberEntity> members;

  const RoomEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.adminId,
    required this.createdAt,
    this.isActive = true,
    this.settings = const RoomSettings(),
    this.members = const {},
  });

  UserRole getRole(String uid) {
    if (uid == adminId) return UserRole.host;
    final member = members[uid];
    if (member != null && member.isController) return UserRole.controller;
    return UserRole.listener;
  }

  bool canChangeSongs(String uid) {
    final role = getRole(uid);
    return role == UserRole.host || role == UserRole.controller;
  }

  bool canAddSongs(String uid) {
    if (canChangeSongs(uid)) return true;
    return settings.membersCanAddSongs;
  }

  factory RoomEntity.fromMap(String id, Map<dynamic, dynamic> map) {
    final membersMap = <String, RoomMemberEntity>{};
    if (map['members'] != null && map['members'] is Map) {
      (map['members'] as Map).forEach((key, val) {
        if (val is Map) {
          membersMap[key.toString()] =
              RoomMemberEntity.fromMap(key.toString(), val);
        }
      });
    }

    return RoomEntity(
      id: id,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled Room',
      adminId: map['adminId'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
      settings: RoomSettings.fromMap(map['settings'] as Map?),
      members: membersMap,
    );
  }
}
