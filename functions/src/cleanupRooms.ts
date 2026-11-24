import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

/**
 * Cloud Function: cleanupInactiveRooms
 * Scheduled cron job running every 6 hours.
 * Cleans up empty or inactive rooms where no presence has been active for >24 hours.
 */
export const cleanupInactiveRooms = onSchedule('every 6 hours', async () => {
  const db = admin.database();
  const cutoffTime = Date.now() - 24 * 60 * 60 * 1000; // 24 hours ago

  const roomsSnap = await db.ref('rooms').get();
  if (!roomsSnap.exists()) return;

  const updates: Record<string, any> = {};
  let deletedCount = 0;

  roomsSnap.forEach((roomChild) => {
    const room = roomChild.val();
    const roomId = roomChild.key!;
    const createdAt = room.createdAt || 0;

    // If room is older than 24 hours and has no members
    const members = room.members ? Object.keys(room.members) : [];
    if (createdAt < cutoffTime && members.length === 0) {
      if (room.code) {
        updates[`roomCodes/${room.code}`] = null;
      }
      updates[`rooms/${roomId}`] = null;
      updates[`presence/${roomId}`] = null;
      deletedCount++;
    }
  });

  if (deletedCount > 0) {
    await db.ref().update(updates);
    console.log(`Cleaned up ${deletedCount} inactive rooms.`);
  }
});
