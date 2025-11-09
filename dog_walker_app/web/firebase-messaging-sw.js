/*
 * Firebase Messaging service worker
 *
 * Update the placeholders with your app's Firebase config before deploying
 * the web build. This file enables background notifications in the browser.
 */

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_ME',
  appId: 'REPLACE_ME',
  messagingSenderId: 'REPLACE_ME',
  projectId: 'REPLACE_ME',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'PawPal';
  const options = {
    body: payload.notification?.body,
    data: payload.data,
  };
  self.registration.showNotification(title, options);
});
