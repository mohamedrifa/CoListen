import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
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
          child: GlassContainer(
            borderColor: AppColors.primaryLight.withValues(alpha: 0.5),
            fillColor: AppColors.primaryDark.withValues(alpha: 0.4),
            padding: const EdgeInsets.all(AppDimens.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mail_outline,
                      size: 20, color: Colors.white),
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
                          ElevatedButton(
                            onPressed: () {
                              if (user != null) {
                                ref
                                    .read(inviteRepositoryProvider)
                                    .acceptInvite(user.uid, invite.id);
                              }
                              onJoin?.call(invite.roomId, invite.roomCode);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Accept & Join',
                                style: TextStyle(fontSize: 12)),
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
                            child: const Text('Dismiss',
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
