import 'dart:math';
import 'package:colisten/features/playback/domain/services/player_service.dart';
import 'package:colisten/features/queue/domain/services/song_search_service.dart';

/// Manages YouTube track recommendations and logged-in user playlist suggestions
/// for continuous, interruption-free autoplay when the room queue runs empty.
class YouTubeSuggestionPool {
  static final List<SearchTrackResult> _userPlaylistSuggestions = [];
  static final Set<String> _playedTrackIds = {};
  static final _random = Random();

  /// Updates the pool with tracks extracted from YouTube Hub
  /// (e.g. from user's logged-in playlist, up next, or personal recommendations)
  static void updateSuggestions(List<Map<String, dynamic>> rawItems) {
    for (final item in rawItems) {
      final videoId = item['videoId'] as String?;
      final title = item['title'] as String?;
      if (videoId != null &&
          videoId.isNotEmpty &&
          !_userPlaylistSuggestions.any((s) => s.trackId == videoId)) {
        _userPlaylistSuggestions.add(
          SearchTrackResult(
            trackId: videoId,
            sourceType: AudioSourceType.youtube,
            title: title ?? 'YouTube Suggestion',
            artist: 'YouTube Recommendation',
            thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
            durationMs: 210000,
          ),
        );
      }
    }
  }

  /// Gets the next track to autoplay when the room queue has finished
  static SearchTrackResult? getNextAutoplayTrack({
    String? currentTrackId,
    String? currentArtist,
    String? currentTitle,
  }) {
    if (currentTrackId != null && currentTrackId.isNotEmpty) {
      _playedTrackIds.add(currentTrackId);
    }

    // 1. Prioritize unplayed tracks from the user's logged-in YouTube playlist / suggestions
    for (final suggestion in _userPlaylistSuggestions) {
      if (suggestion.trackId != currentTrackId &&
          !_playedTrackIds.contains(suggestion.trackId)) {
        _playedTrackIds.add(suggestion.trackId);
        return suggestion;
      }
    }

    // 2. Fallback to unplayed curated tracks from SongSearchService
    final unplayedCurated = SongSearchService.curatedPicks
        .where((s) => s.trackId != currentTrackId && !_playedTrackIds.contains(s.trackId))
        .toList();

    if (unplayedCurated.isNotEmpty) {
      final chosen = unplayedCurated[_random.nextInt(unplayedCurated.length)];
      _playedTrackIds.add(chosen.trackId);
      return chosen;
    }

    // 3. Reset history if all curated tracks have been played once, then cycle
    _playedTrackIds.clear();
    if (currentTrackId != null) _playedTrackIds.add(currentTrackId);

    final anyCurated = SongSearchService.curatedPicks
        .where((s) => s.trackId != currentTrackId)
        .toList();

    if (anyCurated.isNotEmpty) {
      final chosen = anyCurated[_random.nextInt(anyCurated.length)];
      _playedTrackIds.add(chosen.trackId);
      return chosen;
    }

    return null;
  }

  static void clear() {
    _userPlaylistSuggestions.clear();
    _playedTrackIds.clear();
  }
}
