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

              const SizedBox(height: AppDimens.xl),
              Text('Active Rooms with Friends', style: AppTypography.titleMedium),
              const SizedBox(height: AppDimens.md),

              // Sample Active Room Card
              GlassContainer(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: const Center(
                        child: AnimatedEqBars(isPlaying: true, color: AppColors.secondary),
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Late Night Lo-Fi', style: AppTypography.titleMedium),
                          const SizedBox(height: 2),
                          Text('Host: Alex • 4 listening', style: AppTypography.bodyMedium),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
