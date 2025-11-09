# Human Follow-Up Tasks

The codebase is wired for push notifications and hardened Firestore access, but a few
steps require credentials or console access that only you can provide.

1. **Deploy Firestore Security Rules**
   - File: `firestore.rules`
   - Command: `firebase deploy --only firestore:rules`
   - Why: Locks down users, walk requests, chats, notifications, reviews, and device tokens
     so only authorized owners/walkers can read or modify data.

2. **Configure Push Credentials**
   - Firebase Console → Cloud Messaging: upload APNs key/certs for iOS.
   - Xcode (Runner target): enable *Push Notifications* and *Background Modes → Remote notifications*.
   - Firebase Console → Cloud Messaging: generate a Web VAPID key and pass it via
     `--dart-define=FIREBASE_VAPID_KEY=...` when running/building.
   - Update `dog_walker_app/web/firebase-messaging-sw.js` with your Firebase config (apiKey, appId, etc.).

3. **Deploy Cloud Functions**
   - Use the samples in `dog_walker_app/cloud_functions/README.md`.
   - Provides server-side fan-out for chat alerts, cancellations/reschedules, new walk requests,
     and scheduled walk reminders.

4. **Verify FCM end-to-end**
   - Install the app on two devices (owner + walker) and sign in.
   - Check Firestore for `users/{uid}/deviceTokens/{token}` documents.
   - Trigger chat messages, cancellations, and reschedules to ensure `notifications/` entries
     appear and Cloud Functions deliver FCM pushes.
   - Confirm foreground/background notifications bring users to the right screens.

Once these steps are complete, the platform will deliver secure, authenticated push
notifications backed by the deployed Firestore rules.
