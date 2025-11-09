# Security Overview

The latest changes harden the PawPal stack against unauthorized access and data leaks. This document summarises the key protections and how to keep them effective.

## Authentication & Session Handling
- All privileged operations still flow through Firebase Authentication (email & password).
- `MessagingService` (`lib/services/messaging_service.dart`) only captures FCM tokens after a user signs in; tokens are wiped on sign-out.

## Firestore Access Control
- The canonical Firestore Security Rules live in `firestore.rules`. Deploy them with `firebase deploy --only firestore:rules`.
- Highlights:
  - `users/{uid}` and nested `deviceTokens` are writable only by the account owner.
  - `walk_requests/{id}` documents can be created by owners and read/updated only by the owner or the assigned walker.
  - `chats/{chatId}` now store `ownerId`, `walkerId`, and a fixed `participants` list; rules restrict reads/writes to those two users, and chat messages require `senderId == request.auth.uid`.
  - `notifications/{id}` entries demand a `createdBy` field so only walk participants can raise notifications for each other; recipients alone can read or mark them as read.
  - `reviews/{id}` creation is limited to walk participants, preventing arbitrary feedback spam.

## Data Minimisation & Device Tokens
- Device tokens are stored under `users/{uid}/deviceTokens/{token}` with metadata (platform, update time) and can only be managed by the authenticated owner.
- Tokens are refreshed automatically by `MessagingService` and old tokens are overwritten to avoid stale access.

## Notifications & Audit Trail
- In-app notification writes now carry a `createdBy` identifier so Cloud Functions can audit who initiated an alert.
- Walk cancellations, reschedules, and chat messages still post friendly in-app notices for traceability, but server-side fan-out should be performed by Functions to avoid client impersonation.

## Recommendations to Keep it Secure
1. **Enforce TLS everywhere:** Firebase provides this by default; avoid bypassing it with insecure endpoints.
2. **Review Firestore indexes:** Ensure queries in the app match the rule expectations (owner/walker filters) to prevent unexpected data exposure.
3. **Protect Cloud Functions:** Only deploy signed code, keep dependencies patched, and monitor invocation logs for anomalies.
4. **Rotate credentials:** Refresh APNs keys and VAPID keys periodically and store them in a secrets manager.
5. **Penetration test regularly:** Validate rules with `firebase emulators:start` and automated tests that attempt unauthorized reads/writes.

With these measures the platform enforces least-privilege access to user data, limits notification creation to legitimate actors, and keeps push credentials scoped to authenticated sessions.
