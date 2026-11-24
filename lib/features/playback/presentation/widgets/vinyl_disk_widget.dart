import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class VinylDiskWidget extends StatefulWidget {
  final String? imageUrl;
  final bool isPlaying;
  final double size;

  const VinylDiskWidget({
    super.key,
    this.imageUrl,
    required this.isPlaying,
    this.size = 220.0,
  });

  @override
  State<VinylDiskWidget> createState() => _VinylDiskWidgetState();
}

class _VinylDiskWidgetState extends State<VinylDiskWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylDiskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * pi,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111216),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
          border: Border.all(color: const Color(0xFF22242C), width: 4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Vinyl grooves rings
            Container(
              width: widget.size * 0.85,
              height: widget.size * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1D1F27), width: 1.5),
              ),
            ),
            Container(
              width: widget.size * 0.70,
              height: widget.size * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1D1F27), width: 1.5),
              ),
            ),

            // Album Artwork Center Label
            ClipOval(
              child: SizedBox(
                width: widget.size * 0.48,
                height: widget.size * 0.48,
                child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                    ? Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildFallbackCover(),
                      )
                    : _buildFallbackCover(),
              ),
            ),

            // Spindle Hole
            Container(
              width: widget.size * 0.08,
              height: widget.size * 0.08,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(color: Colors.white24, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: AppColors.primaryDark,
      child: const Center(
        child: Icon(Icons.music_note, color: AppColors.secondary, size: 36),
      ),
    );
  }
}
