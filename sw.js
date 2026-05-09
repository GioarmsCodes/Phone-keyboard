// sw.js — minimal service worker (network-first, no caching)
// Its presence is what makes the PWA "installable" on Android Chrome.
self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => {}); // passthrough — browser handles normally
