import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:colisten/features/auth/presentation/providers/auth_provider.dart';
import '../providers/invites_provider.dart';

class InAppInviteBanner extends ConsumerWidget {
  final void Function(String roomId, String roomCode)? onJoin;

  const InAppInviteBanner({super.key, this.onJoin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingInvitesProvider);

    return invitesAsync.when(
      data: (invites) {
        if (invites.isEmpty) return const SizedBox.shrink();

        final invite = invites.first;
        final user = ref.watch(authStateProvider).valueOrNull;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.md),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppDimens.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mail_outline,
                      size: 20,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textPrimary),
                          children: [
                            TextSpan(
                              text: invite.fromName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' invited you to '),
                            TextSpan(
                              text: '"${invite.roomName}"',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Row(
                        children: [
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppDimens.radiusFull),
                                onTap: () {
                                  if (user != null) {
                                    ref
                                        .read(inviteRepositoryProvider)
                                        .acceptInvite(user.uid, invite.id);
                                  }
                                  onJoin?.call(invite.roomId, invite.roomCode);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Center(
                                    child: Text(
                                      'Join',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.sm),
                          TextButton(
                            onPressed: () {
                              if (user != null) {
                                ref
                                    .read(inviteRepositoryProvider)
                                    .declineInvite(user.uid, invite.id);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Decline',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
