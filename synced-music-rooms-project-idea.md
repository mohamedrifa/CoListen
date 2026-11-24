# Synced Music Rooms: Project Idea

**Stack:** Flutter (client) + Firebase (backend)
**Platforms:** Android and iOS
**Status:** Planning

---

## 1. Overview

A social music app where users listen to the same song at the same time, together, in private rooms.

A user creates a room and becomes its **admin**. Others join using a **room code** or an **in-app invite**. Everyone in the room hears the same track in sync, can add songs to a shared **queue**, and can see who is in the room. **Only the admin decides who is allowed to change songs.**

---

## 2. Original Requirements

| # | Requirement |
|---|---|
| 1 | Users can create a room |
| 2 | Other users can join via a room code or an in-app invite |
| 3 | Music is played from YouTube URLs, loaded through the YouTube UI in a webview |
| 4 | Songs should play without ads (ad blocker) |
| 5 | Background play must be supported |
| 6 | Song change and queueing must be implemented |
| 7 | Song change is allowed only if the room admin grants access to other users |
| 8 | Built with Flutter and Firebase |

---

## 3. Compliance Constraints (Read First)

Two of the requirements conflict with YouTube's terms, and this affects the whole design.

- **Ad blocking (req. 4):** YouTube's API Services Terms forbid blocking or altering ads. An ad blocker on the YouTube webview is a direct violation.
- **Background play (req. 5):** The official embedded player cannot play audio in the background. That is a YouTube Premium feature. Extracting audio streams (for example with `youtube_explode`) also violates the terms.

Apps built this way are commonly rejected by the Play Store and App Store, or removed later. YouTube can also break webview tricks at any time.

### Audio source options

| Option | Ads / Background play | Risk |
|---|---|---|
| **A. Official YouTube IFrame player** (`youtube_player_iframe`) | Ads play, no background play | Compliant, but does not meet the ad-free and background goals |
| **B. Option A with each user's own YouTube Premium** | Premium users see no ads | Google sign-in inside embedded webviews is often blocked, so unreliable |
| **C. Ad blocker + audio extraction** | Meets the original goals | High risk of store rejection, takedown and legal issues. Not recommended for a published app |
| **D. Licensed audio source** (Audius API, Jamendo, or Spotify SDK for Premium users) | Background play and no ads, fully legal | Different music catalog than YouTube |

### Decision

Build the room, sync, queue and permission system behind a **player abstraction**, so the audio source is swappable.

- **Development / prototype:** Option A (YouTube IFrame).
- **Shippable product:** move to Option D.

Only `trackId` and `sourceType` are stored per song, so nothing else in the app depends on the source.

---

## 4. Features

### 4.1 Authentication
- Sign in with Google or anonymous (guest) login via Firebase Auth.
- Profile: display name, avatar.

### 4.2 Rooms
- Create a room (name, optional settings).
- Unique 6-character room code (ambiguous characters such as O/0 and I/1 excluded).
- Join by code, by in-app invite, or by shared link.
- Member list with live presence (online/offline).
- Admin can remove members.
- Leave room. If the admin leaves, admin is transferred or the room ends.

### 4.3 Playback
- Synchronized play, pause, seek and song change for all members.
- New joiners automatically jump to the current position.
- Drift correction keeps devices aligned.
- Now-playing view with title, thumbnail and progress.

### 4.4 Queue
- Any member can add songs (configurable by the admin).
- Realtime queue list.
- Reorder, remove and skip (controllers only).
- Auto-advance to the next song when one ends.
- Empty-queue state ("Add a song").

### 4.5 Permissions
- **Admin:** full control, including granting and revoking control.
- **Controller:** a member the admin has allowed to change songs.
- **Listener:** default member. Can listen and add songs, but cannot play, pause, seek or skip.

### 4.6 Invites
- Admin searches users and sends an in-app invite.
- Push notification (FCM) to the invitee.
- Invitee accepts or declines inside the app.
- Shareable deep link: `https://yourapp.com/join/K7P2QX`.

### 4.7 Background play
- Supported only for sources that allow it (Option D).
- Foreground service on Android, audio background mode on iOS, with lock-screen controls.
- Lock-screen controls are disabled for listeners without control rights.

---

## 5. Architecture

```
Flutter app
├─ Auth (Firebase Auth)
├─ Room feature (create, join, members)
├─ Queue feature
├─ Player layer (abstract PlayerService)
│   ├─ YoutubeIframePlayerService
│   └─ (future) AudiusPlayerService / SpotifyPlayerService
├─ Sync engine (applies Firestore state to the player)
└─ Background service (audio_service, licensed sources only)

Firebase
├─ Auth
├─ Firestore (rooms, queue, invites, users)
├─ Realtime Database (presence + server time offset)
├─ Cloud Functions (join by code, invites, queue advance, cleanup)
├─ Cloud Messaging / FCM (invite notifications)
└─ Security Rules
```

