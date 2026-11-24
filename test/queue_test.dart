import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:colisten/features/playback/domain/services/player_service.dart';
import 'package:colisten/features/queue/domain/entities/queue_item_entity.dart';
import 'package:colisten/features/queue/domain/repositories/queue_repository.dart';
import 'package:colisten/features/queue/domain/services/song_search_service.dart';
import 'package:colisten/features/queue/presentation/providers/queue_providers.dart';

class MockQueueRepository implements QueueRepository {
  final StreamController<List<QueueItemEntity>> _controller =
      StreamController<List<QueueItemEntity>>.broadcast();
  List<QueueItemEntity> _items = [];

  void emitQueue(List<QueueItemEntity> items) {
    _items = List.from(items);
    _controller.add(_items);
  }

  @override
  Stream<List<QueueItemEntity>> watchQueue(String roomId) async* {
    yield _items;
    yield* _controller.stream;
  }

  @override
  Future<void> addSong({
    required String roomId,
    required QueueItemEntity item,
  }) async {
    final newItem = item.copyWith(
      id: 'item_${_items.length + 1}',
      order: _items.isNotEmpty ? _items.last.order + 1.0 : 1.0,
    );
    _items.add(newItem);
    _controller.add(List.from(_items));
  }

  @override
  Future<void> removeSong({
    required String roomId,
    required String itemId,
  }) async {
    _items.removeWhere((i) => i.id == itemId);
    _controller.add(List.from(_items));
  }

  @override
  Future<void> reorderQueue({
    required String roomId,
    required String itemId,
    required double newOrder,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(order: newOrder);
      _items.sort((a, b) => a.order.compareTo(b.order));
      _controller.add(List.from(_items));
    }
  }

  @override
  Future<void> voteSkip({
    required String roomId,
    required String itemId,
    required String uid,
    required bool vote,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final updatedVotes = Map<String, bool>.from(_items[index].voteSkipUids);
      if (vote) {
        updatedVotes[uid] = true;
      } else {
        updatedVotes.remove(uid);
      }
      _items[index] = _items[index].copyWith(voteSkipUids: updatedVotes);
      _controller.add(List.from(_items));
    }
  }

  @override
  Future<void> toggleUpvote({
    required String roomId,
    required String itemId,
    required String uid,
    required bool upvote,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final updatedUpvotes = Map<String, bool>.from(_items[index].upvoteUids);
      if (upvote) {
        updatedUpvotes[uid] = true;
      } else {
        updatedUpvotes.remove(uid);
      }
      _items[index] = _items[index].copyWith(upvoteUids: updatedUpvotes);
      _items.sort((a, b) => a.compareTo(b));
      _controller.add(List.from(_items));
    }
  }

  @override
  Future<void> skipToNextSong(String roomId, [String? currentUid]) async {
    if (_items.isNotEmpty) {
      _items.removeAt(0);
      _controller.add(List.from(_items));
    }
  }
}

