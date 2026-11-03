// Service Worker untuk PWA WiFi Billing System
const CACHE_NAME = 'wifibilling-pwa-v2.1.0';
const urlsToCache = [
  './',
  './index.html',
  './login.html',
  './dashboard.html',
  './pelanggan.html',
  './tagihan.html',
  './pengeluaran.html',
  './pelanggan_dashboard.html',
  './pelanggan_profile.html',
  './pelanggan_riwayat_lunas.html',
  './pelanggan_info.html',
  './profile.html',
  './style.css',
  './login.js',
  './auth.js',
  './datetime-display.js',
  './dashboard.js',
  './pelanggan.js',
  './tagihan.js',
  './pengeluaran.js',
  './pelanggan_dashboard.js',
  './pelanggan_profile.js',
  './pelanggan_riwayat_lunas.js',
  './pelanggan_info.js',
  './profile.js',
  './assets/logo_192x192.png',
  './assets/logo_512x512.png',
  './assets/avatar_male.svg',
  './assets/avatar_female.svg',
  './assets/default_avatar.svg',
  './assets/login_illustration.svg',
  './manifest.json',
  './manifest-superadmin.json',
  './superadmin-login.html',
  './superadmin-login.js',
  './superadmin.html',
  './superadmin.js',
  'https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap',
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css'
];

// Install Event - Cache resources with tolerant Promise.allSettled
self.addEventListener('install', (event) => {
  console.log('Service Worker: Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('Service Worker: Caching files');
      return Promise.allSettled(
        urlsToCache.map((url) =>
          cache.add(url).catch((err) => {
            console.warn('SW cache skip:', url, err);
          })
        )
      );
    })
  );
  self.skipWaiting();
});

// Activate Event - Clean up old caches
self.addEventListener('activate', (event) => {
  console.log('Service Worker: Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Service Worker: Deleting old cache', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  return self.clients.claim();
});

// Fetch Event - Network first with cache fallback
self.addEventListener('fetch', (event) => {
  // Hanya tangani request GET http/https
  if (event.request.method !== 'GET' || !event.request.url.startsWith('http')) {
    return;
  }

  // Bypass cache untuk API Supabase agar data selalu real-time
  if (event.request.url.includes('.supabase.co')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Jangan cache jika bukan response sukses
        if (!response || response.status !== 200 || response.type !== 'basic') {
          return response;
        }

        const responseToCache = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseToCache);
        });

        return response;
      })
      .catch(() => {
        // Fallback ke cache jika offline
        return caches.match(event.request).then((cachedResponse) => {
          if (cachedResponse) {
            return cachedResponse;
          }
          if (event.request.mode === 'navigate') {
            return caches.match('./login.html') || caches.match('./index.html');
          }
        });
      })
  );
});