### Tech stack

| Area | Choice |
|---|---|
| State management | Riverpod (or Bloc) |
| Auth | `firebase_auth` |
| Database | `cloud_firestore`, `firebase_database` |
| Backend logic | `cloud_functions` |
| Notifications | `firebase_messaging` |
| YouTube player | `youtube_player_iframe` |
| Background audio | `audio_service` + `just_audio` |
| Deep links | `app_links` (HTTPS App Links / Universal Links) |

> Firebase Dynamic Links is shut down. Do not use it.

---

## 6. Data Model

### `users/{uid}`
```
displayName, photoUrl, fcmToken
```

### `rooms/{roomId}`
```
code: "K7P2QX"
name
adminId: uid
createdAt, isActive
memberIds: [uid, ...]
controllerIds: [uid, ...]     // members allowed to change songs
settings: { membersCanAddSongs: true }
```

### `rooms/{roomId}/queue/{itemId}`
```
trackId, sourceType        // "youtube" | "audius" | ...
title, thumbnail, durationMs
addedBy: uid
order: number              // fractional ordering
```

### `rooms/{roomId}/playback/state` (single document)
```
currentItemId, trackId
status: "playing" | "paused" | "buffering"
positionMs: 42000          // position at the moment of update
updatedAt: serverTimestamp
updatedBy: uid
```

### `roomCodes/{code}`
```
roomId
```

### `invites/{inviteId}`
```
fromUid, toUid, roomId
status: "pending" | "accepted" | "declined"
createdAt
```

### Realtime Database (presence)
```
/presence/{roomId}/{uid}: true | false
```

---

## 7. Sync Logic (Core of the App)

1. A user with control rights (admin or controller) writes the playback state document on play, pause, seek or song change.
2. Every client listens to that document and applies it to its local player.
3. Position is **not** streamed continuously. Store `positionMs` and `updatedAt`, and each client computes:

   ```
   expectedPosition = positionMs + (serverNow - updatedAt)   // while playing
   ```
4. `serverNow` comes from the Realtime Database `.info/serverTimeOffset`, which is more accurate than the device clock.
5. **Drift correction:** about every 5 seconds, compare the local position with `expectedPosition`. Seek only if the difference is greater than about 1.5 seconds.
6. **On join:** read the current state and seek to the computed position.
7. **Song end:** the admin's client (or a Cloud Function) advances to the next queue item and writes the new state, using a transaction so that only one advance happens.

---

## 8. Permissions and Security Rules

### Rules summary

| Action | Admin | Controller | Listener |
|---|---|---|---|
| Read room, queue, playback | Yes | Yes | Yes |
| Add song to queue | Yes | Yes | Yes (if setting enabled) |
| Play / pause / seek / skip | Yes | Yes | No |
| Reorder / remove queue items | Yes | Yes | No |
| Grant or revoke control | Yes | No | No |
| Remove members | Yes | No | No |

### Firestore rules sketch

```
function isAdmin(roomId) {
  return get(/databases/$(database)/documents/rooms/$(roomId)).data.adminId == request.auth.uid;
}
function canControl(roomId) {
  let r = get(/databases/$(database)/documents/rooms/$(roomId)).data;
  return r.adminId == request.auth.uid || request.auth.uid in r.controllerIds;
}
function isMember(roomId) {
  return request.auth.uid in get(/databases/$(database)/documents/rooms/$(roomId)).data.memberIds;
}

match /rooms/{roomId} {
  allow read: if isMember(roomId);
  allow update: if isAdmin(roomId);   // controllerIds changes are admin-only
  match /queue/{itemId} {
    allow read, create: if isMember(roomId);
    allow update, delete: if canControl(roomId);
  }
  match /playback/{doc} {
    allow read: if isMember(roomId);
    allow write: if canControl(roomId);
  }
}
```

The UI hides controls from listeners, but **the security rules are the real enforcement**. Members must not be able to add themselves to `memberIds`. Joining goes through a Cloud Function.

---

## 9. Room Codes, Joining and Invites

