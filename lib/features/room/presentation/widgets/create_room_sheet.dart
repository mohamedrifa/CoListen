import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/room_entity.dart';
import '../providers/room_providers.dart';

class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  final _nameController = TextEditingController(text: 'Late Night Lo-Fi');
  bool _membersCanAddSongs = true;
  bool _membersCanVoteSkip = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _generateRandomName() {
    final suggestions = [
      'Neon Horizon',
      'Cyber Chillout',
      'Midnight Beats',
      'Lo-Fi Study Lounge',
      'Tokyo Drift Synth',
      'Retrograde Radio',
    ];
    suggestions.shuffle();
    setState(() {
      _nameController.text = suggestions.first;
    });
  }

  Future<void> _handleCreate() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final name = _nameController.text.trim();
    final settings = RoomSettings(
      membersCanAddSongs: _membersCanAddSongs,
      membersCanVoteSkip: _membersCanVoteSkip,
    );

    final roomId = await ref.read(roomControllerProvider.notifier).createRoom(
          name: name,
          adminId: user.uid,
          adminName: user.displayName,
          settings: settings,
        );

    if (mounted && roomId != null) {
      Navigator.pop(context);
      context.push('/room/$roomId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomControllerProvider);
    final isLoading = roomState.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLg),
          ),
          border: Border.all(
            color: AppColors.glassBorder,
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.lg,
          AppDimens.sm,
          AppDimens.lg,
          AppDimens.xl,
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top Drag Pill Indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.md),

            // Header & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Create Music Room', style: AppTypography.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Set up a room to listen in sync with your friends.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppDimens.lg),

            // Room Name with Dice Suggestion Button
            TextField(
              controller: _nameController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'Room Name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceLight,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.casino_outlined,
                      color: AppColors.primaryLight),
                  tooltip: 'Suggest Name',
                  onPressed: _generateRandomName,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.md,
                  vertical: AppDimens.md,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.md),

            // Settings Switches
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Allow members to add songs',
                  style: AppTypography.bodyLarge),
              subtitle: Text('Everyone can add tracks to the shared queue',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              value: _membersCanAddSongs,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _membersCanAddSongs = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Enable Vote-to-Skip',
                  style: AppTypography.bodyLarge),
              subtitle: Text(
                  'Track skips when 50% of listeners vote to skip',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              value: _membersCanVoteSkip,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _membersCanVoteSkip = val),
            ),

            const SizedBox(height: AppDimens.lg),

            // Full-Width Gradient CTA Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  onTap: isLoading ? null : _handleCreate,
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Room & Launch',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
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
