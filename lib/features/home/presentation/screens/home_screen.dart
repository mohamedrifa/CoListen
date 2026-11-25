import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_eq_bars.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import 'package:colisten/features/auth/presentation/providers/auth_provider.dart';
import 'package:colisten/features/invites/presentation/widgets/in_app_invite_banner.dart';
import 'package:colisten/features/room/domain/entities/room_history_entity.dart';
import 'package:colisten/features/room/presentation/providers/room_providers.dart';
import 'package:colisten/features/room/presentation/widgets/create_room_sheet.dart';
import 'package:colisten/features/room/presentation/widgets/join_code_sheet.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? initialJoinCode;

  const HomeScreen({super.key, this.initialJoinCode});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialJoinCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => JoinCodeSheet(initialCode: widget.initialJoinCode),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq, color: AppColors.secondary, size: 24),
            const SizedBox(width: AppDimens.sm),
            Text('CoListen', style: AppTypography.titleLarge),
          ],
        ),
        actions: [
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: AppDimens.sm),
              child: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'sign_out') {
                    ref.read(authControllerProvider.notifier).signOut();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: AppColors.primaryLight),
                        const SizedBox(width: AppDimens.sm),
                        Text(user.displayName),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sign_out',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: AppColors.error),
                        SizedBox(width: AppDimens.sm),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
                child: PulseAvatar(
                  imageUrl: user.photoUrl,
                  fallbackInitial: user.displayName.isNotEmpty
                      ? user.displayName[0]
                      : 'U',
                  radius: 18,
                  isOnline: true,
                ),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimens.sm),

              // In-App Invite Banner (Shows if there are pending invites)
              InAppInviteBanner(
                onJoin: (roomId, code) => context.push('/room/$roomId'),
              ),

              Text(
                'Synchronized Music Rooms',
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                'Listen together in real time. Low latency. Zero drift.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppDimens.lg),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => const CreateRoomSheet(),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => const JoinCodeSheet(),
                        );
                      },
                      icon: const Icon(Icons.tag),
                      label: const Text('Enter Code'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.glassBorder),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Room History',
                    style: AppTypography.titleMedium,
                  ),
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded,
                              size: 12, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'One-Tap Re-entry',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),

              // Room History List
              Expanded(
                child: user == null
                    ? const Center(
                        child: Text('Sign in to view your room history'),
                      )
                    : ref.watch(userRoomHistoryProvider(user.uid)).when(
                          data: (history) {
                            if (history.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceHighlight
                                            .withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.meeting_room_outlined,
                                        size: 30,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: AppDimens.sm),
                                    Text(
                                      'No Room History Yet',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppDimens.lg),
                                      child: Text(
                                        'Create a room or enter a 6-digit code. Once you join, you can re-enter here anytime without typing the code again!',
                                        style:
                                            AppTypography.bodySmall.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              padding:
                                  const EdgeInsets.only(bottom: AppDimens.lg),
                              itemCount: history.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppDimens.xs),
                              itemBuilder: (context, index) {
                                return _RoomHistoryCard(
                                  item: history[index],
                                  uid: user.uid,
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                          error: (err, _) => Center(
                            child: Text(
                              'Failed to load history: $err',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomHistoryCard extends ConsumerWidget {
  final RoomHistoryEntity item;
  final String uid;

  const _RoomHistoryCard({
    required this.item,
    required this.uid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveRoomAsync = ref.watch(currentRoomProvider(item.roomId));
    final liveRoom = liveRoomAsync.valueOrNull;
    final isActive = liveRoom?.isActive ?? true;
    final memberCount = liveRoom?.members.length ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: () {
            // One-tap direct re-entry: opens room immediately without prompting for code
            context.push('/room/${item.roomId}');
          },
          child: GlassContainer(
            padding: const EdgeInsets.all(AppDimens.sm),
            child: Row(
              children: [
                // Equalizer or Inactive Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryDark
                        : AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Center(
                    child: isActive
                        ? const AnimatedEqBars(
                            isPlaying: true, color: AppColors.secondary)
                        : const Icon(Icons.music_off_outlined,
                            color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(width: AppDimens.md),

                // Details: Name, Host, Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              liveRoom?.name ?? item.name,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSm),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '#${item.code}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Host: ${item.adminName}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('•',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? '$memberCount listening' : 'Room Ended',
                            style: AppTypography.bodySmall.copyWith(
                              color: isActive
                                  ? AppColors.secondary
                                  : AppColors.textMuted,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Delete from history button
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: AppColors.textMuted),
                  tooltip: 'Remove from history',
                  onPressed: () {
                    ref
                        .read(roomControllerProvider.notifier)
                        .removeRoomFromHistory(
                          uid: uid,
                          roomId: item.roomId,
                        );
                  },
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
