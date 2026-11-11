const CACHE_NAME = 'quiz-app-v126';
const ASSETS_TO_CACHE = [
    './',
    './index.html',
    './manifest.json',
    './favicon.png',
    './icon-192.png',
    './icon-512.png'
];

// 1. Quraşdırma (Faylları yaddaşa yazır, yeni versiya gözləmədən işə düşür)
self.addEventListener('install', (event) => {
    self.skipWaiting();
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('[Service Worker] Fayllar keşlənir...');
                return cache.addAll(ASSETS_TO_CACHE);
            })
    );
});

// 2. Aktivləşmə (Köhnə keşləri silir və açıq səhifələri dərhal idarəyə götürür)
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keyList) => {
            return Promise.all(keyList.map((key) => {
                if (key !== CACHE_NAME) {
                    return caches.delete(key);
                }
            }));
        }).then(() => self.clients.claim())
    );
});

// 3. Sorğu (Əvvəlcə internetdən ən yeni versiyanı götürür, internet yoxdursa yaddaşdan oxuyur)
self.addEventListener('fetch', (event) => {
    const req = event.request;
    if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
    event.respondWith(
        fetch(req, { cache: 'no-cache' })
            .then((response) => {
                if (response.ok) {
                    const copy = response.clone();
                    caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
                }
                return response;
            })
            .catch(() => caches.match(req, { ignoreSearch: true }))
    );
});
