import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:colisten/features/reactions/domain/entities/reaction_entity.dart';
import 'package:colisten/features/reactions/domain/repositories/reactions_repository.dart';
import 'package:colisten/features/reactions/data/repositories/reactions_repository_impl.dart';

final reactionsRepositoryProvider = Provider<ReactionsRepository>((ref) {
  return ReactionsRepositoryImpl();
});

final roomReactionsStreamProvider =
    StreamProvider.autoDispose.family<List<ReactionEntity>, String>(
  (ref, roomId) {
    final repo = ref.watch(reactionsRepositoryProvider);
    return repo.watchReactions(roomId);
  },
);

final reactionControllerProvider =
    StateNotifierProvider<ReactionController, AsyncValue<void>>((ref) {
  final repo = ref.watch(reactionsRepositoryProvider);
  return ReactionController(repo);
});

class ReactionController extends StateNotifier<AsyncValue<void>> {
  final ReactionsRepository _repo;

  ReactionController(this._repo) : super(const AsyncValue.data(null));

  Future<void> sendReaction({
    required String roomId,
    required String uid,
    required String displayName,
    required String emoji,
  }) async {
    try {
      await _repo.sendReaction(
        roomId: roomId,
        uid: uid,
        displayName: displayName,
        emoji: emoji,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
