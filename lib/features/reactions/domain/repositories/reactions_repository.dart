import '../entities/reaction_entity.dart';

abstract class ReactionsRepository {
  Stream<List<ReactionEntity>> watchReactions(String roomId);

  Future<void> sendReaction({
    required String roomId,
    required String uid,
    required String displayName,
    required String emoji,
  });
}
