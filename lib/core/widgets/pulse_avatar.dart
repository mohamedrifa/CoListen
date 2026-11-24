import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PulseAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackInitial;
  final double radius;
  final bool isOnline;

  const PulseAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackInitial,
    this.radius = 20.0,
    this.isOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.surfaceHighlight,
          backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
              ? NetworkImage(imageUrl!)
              : null,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Text(
                  fallbackInitial.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.9,
                  ),
                )
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2.0),
              ),
            ),
          ),
      ],
    );
  }
}
