import '../services/player_service.dart';

class PlaybackStateEntity {
  final String currentItemId;
  final String trackId;
  final AudioSourceType sourceType;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int durationMs;
  final String status; // 'playing' | 'paused' | 'buffering'
  final int positionMs;
  final DateTime updatedAt;
  final String updatedBy;

  const PlaybackStateEntity({
    required this.currentItemId,
    required this.trackId,
    this.sourceType = AudioSourceType.youtube,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.status,
    required this.positionMs,
    required this.updatedAt,
    required this.updatedBy,
  });

  bool get isPlaying => status == 'playing';
  bool get isPaused => status == 'paused';
  bool get isBuffering => status == 'buffering';
  bool get hasTrack => trackId.isNotEmpty;

  factory PlaybackStateEntity.empty() {
    return PlaybackStateEntity.fromMap(null);
  }

  Duration computeExpectedPosition(DateTime serverNow) {
    if (status != 'playing') {
      return Duration(milliseconds: positionMs);
    }
    final elapsedMs = serverNow.difference(updatedAt).inMilliseconds;
    final totalMs = positionMs + (elapsedMs > 0 ? elapsedMs : 0);
    if (durationMs > 0 && totalMs > durationMs) {
      return Duration(milliseconds: durationMs);
    }
    return Duration(milliseconds: totalMs);
  }

  Map<String, dynamic> toMap() {
    return {
      'currentItemId': currentItemId,
      'trackId': trackId,
      'sourceType': sourceType.name,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': durationMs,
      'status': status,
      'positionMs': positionMs,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
    };
  }

  factory PlaybackStateEntity.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return PlaybackStateEntity(
        currentItemId: '',
        trackId: '',
        sourceType: AudioSourceType.youtube,
        title: '',
        artist: '',
        thumbnailUrl: '',
        durationMs: 0,
        status: 'paused',
        positionMs: 0,
        updatedAt: DateTime.now(),
        updatedBy: '',
      );
    }

    return PlaybackStateEntity(
      currentItemId: map['currentItemId'] as String? ?? '',
      trackId: map['trackId'] as String? ?? '',
      sourceType: AudioSourceType.fromString(map['sourceType'] as String?),
      title: map['title'] as String? ?? 'No Track Playing',
      artist: map['artist'] as String? ?? 'Choose a song from queue',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      durationMs: map['durationMs'] as int? ?? 0,
      status: map['status'] as String? ?? 'paused',
      positionMs: map['positionMs'] as int? ?? 0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
      updatedBy: map['updatedBy'] as String? ?? '',
    );
  }

  PlaybackStateEntity copyWith({
    String? currentItemId,
    String? trackId,
    AudioSourceType? sourceType,
    String? title,
    String? artist,
    String? thumbnailUrl,
    int? durationMs,
    String? status,
    int? positionMs,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return PlaybackStateEntity(
      currentItemId: currentItemId ?? this.currentItemId,
      trackId: trackId ?? this.trackId,
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      positionMs: positionMs ?? this.positionMs,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
