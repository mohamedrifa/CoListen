import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../playback/presentation/widgets/youtube_hub_sheet.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../providers/queue_providers.dart';
import '../../domain/services/song_search_service.dart';

class AddSongBottomSheet extends ConsumerStatefulWidget {
  final String roomId;

  const AddSongBottomSheet({super.key, required this.roomId});

  @override
  ConsumerState<AddSongBottomSheet> createState() => _AddSongBottomSheetState();
}

class _AddSongBottomSheetState extends ConsumerState<AddSongBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchTrackResult> _results = SongSearchService.curatedPicks;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final searchService = ref.read(songSearchServiceProvider);
    final results = await searchService.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _searchController.text = text;
      _performSearch(text);
    }
  }

  void _addTrack(SearchTrackResult track) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final queueItem = track.toQueueItem(
      addedBy: user.uid,
      addedByName: user.displayName,
      order: 1.0, // Order is calculated inside QueueRepository
    );

    ref.read(queueControllerProvider.notifier).addSong(
          roomId: widget.roomId,
          item: queueItem,
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${track.title}" to the queue!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78 + bottomInset,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
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
                Text('Add Song to Queue', style: AppTypography.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          // YouTube Hub Explorer Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: InkWell(
              onTap: () {
                final room =
                    ref.read(currentRoomProvider(widget.roomId)).valueOrNull;
                if (room != null) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => YouTubeHubSheet(room: room),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.25),
                      AppColors.surfaceHighlight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_display_rounded,
                        color: Colors.red, size: 24),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open Full YouTube Hub',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Login, browse your playlists & pick any song',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          // Search Field + Paste Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search title, artist or paste URL...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceHighlight,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => _performSearch(val),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                IconButton.filledTonal(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 20),
                  tooltip: 'Paste from Clipboard',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceHighlight,
                    foregroundColor: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.md),

          // Section Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchController.text.isEmpty
                    ? 'TRENDING & CURATED PICKS'
                    : 'SEARCH RESULTS',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xs),

          // Results List
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'No tracks found for "${_searchController.text}"',
                          style: AppTypography.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.lg,
                          vertical: AppDimens.sm,
                        ),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppDimens.xs),
                        itemBuilder: (context, index) {
                          final track = _results[index];

                          return GlassContainer(
                            borderRadius: AppDimens.radiusMd,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.md,
                              vertical: AppDimens.sm,
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppDimens.radiusSm),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    color: AppColors.surfaceHighlight,
                                    child: track.thumbnailUrl.isNotEmpty
                                        ? Image.network(
                                            track.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, _) =>
                                                const Icon(
                                              Icons.music_note,
                                              color: AppColors.primaryLight,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.music_note,
                                            color: AppColors.primaryLight,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: AppDimens.md),

                                // Title and Artist
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: AppTypography.bodyLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${track.artist} • ${track.sourceType.label}',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppDimens.sm),

                                // Add Button
                                ElevatedButton(
                                  onPressed: () => _addTrack(track),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppDimens.radiusFull),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 16),
                                      SizedBox(width: 4),
                                      Text('Add',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