void main() {
  group('QueueItemEntity Tests', () {
    test('Formatted duration formats milliseconds to mm:ss', () {
      final item = QueueItemEntity(
        id: '1',
        trackId: 't1',
        title: 'Song',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 243000, // 4m 03s
        addedBy: 'u1',
        addedByName: 'Alex',
        addedAt: DateTime(2026, 1, 1),
        order: 1.0,
      );

      expect(item.formattedDuration, equals('4:03'));
    });

    test('Vote to skip threshold calculation', () {
      final item = QueueItemEntity(
        id: '1',
        trackId: 't1',
        title: 'Song',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 180000,
        addedBy: 'u1',
        addedByName: 'Alex',
        addedAt: DateTime.now(),
        order: 1.0,
        voteSkipUids: {'u1': true, 'u2': true},
      );

      expect(item.voteSkipCount, equals(2));
      expect(item.hasUserVoted('u1'), isTrue);
      expect(item.hasUserVoted('u3'), isFalse);

      // Total members = 4, threshold = 50% -> (2 / 4) * 100 = 50% -> shouldSkip true
      expect(item.shouldSkip(4, 50), isTrue);

      // Total members = 5, threshold = 50% -> (2 / 5) * 100 = 40% -> shouldSkip false
      expect(item.shouldSkip(5, 50), isFalse);
    });

    test('Serialization toMap and fromMap preserves all values', () {
      final original = QueueItemEntity(
        id: 'queue_99',
        trackId: 'yt_abc123',
        sourceType: AudioSourceType.youtube,
        title: 'Midnight Beats',
        artist: 'DJ LoFi',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        durationMs: 210000,
        addedBy: 'user_42',
        addedByName: 'Alex DJ',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        order: 2.5,
        voteSkipUids: {'u1': true, 'u2': true},
      );

      final map = original.toMap();
      final restored = QueueItemEntity.fromMap('queue_99', map);

      expect(restored.id, equals(original.id));
      expect(restored.trackId, equals(original.trackId));
      expect(restored.title, equals(original.title));
      expect(restored.artist, equals(original.artist));
      expect(restored.sourceType, equals(original.sourceType));
      expect(restored.order, equals(original.order));
      expect(restored.voteSkipCount, equals(2));
      expect(restored.hasUserVoted('u1'), isTrue);
    });
  });

  group('SongSearchService Tests', () {
    final searchService = SongSearchService();

    test('extractYoutubeVideoId parses various YouTube URL formats', () {
      expect(
        SongSearchService.extractYoutubeVideoId(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        SongSearchService.extractYoutubeVideoId('https://youtu.be/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        SongSearchService.extractYoutubeVideoId(
            'https://www.youtube.com/embed/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        SongSearchService.extractYoutubeVideoId('https://google.com'),
        isNull,
      );
    });

    test('Direct YouTube URL paste returns single resolved result', () async {
      final results = await searchService.search(
          'https://www.youtube.com/watch?v=fHI8X480mxo');
      expect(results.length, equals(1));
      expect(results.first.trackId, equals('fHI8X480mxo'));
    });

    test('Keyword query matches curated catalog', () async {
      final results = await searchService.search('Daft Punk');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.artist, equals('Daft Punk'));
    });

    test('Empty query returns curated picks list', () async {
      final results = await searchService.search('');
      expect(results.length, equals(SongSearchService.curatedPicks.length));
    });
  });

  group('QueueController Fractional Reordering Tests', () {
    late MockQueueRepository mockRepo;
    late QueueController controller;

    setUp(() {
      mockRepo = MockQueueRepository();
      controller = QueueController(mockRepo);
    });

    test('Reordering between items calculates fractional order', () async {
      final items = [
        QueueItemEntity(
          id: 'item_1',
          trackId: 't1',
          title: 'Track 1',
          artist: 'A',
          thumbnailUrl: '',
          durationMs: 180000,
          addedBy: 'u1',
          addedByName: 'Alex',
          addedAt: DateTime.now(),
          order: 1.0,
        ),
        QueueItemEntity(
          id: 'item_2',
          trackId: 't2',
          title: 'Track 2',
          artist: 'B',
          thumbnailUrl: '',
          durationMs: 180000,
          addedBy: 'u1',
          addedByName: 'Alex',
          addedAt: DateTime.now(),
          order: 2.0,
        ),
        QueueItemEntity(
          id: 'item_3',
          trackId: 't3',
          title: 'Track 3',
          artist: 'C',
          thumbnailUrl: '',
          durationMs: 180000,
          addedBy: 'u1',
          addedByName: 'Alex',
          addedAt: DateTime.now(),
          order: 3.0,
        ),
      ];

      mockRepo.emitQueue(items);

      // Move Track 3 between Track 1 and Track 2
      // newIndex = 1 -> newOrder = (1.0 + 2.0) / 2 = 1.5
      await controller.reorderQueue(
        roomId: 'room_1',
        currentQueue: items,
        oldIndex: 2,
        newIndex: 1,
      );

      expect(mockRepo._items[1].id, equals('item_3'));
      expect(mockRepo._items[1].order, equals(1.5));
    });

    test('Voting to skip updates repository votes', () async {
      final item = QueueItemEntity(
        id: 'item_vote',
        trackId: 'tv',
        title: 'Vote Track',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 180000,
        addedBy: 'u1',
        addedByName: 'Alex',
        addedAt: DateTime.now(),
        order: 1.0,
      );

      mockRepo.emitQueue([item]);

      await controller.toggleVoteSkip(
        roomId: 'room_1',
        itemId: 'item_vote',
        uid: 'user_voter',
        currentVoted: false,
      );

      expect(mockRepo._items.first.hasUserVoted('user_voter'), isTrue);

      await controller.toggleVoteSkip(
        roomId: 'room_1',
        itemId: 'item_vote',
        uid: 'user_voter',
        currentVoted: true,
      );

      expect(mockRepo._items.first.hasUserVoted('user_voter'), isFalse);
    });

    test('Voting basis queue ordering sorts higher upvoted songs to the top', () async {
      final songA = QueueItemEntity(
        id: 'song_a',
        trackId: 'ta',
        title: 'Song A',
        artist: 'Artist A',
        thumbnailUrl: '',
        durationMs: 180000,
        addedBy: 'u1',
        addedByName: 'Alex',
        addedAt: DateTime.now(),
        order: 1.0,
      );
      final songB = QueueItemEntity(
        id: 'song_b',
        trackId: 'tb',
        title: 'Song B',
        artist: 'Artist B',
        thumbnailUrl: '',
        durationMs: 180000,
        addedBy: 'u2',
        addedByName: 'Sam',
        addedAt: DateTime.now(),
        order: 2.0,
      );

      mockRepo.emitQueue([songA, songB]);

      // Upvote Song B
      await controller.toggleUpvote(
        roomId: 'room_1',
        itemId: 'song_b',
        uid: 'voter_1',
        currentUpvoted: false,
      );

      // Song B should now be sorted to position 0 (top of queue) because it has 1 upvote vs 0
      expect(mockRepo._items.first.id, equals('song_b'));
      expect(mockRepo._items.first.upvoteCount, equals(1));
      expect(mockRepo._items[1].id, equals('song_a'));
    });
  });
}
