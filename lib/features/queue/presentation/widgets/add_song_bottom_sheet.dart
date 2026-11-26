import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../playback/presentation/widgets/youtube_hub_sheet.dart';
import '../../../playback/presentation/widgets/youtube_music_hub_sheet.dart';
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
  String _selectedGenre = 'All';

  final List<String> _quickGenres = const [
    'All',
    'Lo-Fi',
    'Synthwave',
    'Chillout',
    'Pop',
    'EDM',
    'Rock',
  ];

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

  void _onGenreSelected(String genre) {
    setState(() {
      _selectedGenre = genre;
    });
    if (genre == 'All') {
      _searchController.clear();
      setState(() {
        _results = SongSearchService.curatedPicks;
      });
    } else {
      _searchController.text = genre;
      _performSearch(genre);
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
      height: MediaQuery.of(context).size.height * 0.82 + bottomInset,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag Grab Handle
          const SizedBox(height: AppDimens.sm),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.md),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Song to Queue',
                    style: AppTypography.headlineSmall.copyWith(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                  splashRadius: 20,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xs),

          // Dual Explorer Cards: YouTube & YouTube Music
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: Row(
              children: [
                // 1. YouTube Hub Card
                Expanded(
                  child: Material(
                    color: Colors.transparent,
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
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withValues(alpha: 0.18),
                              AppColors.surfaceLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.smart_display_rounded,
                                  color: Colors.redAccent, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'YouTube Hub',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Videos & Sets',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                // 2. YouTube Music Hub Card
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final room =
                            ref.read(currentRoomProvider(widget.roomId)).valueOrNull;
                        if (room != null) {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => YouTubeMusicHubSheet(room: room),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withValues(alpha: 0.18),
                              AppColors.surfaceLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.music_note_rounded,
                                  color: Colors.redAccent, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'YT Music Hub',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Songs & Albums',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
          ),
          const SizedBox(height: AppDimens.md),

          // Search Field + Paste Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusFull),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search title, artist or paste link...',
                        hintStyle: AppTypography.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textMuted, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: AppColors.textMuted, size: 18),
                              splashRadius: 16,
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) => _performSearch(val),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: IconButton(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    tooltip: 'Paste link',
                    color: AppColors.secondary,
                    splashRadius: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sm + 2),

          // Quick Genre / Filter Chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
              itemCount: _quickGenres.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final genre = _quickGenres[index];
                final isSelected = _selectedGenre == genre;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    onTap: () => _onGenreSelected(genre),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusFull),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        genre,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryLight
                              : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
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
                            const SizedBox(height: AppDimens.sm),
                        itemBuilder: (context, index) {
                          final track = _results[index];

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusLg),
                              border: Border.all(
                                color: AppColors.glassBorder,
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimens.md,
                                  vertical: AppDimens.sm,
                                ),
                                child: Row(
                                  children: [
                                    // Thumbnail
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          AppDimens.radiusMd),
                                      child: Container(
                                        width: 46,
                                        height: 46,
                                        color: AppColors.surfaceHighlight,
                                        child: track.thumbnailUrl.isNotEmpty
                                            ? Image.network(
                                                track.thumbnailUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, _, _) =>
                                                        const Icon(
                                                  Icons.music_note_rounded,
                                                  color:
                                                      AppColors.primaryLight,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.music_note_rounded,
                                                color:
                                                    AppColors.primaryLight,
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
                                            style: AppTypography.bodyLarge
                                                .copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${track.artist} • ${track.sourceType.label}',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppDimens.sm),

                                    // Gradient Add Button
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(
                                            AppDimens.radiusFull),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                              AppDimens.radiusFull),
                                          onTap: () => _addTrack(track),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 7,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_rounded,
                                                    size: 15,
                                                    color: Colors.white),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Add',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600,
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
                              ),
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
