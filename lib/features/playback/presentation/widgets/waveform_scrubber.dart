import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class WaveformScrubber extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final bool canControl;
  final ValueChanged<Duration>? onSeek;

  const WaveformScrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.canControl,
    this.onSeek,
  });

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> {
  double? _dragValue;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.duration.inSeconds.toDouble();
    final currentSeconds = widget.position.inSeconds.toDouble().clamp(0.0, totalSeconds > 0 ? totalSeconds : 1.0);
    final sliderValue = _dragValue ?? currentSeconds;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            thumbShape: widget.canControl
                ? const RoundSliderThumbShape(enabledThumbRadius: 6.0)
                : const RoundSliderThumbShape(enabledThumbRadius: 0.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            activeTrackColor: AppColors.secondary,
            inactiveTrackColor: AppColors.surfaceHighlight,
            thumbColor: Colors.white,
            disabledActiveTrackColor: AppColors.secondary.withValues(alpha: 0.7),
            disabledThumbColor: Colors.transparent,
          ),
          child: Slider(
            min: 0.0,
            max: totalSeconds > 0 ? totalSeconds : 1.0,
            value: totalSeconds > 0 ? sliderValue.clamp(0.0, totalSeconds) : 0.0,
            onChanged: widget.canControl && totalSeconds > 0
                ? (val) => setState(() => _dragValue = val)
                : null,
            onChangeEnd: widget.canControl && totalSeconds > 0
                ? (val) {
                    setState(() => _dragValue = null);
                    widget.onSeek?.call(Duration(seconds: val.toInt()));
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.position),
                style: AppTypography.labelSmall,
              ),
              if (!widget.canControl)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'DJ Controlled',
                          style: AppTypography.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                _formatDuration(widget.duration),
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
