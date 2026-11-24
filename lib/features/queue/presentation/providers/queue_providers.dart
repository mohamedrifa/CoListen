import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:colisten/features/queue/domain/entities/queue_item_entity.dart';
import 'package:colisten/features/queue/domain/repositories/queue_repository.dart';
import 'package:colisten/features/queue/domain/services/song_search_service.dart';
import 'package:colisten/features/queue/data/repositories/queue_repository_impl.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepositoryImpl();
});

final songSearchServiceProvider = Provider<SongSearchService>((ref) {
  return SongSearchService();
});

final roomQueueProvider =
    StreamProvider.autoDispose.family<List<QueueItemEntity>, String>(
  (ref, roomId) {
    final repo = ref.watch(queueRepositoryProvider);
    return repo.watchQueue(roomId);
  },
);

final queueControllerProvider =
    StateNotifierProvider<QueueController, AsyncValue<void>>((ref) {
  final repo = ref.watch(queueRepositoryProvider);
  return QueueController(repo);
});

class QueueController extends StateNotifier<AsyncValue<void>> {
  final QueueRepository _repo;

  QueueController(this._repo) : super(const AsyncValue.data(null));

  Future<void> addSong({
    required String roomId,
    required QueueItemEntity item,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addSong(roomId: roomId, item: item);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeSong({
    required String roomId,
    required String itemId,
  }) async {
    try {
      await _repo.removeSong(roomId: roomId, itemId: itemId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reorderQueue({
    required String roomId,
    required List<QueueItemEntity> currentQueue,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (oldIndex < 0 ||
        oldIndex >= currentQueue.length ||
        newIndex < 0 ||
        newIndex > currentQueue.length) {
      return;
    }

    final item = currentQueue[oldIndex];
    double newOrder;

    if (newIndex == 0) {
      // Moved to top
      final topOrder = currentQueue.first.order;
      newOrder = topOrder > 1.0 ? topOrder / 2.0 : topOrder - 1.0;
    } else if (newIndex >= currentQueue.length - 1) {
      // Moved to bottom
      final lastOrder = currentQueue.last.order;
      newOrder = lastOrder + 1.0;
    } else {
      // Moved between items
      final before = currentQueue[newIndex - 1].order;
      final after = currentQueue[newIndex].order;
      newOrder = (before + after) / 2.0;
    }

    try {
      await _repo.reorderQueue(
        roomId: roomId,
        itemId: item.id,
        newOrder: newOrder,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleVoteSkip({
    required String roomId,
    required String itemId,
    required String uid,
    required bool currentVoted,
  }) async {
    try {
      await _repo.voteSkip(
        roomId: roomId,
        itemId: itemId,
        uid: uid,
        vote: !currentVoted,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> skipToNextSong(String roomId, [String? uid]) async {
    try {
      await _repo.skipToNextSong(roomId, uid);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
