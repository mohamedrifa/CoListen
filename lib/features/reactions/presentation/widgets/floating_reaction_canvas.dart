import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:colisten/core/theme/app_colors.dart';
import 'package:colisten/features/reactions/domain/entities/reaction_entity.dart';
import 'package:colisten/features/reactions/presentation/providers/reactions_provider.dart';

class FloatingReactionParticle {
  final String id;
  final String emoji;
  final String sender;
  final double startXPercent; // 0.1 to 0.9 across screen width
  final double wobbleFactor;  // Frequency and amplitude multiplier
  final DateTime spawnTime;

  FloatingReactionParticle({
    required this.id,
    required this.emoji,
    required this.sender,
    required this.startXPercent,
    required this.wobbleFactor,
    required this.spawnTime,
  });
}

class FloatingReactionCanvas extends ConsumerStatefulWidget {
  final String roomId;

  const FloatingReactionCanvas({super.key, required this.roomId});

  @override
  ConsumerState<FloatingReactionCanvas> createState() =>
      _FloatingReactionCanvasState();
}

class _FloatingReactionCanvasState extends ConsumerState<FloatingReactionCanvas>
    with SingleTickerProviderStateMixin {
  final List<FloatingReactionParticle> _activeParticles = [];
  final Set<String> _seenReactionIds = {};
  late final AnimationController _ticker;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onReactionsUpdated(List<ReactionEntity> reactions) {
    final now = DateTime.now();

    for (final reaction in reactions) {
      if (_seenReactionIds.contains(reaction.id)) continue;
      _seenReactionIds.add(reaction.id);

      // Only animate reactions created within the last 8 seconds
      final age = now.difference(reaction.createdAt).inSeconds;
      if (age > 8) continue;

      final particle = FloatingReactionParticle(
        id: reaction.id,
        emoji: reaction.emoji,
        sender: reaction.displayName,
        startXPercent: 0.15 + (_random.nextDouble() * 0.70),
        wobbleFactor: (_random.nextBool() ? 1.0 : -1.0) * (0.8 + _random.nextDouble() * 0.6),
        spawnTime: now,
      );

      _activeParticles.add(particle);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<ReactionEntity>>>(
      roomReactionsStreamProvider(widget.roomId),
      (_, next) {
        final list = next.valueOrNull;
        if (list != null) {
          _onReactionsUpdated(list);
        }
      },
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ticker,
        builder: (context, _) {
          final now = DateTime.now();
          const durationMs = 2800; // 2.8 seconds total lifetime

          // Remove expired particles
          _activeParticles.removeWhere(
            (p) => now.difference(p.spawnTime).inMilliseconds >= durationMs,
          );

          if (_activeParticles.isEmpty) {
            return const SizedBox.shrink();
          }

          final size = MediaQuery.of(context).size;

          return Stack(
            children: _activeParticles.map((particle) {
              final elapsedMs =
                  now.difference(particle.spawnTime).inMilliseconds;
              final progress = (elapsedMs / durationMs).clamp(0.0, 1.0);

              // Upward Y trajectory (starts at bottom 0.85, ascends to 0.12)
              final startY = size.height * 0.82;
              final endY = size.height * 0.12;
              final currentY = startY - ((startY - endY) * Curves.easeOutCubic.transform(progress));

              // Horizontal wobble (sin wave)
              final wobbleOffset = math.sin(progress * math.pi * 3.5) * 24.0 * particle.wobbleFactor;
              final currentX = (particle.startXPercent * size.width) + wobbleOffset;

              // Scale spring effect: 0.3 -> 1.3 -> 1.0
              double scale = 1.0;
              if (progress < 0.2) {
                scale = 0.3 + (progress / 0.2) * 1.0;
              } else if (progress < 0.4) {
                scale = 1.3 - ((progress - 0.2) / 0.2) * 0.3;
              }

              // Opacity: fade in (first 10%), solid, fade out (last 25%)
              double opacity = 1.0;
              if (progress < 0.1) {
                opacity = progress / 0.1;
              } else if (progress > 0.75) {
                opacity = 1.0 - ((progress - 0.75) / 0.25);
              }

              return Positioned(
                left: currentX - 25,
                top: currentY,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          particle.emoji,
                          style: const TextStyle(fontSize: 34),
                        ),
                        if (particle.sender.isNotEmpty && progress < 0.6)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              particle.sender,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
