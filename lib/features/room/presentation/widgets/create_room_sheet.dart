import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
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
      child: GlassContainer(
        borderRadius: AppDimens.radiusLg,
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: AppDimens.sm),
            Text(
              'Set up a room to listen in sync with your friends.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppDimens.md),

            // Room Name
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Room Name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceHighlight,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.casino_outlined,
                      color: AppColors.primaryLight),
                  tooltip: 'Suggest Name',
                  onPressed: _generateRandomName,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.md),

            // Toggles
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Allow members to add songs',
                  style: AppTypography.bodyLarge),
              subtitle: Text('Everyone can add tracks to the shared queue',
                  style: AppTypography.labelSmall),
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
                  style: AppTypography.labelSmall),
              value: _membersCanVoteSkip,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _membersCanVoteSkip = val),
            ),

            const SizedBox(height: AppDimens.lg),

            // Submit Button
            ElevatedButton(
              onPressed: isLoading ? null : _handleCreate,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Room & Launch'),
            ),
          ],
        ),
      ),
    );
  }
}
