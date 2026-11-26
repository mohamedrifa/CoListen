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

class YouTubeHubSheet extends ConsumerStatefulWidget {
  final RoomEntity room;
  final bool isEmbedded;
  final String? initialVideoId;
  final VoidCallback? onSwitchToAppPlayer;

  const YouTubeHubSheet({
    super.key,
    required this.room,
    this.isEmbedded = false,
    this.initialVideoId,
    this.onSwitchToAppPlayer,
  });

  @override
  ConsumerState<YouTubeHubSheet> createState() => YouTubeHubSheetState();
}

class YouTubeHubSheetState extends ConsumerState<YouTubeHubSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _detectedVideoId;
  String? _detectedVideoTitle;
  bool _canGoBack = false;
  bool _canGoForward = false;

  /// Dynamically queries YouTube's logged-in recommendation API and watch feed
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
                  const items = d?.contents?.singleColumnWatchNextResults?.results?.results?.contents || [];
                  items.forEach(it => {
                    const v = it.compactVideoRenderer || it.videoWithContextRenderer;
                    if (v && v.videoId && v.videoId !== '$videoId') {
                      const t = v.title?.runs?.[0]?.text || v.headline?.runs?.[0]?.text || '';
                      const a = v.shortBylineText?.runs?.[0]?.text || '$safeArtist';
                      if (t) list.push({ videoId: v.videoId, title: t, artist: a });
                    }
                  });
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

          if (typeof extractAutoplaySuggestions === 'function') {
            extractAutoplaySuggestions();
          }
        })();
      ''');
    } catch (_) {}
  }

  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) {
      _initWebViewController();
    }
  }

  void _initWebViewController() {
    final initialUrl = widget.initialVideoId != null && widget.initialVideoId!.isNotEmpty
        ? 'https://m.youtube.com/watch?v=${widget.initialVideoId}'
        : 'https://m.youtube.com';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
              _checkNavigationState();
              _inspectUrlForVideo(url);
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
            // Prevent opening external YouTube native app
            if (request.url.startsWith('vnd.youtube') ||
                request.url.startsWith('intent://')) {
              return NavigationDecision.prevent;
            }

            // Direct watch URL navigation interception
            final vId = SongSearchService.extractYoutubeVideoId(request.url);
            if (vId != null && vId.isNotEmpty) {
              _controller.runJavaScript(
                'document.querySelectorAll("video").forEach(v => { try { v.pause(); v.muted = true; } catch(e){} });',
              );
              _handleVideoTap(vId, _detectedVideoTitle ?? 'YouTube Video');
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
          if (cleanTitle.endsWith('- YouTube')) {
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
        });
      }
    }
  }

  void _injectInterceptionAndAdBlocker() {
    try {
      _controller.runJavaScript('''
        (function() {
          function pauseAllVideos() {
            try {
              document.querySelectorAll('video').forEach(function(v) {
                v.pause();
                v.muted = true;
              });
            } catch(e) {}
          }

          // 1. Skip ads on mobile YouTube
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

          // 2. Video Link Extractor
          function findVideoInfo(startElement) {
            let el = startElement;
            while (el && el !== document.body && el !== document.documentElement) {
              const href = el.getAttribute ? (el.getAttribute('href') || (el.tagName === 'A' ? el.href : '')) : '';
              if (href) {
                let videoId = null;
                const vMatch = href.match(/[?&]v=([^&#]+)/);
                if (vMatch && vMatch[1]) {
                  videoId = vMatch[1];
                } else {
                  const sMatch = href.match(/\\/shorts\\/([^/?&#]+)/);
                  if (sMatch && sMatch[1]) {
                    videoId = sMatch[1];
                  }
                }

                if (videoId) {
                  let title = '';
                  if (el.getAttribute('aria-label')) {
                    title = el.getAttribute('aria-label');
                  }
                  if (!title) {
                    const card = el.closest('ytm-video-with-context-renderer, ytm-compact-video-renderer, ytm-rich-item-renderer, ytm-item-section-renderer, .media-item-thumbnail-container') || el.parentElement;
                    if (card) {
                      const h = card.querySelector('.media-item-headline, .compact-media-item-headline, h3, h4, .ytm-pivot-bar-item-title, [class*="headline"], [class*="title"]');
                      if (h) title = h.innerText || h.textContent;
                    }
                  }
                  if (!title) {
                    title = el.innerText || el.textContent || '';
                  }
                  if (title) {
                    title = title.split('\\n')[0].replace(/•.*/, '').replace(/\\d+:\\d+.*/, '').trim();
                  }
                  return { videoId: videoId, title: title || 'YouTube Video' };
                }
              }
              el = el.parentElement;
            }
            return null;
          }

          // 3. Click Interception in Capture Phase
          if (!window._clClickAttached) {
            window._clClickAttached = true;
            window.addEventListener('click', function(e) {
              const info = findVideoInfo(e.target);
              if (info && info.videoId) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                pauseAllVideos();

                if (window.CoListenBridge) {
                  window.CoListenBridge.postMessage(JSON.stringify({
                    type: 'VIDEO_TAPPED',
                    videoId: info.videoId,
                    title: info.title
                  }));
                }
                return false;
              }
            }, true);
          }

          // 4. Hook history pushState and replaceState
          if (!window._clHistoryHooked) {
            window._clHistoryHooked = true;
            const origPush = history.pushState;
            history.pushState = function(state, title, url) {
              origPush.apply(this, arguments);
              if (url && typeof url === 'string') {
                const vMatch = url.match(/[?&]v=([^&#]+)/) || url.match(/\\/shorts\\/([^/?&#]+)/);
                if (vMatch && vMatch[1]) {
                  pauseAllVideos();
                  if (window.CoListenBridge) {
                    window.CoListenBridge.postMessage(JSON.stringify({
                      type: 'VIDEO_TAPPED',
                      videoId: vMatch[1],
                      title: document.title || 'YouTube Video'
                    }));
                  }
                }
              }
            };

            const origReplace = history.replaceState;
            history.replaceState = function(state, title, url) {
              origReplace.apply(this, arguments);
              if (url && typeof url === 'string') {
                const vMatch = url.match(/[?&]v=([^&#]+)/) || url.match(/\\/shorts\\/([^/?&#]+)/);
                if (vMatch && vMatch[1]) {
                  pauseAllVideos();
                  if (window.CoListenBridge) {
                    window.CoListenBridge.postMessage(JSON.stringify({
                      type: 'VIDEO_TAPPED',
                      videoId: vMatch[1],
                      title: document.title || 'YouTube Video'
                    }));
                  }
                }
              }
            };
          }

          // 5. Ensure video playback inside Hub WebView is paused (audio goes through main App Player)
          if (!window._clVideoObserverAttached) {
            window._clVideoObserverAttached = true;
            const obs = new MutationObserver(function() {
              pauseAllVideos();
            });
            obs.observe(document.documentElement || document.body, { childList: true, subtree: true });
          }

          // 6. Extract visible playlist items, recommendations & Up Next tracks for autoplay
          function extractAutoplaySuggestions() {
            try {
              const list = [];
              const elements = document.querySelectorAll(
                'ytm-video-with-context-renderer, ytm-compact-video-renderer, ytm-playlist-panel-video-renderer, a[href*="/watch?v="]'
              );
              elements.forEach(function(el) {
                const a = el.tagName === 'A' ? el : el.querySelector('a[href*="/watch?v="]');
                if (!a) return;
                const href = a.getAttribute('href') || a.href || '';
                const vMatch = href.match(/[?&]v=([^&#]+)/);
                if (vMatch && vMatch[1]) {
                  const id = vMatch[1];
                  let title = a.getAttribute('aria-label') || '';
                  if (!title) {
                    const h = el.querySelector('.media-item-headline, .compact-media-item-headline, h3, h4, .title');
                    if (h) title = h.innerText || h.textContent || '';
                  }
                  if (title) {
                    title = title.split('\\n')[0].replace(/•.*/, '').replace(/\\d+:\\d+.*/, '').trim();
                  }
                  if (id && title && !list.some(function(x) { return x.videoId === id; })) {
                    list.push({ videoId: id, title: title });
                  }
                }
              });
              if (list.length > 0 && window.CoListenBridge) {
                window.CoListenBridge.postMessage(JSON.stringify({
                  type: 'SUGGESTIONS_EXTRACTED',
                  items: list.slice(0, 20)
                }));
              }
            } catch(e) {}
          }
          if (!window._clSuggestionInterval) {
            window._clSuggestionInterval = setInterval(extractAutoplaySuggestions, 6000);
          }
          setTimeout(extractAutoplaySuggestions, 1500);

          pauseAllVideos();
        })();
      ''');
    } catch (_) {}
  }

  void _handleBridgeMessage(String rawMessage) {
    try {
      final data = jsonDecode(rawMessage);
      if (data is! Map) return;

      final type = data['type'] as String?;
      if (type == 'VIDEO_TAPPED') {
        final videoId = data['videoId'] as String?;
        final title = data['title'] as String? ?? 'YouTube Video';
        if (videoId != null && videoId.isNotEmpty) {
          _handleVideoTap(videoId, title);
        }
      } else if (type == 'SUGGESTIONS_EXTRACTED') {
        final rawItems = data['items'];
        if (rawItems is List) {
          final items = rawItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          YouTubeSuggestionPool.updateSuggestions(items);
        }
      }
    } catch (_) {}
  }

  void _handleVideoTap(String videoId, String title) {
    if (!mounted) return;

    // Check whether any other song is currently playing on the room's app player
    final playback =
        ref.read(playbackSyncNotifierProvider(widget.room.id)).valueOrNull;
    final isAnotherSongPlaying = playback != null &&
        playback.hasTrack &&
        (playback.isPlaying ||
            playback.status == 'playing' ||
            playback.status == 'buffering');

    final currentUser = ref.read(authStateProvider).valueOrNull;
    final currentUserId = currentUser?.uid ?? '';
    final canChangeSong = widget.room.canChangeSongs(currentUserId);
    final canAddQueue = widget.room.canAddSongs(currentUserId);

    if (isAnotherSongPlaying) {
      // Show bottom sheet popup with Play Now and Add to Queue buttons
      _showSongActionModal(
        videoId: videoId,
        title: title,
        canChangeSong: canChangeSong,
        canAddQueue: canAddQueue,
      );
    } else {
      // Room player is idle or empty
      if (canChangeSong) {
        _playTrackNowInAppPlayer(videoId, title);
      } else if (canAddQueue) {
        _addTrackToRoomQueue(videoId, title);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$title" to queue. Host will start playback.'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the host can start playback in this room.'),
            backgroundColor: AppColors.surfaceHighlight,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSongActionModal({
    required String videoId,
    required String title,
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
                // Header badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Song Selected from YouTube',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(modalContext),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.md),
                // Track Preview Card
                Container(
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: Image.network(
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                          width: 68,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 68,
                            height: 50,
                            color: Colors.black26,
                            child: const Icon(Icons.smart_display, color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Another track is currently playing in the room',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
                // Buttons: Play Now & Add to Queue
                Row(
                  children: [
                    // Play Now Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canChangeSong
                            ? () {
                                Navigator.pop(modalContext);
                                _playTrackNowInAppPlayer(videoId, title);
                              }
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canChangeSong ? 'Play Now' : 'Play Now (Host Only)',
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
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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
                                _addTrackToRoomQueue(videoId, title);
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
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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

  void _playTrackNowInAppPlayer(String videoId, String title) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    int detectedDurationMs = 0;
    try {
      final res = await _controller.runJavaScriptReturningResult(
        '(function(){ const v = document.querySelector("video"); return (v && isFinite(v.duration) && v.duration > 0) ? Math.round(v.duration * 1000) : 0; })()',
      );
      if (res is num && res > 0) {
        detectedDurationMs = res.toInt();
      } else if (res is String) {
        final parsed = int.tryParse(res);
        if (parsed != null && parsed > 0) detectedDurationMs = parsed;
      }
    } catch (_) {}

    // Pause any video in hub webview
    _controller.runJavaScript(
      'document.querySelectorAll("video").forEach(v => { try { v.pause(); v.currentTime = 0; } catch(e){} });',
    );

    final newState = PlaybackStateEntity(
      currentItemId: 'yt_${DateTime.now().millisecondsSinceEpoch}',
      trackId: videoId,
      sourceType: AudioSourceType.youtube,
      title: title,
      artist: 'YouTube',
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

    if (widget.isEmbedded) {
      widget.onSwitchToAppPlayer?.call();
    } else {
      Navigator.pop(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now Playing in Room: "$title"'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addTrackToRoomQueue(String videoId, String title) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    int detectedDurationMs = 0;
    try {
      final res = await _controller.runJavaScriptReturningResult(
        '(function(){ const v = document.querySelector("video"); return (v && isFinite(v.duration) && v.duration > 0) ? Math.round(v.duration * 1000) : 0; })()',
      );
      if (res is num && res > 0) {
        detectedDurationMs = res.toInt();
      } else if (res is String) {
        final parsed = int.tryParse(res);
        if (parsed != null && parsed > 0) detectedDurationMs = parsed;
      }
    } catch (_) {}

    // Pause any video in hub webview
    _controller.runJavaScript(
      'document.querySelectorAll("video").forEach(v => { try { v.pause(); } catch(e){} });',
    );

    final queueItem = QueueItemEntity(
      id: '',
      trackId: videoId,
      sourceType: AudioSourceType.youtube,
      title: title,
      artist: 'YouTube',
      thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      durationMs: detectedDurationMs,
      addedBy: currentUser.uid,
      addedByName: currentUser.displayName,
      addedAt: DateTime.now(),
      order: 1.0,
    );

    ref.read(queueControllerProvider.notifier).addSong(
          roomId: widget.room.id,
          item: queueItem,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to Queue: "$title"'),
        backgroundColor: AppColors.primary,
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
    final canControl = currentUser != null && widget.room.canChangeSongs(currentUser.uid);
    final canAdd = currentUser != null && widget.room.canAddSongs(currentUser.uid);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final hubBody = Column(
      children: [
        if (widget.isEmbedded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                if (widget.onSwitchToAppPlayer != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary, size: 20),
                    tooltip: 'Back to App Player',
                    onPressed: () {
                      _controller.runJavaScript(
                        'document.querySelectorAll("video").forEach(v => { try { v.pause(); v.muted = true; } catch(e){} });',
                      );
                      widget.onSwitchToAppPlayer?.call();
                    },
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.smart_display, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Text('YouTube Hub', style: AppTypography.titleMedium),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      size: 14,
                      color: _canGoBack ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.3)),
                  onPressed: _canGoBack ? () => _controller.goBack() : null,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: _canGoForward ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.3)),
                  onPressed: _canGoForward ? () => _controller.goForward() : null,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 18),
                  onPressed: () => _controller.reload(),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        // Quick Access Shortcut Bar (Hidden while typing to maximize search suggestions & keyboard area)
        if (!isKeyboardOpen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 6),
            color: AppColors.surfaceCard.withValues(alpha: 0.8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickLinkChip(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () => _controller.loadRequest(Uri.parse('https://m.youtube.com')),
                  ),
                  const SizedBox(width: 6),
                  _QuickLinkChip(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    onTap: () => _controller.loadRequest(Uri.parse('https://m.youtube.com/results?search_query=trending+music')),
                  ),
                  const SizedBox(width: 6),
                  _QuickLinkChip(
                    icon: Icons.video_library_rounded,
                    label: 'My Playlists',
                    onTap: () => _controller.loadRequest(Uri.parse('https://m.youtube.com/feed/library')),
                  ),
                  const SizedBox(width: 6),
                  _QuickLinkChip(
                    icon: Icons.thumb_up_alt_rounded,
                    label: 'Liked Videos',
                    onTap: () => _controller.loadRequest(Uri.parse('https://m.youtube.com/playlist?list=LL')),
                  ),
                  const SizedBox(width: 6),
                  _QuickLinkChip(
                    icon: Icons.account_circle_rounded,
                    label: 'Sign In',
                    color: AppColors.secondary,
                    onTap: () => _controller.loadRequest(Uri.parse('https://accounts.google.com/ServiceLogin?service=youtube')),
                  ),
                ],
              ),
            ),
          ),

        // Loading Bar
        if (_isLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),

        // Main YouTube WebView
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),

        // Floating Room Action Bar (Active when video is detected, hidden when typing)
        if (_detectedVideoId != null && !isKeyboardOpen)
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
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
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: Image.network(
                          'https://img.youtube.com/vi/$_detectedVideoId/hqdefault.jpg',
                          width: 48,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.music_video, color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _detectedVideoTitle ?? 'Selected Track',
                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'YouTube Track ID: $_detectedVideoId',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    children: [
                      // Play Now Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canControl
                              ? () => _playTrackNowInAppPlayer(
                                    _detectedVideoId!,
                                    _detectedVideoTitle ?? 'YouTube Track',
                                  )
                              : null,
                          icon: Icon(canControl ? Icons.play_arrow_rounded : Icons.lock_outline, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              canControl ? 'Play in Room' : 'Host Only',
                              maxLines: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canControl ? AppColors.primary : AppColors.surfaceHighlight,
                            foregroundColor: canControl ? AppColors.textPrimary : AppColors.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                                    _detectedVideoTitle ?? 'YouTube Track',
                                  )
                              : null,
                          icon: Icon(canAdd ? Icons.queue_music : Icons.lock_outline, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              canAdd ? 'Add to Queue' : 'Queue Locked',
                              maxLines: 1,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: canAdd ? AppColors.secondary : AppColors.textMuted,
                            side: BorderSide(
                              color: canAdd ? AppColors.secondary : AppColors.glassBorder,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
    );

    if (widget.isEmbedded) {
      return Container(
        color: AppColors.background,
        child: hubBody,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_display, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('YouTube Hub', style: AppTypography.titleMedium),
              ],
            ),
            Text(
              'Search, Playlists, Account Login & Likes',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                size: 16,
                color: _canGoBack ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.3)),
            onPressed: _canGoBack ? () => _controller.goBack() : null,
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded,
                size: 16,
                color: _canGoForward ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.3)),
            onPressed: _canGoForward ? () => _controller.goForward() : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: hubBody,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(color: color?.withValues(alpha: 0.5) ?? AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
