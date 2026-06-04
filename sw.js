const CACHE_NAME = 'quiz-app-v89';
const ASSETS_TO_CACHE = [
    './',
    './index.html',
    './manifest.json',
    './favicon.png',
    './icon-192.png',
    './icon-512.png'
];

// 1. Quraşdırma (Faylları yaddaşa yazır)
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('[Service Worker] Fayllar keşlənir...');
                return cache.addAll(ASSETS_TO_CACHE);
            })
    );
});

// 2. Aktivləşmə (Köhnə keşləri silir)
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keyList) => {
            return Promise.all(keyList.map((key) => {
                if (key !== CACHE_NAME) {
                    return caches.delete(key);
                }
            }));
        })
    );
});

// 3. Sorğu (İnternet yoxdursa, yaddaşdan oxuyur)
self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request)
            .then((response) => {
                // Keşdə varsa qaytar, yoxdursa internetdən götür
                return response || fetch(event.request);
            })
    );
});