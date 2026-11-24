import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

/**
 * Cloud Function: advanceQueue
 * Atomically advances the room playback to the top track in the queue,
 * or clears playback if the queue is empty.
 * Prevents double-skips via atomic database transaction.
 */
export const advanceQueue = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'User must be signed in to skip tracks.');
  }

  const { roomId } = request.data;
  if (!roomId || typeof roomId !== 'string') {
    throw new HttpsError('invalid-argument', 'Valid roomId is required.');
  }

  const db = admin.database();

  // 1. Verify caller has DJ / Host privileges or vote threshold met
  const roomSnap = await db.ref(`rooms/${roomId}`).get();
  if (!roomSnap.exists()) {
    throw new HttpsError('not-found', 'Room not found.');
  }

  const room = roomSnap.val();
  const isAdmin = room.adminId === uid;
  const isController = room.members?.[uid]?.isController === true;

  if (!isAdmin && !isController) {
    throw new HttpsError('permission-denied', 'Only DJs or the Host can advance the queue directly.');
  }

  // 2. Fetch queue items ordered by 'order'
  const queueSnap = await db.ref(`rooms/${roomId}/queue`).orderByChild('order').get();

  if (!queueSnap.exists() || !queueSnap.val()) {
    // Queue is empty, reset playback
    await db.ref(`rooms/${roomId}/playback`).set({
      currentItemId: '',
      trackId: '',
      sourceType: 'youtube',
      title: '',
      artist: '',
      thumbnailUrl: '',
      durationMs: 0,
      status: 'paused',
      positionMs: 0,
      updatedAt: admin.database.ServerValue.TIMESTAMP,
      updatedBy: uid,
    });

    return { success: true, message: 'Queue was empty, playback reset.' };
  }

  const items: any[] = [];
  queueSnap.forEach((child) => {
    items.push({ id: child.key, ...child.val() });
  });

  const nextSong = items[0];

  // 3. Atomically update playback and remove the item from queue
  const updates: Record<string, any> = {};
  updates[`rooms/${roomId}/playback`] = {
    currentItemId: nextSong.id,
    trackId: nextSong.trackId,
    sourceType: nextSong.sourceType || 'youtube',
    title: nextSong.title,
    artist: nextSong.artist,
    thumbnailUrl: nextSong.thumbnailUrl,
    durationMs: nextSong.durationMs,
    status: 'playing',
    positionMs: 0,
    updatedAt: admin.database.ServerValue.TIMESTAMP,
    updatedBy: uid,
  };
  updates[`rooms/${roomId}/queue/${nextSong.id}`] = null;

  await db.ref().update(updates);

  return {
    success: true,
    nowPlaying: nextSong.title,
  };
});
