import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

export { advanceQueue } from './advanceQueue';
export { createRoom } from './createRoom';
export { cleanupInactiveRooms } from './cleanupRooms';
