import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:colisten/app.dart';
import 'package:colisten/core/sync/server_clock.dart';
import 'package:colisten/features/auth/domain/entities/user_entity.dart';
import 'package:colisten/features/auth/domain/repositories/auth_repository.dart';
import 'package:colisten/features/auth/presentation/providers/auth_provider.dart';
import 'package:colisten/features/invites/domain/entities/invite_entity.dart';
import 'package:colisten/features/invites/domain/repositories/invite_repository.dart';
import 'package:colisten/features/invites/presentation/providers/invites_provider.dart';
import 'package:colisten/features/playback/domain/entities/playback_state_entity.dart';
import 'package:colisten/features/playback/presentation/providers/playback_sync_provider.dart';
import 'package:colisten/features/playback/presentation/widgets/now_playing_view.dart';
import 'package:colisten/features/queue/domain/entities/queue_item_entity.dart';
import 'package:colisten/features/queue/presentation/providers/queue_providers.dart';
import 'package:colisten/features/queue/presentation/widgets/queue_bottom_sheet.dart';
import 'package:colisten/features/queue/presentation/widgets/add_song_bottom_sheet.dart';
import 'package:colisten/features/reactions/presentation/providers/reactions_provider.dart';
import 'package:colisten/features/room/data/services/presence_service.dart';
import 'package:colisten/features/room/domain/entities/room_entity.dart';
import 'package:colisten/features/room/domain/entities/room_history_entity.dart';
import 'package:colisten/features/room/domain/repositories/room_repository.dart';
import 'package:colisten/features/room/presentation/providers/room_providers.dart';
import 'package:colisten/features/room/presentation/screens/room_screen.dart';
import 'playback_sync_test.dart';
import 'queue_test.dart';
import 'reactions_test.dart';

class MockAuthRepository implements AuthRepository {
  final UserEntity? initialUser;
  MockAuthRepository({this.initialUser});

  @override
  Stream<UserEntity?> get authStateChanges => Stream.value(initialUser);

  @override
  UserEntity? get currentUser => initialUser;

  @override
  Future<UserEntity> signInAnonymously(String displayName) async =>
      UserEntity(uid: 'guest', displayName: displayName, isAnonymous: true);

  @override
  Future<UserEntity> signInWithGoogle() async =>
      const UserEntity(uid: 'google_user', displayName: 'Google User');

  @override
  Future<void> signOut() async {}
}

class MockInviteRepository implements InviteRepository {
  @override
  Stream<List<InviteEntity>> watchMyPendingInvites(String uid) =>
      Stream.value([]);

  @override
  Future<void> sendInvite({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String roomId,
    required String roomName,
    required String roomCode,
  }) async {}

  @override
  Future<void> acceptInvite(String uid, String inviteId) async {}

  @override
  Future<void> declineInvite(String uid, String inviteId) async {}
}

class MockRoomRepository implements RoomRepository {
  final RoomEntity? defaultRoom;
  MockRoomRepository({this.defaultRoom});

  @override
  Future<RoomEntity> createRoom({
    required String name,
    required String adminId,
    required String adminName,
    required RoomSettings settings,
  }) async {
    return RoomEntity(
      id: 'room_test_123',
      code: 'K7P2QX',
      name: name,
      adminId: adminId,
      createdAt: DateTime.now(),
      settings: settings,
      members: {
        adminId: RoomMemberEntity(
          uid: adminId,
          displayName: adminName,
          isController: true,
          joinedAt: DateTime.now(),
        ),
      },
    );
  }

  @override
  Future<String> joinRoomByCode({
    required String code,
    required String uid,
    required String displayName,
  }) async =>
      'room_test_123';

  @override
  Stream<RoomEntity?> watchRoom(String roomId) =>
      Stream.value(defaultRoom);

  @override
  Future<void> toggleControllerRole({
    required String roomId,
    required String targetUid,
    required bool isController,
  }) async {}

  @override
  Future<void> removeMember({
    required String roomId,
    required String targetUid,
  }) async {}

  @override
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) async {}

  @override
  Stream<List<RoomHistoryEntity>> watchUserRoomHistory(String uid) =>
      Stream.value([
        RoomHistoryEntity(
          roomId: 'room_test_123',
          code: 'K7P2QX',
          name: 'Late Night Music Room',
          adminId: uid,
          adminName: 'Test User',
          role: 'Host',
          joinedAt: DateTime.now(),
          lastVisitedAt: DateTime.now(),
        ),
      ]);

  @override
  Future<void> removeRoomFromHistory({
    required String uid,
    required String roomId,
  }) async {}

  @override
  Future<void> recordRoomVisit({
    required String uid,
    required String roomId,
    required String displayName,
  }) async {}
}

