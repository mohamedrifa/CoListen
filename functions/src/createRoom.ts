import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

// Unambiguous Base-32 charset (no 0/O, 1/I)
const CODE_CHARS = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

function generateRandomCode(): string {
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += CODE_CHARS.charAt(Math.floor(Math.random() * CODE_CHARS.length));
  }
  return result;
}

/**
 * Cloud Function: createRoom
 * Creates a listening room with an unambiguous, collision-checked 6-character code.
 */
export const createRoom = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }

  const { name, displayName, settings } = request.data;
  if (!name || typeof name !== 'string') {
    throw new HttpsError('invalid-argument', 'Room name is required.');
  }

  const db = admin.database();

  // Collision-check code generator with 10 max retries
  let roomCode = '';
  let attempts = 0;

  while (attempts < 10) {
    const candidate = generateRandomCode();
    const snap = await db.ref(`roomCodes/${candidate}`).get();
    if (!snap.exists()) {
      roomCode = candidate;
      break;
    }
    attempts++;
  }

  if (!roomCode) {
    throw new HttpsError('resource-exhausted', 'Could not generate unique room code. Please try again.');
  }

  const newRoomRef = db.ref('rooms').push();
  const roomId = newRoomRef.key!;
  const now = admin.database.ServerValue.TIMESTAMP;

  const updates: Record<string, any> = {};
  updates[`roomCodes/${roomCode}`] = roomId;
  updates[`rooms/${roomId}`] = {
    code: roomCode,
    name: name.trim(),
    adminId: uid,
    createdAt: now,
    isActive: true,
    settings: {
      membersCanAddSongs: settings?.membersCanAddSongs ?? true,
      membersCanVoteSkip: settings?.membersCanVoteSkip ?? true,
      voteSkipThresholdPercent: settings?.voteSkipThresholdPercent ?? 50,
      isPrivate: settings?.isPrivate ?? false,
    },
    members: {
      [uid]: {
        displayName: displayName || 'Host',
        isController: true,
        joinedAt: now,
      },
    },
    playback: {
      currentItemId: '',
      trackId: '',
      sourceType: 'youtube',
      title: '',
      artist: '',
      thumbnailUrl: '',
      durationMs: 0,
      status: 'paused',
      positionMs: 0,
      updatedAt: now,
      updatedBy: uid,
    },
  };

  await db.ref().update(updates);

  return {
    roomId,
    roomCode,
  };
});
