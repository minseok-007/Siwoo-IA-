# Cloud Functions for Push Notifications

The Flutter client stores device tokens under `users/{userId}/deviceTokens/{token}` and
creates notification documents in the top-level `notifications` collection whenever a
chat message, walk reschedule, or cancellation occurs. Use Firebase Cloud Functions to
convert those events into real push notifications.

## Prerequisites

- Firebase project with Cloud Functions enabled
- Billing tier that supports scheduled functions if you plan to send walk reminders
- The FCM server key is managed by Firebase; no extra secrets file is required

## Recommended Functions

```ts
import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

async function sendPush(userId: string, payload: admin.messaging.MessagingPayload) {
  const tokensSnap = await db.collection('users').doc(userId).collection('deviceTokens').get();
  const tokens = tokensSnap.docs.map((doc) => doc.id);
  if (!tokens.length) return;
  await admin.messaging().sendEachForMulticast({ tokens, notification: payload.notification, data: payload.data });
}

export const onNotificationCreated = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    if (!data) return;
    await sendPush(data.userId, {
      notification: {
        title: data.title,
        body: data.body,
      },
      data: {
        type: data.type ?? 'info',
        relatedId: data.relatedId ?? '',
      },
    });
  });

export const onChatMessageCreated = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message) return;
    const chatId = context.params.chatId as string;
    const [, walkId, ownerId, walkerId] = chatId.split('_');
    const senderId = message.senderId as string;
    const recipientId = senderId === ownerId ? walkerId : ownerId;
    if (!recipientId) return;
    await sendPush(recipientId, {
      notification: {
        title: 'New chat message',
        body: message.text?.substring(0, 120) ?? '',
      },
      data: {
        type: 'message',
        relatedId: walkId,
        chatId,
      },
    });
  });

export const onWalkRequestCreated = functions.firestore
  .document('walk_requests/{walkId}')
  .onCreate(async (snap) => {
    const walk = snap.data();
    if (!walk) return;
    const ownerId = walk.ownerId as string;
    const location = walk.location as string;

    // Naïve broadcast: notify the first 20 walkers.
    const walkers = await db
      .collection('users')
      .where('userType', '==', 'dogWalker')
      .limit(20)
      .get();

    const tokens: string[] = [];
    for (const walker of walkers.docs) {
      const tokenSnap = await walker.ref.collection('deviceTokens').get();
      tokenSnap.forEach((tokenDoc) => tokens.push(tokenDoc.id));
    }

    if (!tokens.length) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: 'New walk request',
        body: `${location} has a new walk opportunity`,
      },
      data: {
        type: 'walk_request',
        relatedId: snap.id,
        ownerId,
      },
    });
  });

export const scheduleWalkReminders = functions.scheduler.onSchedule('every 30 minutes', async () => {
  const now = admin.firestore.Timestamp.now();
  const reminderWindow = admin.firestore.Timestamp.fromMillis(now.toMillis() + 60 * 60 * 1000);
  const query = await db
    .collection('walk_requests')
    .where('status', '==', 'accepted')
    .where('startTime', '<=', reminderWindow)
    .where('startTime', '>=', now)
    .get();

  for (const doc of query.docs) {
    const walk = doc.data();
    const ownerId = walk.ownerId as string;
    const walkerId = walk.walkerId as string;
    const formatted = new Date(walk.startTime.toDate()).toLocaleString();
    const payload = {
      notification: {
        title: 'Upcoming walk',
        body: `Walk at ${walk.location} starts soon (${formatted})`,
      },
      data: {
        type: 'reminder',
        relatedId: doc.id,
      },
    } as admin.messaging.MessagingPayload;
    await sendPush(ownerId, payload);
    await sendPush(walkerId, payload);
  }
});
```

Deploying these functions satisfies the push notification requirement for
messages, walk updates, and reminders.
