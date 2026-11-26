import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class CoListenLogo extends StatefulWidget {
  final double size;
  final bool showWordmark;
  final double? wordmarkFontSize;
  final bool animate;
  final bool showGlow;

  const CoListenLogo({
    super.key,
    this.size = 40.0,
    this.showWordmark = false,
    this.wordmarkFontSize,
    this.animate = true,
    this.showGlow = false,
  });

  @override
  State<CoListenLogo> createState() => _CoListenLogoState();
}

class _CoListenLogoState extends State<CoListenLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CoListenLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
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
    final iconWidget = SizedBox(
      width: widget.size * 1.3,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showGlow)
            Container(
              width: widget.size * 1.4,
              height: widget.size * 1.4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.heroGlow,
              ),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size * 1.3, widget.size),
                painter: _CoListenLogoPainter(
                  animValue: widget.animate ? _controller.value : 0.5,
                ),
              );
            },
          ),
        ],
      ),
    );

    if (!widget.showWordmark) {
      return iconWidget;
    }

    final fontSize = widget.wordmarkFontSize ?? (widget.size * 0.52);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        SizedBox(width: widget.size * 0.2),
        Text(
          'CoListen',
          style: GoogleFonts.sora(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _CoListenLogoPainter extends CustomPainter {
  final double animValue;

  _CoListenLogoPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = h * 0.085;
    final radius = h * 0.36;

    final leftCenter = Offset(w * 0.38, h * 0.5);
    final rightCenter = Offset(w * 0.62, h * 0.5);

    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = const LinearGradient(
      colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(rect);

    final ringPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    // Draw Left & Right Overlapping Rings (Two listeners in sync)
    canvas.drawCircle(leftCenter, radius, ringPaint);
    canvas.drawCircle(rightCenter, radius, ringPaint);

    // Draw 3 Equalizer Bars at intersection (x = w * 0.5)
    final eqPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.95
      ..isAntiAlias = true;

    final centerX = w * 0.5;
    final spacing = h * 0.08;

    // Height calculations with subtle oscillation
    final bar1H = h * (0.24 + 0.10 * animValue);
    final bar2H = h * (0.44 - 0.12 * animValue);
    final bar3H = h * (0.28 + 0.14 * (1.0 - animValue));

    // Bar 1 (Left)
    canvas.drawLine(
      Offset(centerX - spacing, (h - bar1H) * 0.5),
      Offset(centerX - spacing, (h + bar1H) * 0.5),
      eqPaint,
    );

    // Bar 2 (Center)
    canvas.drawLine(
      Offset(centerX, (h - bar2H) * 0.5),
      Offset(centerX, (h + bar2H) * 0.5),
      eqPaint,
    );

    // Bar 3 (Right)
    canvas.drawLine(
      Offset(centerX + spacing, (h - bar3H) * 0.5),
      Offset(centerX + spacing, (h + bar3H) * 0.5),
      eqPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CoListenLogoPainter oldDelegate) {
    return oldDelegate.animValue != animValue;
  }
}
