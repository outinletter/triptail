const CACHE='triptail-v4';
const ASSETS=['./','index.html','privacy.html','app.js','location-ui.js','photo-gps.js','styles.css','icon.png','manifest.json'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('triptail-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{const url=new URL(e.request.url);if(e.request.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/'))return;
e.respondWith(fetch(e.request).then(response=>{if(response.ok&&ASSETS.some(p=>new URL(p,self.location.href).pathname===url.pathname)){const copy=response.clone();e.waitUntil(caches.open(CACHE).then(c=>c.put(e.request,copy)))}return response}).catch(async()=>await caches.match(e.request)||new Response('오프라인입니다. 연결 후 다시 시도해주세요.',{status:503}))) });
