import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class PlaybackControlsRow extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final bool canControl;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onQueueTap;
  final int queueCount;

  const PlaybackControlsRow({
    super.key,
    required this.isPlaying,
    this.isBuffering = false,
    required this.canControl,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onQueueTap,
    this.queueCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous Button
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_previous_rounded),
          color: canControl ? AppColors.textPrimary : AppColors.textMuted,
          onPressed: canControl ? onPrevious : null,
        ),
        const SizedBox(width: AppDimens.md),

        // Primary Play / Pause Button (64px, Midnight Gradient)
        GestureDetector(
          onTap: canControl ? onPlayPause : null,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: canControl ? AppColors.primaryGradient : null,
              color: canControl ? null : AppColors.surfaceHighlight,
              boxShadow: canControl
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isBuffering
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 36,
                      color: canControl ? Colors.white : AppColors.textMuted,
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.md),

        // Next / Skip Button
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_next_rounded),
          color: canControl ? AppColors.textPrimary : AppColors.textMuted,
          onPressed: canControl ? onNext : null,
        ),

        // Queue Button with Badge (Optional)
        if (onQueueTap != null) ...[
          const SizedBox(width: AppDimens.xs),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                iconSize: 26,
                icon: const Icon(Icons.queue_music_rounded),
                color: AppColors.textPrimary,
                onPressed: onQueueTap,
              ),
              if (queueCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusFull),
                    ),
                    child: Text(
                      '$queueCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
