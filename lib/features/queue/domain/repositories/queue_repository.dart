import '../entities/queue_item_entity.dart';

abstract class QueueRepository {
  Stream<List<QueueItemEntity>> watchQueue(String roomId);

  Future<void> addSong({
    required String roomId,
    required QueueItemEntity item,
  });

  Future<void> removeSong({
    required String roomId,
    required String itemId,
  });

  Future<void> reorderQueue({
    required String roomId,
    required String itemId,
    required double newOrder,
  });

  Future<void> voteSkip({
    required String roomId,
    required String itemId,
    required String uid,
    required bool vote,
  });

  Future<void> toggleUpvote({
    required String roomId,
    required String itemId,
    required String uid,
    required bool upvote,
  });

  Future<void> skipToNextSong(String roomId, [String? currentUid]);

  Future<void> skipToPreviousSong(String roomId, [String? currentUid]);
}
