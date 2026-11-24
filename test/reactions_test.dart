import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:colisten/features/auth/domain/entities/user_entity.dart';
import 'package:colisten/features/auth/presentation/providers/auth_provider.dart';
import 'package:colisten/features/reactions/domain/entities/reaction_entity.dart';
import 'package:colisten/features/reactions/domain/repositories/reactions_repository.dart';
import 'package:colisten/features/reactions/presentation/providers/reactions_provider.dart';
import 'package:colisten/features/reactions/presentation/widgets/emoji_bar.dart';
import 'package:colisten/features/reactions/presentation/widgets/floating_reaction_canvas.dart';

class MockReactionsRepository implements ReactionsRepository {
  final StreamController<List<ReactionEntity>> _controller =
      StreamController<List<ReactionEntity>>.broadcast();
  final List<ReactionEntity> _reactions = [];

  void emitReactions(List<ReactionEntity> list) {
    _reactions.clear();
    _reactions.addAll(list);
    _controller.add(List.from(_reactions));
  }

  @override
  Stream<List<ReactionEntity>> watchReactions(String roomId) async* {
    yield _reactions;
    yield* _controller.stream;
  }

  @override
  Future<void> sendReaction({
    required String roomId,
    required String uid,
    required String displayName,
    required String emoji,
  }) async {
    final reaction = ReactionEntity(
      id: 'react_${_reactions.length + 1}',
      uid: uid,
      displayName: displayName,
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    _reactions.add(reaction);
    _controller.add(List.from(_reactions));
  }
}

void main() {
  group('ReactionEntity Serialization', () {
    test('toMap and fromMap preserve values correctly', () {
      final original = ReactionEntity(
        id: 'rx_123',
        uid: 'user_456',
        displayName: 'Alex DJ',
        emoji: '🔥',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final map = original.toMap();
      final restored = ReactionEntity.fromMap('rx_123', map);

      expect(restored.id, equals(original.id));
      expect(restored.uid, equals(original.uid));
      expect(restored.displayName, equals(original.displayName));
      expect(restored.emoji, equals(original.emoji));
      expect(restored.createdAt, equals(original.createdAt));
    });
  });

  group('Reactions Widgets Tests', () {
    testWidgets('EmojiBar renders all standard emojis and sends reaction on tap',
        (WidgetTester tester) async {
      final mockRepo = MockReactionsRepository();
      const mockUser = UserEntity(uid: 'user_1', displayName: 'Alex');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reactionsRepositoryProvider.overrideWithValue(mockRepo),
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: EmojiBar(roomId: 'room_123'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check all 7 emojis are present
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('💃'), findsOneWidget);
      expect(find.text('🎧'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);
      expect(find.text('⚡'), findsOneWidget);
      expect(find.text('👏'), findsOneWidget);

      // Tap 🔥 emoji
      await tester.tap(find.text('🔥'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockRepo._reactions.length, equals(1));
      expect(mockRepo._reactions.first.emoji, equals('🔥'));
      expect(mockRepo._reactions.first.displayName, equals('Alex'));
    });

    testWidgets('FloatingReactionCanvas displays incoming reaction particle',
        (WidgetTester tester) async {
      final mockRepo = MockReactionsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reactionsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: FloatingReactionCanvas(roomId: 'room_test'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Emit new reaction
      final newReaction = ReactionEntity(
        id: 'rx_burst_1',
        uid: 'user_sarah',
        displayName: 'Sarah',
        emoji: '💃',
        createdAt: DateTime.now(),
      );

      mockRepo.emitReactions([newReaction]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Particle should now be rendered on canvas
      expect(find.text('💃'), findsOneWidget);
      expect(find.text('Sarah'), findsOneWidget);
    });
  });
}
