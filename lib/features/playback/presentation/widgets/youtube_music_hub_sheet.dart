import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../queue/domain/entities/queue_item_entity.dart';
import '../../../queue/domain/services/song_search_service.dart';
import '../../../queue/domain/services/youtube_suggestion_pool.dart';
import '../../../queue/presentation/providers/queue_providers.dart';
import '../../../room/domain/entities/room_entity.dart';
import '../../domain/entities/playback_state_entity.dart';
import '../../domain/services/player_service.dart';
import '../providers/playback_sync_provider.dart';

class YouTubeMusicHubSheet extends ConsumerStatefulWidget {
  final RoomEntity room;
  final bool isEmbedded;
  final String? initialVideoId;
  final VoidCallback? onSwitchToAppPlayer;

  const YouTubeMusicHubSheet({
    super.key,
    required this.room,
    this.isEmbedded = false,
    this.initialVideoId,
    this.onSwitchToAppPlayer,
  });

  @override
  ConsumerState<YouTubeMusicHubSheet> createState() =>
      YouTubeMusicHubSheetState();
}

class YouTubeMusicHubSheetState extends ConsumerState<YouTubeMusicHubSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _detectedVideoId;
  String? _detectedVideoTitle;
  String? _detectedVideoArtist;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _lastHandledVideoId;
  DateTime? _lastHandledTime;

  /// Dynamically queries YouTube Music's logged-in recommendation API and dashboard
  /// for next songs based on the specified last played track.
  void fetchSuggestionsFor(String videoId, String title, String artist) {
    if (WebViewPlatform.instance == null) return;
    try {
      final safeArtist = artist.replaceAll("'", r"\'").replaceAll('"', r'\"');
      _controller.runJavaScript('''
        (function() {
          try {
            const key = (window.ytcfg && window.ytcfg.data_ && window.ytcfg.data_.INNERTUBE_API_KEY) || '';
            const ctx = (window.ytcfg && window.ytcfg.data_ && window.ytcfg.data_.INNERTUBE_CONTEXT) || {};
            if (key && ctx) {
              fetch('/youtubei/v1/next?key=' + key, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ context: ctx, videoId: '$videoId' })
              })
              .then(r => r.json())
              .then(d => {
                const list = [];
                try {
                  const tabs = d?.contents?.singleColumnMusicWatchNextResultsRenderer?.tabbedRenderer?.watchNextTabbedResultsRenderer?.tabs;
                  const queueTab = tabs?.find(t => t?.tabRenderer?.content?.musicQueueRenderer);
                  const contents = queueTab?.tabRenderer?.content?.musicQueueRenderer?.content?.playlistPanelRenderer?.contents;
                  if (contents && contents.length > 0) {
                    contents.forEach(c => {
                      const r = c.playlistPanelVideoRenderer;
                      if (r && r.videoId && r.videoId !== '$videoId') {
                        const t = r.title?.runs?.[0]?.text || '';
                        const a = r.shortBylineText?.runs?.[0]?.text || '$safeArtist';
                        if (t) list.push({ videoId: r.videoId, title: t, artist: a });
                      }
                    });
                  }
                } catch(e) {}
                if (list.length > 0 && window.CoListenBridge) {
                  window.CoListenBridge.postMessage(JSON.stringify({
                    type: 'SUGGESTIONS_EXTRACTED',
                    items: list.slice(0, 15)
                  }));
                }
              }).catch(function(){});
            }
          } catch(e) {}

          // Also trigger visible dashboard suggestion extraction
          if (typeof extractAutoplaySuggestions === 'function') {
            extractAutoplaySuggestions();
          }
        })();
      ''');
    } catch (_) {}
  }

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) {
      _initWebViewController();
    }
  }

  void _initWebViewController() {
    const initialUrl = 'https://music.youtube.com';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              final host = uri.host.toLowerCase();
              if (host == 'm.youtube.com' ||
                  host == 'www.youtube.com' ||
                  host == 'youtube.com') {
                _controller.loadRequest(Uri.parse('https://music.youtube.com'));
                return;
              }
            }
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
              _checkNavigationState();
              _inspectUrlForVideo(url);
              _injectInterceptionAndAdBlocker();
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _checkNavigationState();
              _inspectUrlForVideo(url);
              _injectInterceptionAndAdBlocker();
            }
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith('vnd.youtube') ||
                request.url.startsWith('intent://')) {
              return NavigationDecision.prevent;
            }

            // Prevent redirecting out of music.youtube.com to m.youtube.com
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              final host = uri.host.toLowerCase();
              if (host == 'm.youtube.com' ||
                  host == 'www.youtube.com' ||
                  host == 'youtube.com') {
                final vId = SongSearchService.extractYoutubeVideoId(request.url);
                if (vId != null && vId.isNotEmpty) {
                  _handleVideoTap(vId, _detectedVideoTitle ?? 'YouTube Music Track');
                } else {
                  _controller.loadRequest(Uri.parse('https://music.youtube.com'));
                }
                return NavigationDecision.prevent;
              }
            }

            final vId = SongSearchService.extractYoutubeVideoId(request.url);
            if (vId != null &&
                vId.isNotEmpty &&
                request.url.contains('music.youtube.com/watch')) {
              _controller.runJavaScript(
                'document.querySelectorAll("video, audio").forEach(v => { try { v.pause(); v.muted = true; } catch(e){} });',
              );
              _handleVideoTap(
                vId,
                _detectedVideoTitle ?? 'YouTube Music Track',
                artist: _detectedVideoArtist,
              );
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'CoListenBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  Future<void> _checkNavigationState() async {
    final back = await _controller.canGoBack();
    final fwd = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = fwd;
      });
    }
  }

  void _inspectUrlForVideo(String url) {
    final videoId = SongSearchService.extractYoutubeVideoId(url);
    if (videoId != null && videoId.isNotEmpty) {
      setState(() {
        _detectedVideoId = videoId;
      });
      _controller.runJavaScriptReturningResult('document.title').then((value) {
        if (mounted && value is String && value.isNotEmpty) {
          var cleanTitle = value.replaceAll('"', '').trim();
          if (cleanTitle.endsWith('- YouTube Music')) {
            cleanTitle = cleanTitle.replaceAll('- YouTube Music', '').trim();
          } else if (cleanTitle.endsWith('- YouTube')) {
            cleanTitle = cleanTitle.replaceAll('- YouTube', '').trim();
          }
          if (cleanTitle.isNotEmpty) {
            setState(() => _detectedVideoTitle = cleanTitle);
          }
        }
      });
    } else {
      if (_detectedVideoId != null) {
        setState(() {
          _detectedVideoId = null;
          _detectedVideoTitle = null;
          _detectedVideoArtist = null;
        });
      }
    }
  }

  void _injectInterceptionAndAdBlocker() {
    try {
      _controller.runJavaScript(r'''
        (function() {
          // 0. Ensure responsive viewport on mobile
          try {
            var vp = document.querySelector('meta[name="viewport"]');
            if (!vp) {
              vp = document.createElement('meta');
              vp.name = 'viewport';
              document.head.appendChild(vp);
            }
            vp.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=2.0, user-scalable=yes');
          } catch(e) {}

          // 0.1 Clean Non-Destructive Mobile CSS (Preserves YouTube Music layout & virtual scrolling)
          function injectMobileStyles() {
            try {
              var styleId = 'colisten-ytmusic-responsive';
              if (!document.getElementById(styleId)) {
                var style = document.createElement('style');
                style.id = styleId;
                style.textContent = `
                  /* 1. Prevent root horizontal scrolling */
                  html, body {
                    overflow-x: hidden !important;
                    overscroll-behavior-x: none !important;
                    max-width: 100vw !important;
                  }

                  /* 2. Hide bulky fixed bottom desktop player bar so room player is unobstructed */
                  ytmusic-player-bar,
                  #player-bar-background,
                  ytmusic-app-layout > [slot="player-bar"] {
                    display: none !important;
                    height: 0 !important;
                    visibility: hidden !important;
                  }

                  /* 3. Responsive Watch Player Page (Up Next, Lyrics, Queue) */
                  ytmusic-player-page {
                    max-width: 100vw !important;
                    width: 100% !important;
                    box-sizing: border-box !important;
                    overflow-x: hidden !important;
                  }
                  ytmusic-player-page #main-panel {
                    max-height: 220px !important;
                  }
                  ytmusic-player-page #player {
                    max-height: 200px !important;
                  }

                  /* 4. Hide desktop side nav guide so main content uses full width */
                  #guide,
                  ytmusic-guide-renderer,
                  ytmusic-app-layout[is-guide-open] #guide {
                    display: none !important;
                    width: 0 !important;
                    visibility: hidden !important;
                  }

                  /* 5. Mobile responsive content container */
                  ytmusic-app-layout #content {
                    margin-left: 0 !important;
                    padding: 0 4px 80px 4px !important;
                    width: 100% !important;
                    max-width: 100vw !important;
                    box-sizing: border-box !important;
                    overflow-y: auto !important;
                    -webkit-overflow-scrolling: touch !important;
                  }

                  ytmusic-browse-response {
                    padding: 0 4px !important;
                    margin: 0 !important;
                    width: 100% !important;
                    max-width: 100vw !important;
                    box-sizing: border-box !important;
                  }

                  /* 6. Clean header navigation bar */
                  ytmusic-nav-bar {
                    padding: 0 4px !important;
                  }
                  ytmusic-search-box {
                    max-width: 200px !important;
                  }

                  /* 7. Allow horizontal carousels to scroll smoothly */
                  ytmusic-carousel {
                    overflow-x: auto !important;
                    -webkit-overflow-scrolling: touch !important;
                    scroll-behavior: smooth !important;
                  }

                  /* 8. Hide annoying promotional popups and upsell overlays */
                  ytmusic-mealbar-promo-renderer,
                  ytmusic-upsell-dialog-renderer,
                  yt-upsell-dialog-renderer,
                  .ytmusic-popup-container ytmusic-mealbar-promo-renderer,
                  #upsell-dialog,
                  tp-yt-paper-dialog:has(ytmusic-mealbar-promo-renderer),
                  .opened.ytmusic-mealbar-promo-renderer {
                    display: none !important;
                    height: 0 !important;
                  }

                  /* 9. Hide redundant desktop cast button */
                  ytmusic-cast-button {
                    display: none !important;
                  }
                `;
                (document.head || document.documentElement).appendChild(style);
              }
            } catch(e) {}
          }
          injectMobileStyles();

          function pauseAllVideos() {
            try {
              document.querySelectorAll('video, audio').forEach(function(v) {
                v.pause();
                v.muted = true;
              });
            } catch(e) {}
          }

          // 1. Skip ads on YouTube Music
          function removeAds() {
            try {
              const skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
              if (skipBtn) skipBtn.click();
              const adOverlay = document.querySelectorAll('.ad-showing, .ad-interrupting, .video-ads, ytm-promoted-sparkles-web-renderer');
              adOverlay.forEach(function(el) { el.style.display = 'none'; });
            } catch(e) {}
          }
          if (!window._clAdInterval) {
            window._clAdInterval = setInterval(removeAds, 2000);
          }

          // 2. Music Item Link Extractor for YouTube Music DOM (Tracks & Playlists)
          function findMusicItemInfo(startElement) {
            let el = startElement;

            // Never intercept clicks on navigation bar, search box, category chips, or 3-dot menus
            if (el.closest('ytmusic-nav-bar, #nav-bar-background, ytmusic-search-box, ytmusic-chip-cloud-renderer, ytmusic-menu-renderer, input, textarea, #guide-button')) {
              return null;
            }

            // Find enclosing card, list row, or header
            const item = el.closest(
              'ytmusic-responsive-list-item-renderer, ytmusic-two-row-item-renderer, ytmusic-player-queue-item, ytmusic-playlist-shelf-renderer, ytmusic-compact-playlist-renderer, ytmusic-responsive-header-renderer'
            );

            // A. Check for playlist/album anchor
            const playlistAnchor = (item ? item.querySelector('a[href*="playlist?list="], a[href*="/browse/VL"], a[href*="/browse/MPRE"]') : null) || el.closest('a[href*="playlist?list="], a[href*="/browse/VL"], a[href*="/browse/MPRE"]');
            if (playlistAnchor && (!item || item.tagName === 'YTMUSIC-TWO-ROW-ITEM-RENDERER' || item.tagName === 'YTMUSIC-RESPONSIVE-HEADER-RENDERER' || !item.querySelector('a[href*="watch?v="]'))) {
              const href = playlistAnchor.getAttribute('href') || playlistAnchor.href || '';
              const mList = href.match(/[?&]list=([^&#]+)/) || href.match(/\/browse\/(VL[^&#]+)/) || href.match(/\/browse\/(MPRE[^&#]+)/);
              if (mList && mList[1]) {
                const playlistId = mList[1];
                let title = '';
                let artist = 'Playlist';
                if (item) {
                  const titleEl = item.querySelector('.title, [class*="title"], yt-formatted-string.title, h1, h2');
                  if (titleEl) title = titleEl.innerText || titleEl.textContent || '';
                  const artistEl = item.querySelector('.subtitle, [class*="subtitle"], .byline, [class*="byline"]');
                  if (artistEl) artist = artistEl.innerText || artistEl.textContent || '';
                }
                if (!title) title = playlistAnchor.getAttribute('aria-label') || playlistAnchor.innerText || 'YouTube Music Playlist';
                title = title.split('\n')[0].replace(/•.*/, '').trim();

                const img = item ? item.querySelector('img') : null;
                const thumb = img ? (img.getAttribute('src') || '') : '';
                const mV = href.match(/[?&]v=([^&#]+)/);

                return {
                  type: 'PLAYLIST',
                  playlistId: playlistId,
                  firstVideoId: mV ? mV[1] : '',
                  title: title || 'YouTube Music Playlist',
                  artist: artist.split('•')[0].trim() || 'Playlist',
                  thumbnailUrl: thumb
                };
              }
            }

            // B. Check for song anchor (watch?v=)
            const watchAnchor = (item ? item.querySelector('a[href*="watch?v="]') : null) || el.closest('a[href*="watch?v="]');
            if (watchAnchor) {
              const href = watchAnchor.getAttribute('href') || watchAnchor.href || '';
              const vMatch = href.match(/[?&]v=([^&#]+)/);
              if (vMatch && vMatch[1]) {
                const videoId = vMatch[1];
                let title = '';
                let artist = 'YouTube Music';
                if (item) {
                  const titleEl = item.querySelector('.title, [class*="title"], yt-formatted-string.title');
                  if (titleEl) title = titleEl.innerText || titleEl.textContent || '';
                  const artistEl = item.querySelector('.subtitle, [class*="subtitle"], .byline, [class*="byline"]');
                  if (artistEl) artist = artistEl.innerText || artistEl.textContent || '';
                }
                if (!title) title = watchAnchor.getAttribute('aria-label') || watchAnchor.innerText || '';
                if (title) {
                  title = title.split('\n')[0].replace(/•.*/, '').replace(/\d+:\d+.*/, '').trim();
                }

                const listMatch = href.match(/[?&]list=([^&#]+)/);
                const playlistId = listMatch ? listMatch[1] : '';

                // If this is a Two-Row item in a carousel and has list=, treat as playlist card so all tracks load
                if (item && item.tagName === 'YTMUSIC-TWO-ROW-ITEM-RENDERER' && playlistId && !playlistId.startsWith('RDAMVM')) {
                  return {
                    type: 'PLAYLIST',
                    playlistId: playlistId,
                    firstVideoId: videoId,
                    title: title || 'YouTube Music Playlist',
                    artist: artist.split('•')[0].trim() || 'Playlist',
                    thumbnailUrl: 'https://img.youtube.com/vi/' + videoId + '/hqdefault.jpg'
                  };
                }

                return {
                  type: 'SONG',
                  videoId: videoId,
                  title: title || 'YouTube Music Track',
                  artist: artist.split('•')[0].trim() || 'YouTube Music'
                };
              }
            }

            return null;
          }

          // 3. Click Interception in Capture Phase
          if (!window._clClickAttached) {
            window._clClickAttached = true;
            window.addEventListener('click', function(e) {
              const info = findMusicItemInfo(e.target);
              if (info) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                pauseAllVideos();

                if (window.CoListenBridge) {
                  if (info.type === 'PLAYLIST') {
                    window.CoListenBridge.postMessage(JSON.stringify({
                      type: 'PLAYLIST_TAPPED',
                      playlistId: info.playlistId,
                      firstVideoId: info.firstVideoId || '',
                      title: info.title,
                      artist: info.artist,
                      thumbnailUrl: info.thumbnailUrl || ''
                    }));
                  } else {
                    window.CoListenBridge.postMessage(JSON.stringify({
                      type: 'VIDEO_TAPPED',
                      videoId: info.videoId,
                      title: info.title,
                      artist: info.artist
                    }));
                  }
                }
                return false;
              }
            }, true);
          }

          // 4. Playlist Tracks Resolver (via YouTube Music Innertube API)
          window.fetchPlaylistTracks = function(playlistId, actionType, firstVideoId, firstTitle, firstArtist) {
            try {
              const key = (window.ytcfg && window.ytcfg.data_ && window.ytcfg.data_.INNERTUBE_API_KEY) || '';
              const ctx = (window.ytcfg && window.ytcfg.data_ && window.ytcfg.data_.INNERTUBE_CONTEXT) || {};
              const browseId = playlistId.startsWith('VL') ? playlistId : 'VL' + playlistId;

              function parseTracksFromData(data) {
                const list = [];
                function walk(obj) {
                  if (!obj || typeof obj !== 'object') return;
                  if (obj.musicResponsiveListItemRenderer) {
                    const r = obj.musicResponsiveListItemRenderer;
                    let vId = '';
                    const nav = r.navigationEndpoint || r.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint;
                    if (nav?.watchEndpoint?.videoId) vId = nav.watchEndpoint.videoId;
                    if (!vId && r.videoId) vId = r.videoId;
                    const flex = r.flexColumns || [];
                    const t = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || '';
                    const a = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || 'YouTube Music';
                    if (vId && t && !list.some(x => x.videoId === vId)) {
                      list.push({ videoId: vId, title: t, artist: a });
                    }
                  } else if (obj.playlistPanelVideoRenderer) {
                    const r = obj.playlistPanelVideoRenderer;
                    const vId = r.videoId;
                    const t = r.title?.runs?.[0]?.text || '';
                    const a = r.shortBylineText?.runs?.[0]?.text || 'YouTube Music';
                    if (vId && t && !list.some(x => x.videoId === vId)) {
                      list.push({ videoId: vId, title: t, artist: a });
                    }
                  }
                  for (let k in obj) {
                    if (obj.hasOwnProperty(k) && typeof obj[k] === 'object') {
                      walk(obj[k]);
                    }
                  }
                }
                walk(data);
                return list;
              }

              fetch('/youtubei/v1/browse?key=' + key, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ context: ctx, browseId: browseId })
              })
              .then(r => r.json())
              .then(data => {
                let tracks = parseTracksFromData(data);
                if (tracks.length === 0 && firstVideoId) {
                  return fetch('/youtubei/v1/next?key=' + key, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ context: ctx, videoId: firstVideoId, playlistId: playlistId })
                  }).then(r => r.json()).then(nextData => parseTracksFromData(nextData));
                }
                return tracks;
              })
              .then(tracks => {
                if (!tracks || tracks.length === 0) {
                  if (firstVideoId && firstTitle) {
                    tracks = [{ videoId: firstVideoId, title: firstTitle, artist: firstArtist || 'YouTube Music' }];
                  }
                }
                if (window.CoListenBridge) {
                  window.CoListenBridge.postMessage(JSON.stringify({
                    type: 'PLAYLIST_TRACKS_LOADED',
                    playlistId: playlistId,
                    action: actionType,
                    tracks: tracks
                  }));
                }
              })
              .catch(err => {
                if (firstVideoId && firstTitle && window.CoListenBridge) {
                  window.CoListenBridge.postMessage(JSON.stringify({
                    type: 'PLAYLIST_TRACKS_LOADED',
                    playlistId: playlistId,
                    action: actionType,
                    tracks: [{ videoId: firstVideoId, title: firstTitle, artist: firstArtist || 'YouTube Music' }]
                  }));
                }
              });
            } catch(e) {}
          };

          // 5. Instantly pause any media without CPU-heavy DOM mutation sweeps
          if (!window._clPlayListenerAttached) {
            window._clPlayListenerAttached = true;
            document.addEventListener('play', function(e) {
              try {
                if (e.target && (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO')) {
                  e.target.pause();
                  e.target.muted = true;
                }
              } catch(err) {}
            }, true);
          }

          // 6. Extract autoplay recommendations from queue
          function extractAutoplaySuggestions() {
            try {
              const list = [];
              const elements = document.querySelectorAll(
                'ytmusic-responsive-list-item-renderer a[href*="/watch?v="], ytmusic-player-queue-item a[href*="/watch?v="], a[href*="/watch?v="]'
              );
              elements.forEach(function(a) {
                const href = a.getAttribute('href') || '';
                const m = href.match(/[?&]v=([^&#]+)/);
                if (m && m[1]) {
                  const videoId = m[1];
                  const item = a.closest('ytmusic-responsive-list-item-renderer, ytmusic-two-row-item-renderer, ytmusic-player-queue-item') || a.parentElement;
                  let title = '';
                  let artist = 'YouTube Music';
                  if (item) {
                    const titleEl = item.querySelector('.title, yt-formatted-string.title');
                    if (titleEl) title = titleEl.innerText || titleEl.textContent || '';
                    const artistEl = item.querySelector('.subtitle, .byline');
                    if (artistEl) artist = artistEl.innerText || artistEl.textContent || artist;
                  }
                  if (!title) title = a.innerText || a.textContent || '';
                  if (title) {
                    title = title.split('\n')[0].replace(/•.*/, '').trim();
                    list.push({
                      videoId: videoId,
                      title: title,
                      artist: artist.split('•')[0].trim() || 'YouTube Music'
                    });
                  }
                }
              });

              if (list.length > 0 && window.CoListenBridge) {
                window.CoListenBridge.postMessage(JSON.stringify({
                  type: 'SUGGESTIONS_EXTRACTED',
                  items: list.slice(0, 15)
                }));
              }
            } catch(e) {}
          }

          if (!window._clPeriodicInterval) {
            window._clPeriodicInterval = setInterval(function() {
              removeAds();
              extractAutoplaySuggestions();
              injectMobileStyles();
            }, 6000);
          }
        })();
      ''');
    } catch (_) {}
  }

  void _handleBridgeMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;

      final type = data['type'] as String?;
      if (type == 'VIDEO_TAPPED') {
        final videoId = data['videoId'] as String?;
        final title = data['title'] as String? ?? 'YouTube Music Track';
        final artist = data['artist'] as String? ?? 'YouTube Music';
        if (videoId != null && videoId.isNotEmpty) {
          _handleVideoTap(videoId, title, artist: artist);
        }
      } else if (type == 'PLAYLIST_TAPPED') {
        final playlistId = data['playlistId'] as String?;
        final firstVideoId = data['firstVideoId'] as String? ?? '';
        final title = data['title'] as String? ?? 'YouTube Music Playlist';
        final artist = data['artist'] as String? ?? 'Playlist';
        final thumb = data['thumbnailUrl'] as String?;
        if (playlistId != null && playlistId.isNotEmpty) {
          _handlePlaylistTap(
            playlistId: playlistId,
            firstVideoId: firstVideoId,
            title: title,
            artist: artist,
            thumbnailUrl: thumb,
          );
        }
      } else if (type == 'PLAYLIST_TRACKS_LOADED') {
        final action = data['action'] as String? ?? 'PLAY_NOW';
        final rawTracks = data['tracks'];
        if (rawTracks is List && rawTracks.isNotEmpty) {
          final tracks = rawTracks
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _handlePlaylistTracksLoaded(action, tracks);
        }
      } else if (type == 'SUGGESTIONS_EXTRACTED') {
        final rawItems = data['items'];
        if (rawItems is List) {
          final items = rawItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          YouTubeSuggestionPool.updateSuggestions(
              items, AudioSourceType.youtubeMusic);
        }
      }
    } catch (_) {}
  }

  void _handleVideoTap(String videoId, String title, {String? artist}) {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastHandledVideoId == videoId &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inMilliseconds < 1500) {
      return;
    }
    _lastHandledVideoId = videoId;
    _lastHandledTime = now;

    final currentUser = ref.read(authStateProvider).valueOrNull;
    final currentUserId = currentUser?.uid ?? '';
    final canChangeSong = widget.room.canChangeSongs(currentUserId);
    final canAddQueue = widget.room.canAddSongs(currentUserId);

    // ALWAYS show the Action Modal with "Play in Room" and "Add to Queue"
    _showSongActionModal(
      videoId: videoId,
      title: title,
      artist: artist ?? 'YouTube Music',
      canChangeSong: canChangeSong,
      canAddQueue: canAddQueue,
    );
  }

  void _handlePlaylistTap({
    required String playlistId,
    required String firstVideoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
  }) {
    if (!mounted) return;

    final currentUser = ref.read(authStateProvider).valueOrNull;
    final currentUserId = currentUser?.uid ?? '';
    final canChangeSong = widget.room.canChangeSongs(currentUserId);
    final canAddQueue = widget.room.canAddSongs(currentUserId);

    _showPlaylistActionModal(
      playlistId: playlistId,
      firstVideoId: firstVideoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      canChangeSong: canChangeSong,
      canAddQueue: canAddQueue,
    );
  }

  void _handlePlaylistTracksLoaded(
      String action, List<Map<String, dynamic>> tracks) {
    if (!mounted || tracks.isEmpty) return;

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    if (action == 'PLAY_NOW') {
      final first = tracks.first;
      final remaining = tracks.skip(1).toList();

      // 1. Play first track now
      _playTrackNowInAppPlayer(
        first['videoId'],
        first['title'],
        artist: first['artist'],
      );

      // 2. Queue all remaining tracks in sequence
      for (var i = 0; i < remaining.length; i++) {
        final t = remaining[i];
        final item = QueueItemEntity(
          id: '',
          trackId: t['videoId'],
          sourceType: AudioSourceType.youtubeMusic,
          title: t['title'],
          artist: t['artist'] ?? 'YouTube Music',
          thumbnailUrl:
              'https://img.youtube.com/vi/${t['videoId']}/hqdefault.jpg',
          durationMs: 210000,
          addedBy: currentUser.uid,
          addedByName: currentUser.displayName,
          addedAt: DateTime.now(),
          order: (i + 1).toDouble(),
        );
        ref.read(queueControllerProvider.notifier).addSong(
              roomId: widget.room.id,
              item: item,
            );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Playing "${first['title']}" & queued ${remaining.length} songs from playlist!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (action == 'ADD_QUEUE') {
      for (var i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        final item = QueueItemEntity(
          id: '',
          trackId: t['videoId'],
          sourceType: AudioSourceType.youtubeMusic,
          title: t['title'],
          artist: t['artist'] ?? 'YouTube Music',
          thumbnailUrl:
              'https://img.youtube.com/vi/${t['videoId']}/hqdefault.jpg',
          durationMs: 210000,
          addedBy: currentUser.uid,
          addedByName: currentUser.displayName,
          addedAt: DateTime.now(),
          order: (i + 1).toDouble(),
        );
        ref.read(queueControllerProvider.notifier).addSong(
              roomId: widget.room.id,
              item: item,
            );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${tracks.length} songs from playlist to queue!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showPlaylistActionModal({
    required String playlistId,
    required String firstVideoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    required bool canChangeSong,
    required bool canAddQueue,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusXl),
            ),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppDimens.lg),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                // Playlist preview row
                Container(
                  padding: const EdgeInsets.all(AppDimens.sm + 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                            ? Image.network(
                                thumbnailUrl,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 58,
                                  height: 58,
                                  color: Colors.black26,
                                  child: const Icon(Icons.playlist_play_rounded,
                                      color: AppColors.secondary, size: 30),
                                ),
                              )
                            : Container(
                                width: 58,
                                height: 58,
                                color: Colors.black26,
                                child: const Icon(Icons.playlist_play_rounded,
                                    color: AppColors.secondary, size: 30),
                              ),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.4),
                                        width: 0.8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.queue_music_rounded,
                                          size: 10, color: Colors.redAccent),
                                      SizedBox(width: 3),
                                      Text(
                                        'PLAYLIST',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
                // Buttons
                Row(
                  children: [
                    // Play Playlist Now Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canChangeSong
                            ? () {
                                Navigator.pop(modalContext);
                                final safeTitle = title.replaceAll("'", r"\'");
                                final safeArtist = artist.replaceAll("'", r"\'");
                                _controller.runJavaScript(
                                  "window.fetchPlaylistTracks('$playlistId', 'PLAY_NOW', '$firstVideoId', '$safeTitle', '$safeArtist');",
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Loading playlist tracks into room...'),
                                    backgroundColor: AppColors.primary,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.playlist_play_rounded, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canChangeSong ? 'Play Playlist' : 'Host Only',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canChangeSong
                              ? AppColors.primary
                              : AppColors.surfaceHighlight,
                          foregroundColor: canChangeSong
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    // Add All to Queue Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canAddQueue
                            ? () {
                                Navigator.pop(modalContext);
                                final safeTitle = title.replaceAll("'", r"\'");
                                final safeArtist = artist.replaceAll("'", r"\'");
                                _controller.runJavaScript(
                                  "window.fetchPlaylistTracks('$playlistId', 'ADD_QUEUE', '$firstVideoId', '$safeTitle', '$safeArtist');",
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Adding playlist tracks to queue...'),
                                    backgroundColor: AppColors.secondary,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.queue_music_rounded, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canAddQueue ? 'Add All to Queue' : 'Queue Locked',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: canAddQueue
                              ? AppColors.secondary
                              : AppColors.textMuted,
                          side: BorderSide(
                            color: canAddQueue
                                ? AppColors.secondary
                                : AppColors.glassBorder,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                // Browse Tracks Button
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(modalContext);
                    _controller.loadRequest(
                      Uri.parse('https://music.youtube.com/playlist?list=$playlistId'),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded,
                      size: 16, color: AppColors.textMuted),
                  label: const Text(
                    'Browse Individual Tracks in Playlist',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSongActionModal({
    required String videoId,
    required String title,
    required String artist,
    required bool canChangeSong,
    required bool canAddQueue,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusXl),
            ),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppDimens.lg),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                // Track preview row with YouTube Music branding
                Container(
                  padding: const EdgeInsets.all(AppDimens.sm + 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: Image.network(
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 58,
                            height: 58,
                            color: Colors.black26,
                            child: const Icon(Icons.music_note_rounded,
                                color: AppColors.secondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.4),
                                        width: 0.8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.music_note_rounded,
                                          size: 10, color: Colors.redAccent),
                                      SizedBox(width: 3),
                                      Text(
                                        'YT MUSIC',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
                // Action Buttons: Play Now & Add to Queue
                Row(
                  children: [
                    // Play Now Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canChangeSong
                            ? () {
                                Navigator.pop(modalContext);
                                _playTrackNowInAppPlayer(videoId, title,
                                    artist: artist);
                              }
                            : null,
                        icon: Icon(
                          canChangeSong
                              ? Icons.play_arrow_rounded
                              : Icons.lock_outline_rounded,
                          size: 20,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canChangeSong ? 'Play in Room' : 'Host Only',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canChangeSong
                              ? AppColors.primary
                              : AppColors.surfaceHighlight,
                          foregroundColor: canChangeSong
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    // Add to Queue Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canAddQueue
                            ? () {
                                Navigator.pop(modalContext);
                                _addTrackToRoomQueue(videoId, title,
                                    artist: artist);
                              }
                            : null,
                        icon: const Icon(Icons.queue_music_rounded, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canAddQueue ? 'Add to Queue' : 'Queue Locked',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: canAddQueue
                              ? AppColors.secondary
                              : AppColors.textMuted,
                          side: BorderSide(
                            color: canAddQueue
                                ? AppColors.secondary
                                : AppColors.glassBorder,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _playTrackNowInAppPlayer(String videoId, String title,
      {String? artist}) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    int detectedDurationMs = 0;
    try {
      final res = await _controller
          .runJavaScriptReturningResult(
            '(function(){ const v = document.querySelector("video"); return (v && isFinite(v.duration) && v.duration > 0) ? Math.round(v.duration * 1000) : 0; })()',
          )
          .timeout(const Duration(milliseconds: 500), onTimeout: () => 0);
      if (res is num && res > 0) {
        detectedDurationMs = res.toInt();
      } else if (res is String) {
        final parsed = int.tryParse(res);
        if (parsed != null && parsed > 0) detectedDurationMs = parsed;
      }
    } catch (_) {}

    _controller.runJavaScript(
      'document.querySelectorAll("video").forEach(v => { try { v.pause(); v.currentTime = 0; } catch(e){} });',
    );

    final newState = PlaybackStateEntity(
      currentItemId: 'ytm_${DateTime.now().millisecondsSinceEpoch}',
      trackId: videoId,
      sourceType: AudioSourceType.youtubeMusic,
      title: title,
      artist: artist ?? 'YouTube Music',
      thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      durationMs: detectedDurationMs,
      positionMs: 0,
      status: 'playing',
      updatedAt: DateTime.now(),
      updatedBy: currentUser.uid,
    );

    ref
        .read(playbackRepositoryProvider)
        .updatePlayback(widget.room.id, newState);

    if (!mounted) return;
    if (widget.isEmbedded && widget.onSwitchToAppPlayer != null) {
      widget.onSwitchToAppPlayer!();
    } else {
      Navigator.pop(context);
    }
  }

  void _addTrackToRoomQueue(String videoId, String title,
      {String? artist}) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    final item = QueueItemEntity(
      id: '',
      trackId: videoId,
      sourceType: AudioSourceType.youtubeMusic,
      title: title,
      artist: artist ?? 'YouTube Music',
      thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      durationMs: 210000,
      addedBy: currentUser.uid,
      addedByName: currentUser.displayName,
      addedAt: DateTime.now(),
      order: 1.0,
    );

    ref.read(queueControllerProvider.notifier).addSong(
          roomId: widget.room.id,
          item: item,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$title" to the queue!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (WebViewPlatform.instance == null) {
      return const SizedBox.shrink();
    }
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final currentUserId = currentUser?.uid ?? '';
    final canControl = widget.room.canChangeSongs(currentUserId);
    final canAdd = widget.room.canAddSongs(currentUserId);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Single Unified Sleek Navigation & Quick Links Bar
            if (!isKeyboardOpen)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border(
                    bottom: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
                child: Row(
                  children: [
                    if (!widget.isEmbedded)
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textPrimary, size: 20),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    if (widget.isEmbedded &&
                        widget.onSwitchToAppPlayer != null) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.secondary, size: 18),
                        tooltip: 'Back to Player',
                        onPressed: () {
                          _controller.runJavaScript(
                            'document.querySelectorAll("video, audio").forEach(v => { try { v.pause(); v.muted = true; } catch(e){} });',
                          );
                          widget.onSwitchToAppPlayer?.call();
                        },
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 2),
                    ],
                    // Web Back, Forward & Reload
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 13,
                        color: _canGoBack
                            ? AppColors.textPrimary
                            : AppColors.textMuted.withValues(alpha: 0.3),
                      ),
                      onPressed: _canGoBack ? () => _controller.goBack() : null,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: _canGoForward
                            ? AppColors.textPrimary
                            : AppColors.textMuted.withValues(alpha: 0.3),
                      ),
                      onPressed:
                          _canGoForward ? () => _controller.goForward() : null,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      onPressed: () => _controller.reload(),
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      padding: EdgeInsets.zero,
                    ),
                    Container(
                      height: 18,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: AppColors.glassBorder,
                    ),
                    // Quick Navigation Links
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _QuickLinkChip(
                              icon: Icons.home_rounded,
                              label: 'Home',
                              onTap: () => _controller.loadRequest(
                                  Uri.parse('https://music.youtube.com')),
                            ),
                            const SizedBox(width: 5),
                            _QuickLinkChip(
                              icon: Icons.search_rounded,
                              label: 'Search',
                              onTap: () => _controller.loadRequest(
                                  Uri.parse('https://music.youtube.com/search?q=trending+songs')),
                            ),
                            const SizedBox(width: 5),
                            _QuickLinkChip(
                              icon: Icons.explore_rounded,
                              label: 'Explore',
                              onTap: () => _controller.loadRequest(
                                  Uri.parse('https://music.youtube.com/explore')),
                            ),
                            const SizedBox(width: 5),
                            _QuickLinkChip(
                              icon: Icons.library_music_rounded,
                              label: 'Library',
                              onTap: () => _controller.loadRequest(
                                  Uri.parse('https://music.youtube.com/library/playlists')),
                            ),
                            const SizedBox(width: 5),
                            _QuickLinkChip(
                              icon: Icons.thumb_up_alt_rounded,
                              label: 'Liked',
                              onTap: () => _controller.loadRequest(
                                  Uri.parse('https://music.youtube.com/playlist?list=LM')),
                            ),
                            const SizedBox(width: 5),
                            _QuickLinkChip(
                              icon: Icons.account_circle_rounded,
                              label: 'Sign In',
                              color: AppColors.secondary,
                              onTap: () => _controller.loadRequest(Uri.parse(
                                  'https://accounts.google.com/ServiceLogin?service=youtube')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Loading Progress Bar
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),

            // Main YouTube Music WebView
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),

            // Floating Room Action Bar if a video/track is detected
            if (_detectedVideoId != null && !isKeyboardOpen)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: const Border(
                      top: BorderSide(color: AppColors.glassBorder)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                            child: Image.network(
                              'https://img.youtube.com/vi/$_detectedVideoId/hqdefault.jpg',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.redAccent),
                            ),
                          ),
                          const SizedBox(width: AppDimens.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _detectedVideoTitle ?? 'Selected Track',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _detectedVideoArtist ??
                                      'YouTube Music Track',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: AppColors.textMuted),
                            tooltip: 'Dismiss',
                            onPressed: () =>
                                setState(() => _detectedVideoId = null),
                            constraints: const BoxConstraints(
                                minWidth: 30, minHeight: 30),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Play Now Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: canControl
                                  ? () => _playTrackNowInAppPlayer(
                                        _detectedVideoId!,
                                        _detectedVideoTitle ??
                                            'YouTube Music Track',
                                        artist: _detectedVideoArtist,
                                      )
                                  : null,
                              icon: Icon(
                                canControl
                                    ? Icons.play_arrow_rounded
                                    : Icons.lock_outline_rounded,
                                size: 16,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  canControl ? 'Play in Room' : 'Host Only',
                                  maxLines: 1,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canControl
                                    ? AppColors.primary
                                    : AppColors.surfaceHighlight,
                                foregroundColor: canControl
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                                minimumSize: const Size(0, 36),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.sm),
                          // Add to Queue Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: canAdd
                                  ? () => _addTrackToRoomQueue(
                                        _detectedVideoId!,
                                        _detectedVideoTitle ??
                                            'YouTube Music Track',
                                        artist: _detectedVideoArtist,
                                      )
                                  : null,
                              icon: Icon(
                                canAdd
                                    ? Icons.queue_music_rounded
                                    : Icons.lock_outline_rounded,
                                size: 16,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  canAdd ? 'Add to Queue' : 'Queue Locked',
                                  maxLines: 1,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: canAdd
                                    ? AppColors.secondary
                                    : AppColors.textMuted,
                                side: BorderSide(
                                  color: canAdd
                                      ? AppColors.secondary
                                      : AppColors.glassBorder,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                                minimumSize: const Size(0, 36),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _QuickLinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceHighlight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: chipColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
