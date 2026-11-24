import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:colisten/core/theme/app_colors.dart';
import 'package:colisten/core/theme/app_dimens.dart';
import 'package:colisten/features/auth/domain/entities/user_entity.dart';
import 'package:colisten/features/auth/presentation/providers/auth_provider.dart';
import 'package:colisten/features/reactions/presentation/providers/reactions_provider.dart';

class EmojiBar extends ConsumerStatefulWidget {
  final String roomId;

  const EmojiBar({super.key, required this.roomId});

  @override
  ConsumerState<EmojiBar> createState() => _EmojiBarState();
}

class _EmojiBarState extends ConsumerState<EmojiBar> {
  static const List<String> _emojis = ['🔥', '❤️', '💃', '🎧', '🎉', '⚡', '👏'];
  String? _tappedEmoji;
  Timer? _tapTimer;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _sendEmoji(String emoji, UserEntity? user) {
    HapticFeedback.lightImpact();
    if (user == null) return;

    setState(() => _tappedEmoji = emoji);
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _tappedEmoji = null);
    });

    ref.read(reactionControllerProvider.notifier).sendReaction(
          roomId: widget.roomId,
          uid: user.uid,
          displayName: user.displayName,
          emoji: emoji,
        );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _emojis.map((emoji) {
          final isTapped = _tappedEmoji == emoji;

          return GestureDetector(
            onTap: () => _sendEmoji(emoji, user),
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: isTapped ? 1.4 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
