import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/services/presence_service.dart';
import '../../domain/entities/room_entity.dart';
import '../providers/room_providers.dart';

class MembersBottomSheet extends ConsumerWidget {
  final RoomEntity room;

  const MembersBottomSheet({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isHost = currentUser != null && currentUser.uid == room.adminId;
    final presenceAsync = ref.watch(roomPresenceProvider(room.id));
    final presenceMap = presenceAsync.valueOrNull ?? {};

    final memberList = room.members.values.toList();
    // Sort so Host is first, then Controllers, then Listeners
    memberList.sort((a, b) {
      if (a.uid == room.adminId) return -1;
      if (b.uid == room.adminId) return 1;
      if (a.isController && !b.isController) return -1;
      if (!a.isController && b.isController) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    return GlassContainer(
      borderRadius: AppDimens.radiusLg,
      padding: const EdgeInsets.all(AppDimens.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room Members (${memberList.length})',
                style: AppTypography.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            isHost
                ? 'As Host, you decide who is allowed to change songs.'
                : 'Only Host and DJs can control playback.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppDimens.md),

          // Member List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: memberList.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.glassBorder, height: 1),
              itemBuilder: (context, index) {
                final member = memberList[index];
                final isMe = currentUser != null && currentUser.uid == member.uid;
                final isMemberHost = member.uid == room.adminId;
                final presence = presenceMap[member.uid];
                final isOnline = presence?.isOnline ?? true;
                final role = room.getRole(member.uid);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                  child: Row(
                    children: [
                      PulseAvatar(
                        imageUrl: member.photoUrl,
                        fallbackInitial: member.displayName.isNotEmpty
                            ? member.displayName[0]
                            : 'M',
                        radius: 18,
                        isOnline: isOnline,
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  member.displayName + (isMe ? ' (You)' : ''),
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: isMemberHost
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${role.icon} ${role.label} • ${isOnline ? "Online" : "Offline"}',
                              style: AppTypography.labelSmall.copyWith(
                                color: isMemberHost
                                    ? AppColors.primaryLight
                                    : role == UserRole.controller
                                        ? AppColors.secondary
                                        : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Host controls for other members
                      if (isHost && !isMemberHost) ...[
                        TextButton(
                          onPressed: () {
                            ref
                                .read(roomControllerProvider.notifier)
                                .toggleControllerRole(
                                  roomId: room.id,
                                  targetUid: member.uid,
                                  isController: !member.isController,
                                );
                          },
                          child: Text(
                            member.isController ? 'Revoke DJ' : 'Make DJ',
                            style: TextStyle(
                              fontSize: 12,
                              color: member.isController
                                  ? AppColors.warning
                                  : AppColors.secondary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined,
                              size: 18, color: AppColors.error),
                          tooltip: 'Remove',
                          onPressed: () {
                            ref
                                .read(roomControllerProvider.notifier)
                                .removeMember(
                                  roomId: room.id,
                                  targetUid: member.uid,
                                );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          // Leave Room Button
          OutlinedButton.icon(
            onPressed: () async {
              if (currentUser != null) {
                await ref.read(roomControllerProvider.notifier).leaveRoom(
                      roomId: room.id,
                      uid: currentUser.uid,
                    );
              }
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/');
              }
            },
            icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
            label: Text(
              isHost ? 'Leave & End Room' : 'Leave Room',
              style: const TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
