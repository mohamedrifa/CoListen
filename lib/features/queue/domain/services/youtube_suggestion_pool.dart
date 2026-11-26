import 'dart:math';
import 'package:colisten/features/playback/domain/services/player_service.dart';
import 'package:colisten/features/queue/domain/services/song_search_service.dart';

/// Manages YouTube track recommendations and logged-in user playlist suggestions
/// for continuous, interruption-free autoplay when the room queue runs empty.
class YouTubeSuggestionPool {
  static final List<SearchTrackResult> _userPlaylistSuggestions = [];
  static final Set<String> _playedTrackIds = {};
  static final _random = Random();

  /// Callback registered by NowPlayingView to dispatch dynamic recommendation fetch
  /// into the active YouTube or YouTube Music WebView with user's login session.
  static void Function(
    String videoId,
    String title,
    String artist,
    AudioSourceType sourceType,
  )? suggestionRequestHandler;

  /// Requests dynamic suggestions based on the last played track
  static void requestDynamicSuggestions({
    required String trackId,
    required String title,
    required String artist,
    required AudioSourceType sourceType,
  }) {
    suggestionRequestHandler?.call(trackId, title, artist, sourceType);
  }

  /// Updates the pool with tracks extracted from YouTube or YouTube Music Hub
  /// (e.g. from user's logged-in playlist, up next, or personal recommendations)
  static void updateSuggestions(
    List<Map<String, dynamic>> rawItems, [
    AudioSourceType sourceType = AudioSourceType.youtube,
  ]) {
    for (final item in rawItems) {
      final videoId = item['videoId'] as String?;
      final title = item['title'] as String?;
      final artist = item['artist'] as String? ??
          (sourceType == AudioSourceType.youtubeMusic
              ? 'YouTube Music'
              : 'YouTube Recommendation');
      if (videoId != null &&
          videoId.isNotEmpty &&
          !_userPlaylistSuggestions.any((s) => s.trackId == videoId)) {
        _userPlaylistSuggestions.add(
          SearchTrackResult(
            trackId: videoId,
            sourceType: sourceType,
            title: title ??
                (sourceType == AudioSourceType.youtubeMusic
                    ? 'YouTube Music Track'
                    : 'YouTube Suggestion'),
            artist: artist,
            thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
            durationMs: 210000,
          ),
        );
      }
    }
  }

  /// Asynchronously retrieves the next autoplay track, requesting fresh
  /// user-login suggestions based on the last played song if the pool is running low.
  static Future<SearchTrackResult?> getNextAutoplayTrackAsync({
    String? currentTrackId,
    String? currentArtist,
    String? currentTitle,
    AudioSourceType sourceType = AudioSourceType.youtubeMusic,
  }) async {
    // 1. Request fresh suggestions from logged-in session based on current song
    if (currentTrackId != null && currentTrackId.isNotEmpty) {
      requestDynamicSuggestions(
        trackId: currentTrackId,
        title: currentTitle ?? '',
        artist: currentArtist ?? '',
        sourceType: sourceType,
      );
      // Brief grace period for WebView bridge to deliver results
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return getNextAutoplayTrack(
      currentTrackId: currentTrackId,
      currentArtist: currentArtist,
      currentTitle: currentTitle,
      sourceType: sourceType,
    );
  }

  /// Gets the next track to autoplay when the room queue has finished
  static SearchTrackResult? getNextAutoplayTrack({
    String? currentTrackId,
    String? currentArtist,
    String? currentTitle,
    AudioSourceType? sourceType,
  }) {
    if (currentTrackId != null && currentTrackId.isNotEmpty) {
      _playedTrackIds.add(currentTrackId);
    }

    // 1. Prioritize unplayed tracks matching the current source type & artist from user suggestions
    if (currentArtist != null && currentArtist.isNotEmpty) {
      final artistNorm = currentArtist.toLowerCase();
      final artistMatch = _userPlaylistSuggestions.firstWhere(
        (s) =>
            s.trackId != currentTrackId &&
            !_playedTrackIds.contains(s.trackId) &&
            s.artist.toLowerCase().contains(artistNorm),
        orElse: () => _userPlaylistSuggestions.firstWhere(
          (s) =>
              s.trackId != currentTrackId &&
              !_playedTrackIds.contains(s.trackId),
          orElse: () => const SearchTrackResult(
            trackId: '',
            sourceType: AudioSourceType.youtube,
            title: '',
            artist: '',
            thumbnailUrl: '',
            durationMs: 0,
          ),
        ),
      );
      if (artistMatch.trackId.isNotEmpty) {
        _playedTrackIds.add(artistMatch.trackId);
        return artistMatch;
      }
    }

    // 2. Any unplayed tracks from the user's logged-in YouTube playlist / suggestions
    for (final suggestion in _userPlaylistSuggestions) {
      if (suggestion.trackId != currentTrackId &&
          !_playedTrackIds.contains(suggestion.trackId)) {
        _playedTrackIds.add(suggestion.trackId);
        return suggestion;
      }
    }

    // 3. Fallback to unplayed curated tracks from SongSearchService
    final unplayedCurated = SongSearchService.curatedPicks
        .where((s) => s.trackId != currentTrackId && !_playedTrackIds.contains(s.trackId))
        .toList();

    if (unplayedCurated.isNotEmpty) {
      final chosen = unplayedCurated[_random.nextInt(unplayedCurated.length)];
      _playedTrackIds.add(chosen.trackId);
      return chosen;
    }

    // 4. Reset history if all curated tracks have been played once, then cycle
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
