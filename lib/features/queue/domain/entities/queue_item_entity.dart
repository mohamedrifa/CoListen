import 'package:colisten/features/playback/domain/services/player_service.dart';

class QueueItemEntity {
  final String id;
  final String trackId;
  final AudioSourceType sourceType;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int durationMs;
  final String addedBy;
  final String addedByName;
  final DateTime addedAt;
  final double order;
  final Map<String, bool> voteSkipUids;

  const QueueItemEntity({
    required this.id,
    required this.trackId,
    this.sourceType = AudioSourceType.youtube,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.addedBy,
    required this.addedByName,
    required this.addedAt,
    required this.order,
    this.voteSkipUids = const {},
  });

  int get voteSkipCount => voteSkipUids.length;

  bool hasUserVoted(String uid) => voteSkipUids[uid] == true;

  bool shouldSkip(int totalMembers, int thresholdPercent) {
    if (totalMembers <= 0) return false;
    final votePercentage = (voteSkipCount / totalMembers) * 100;
    return votePercentage >= thresholdPercent;
  }

  String get formattedDuration {
    final minutes = (durationMs ~/ 60000);
    final seconds = ((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'sourceType': sourceType.name,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': durationMs,
      'addedBy': addedBy,
      'addedByName': addedByName,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'order': order,
      'voteSkipUids': voteSkipUids,
    };
  }

  factory QueueItemEntity.fromMap(String id, Map<dynamic, dynamic> map) {
    final votes = <String, bool>{};
    if (map['voteSkipUids'] != null && map['voteSkipUids'] is Map) {
      (map['voteSkipUids'] as Map).forEach((k, v) {
        if (v == true) votes[k.toString()] = true;
      });
    }

    return QueueItemEntity(
      id: id,
      trackId: map['trackId'] as String? ?? '',
      sourceType: AudioSourceType.fromString(map['sourceType'] as String?),
      title: map['title'] as String? ?? 'Untitled Track',
      artist: map['artist'] as String? ?? 'Unknown Artist',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      durationMs: map['durationMs'] as int? ?? 0,
      addedBy: map['addedBy'] as String? ?? '',
      addedByName: map['addedByName'] as String? ?? 'Listener',
      addedAt: map['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int)
          : DateTime.now(),
      order: (map['order'] as num?)?.toDouble() ?? 1.0,
      voteSkipUids: votes,
    );
  }

  QueueItemEntity copyWith({
    String? id,
    String? trackId,
    AudioSourceType? sourceType,
    String? title,
    String? artist,
    String? thumbnailUrl,
    int? durationMs,
    String? addedBy,
    String? addedByName,
    DateTime? addedAt,
    double? order,
    Map<String, bool>? voteSkipUids,
  }) {
    return QueueItemEntity(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      addedBy: addedBy ?? this.addedBy,
      addedByName: addedByName ?? this.addedByName,
      addedAt: addedAt ?? this.addedAt,
      order: order ?? this.order,
      voteSkipUids: voteSkipUids ?? this.voteSkipUids,
    );
  }
}
