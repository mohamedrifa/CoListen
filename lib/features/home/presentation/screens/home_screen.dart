import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animated_eq_bars.dart';
import '../../../../core/widgets/colisten_logo.dart';
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoListenLogo(size: 26, showGlow: false, animate: true),
            const SizedBox(width: AppDimens.sm),
            Text('CoListen', style: AppTypography.titleLarge),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: AppDimens.md),
              child: PopupMenuButton<String>(
                color: AppColors.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  side: const BorderSide(color: AppColors.glassBorder),
                ),
                onSelected: (val) {
                  if (val == 'sign_out') {
                    ref.read(authControllerProvider.notifier).signOut();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'profile',
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.isAnonymous ? 'Guest DJ' : 'Synced Listener',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'sign_out',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: AppColors.error, size: 18),
                        SizedBox(width: AppDimens.sm),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimens.xs),

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
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppDimens.lg),

              // Side-by-Side Action Duo
              Row(
                children: [
                  // Hero CTA: Create Room (Gradient Pill)
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusFull),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusFull),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => const CreateRoomSheet(),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline,
                                  color: Colors.white, size: 20),
                              SizedBox(width: AppDimens.sm),
                              Text(
                                'Create Room',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),

                  // Secondary CTA: Enter Code (Frosted Glass Pill)
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: 0.5),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusFull),
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusFull),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => const JoinCodeSheet(),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tag,
                                  color: AppColors.textPrimary, size: 20),
                              SizedBox(width: AppDimens.sm),
                              Text(
                                'Enter Code',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.xl),

              // Recent Rooms Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Rooms',
                    style: AppTypography.titleMedium,
                  ),
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusFull),
                        border: Border.all(color: AppColors.glassBorder),
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
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.glassBorder),
                                      ),
                                      child: const Icon(
                                        Icons.music_note_outlined,
                                        size: 32,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: AppDimens.md),
                                    Text(
                                      'No Recent Rooms',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppDimens.xl),
                                      child: Text(
                                        'Create a music room or enter a 6-digit code. Rooms you join will show up here for one-tap re-entry.',
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
      child: Dismissible(
        key: ValueKey('room_history_${item.roomId}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppDimens.lg),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 22),
              SizedBox(width: 6),
              Text(
                'Remove',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (_) {
          ref.read(roomControllerProvider.notifier).removeRoomFromHistory(
                uid: uid,
                roomId: item.roomId,
              );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              onTap: () {
                // One-tap direct re-entry
                context.push('/room/${item.roomId}');
              },
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: Row(
                  children: [
                    // Equalizer / Music Art Tile
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.glassBorder,
                        ),
                      ),
                      child: Center(
                        child: isActive
                            ? const AnimatedEqBars(
                                isPlaying: true,
                                color: AppColors.secondary,
                                height: 20,
                              )
                            : const Icon(
                                Icons.music_off_outlined,
                                color: AppColors.textMuted,
                                size: 22,
                              ),
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
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                      AppDimens.radiusFull),
                                  border: Border.all(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '#${item.code}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Host: ${item.adminName}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('•',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textMuted)),
                              const SizedBox(width: 6),
                              if (isActive) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isActive
                                    ? '$memberCount listening'
                                    : 'Room Ended',
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

                    const SizedBox(width: AppDimens.xs),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