void main() {
  testWidgets('CoListenApp unauthenticated shows LoginScreen',
      (WidgetTester tester) async {
    final mockAuth = MockAuthRepository(initialUser: null);
    final mockInvites = MockInviteRepository();
    final mockRoom = MockRoomRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          inviteRepositoryProvider.overrideWithValue(mockInvites),
          roomRepositoryProvider.overrideWithValue(mockRoom),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const CoListenApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Listen together. In sync.'), findsOneWidget);
    expect(find.text('Real-time music rooms with zero drift.'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('CoListenApp authenticated shows HomeScreen and opens Create Room sheet',
      (WidgetTester tester) async {
    final mockUser = const UserEntity(uid: 'test_1', displayName: 'Alex DJ');
    final mockAuth = MockAuthRepository(initialUser: mockUser);
    final mockInvites = MockInviteRepository();
    final mockRoom = MockRoomRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          inviteRepositoryProvider.overrideWithValue(mockInvites),
          roomRepositoryProvider.overrideWithValue(mockRoom),
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
        ],
        child: const CoListenApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CoListen'), findsOneWidget);
    expect(find.text('Synchronized Music Rooms'), findsOneWidget);
    expect(find.text('Create Room'), findsOneWidget);

    // Tap Create Room button
    await tester.tap(find.text('Create Room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Create Room sheet is displayed
    expect(find.text('Create Music Room'), findsOneWidget);
    expect(find.text('Allow members to add songs'), findsOneWidget);
    expect(find.text('Enable Vote-to-Skip'), findsOneWidget);
  });

  testWidgets('HomeScreen opens Join Code sheet',
      (WidgetTester tester) async {
    final mockUser = const UserEntity(uid: 'test_1', displayName: 'Alex DJ');
    final mockAuth = MockAuthRepository(initialUser: mockUser);
    final mockInvites = MockInviteRepository();
    final mockRoom = MockRoomRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          inviteRepositoryProvider.overrideWithValue(mockInvites),
          roomRepositoryProvider.overrideWithValue(mockRoom),
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
        ],
        child: const CoListenApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Enter Code button
    await tester.tap(find.text('Enter Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Join Code sheet is displayed
    expect(find.text('Join with Room Code'), findsOneWidget);
    expect(find.text('Paste from Clipboard'), findsOneWidget);
    expect(find.text('Join Room Now'), findsOneWidget);
  });

  testWidgets('NowPlayingView shows empty state when no track is playing',
      (WidgetTester tester) async {
    final fakePlayer = FakePlayerService();
    final fakeRepo = FakePlaybackRepository();
    final fakeClock = ServerClock(initialOffsetMs: 0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerServiceProvider.overrideWithValue(fakePlayer),
          playbackRepositoryProvider.overrideWithValue(fakeRepo),
          serverClockProvider.overrideWithValue(fakeClock),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NowPlayingView(roomId: 'room_empty', canControl: true),
          ),
        ),
      ),
    );

    // Emit empty playback
    fakeRepo.emitState(PlaybackStateEntity.empty());
    await tester.pump();

    expect(find.text('No Track Playing'), findsOneWidget);
    expect(find.text('Add songs to the queue to start listening'), findsOneWidget);
  });

  testWidgets('NowPlayingView displays vinyl and track info when track is playing',
      (WidgetTester tester) async {
    final fakePlayer = FakePlayerService();
    final fakeRepo = FakePlaybackRepository();
    final fakeClock = ServerClock(initialOffsetMs: 0);

    final track = PlaybackStateEntity(
      currentItemId: 'item_123',
      trackId: 'track_123',
      title: 'Synthwave Nightfall',
      artist: 'Kavinsky & Daft',
      thumbnailUrl: '',
      durationMs: 240000,
      positionMs: 60000,
      status: 'playing',
      updatedAt: DateTime.now(),
      updatedBy: 'host_1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerServiceProvider.overrideWithValue(fakePlayer),
          playbackRepositoryProvider.overrideWithValue(fakeRepo),
          serverClockProvider.overrideWithValue(fakeClock),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: NowPlayingView(roomId: 'room_playing', canControl: true),
          ),
        ),
      ),
    );

    fakeRepo.emitState(track);
    await tester.pump();

    expect(find.text('Synthwave Nightfall'), findsOneWidget);
    expect(find.text('Kavinsky & Daft'), findsOneWidget);
    expect(find.text('YouTube Stream'), findsOneWidget);
    expect(find.text('Ad Blocker Active'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('RoomScreen integrates NowPlayingView and displays room info',
      (WidgetTester tester) async {
    final mockUser = const UserEntity(uid: 'admin_1', displayName: 'Host DJ');
    final mockAuth = MockAuthRepository(initialUser: mockUser);
    final mockInvites = MockInviteRepository();
    final fakePlayer = FakePlayerService();
    final fakeRepo = FakePlaybackRepository();
    final fakeClock = ServerClock(initialOffsetMs: 0);
    final fakePresence = PresenceService();
    final mockQueue = MockQueueRepository();
    final mockReactions = MockReactionsRepository();

    final testRoom = RoomEntity(
      id: 'room_test_123',
      code: 'K7P2QX',
      name: 'Electric Vibes Room',
      adminId: 'admin_1',
      createdAt: DateTime.now(),
      members: {
        'admin_1': RoomMemberEntity(
          uid: 'admin_1',
          displayName: 'Host DJ',
          isController: true,
          joinedAt: DateTime.now(),
        ),
      },
    );

    final mockRoom = MockRoomRepository(defaultRoom: testRoom);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          inviteRepositoryProvider.overrideWithValue(mockInvites),
          roomRepositoryProvider.overrideWithValue(mockRoom),
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          playerServiceProvider.overrideWithValue(fakePlayer),
          playbackRepositoryProvider.overrideWithValue(fakeRepo),
          serverClockProvider.overrideWithValue(fakeClock),
          presenceServiceProvider.overrideWithValue(fakePresence),
          queueRepositoryProvider.overrideWithValue(mockQueue),
          reactionsRepositoryProvider.overrideWithValue(mockReactions),
        ],
        child: const MaterialApp(
          home: RoomScreen(roomId: 'room_test_123'),
        ),
      ),
    );

    fakeRepo.emitState(PlaybackStateEntity.empty());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Electric Vibes Room'), findsOneWidget);
    expect(find.text('Role: 👑 Host'), findsOneWidget);
    expect(find.text('SYNC ACTIVE'), findsOneWidget);
    expect(find.text('No Track Playing'), findsOneWidget);
  });

  testWidgets('QueueBottomSheet displays shared queue and add song action',
      (WidgetTester tester) async {
    final mockUser = const UserEntity(uid: 'admin_1', displayName: 'Host DJ');
    final fakePlayer = FakePlayerService();
    final fakeRepo = FakePlaybackRepository();
    final fakeClock = ServerClock(initialOffsetMs: 0);
    final mockQueue = MockQueueRepository();

    final testRoom = RoomEntity(
      id: 'room_test_123',
      code: 'K7P2QX',
      name: 'Electric Vibes Room',
      adminId: 'admin_1',
      createdAt: DateTime.now(),
      members: {
        'admin_1': RoomMemberEntity(
          uid: 'admin_1',
          displayName: 'Host DJ',
          isController: true,
          joinedAt: DateTime.now(),
        ),
      },
    );

    final item1 = QueueItemEntity(
      id: 'item_1',
      trackId: 't1',
      title: 'Midnight City',
      artist: 'M83',
      thumbnailUrl: '',
      durationMs: 240000,
      addedBy: 'admin_1',
      addedByName: 'Host DJ',
      addedAt: DateTime.now(),
      order: 1.0,
    );

    mockQueue.emitQueue([item1]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          playerServiceProvider.overrideWithValue(fakePlayer),
          playbackRepositoryProvider.overrideWithValue(fakeRepo),
          serverClockProvider.overrideWithValue(fakeClock),
          queueRepositoryProvider.overrideWithValue(mockQueue),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: QueueBottomSheet(room: testRoom),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Shared Queue (1 upcoming)'), findsOneWidget);
    expect(find.text('Add Song'), findsOneWidget);
    expect(find.text('Midnight City'), findsOneWidget);
    expect(find.text('UP NEXT'), findsOneWidget);
  });

  testWidgets('AddSongBottomSheet displays search input and trending picks',
      (WidgetTester tester) async {
    final mockUser = const UserEntity(uid: 'admin_1', displayName: 'Host DJ');
    final mockQueue = MockQueueRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          queueRepositoryProvider.overrideWithValue(mockQueue),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddSongBottomSheet(roomId: 'room_test_123'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Add Song to Queue'), findsOneWidget);
    expect(find.text('TRENDING & CURATED PICKS'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
