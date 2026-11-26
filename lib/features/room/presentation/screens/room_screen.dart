import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/background_media_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_eq_bars.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../invites/domain/services/native_share_service.dart';
import '../../../playback/presentation/widgets/now_playing_view.dart';
import '../../../queue/presentation/providers/queue_providers.dart';
import '../../../queue/presentation/widgets/queue_bottom_sheet.dart';
import '../../../reactions/presentation/widgets/emoji_bar.dart';
import '../../../reactions/presentation/widgets/floating_reaction_canvas.dart';
import '../../data/services/presence_service.dart';
import '../../domain/entities/room_entity.dart';
import '../providers/room_providers.dart';
import '../widgets/members_bottom_sheet.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> with WidgetsBindingObserver {
  late final PresenceService _presenceService;
  late final BackgroundMediaService _mediaService;
  bool _isYouTubeHubMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _presenceService = ref.read(presenceServiceProvider);
    _mediaService = ref.read(backgroundMediaServiceProvider);
    _mediaService.checkPipMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mediaService.checkPipMode();
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        _presenceService.startHeartbeat(
              roomId: widget.roomId,
              uid: user.uid,
              displayName: user.displayName,
            );
        ref.read(roomControllerProvider.notifier).recordRoomVisit(
              uid: user.uid,
              roomId: widget.roomId,
              displayName: user.displayName,
            );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceService.stopHeartbeat();
    _mediaService.stopForeground();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _mediaService.checkPipMode();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) {
      _mediaService.checkPipMode();
    }
  }

  void _copyRoomLink(String code, [String? name]) {
    NativeShareService.shareRoom(roomName: name ?? 'Music Room', roomCode: code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room link copied! Code: $code'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Leave Room?', style: AppTypography.titleLarge),
        content: Text(
          'Are you sure you want to leave this listening room?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final user = ref.read(authStateProvider).valueOrNull;
              if (user != null) {
                ref.read(roomControllerProvider.notifier).leaveRoom(
                      roomId: widget.roomId,
                      uid: user.uid,
                    );
              }
              context.go('/');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isPip = ref.watch(pipModeProvider) ||
        (mq.size.height < 500 && mq.size.width < 500) ||
        (mq.size.height < 360) ||
        (mq.size.aspectRatio > 1.3 && mq.size.height < 450);
    final roomAsync = ref.watch(currentRoomProvider(widget.roomId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    // When minimized into Picture-in-Picture mode, render exclusively the full-bleed player without bars or headers
    if (isPip) {
      return ColoredBox(
        color: Colors.black,
        child: NowPlayingView(
          roomId: widget.roomId,
          canControl: false,
          isPipMode: true,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => _confirmLeave(context),
        ),
        title: roomAsync.when(
          data: (room) {
            if (room == null) return const Text('Room');
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => _copyRoomLink(room.code),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.code,
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, size: 13, color: AppColors.secondary),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('Room'),
        ),
        actions: [
          roomAsync.when(
            data: (room) {
              if (room == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => MembersBottomSheet(room: room),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 17, color: AppColors.textPrimary),
                          const SizedBox(width: 4),
                          Text(
                            '${room.members.length}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: AppColors.textPrimary, size: 20),
                    onPressed: () => _copyRoomLink(room.code),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: AppDimens.md),
                  Text('This room is no longer active.', style: AppTypography.titleLarge),
                  const SizedBox(height: AppDimens.lg),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Back to Lobby'),
                  ),
                ],
              ),
            );
          }

          final myRole = currentUser != null
              ? room.getRole(currentUser.uid)
              : UserRole.listener;

          return Stack(
            children: [
              SafeArea(
                top: !isPip,
                bottom: !isPip,
                left: !isPip,
                right: !isPip,
                child: Padding(
                  padding: isPip
                      ? EdgeInsets.zero
                      : (_isYouTubeHubMode
                          ? const EdgeInsets.fromLTRB(AppDimens.xs, AppDimens.xs, AppDimens.xs, 0)
                          : const EdgeInsets.all(AppDimens.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Room Header Card (Hidden in PiP and YouTube Hub mode to maximize video / search space)
                      if (!isPip && !_isYouTubeHubMode) ...[
                        GlassContainer(
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark,
                                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                ),
                                child: const Center(
                                  child: AnimatedEqBars(
                                    isPlaying: true,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppDimens.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(room.name, style: AppTypography.titleLarge),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Role: ${myRole.icon} ${myRole.label}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: myRole == UserRole.host
                                            ? AppColors.primaryLight
                                            : myRole == UserRole.controller
                                                ? AppColors.secondary
                                                : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                ),
                                child: const Text(
                                  'SYNC ACTIVE',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.md),
                      ],

                      // Center Stage: Now Playing & Audio Controls
                      Expanded(
                        child: NowPlayingView(
                          roomId: widget.roomId,
                          canControl: room.canChangeSongs(currentUser?.uid ?? ''),
                          isPipMode: isPip,
                          onHubModeChanged: (isHub) {
                            setState(() => _isYouTubeHubMode = isHub);
                          },
                        ),
                      ),

                      // These bottom elements collapse completely when in PiP or YouTube Hub mode
                      if (!isPip && !_isYouTubeHubMode) ...[
                        const SizedBox(height: AppDimens.sm),

                        // Live Floating Emoji Reactions Bar
                        Center(
                          child: EmojiBar(roomId: widget.roomId),
                        ),

                        const SizedBox(height: AppDimens.sm),

                        // Up Next / Queue Preview Pill
                        Consumer(
                          builder: (context, ref, _) {
                            final queueAsync = ref.watch(roomQueueProvider(widget.roomId));
                            return queueAsync.when(
                              data: (items) {
                                final count = items.length;
                                final nextTitle = items.isNotEmpty ? items.first.title : 'Tap to add songs';

                                return GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      builder: (_) => QueueBottomSheet(room: room),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: AppDimens.sm),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppDimens.md, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHighlight,
                                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                      border: Border.all(color: AppColors.glassBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.queue_music,
                                            size: 20, color: AppColors.secondary),
                                        const SizedBox(width: AppDimens.sm),
                                        Expanded(
                                          child: Text(
                                            items.isNotEmpty
                                                ? 'UP NEXT ($count): $nextTitle'
                                                : 'QUEUE: Tap to add songs',
                                            style: AppTypography.bodySmall.copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(Icons.keyboard_arrow_up,
                                            size: 20, color: AppColors.textMuted),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            );
                          },
                        ),

                        // Bottom Action Strip
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) => QueueBottomSheet(room: room),
                                  );
                                },
                                icon: const Icon(Icons.queue_music),
                                label: const Text('Queue'),
                              ),
                            ),
                            const SizedBox(width: AppDimens.sm),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) => MembersBottomSheet(room: room),
                                  );
                                },
                                icon: const Icon(Icons.people, size: 18),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Members (${room.members.length})',
                                    maxLines: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.sm),
                            IconButton.filledTonal(
                              onPressed: () => _copyRoomLink(room.code, room.name),
                              icon: const Icon(Icons.share, size: 20),
                              tooltip: 'Share Code',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surfaceHighlight,
                                foregroundColor: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Fullscreen Floating Reaction Canvas (disabled in PiP mode)
              if (!isPip)
                Positioned.fill(
                  child: FloatingReactionCanvas(roomId: widget.roomId),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}
