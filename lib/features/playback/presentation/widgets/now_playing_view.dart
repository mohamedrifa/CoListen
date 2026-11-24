import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../queue/presentation/providers/queue_providers.dart';
import '../../data/services/youtube_iframe_player_service.dart';
import '../../domain/entities/playback_state_entity.dart';
import '../../domain/services/player_service.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../providers/playback_sync_provider.dart';
import 'playback_controls_row.dart';
import 'waveform_scrubber.dart';
import 'youtube_hub_sheet.dart';

enum NowPlayingMode {
  player,
  youtubeHub,
}

class NowPlayingView extends ConsumerStatefulWidget {
  final String roomId;
  final bool canControl;
  final void Function(bool isHub)? onHubModeChanged;

  const NowPlayingView({
    super.key,
    required this.roomId,
    required this.canControl,
    this.onHubModeChanged,
  });

  @override
  ConsumerState<NowPlayingView> createState() => _NowPlayingViewState();
}

class _NowPlayingViewState extends ConsumerState<NowPlayingView> {
  NowPlayingMode _mode = NowPlayingMode.player;
  bool _hubEverOpened = false;

  void _setMode(NowPlayingMode mode) {
    setState(() {
      _mode = mode;
      if (mode == NowPlayingMode.youtubeHub) {
        _hubEverOpened = true;
      }
    });
    widget.onHubModeChanged?.call(mode == NowPlayingMode.youtubeHub);
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeChip(
              icon: Icons.play_circle_filled_rounded,
              label: 'App Player',
              isSelected: _mode == NowPlayingMode.player,
              onTap: () => _setMode(NowPlayingMode.player),
            ),
            const SizedBox(width: 4),
            _ModeChip(
              icon: Icons.smart_display_rounded,
              iconColor: Colors.red,
              label: 'YouTube Hub',
              isSelected: _mode == NowPlayingMode.youtubeHub,
              onTap: () => _setMode(NowPlayingMode.youtubeHub),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playbackAsync = ref.watch(playbackSyncNotifierProvider(widget.roomId));
    final player = ref.watch(playerServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final room = ref.watch(currentRoomProvider(widget.roomId)).valueOrNull;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return playbackAsync.when(
      data: (playback) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Layer 0: App Player View (Permanently mounted to preserve Android SurfaceProducer & MediaCodec decoder)
            Offstage(
              offstage: _mode != NowPlayingMode.player,
              child: _buildPlayerContent(playback, player, user),
            ),

            // Layer 1: YouTube Hub View (Lazily created on first open, then kept mounted to preserve search & login state)
            if (room != null && _hubEverOpened)
              Offstage(
                offstage: _mode != NowPlayingMode.youtubeHub,
                child: Column(
                  children: [
                    if (!isKeyboardOpen) _buildModeSelector(),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        child: YouTubeHubSheet(
                          room: room,
                          isEmbedded: true,
                          initialVideoId: playback?.hasTrack == true ? playback!.trackId : null,
                          onSwitchToAppPlayer: () => _setMode(NowPlayingMode.player),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => Center(
        child: Text('Playback Sync Error: $err',
            style: const TextStyle(color: AppColors.error)),
      ),
    );
  }

  Widget _buildPlayerContent(
    PlaybackStateEntity? playback,
    PlayerService player,
    UserEntity? user,
  ) {
    if (playback == null || !playback.hasTrack) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeSelector(),
              const SizedBox(height: AppDimens.md),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.2),
                      AppColors.surfaceHighlight,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.smart_display_rounded, size: 60, color: Colors.red),
                ),
              ),
              const SizedBox(height: AppDimens.lg),
              Text('No Track Playing', style: AppTypography.titleLarge),
              const SizedBox(height: AppDimens.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
                child: Text(
                  widget.canControl
                      ? 'Add songs to the queue to start listening'
                      : 'Waiting for the host to choose a track...',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppDimens.lg),
              ElevatedButton.icon(
                onPressed: () => _setMode(NowPlayingMode.youtubeHub),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Open YouTube Hub'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isPlaying = playback.isPlaying;
    final isBuffering = playback.isBuffering;
    final duration = Duration(milliseconds: playback.durationMs);
    final isYoutubePlayer = player is YoutubeIframePlayerService;

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      initialData: player.currentPosition,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;

        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mode Switcher: App Player vs YouTube Hub
                _buildModeSelector(),

                // Center Stage: YouTube Player in WebView
                if (isYoutubePlayer)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg - 1.5),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: YoutubePlayer(
                          key: const ValueKey('youtube_player_stable'),
                          controller: player.controller,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 220,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: const Center(
                      child: Icon(Icons.music_video_rounded, size: 48, color: AppColors.primary),
                    ),
                  ),
                const SizedBox(height: AppDimens.md),

                // Track Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                  child: Column(
                    children: [
                      Text(
                        playback.title,
                        style: AppTypography.titleLarge,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.xs),
                      Text(
                        playback.artist,
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.sm),

                      // Source & Ad-Block Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.smart_display, size: 12, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  'YouTube Stream',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDimens.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_outlined,
                                    size: 12, color: AppColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  'Ad Blocker Active',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (player.currentStatus == PlayerStatus.error) ...[
                        const SizedBox(height: AppDimens.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMd),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 18, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Track has YouTube embed restrictions.',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _setMode(NowPlayingMode.youtubeHub),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Play in Hub',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.md),

                // Waveform Scrubber
                WaveformScrubber(
                  position: position,
                  duration: duration,
                  canControl: widget.canControl,
                  onSeek: (newPos) {
                    if (user != null) {
                      ref
                          .read(playbackSyncNotifierProvider(widget.roomId).notifier)
                          .seek(newPos, user.uid);
                    }
                  },
                ),
                const SizedBox(height: AppDimens.sm),

                // Controls Row
                PlaybackControlsRow(
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  canControl: widget.canControl,
                  onPlayPause: () {
                    if (user == null) return;
                    final notifier = ref.read(
                        playbackSyncNotifierProvider(widget.roomId).notifier);
                    if (isPlaying) {
                      notifier.pause(user.uid);
                    } else {
                      notifier.play(user.uid);
                    }
                  },
                  onNext: widget.canControl
                      ? () {
                          ref
                              .read(queueControllerProvider.notifier)
                              .skipToNextSong(widget.roomId, user?.uid);
                        }
                      : null,
                  onPrevious: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.textPrimary
                  : (iconColor ?? AppColors.textMuted),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
