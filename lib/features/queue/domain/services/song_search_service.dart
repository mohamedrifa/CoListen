import 'package:colisten/features/playback/domain/services/player_service.dart';
import 'package:colisten/features/queue/domain/entities/queue_item_entity.dart';

class SearchTrackResult {
  final String trackId;
  final AudioSourceType sourceType;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int durationMs;

  const SearchTrackResult({
    required this.trackId,
    required this.sourceType,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.durationMs,
  });

  QueueItemEntity toQueueItem({
    required String addedBy,
    required String addedByName,
    required double order,
  }) {
    return QueueItemEntity(
      id: '',
      trackId: trackId,
      sourceType: sourceType,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
      addedBy: addedBy,
      addedByName: addedByName,
      addedAt: DateTime.now(),
      order: order,
    );
  }
}

class SongSearchService {
  // Built-in curated popular tracks with real YouTube IDs
  static const List<SearchTrackResult> curatedPicks = [
    SearchTrackResult(
      trackId: 'jfKfPfyJRdk',
      sourceType: AudioSourceType.youtube,
      title: 'Lofi Hip Hop Radio - Beats to Relax/Study to',
      artist: 'Lofi Girl',
      thumbnailUrl: 'https://img.youtube.com/vi/jfKfPfyJRdk/hqdefault.jpg',
      durationMs: 0, // Live stream
    ),
    SearchTrackResult(
      trackId: '4xDzrJKXOOY',
      sourceType: AudioSourceType.youtube,
      title: 'Synthwave Radio - Beats to Chill/Game to',
      artist: 'Lofi Girl',
      thumbnailUrl: 'https://img.youtube.com/vi/4xDzrJKXOOY/hqdefault.jpg',
      durationMs: 0,
    ),
    SearchTrackResult(
      trackId: 'fHI8X480mxo',
      sourceType: AudioSourceType.youtube,
      title: 'One More Time',
      artist: 'Daft Punk',
      thumbnailUrl: 'https://img.youtube.com/vi/fHI8X480mxo/hqdefault.jpg',
      durationMs: 320000,
    ),
    SearchTrackResult(
      trackId: 'dX3k_QDnzHE',
      sourceType: AudioSourceType.youtube,
      title: 'Midnight City',
      artist: 'M83',
      thumbnailUrl: 'https://img.youtube.com/vi/dX3k_QDnzHE/hqdefault.jpg',
      durationMs: 243000,
    ),
    SearchTrackResult(
      trackId: '4NRXx6U8ABQ',
      sourceType: AudioSourceType.youtube,
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      thumbnailUrl: 'https://img.youtube.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
      durationMs: 200000,
    ),
    SearchTrackResult(
      trackId: 'sFMRqxCexDk',
      sourceType: AudioSourceType.youtube,
      title: 'The Less I Know The Better',
      artist: 'Tame Impala',
      thumbnailUrl: 'https://img.youtube.com/vi/sFMRqxCexDk/hqdefault.jpg',
      durationMs: 216000,
    ),
    SearchTrackResult(
      trackId: 'JGwWNGJdvx8',
      sourceType: AudioSourceType.youtube,
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      thumbnailUrl: 'https://img.youtube.com/vi/JGwWNGJdvx8/hqdefault.jpg',
      durationMs: 233000,
    ),
    SearchTrackResult(
      trackId: 'kJQP7kiw5Fk',
      sourceType: AudioSourceType.youtube,
      title: 'Despacito',
      artist: 'Luis Fonsi ft. Daddy Yankee',
      thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
      durationMs: 282000,
    ),
    SearchTrackResult(
      trackId: '3JZ_D3ELwOQ',
      sourceType: AudioSourceType.youtube,
      title: 'Radioactive',
      artist: 'Imagine Dragons',
      thumbnailUrl: 'https://img.youtube.com/vi/3JZ_D3ELwOQ/hqdefault.jpg',
      durationMs: 188000,
    ),
    SearchTrackResult(
      trackId: 'YQHsXMglC9A',
      sourceType: AudioSourceType.youtube,
      title: 'Hello',
      artist: 'Adele',
      thumbnailUrl: 'https://img.youtube.com/vi/YQHsXMglC9A/hqdefault.jpg',
      durationMs: 367000,
    ),
    SearchTrackResult(
      trackId: '34Na4j8AVgA',
      sourceType: AudioSourceType.youtubeMusic,
      title: 'Starboy',
      artist: 'The Weeknd ft. Daft Punk',
      thumbnailUrl: 'https://img.youtube.com/vi/34Na4j8AVgA/hqdefault.jpg',
      durationMs: 230000,
    ),
    SearchTrackResult(
      trackId: 'TUVcZfQe-Kw',
      sourceType: AudioSourceType.youtubeMusic,
      title: 'Levitating',
      artist: 'Dua Lipa',
      thumbnailUrl: 'https://img.youtube.com/vi/TUVcZfQe-Kw/hqdefault.jpg',
      durationMs: 203000,
    ),
  ];

  static String? extractYoutubeVideoId(String url) {
    final cleanUrl = url.trim();
    // Match youtube.com/watch?v=VIDEO_ID or youtu.be/VIDEO_ID or music.youtube.com/watch?v=VIDEO_ID
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.|music\.)?(?:youtube\.com\/(?:watch\?.*v=|embed\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(cleanUrl);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  static bool isYoutubeMusicUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.contains('music.youtube.com');
  }

  Future<List<SearchTrackResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return curatedPicks;
    }

    // 1. Check if direct YouTube or YouTube Music URL was pasted
    final directId = extractYoutubeVideoId(trimmed);
    if (directId != null) {
      final isYtMusic = isYoutubeMusicUrl(trimmed);
      return [
        SearchTrackResult(
          trackId: directId,
          sourceType: isYtMusic
              ? AudioSourceType.youtubeMusic
              : AudioSourceType.youtube,
          title: isYtMusic
              ? 'YouTube Music Track ($directId)'
              : 'YouTube Track ($directId)',
          artist: isYtMusic ? 'YouTube Music' : 'Direct YouTube Link',
          thumbnailUrl: 'https://img.youtube.com/vi/$directId/hqdefault.jpg',
          durationMs: 210000,
        ),
      ];
    }

    // 2. Search against curated catalog
    final queryLower = trimmed.toLowerCase();
    final results = curatedPicks.where((track) {
      return track.title.toLowerCase().contains(queryLower) ||
          track.artist.toLowerCase().contains(queryLower);
    }).toList();

    // 3. Fallback: if query is a plain 11-char ID or custom search term
    if (results.isEmpty) {
      if (trimmed.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
        return [
          SearchTrackResult(
            trackId: trimmed,
            sourceType: AudioSourceType.youtube,
            title: 'YouTube Track ($trimmed)',
            artist: 'YouTube Video ID',
            thumbnailUrl: 'https://img.youtube.com/vi/$trimmed/hqdefault.jpg',
            durationMs: 210000,
          ),
        ];
      }

      // Generate a dynamic YouTube search result from the query
      return [
        SearchTrackResult(
          trackId: 'jfKfPfyJRdk', // Default audio fallback
          sourceType: AudioSourceType.youtube,
          title: trimmed,
          artist: 'Search Result',
          thumbnailUrl: 'https://img.youtube.com/vi/jfKfPfyJRdk/hqdefault.jpg',
          durationMs: 180000,
        ),
      ];
    }

    return results;
  }
}
