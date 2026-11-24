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

  const PlaybackControlsRow({
    super.key,
    required this.isPlaying,
    this.isBuffering = false,
    required this.canControl,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
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

        // Primary Play / Pause Button
        GestureDetector(
          onTap: canControl ? onPlayPause : null,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: canControl ? AppColors.primary : AppColors.surfaceHighlight,
              boxShadow: canControl
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isBuffering
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 38,
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
      ],
    );
  }
}
