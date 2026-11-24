import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_eq_bars.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../playback/presentation/providers/playback_sync_provider.dart';
import '../../../room/domain/entities/room_entity.dart';
import '../../domain/entities/queue_item_entity.dart';
import '../providers/queue_providers.dart';
import 'add_song_bottom_sheet.dart';

class QueueBottomSheet extends ConsumerWidget {
  final RoomEntity room;

  const QueueBottomSheet({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(roomQueueProvider(room.id));
    final playbackAsync = ref.watch(playbackSyncNotifierProvider(room.id));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final canControl = room.canChangeSongs(currentUser?.uid ?? '');
    final canAdd = room.canAddSongs(currentUser?.uid ?? '');

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: AppDimens.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            ),
          ),
          const SizedBox(height: AppDimens.md),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: queueAsync.when(
                    data: (items) => Text(
                      'Shared Queue (${items.length} upcoming)',
                      style: AppTypography.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    loading: () => Text(
                      'Shared Queue',
                      style: AppTypography.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    error: (_, _) => Text(
                      'Shared Queue',
                      style: AppTypography.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (canAdd) ...[
                  const SizedBox(width: AppDimens.sm),
                  ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => AddSongBottomSheet(roomId: room.id),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Song'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusFull),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.md),

          // Now Playing Section
          playbackAsync.when(
            data: (playback) {
              if (playback == null || !playback.hasTrack) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOW PLAYING',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimens.xs),
                    GlassContainer(
                      borderRadius: AppDimens.radiusMd,
                      borderColor: AppColors.secondary.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                            child: Container(
                              width: 44,
                              height: 44,
                              color: AppColors.surfaceHighlight,
                              child: playback.thumbnailUrl.isNotEmpty
                                  ? Image.network(
                                      playback.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, _) => const Icon(
                                        Icons.album,
                                        color: AppColors.secondary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.album,
                                      color: AppColors.secondary,
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playback.title,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  playback.artist,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          AnimatedEqBars(
                            isPlaying: playback.isPlaying,
                            color: AppColors.secondary,
                            height: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.md),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Subheader: UP NEXT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'UP NEXT',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.how_to_vote,
                          size: 11, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Voting Queue Active',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xs),

          // Queue Items List
          Expanded(
            child: queueAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.queue_music,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: AppDimens.sm),
                        Text('The queue is empty',
                            style: AppTypography.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          canAdd
                              ? 'Tap "+ Add Song" to choose upcoming tracks'
                              : 'Waiting for the DJ to add tracks...',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                // If user is Controller / Host: provide ReorderableListView
                if (canControl) {
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: AppDimens.sm,
                    ),
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) {
                      ref.read(queueControllerProvider.notifier).reorderQueue(
                            roomId: room.id,
                            currentQueue: items,
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          );
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isAddedByMe = currentUser?.uid == item.addedBy;

                      return Container(
                        key: ValueKey(item.id),
                        margin: const EdgeInsets.only(bottom: AppDimens.sm),
                        child: GlassContainer(
                          borderRadius: AppDimens.radiusMd,
                          padding: const EdgeInsets.all(AppDimens.sm),
                          child: Row(
                            children: [
                              // Drag Handle
                              const Icon(Icons.drag_handle_rounded,
                                  color: AppColors.textMuted),
                              const SizedBox(width: AppDimens.xs),

                              // Index Number
                              Text(
                                '${index + 1}.',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: AppDimens.sm),

                              // Thumbnail
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppDimens.radiusSm),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: AppColors.surfaceHighlight,
                                  child: item.thumbnailUrl.isNotEmpty
                                      ? Image.network(
                                          item.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, _) =>
                                              const Icon(Icons.music_note,
                                                  color: AppColors.primary),
                                        )
                                      : const Icon(Icons.music_note,
                                          color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: AppDimens.md),

                              // Title, Artist, Added By
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.artist} • Added by ${item.addedByName}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Upvote Button
                              _UpvoteButton(
                                item: item,
                                currentUid: currentUser?.uid,
                                roomId: room.id,
                              ),
                              const SizedBox(width: 4),

                              // Skip Vote Chip
                              if (item.voteSkipCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                        AppDimens.radiusSm),
                                  ),
                                  child: Text(
                                    '🗳️ ${item.voteSkipCount}',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              // Delete Action
                              if (canControl || isAddedByMe)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: AppColors.error),
                                  onPressed: () {
                                    ref
                                        .read(queueControllerProvider.notifier)
                                        .removeSong(
                                          roomId: room.id,
                                          itemId: item.id,
                                        );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                // If user is Listener: static list with Vote-to-Skip action
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.lg,
                    vertical: AppDimens.sm,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.xs),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final hasVoted = currentUser != null &&
                        item.hasUserVoted(currentUser.uid);
                    final isAddedByMe = currentUser?.uid == item.addedBy;

                    return GlassContainer(
                      borderRadius: AppDimens.radiusMd,
                      padding: const EdgeInsets.all(AppDimens.sm),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: AppDimens.sm),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                            child: Container(
                              width: 44,
                              height: 44,
                              color: AppColors.surfaceHighlight,
                              child: item.thumbnailUrl.isNotEmpty
                                  ? Image.network(
                                      item.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, _) => const Icon(
                                          Icons.music_note,
                                          color: AppColors.primary),
                                    )
                                  : const Icon(Icons.music_note,
                                      color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: AppDimens.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.artist} • By ${item.addedByName}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Upvote Button
                          _UpvoteButton(
                            item: item,
                            currentUid: currentUser?.uid,
                            roomId: room.id,
                          ),
                          const SizedBox(width: 4),

                          // Vote to Skip Button
                          if (room.settings.membersCanVoteSkip &&
                              currentUser != null)
                            TextButton.icon(
                              onPressed: () {
                                ref
                                    .read(queueControllerProvider.notifier)
                                    .toggleVoteSkip(
                                      roomId: room.id,
                                      itemId: item.id,
                                      uid: currentUser.uid,
                                      currentVoted: hasVoted,
                                    );
                              },
                              icon: Icon(
                                hasVoted
                                    ? Icons.thumb_down
                                    : Icons.thumb_down_outlined,
                                size: 16,
                                color: hasVoted
                                    ? AppColors.error
                                    : AppColors.textMuted,
                              ),
                              label: Text(
                                '${item.voteSkipCount}',
                                style: TextStyle(
                                  color: hasVoted
                                      ? AppColors.error
                                      : AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          // Remove if added by this user
                          if (isAddedByMe)
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: AppColors.textMuted),
                              onPressed: () {
                                ref
                                    .read(queueControllerProvider.notifier)
                                    .removeSong(
                                      roomId: room.id,
                                      itemId: item.id,
                                    );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Text('Error loading queue: $err',
                    style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpvoteButton extends ConsumerWidget {
  final QueueItemEntity item;
  final String? currentUid;
  final String roomId;

  const _UpvoteButton({
    required this.item,
    required this.currentUid,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUpvoted = currentUid != null && item.hasUserUpvoted(currentUid!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        onTap: currentUid == null
            ? null
            : () {
                ref.read(queueControllerProvider.notifier).toggleUpvote(
                      roomId: roomId,
                      itemId: item.id,
                      uid: currentUid!,
                      currentUpvoted: hasUpvoted,
                    );
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasUpvoted
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.surfaceHighlight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            border: Border.all(
              color: hasUpvoted
                  ? AppColors.primary
                  : AppColors.textMuted.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasUpvoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                size: 13,
                color: hasUpvoted ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.upvoteCount}',
                style: TextStyle(
                  color: hasUpvoted ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
