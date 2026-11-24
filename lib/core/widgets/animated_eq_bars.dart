import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedEqBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;

  const AnimatedEqBars({
    super.key,
    this.isPlaying = true,
    this.color = AppColors.secondary,
    this.height = 16.0,
  });

  @override
  State<AnimatedEqBars> createState() => _AnimatedEqBarsState();
}

class _AnimatedEqBarsState extends State<AnimatedEqBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(0.4 + 0.6 * _controller.value),
            const SizedBox(width: 2.5),
            _buildBar(0.8 - 0.5 * _controller.value),
            const SizedBox(width: 2.5),
            _buildBar(0.3 + 0.7 * _controller.value),
          ],
        );
      },
    );
  }

  Widget _buildBar(double fraction) {
    return Container(
      width: 3.0,
      height: widget.height * fraction.clamp(0.2, 1.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