| Flow | How it works |
|---|---|
| **Create room** | Cloud Function generates a unique 6-char code, creates the room and the `roomCodes` entry, and sets the caller as admin |
| **Join by code** | Callable function `joinRoom(code)` looks up the room and adds the uid to `memberIds`. Attempts are rate-limited to prevent brute-forcing |
| **In-app invite** | Admin searches users and creates an `invites` doc. A Cloud Function sends an FCM push. Accepting calls `joinRoom` for that room. The invite screen listens to `invites where toUid == me and status == pending` |
| **Link invite** | `https://yourapp.com/join/K7P2QX` handled by `app_links` |
| **Leaving / cleanup** | Admin leaving transfers admin or ends the room. A scheduled Cloud Function deletes inactive rooms |

---

## 10. Player Layer

```dart
abstract class PlayerService {
  Future<void> load(String trackId, {Duration start});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Stream<PlayerStatus> get status;      // ended, buffering, etc.
  Stream<Duration> get position;
}
```

- **YouTube (webview):** `youtube_player_iframe` with controller callbacks for state and position. Use the YouTube Data API for search and metadata (watch the quota and cache results).
- **Licensed sources (background play):** wrap `just_audio` in `audio_service`, with a foreground service on Android and the audio background mode on iOS, plus lock-screen controls.

---

## 11. Queue Behavior

- **Add:** writes a queue doc with `order = lastOrder + 1`.
- **Reorder:** update `order` using fractional values, so not every doc is rewritten.
- **Next (controller):** a transaction deletes or marks the played item, sets `currentItemId` to the next item, and resets `positionMs = 0` and `status = playing`.
- **Empty queue:** set status to `paused` and show "Add a song."

---

## 12. Screens

1. Splash / Login
2. Home (create room, join with code, pending invites, recent rooms)
3. Create Room
4. Join Room (code input)
5. Room (now playing, queue, members)
6. Add Song (search or paste URL)
7. Members and Permissions (admin: toggle control per member, remove member)
8. Invite Users
9. Profile / Settings

---

## 13. Suggested Flutter Folder Structure

```
lib/
├─ core/            (theme, routing, utils, constants)
├─ data/
│   ├─ models/
│   ├─ repositories/  (room, queue, playback, invite, auth)
│   └─ services/      (firebase, functions, fcm)
├─ player/
│   ├─ player_service.dart
│   ├─ youtube_iframe_player_service.dart
│   └─ audio_player_service.dart
├─ sync/            (sync engine, server time offset, drift correction)
├─ features/
│   ├─ auth/
│   ├─ home/
│   ├─ room/
│   ├─ queue/
│   ├─ members/
│   └─ invites/
└─ main.dart

functions/
├─ createRoom.ts
├─ joinRoom.ts
├─ sendInvite.ts
├─ advanceQueue.ts
└─ cleanupRooms.ts
```

---

## 14. Build Phases

| Phase | Work |
|---|---|
| 1. Foundations | Firebase project, Auth, Flutter structure, state management, basic UI |
| 2. Rooms | Create room, code generation, join by code, member list, presence |
| 3. Single-user player | Player abstraction, YouTube iframe, search and add song |
| 4. Queue | Realtime queue UI, add, remove, reorder |
| 5. Sync engine | Playback state doc, server time offset, drift correction, song-end handling |
| 6. Permissions | `controllerIds`, admin toggles, security rules, emulator tests |
| 7. Invites | User search, invites collection, FCM, deep links |
| 8. Background and polish | `audio_service` for licensed sources, reconnect handling, error states, analytics |
| 9. Testing | Firebase Emulator Suite for rules and functions, multi-device sync tests on poor networks |

---

## 15. Risks and Pitfalls

| Risk | Mitigation |
|---|---|
| Some YouTube videos have embedding disabled | Detect the error and auto-skip |
| Mobile webviews may block autoplay | Require a user tap before the first play |
| Firestore cost from frequent writes | Write only on state changes, never continuously |
| Device clock and latency differences | Server time offset plus drift correction |
| YouTube Data API quota | Cache search results, limit queries |
| Store rejection or takedown (ad blocking, audio extraction) | Use compliant sources (Options A or D) |
| Race conditions on song end | Advance the queue in a transaction |
| Room code brute-forcing | Rate limiting in `joinRoom` |

---

## 16. Out of Scope (for now)

- Ad blocking and audio extraction from YouTube (see Section 3)
- Voice chat or video
- Public rooms and discovery
- Playlists saved across rooms
- Web or desktop clients

---

## 17. Open Decisions

1. Audio source for the shipped product: Option A (YouTube IFrame) or Option D (licensed source).
2. State management: Riverpod or Bloc.
3. Who advances the queue on song end: the admin client or a Cloud Function.
4. Whether "members can add songs" is always on or a room setting.
5. What happens when the admin leaves: transfer admin or end the room.
