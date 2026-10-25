const CACHE='ccv-cloud-v15-9';
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(['./','./index.html','./manifest.webmanifest','./assets/hero.jpg','./assets/cashew-creek-logo.png','./assets/cashew-creek-logo-192.png','./assets/cashew-creek-logo-512.png','./fonts/NotoSansDevanagari-Regular.ttf','./fonts/NotoSansDevanagari-Bold.ttf'])).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(CACHE).then(x=>x.put(e.request,c));return r}).catch(()=>caches.match(e.request)))});
