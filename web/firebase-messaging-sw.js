// Firebase Messaging Service Worker
// Project: zorvia-cc840
// Firebase JS SDK version: 10.13.0
// This version aligns with firebase_core ^3.6.0 / firebase_messaging ^15.1.3
// which depend on Firebase JS SDK ~10.x.
//
// This file handles BACKGROUND push messages when the Flutter Web app is not
// in the foreground. Flutter's own flutter_service_worker.js handles caching
// and is a separate, independent service worker — they do NOT conflict.
//
// Registration is done in web/index.html via navigator.serviceWorker.register().

importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

// Firebase Web configuration — matches firebase_options.dart
firebase.initializeApp({
  apiKey: 'AIzaSyD3ek9YbVyn8zAgwEfKAfDMICXh669DScQ',
  authDomain: 'zorvia-cc840.firebaseapp.com',
  projectId: 'zorvia-cc840',
  storageBucket: 'zorvia-cc840.firebasestorage.app',
  messagingSenderId: '281117677106',
  appId: '1:281117677106:web:2f428ea7ba0c2c6c280e2b',
});

const messaging = firebase.messaging();

// ─── BACKGROUND MESSAGE HANDLER ─────────────────────────────────────────────
// This fires when the browser tab is in the background, closed, or hidden.
// The Flutter app's onMessage listener handles foreground messages instead.
messaging.onBackgroundMessage((payload) => {
  console.log('[FCM SW] Background message received:', payload);

  const notificationTitle = payload.notification?.title || 'ZForce Notification';

  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: payload.notification?.image || (payload.data && (payload.data.image || payload.data.image_url)) || '/icons/Icon-192.png',
    image: payload.notification?.image || (payload.data && (payload.data.image || payload.data.image_url)),
    badge: '/icons/favicon-96.png',
    // Preserve custom data payload so it is accessible on notification click.
    data: payload.data || {},
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// ─── NOTIFICATION CLICK HANDLER ─────────────────────────────────────────────
// Handles clicks on browser-native notifications shown by the service worker.
self.addEventListener('notificationclick', (event) => {
  console.log('[FCM SW] Notification clicked:', event.notification.data);

  event.notification.close();

  // The notification data may contain a route for deep-linking.
  const data = event.notification.data || {};
  let targetUrl = self.location.origin + '/';
  
  if (data.url) {
    targetUrl = data.url;
  } else if (data.link) {
    targetUrl = data.link;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If an existing app window is already open, focus it.
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          // Pass the notification data to the Flutter app via postMessage
          // so it can navigate to the appropriate screen.
          client.focus();
          client.postMessage({
            type: 'FCM_NOTIFICATION_CLICK',
            data: data,
          });
          return;
        }
      }
      // No existing window — open the app.
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
