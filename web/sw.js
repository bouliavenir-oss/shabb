const CACHE='shabbattv-shell-v2';
const ASSETS=['./','./index.html','./styles.css','./app.js','./core.js','./storage.js','./storage-worker.js','./player.js','./manifest.webmanifest','./icon.svg','./icon-192.png','./icon-512.png','./apple-touch-icon.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS))));
// An update waits until the old application has closed: never replace code during playback.
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const key of await caches.keys())if(key.startsWith('shabbattv-shell-')&&key!==CACHE)await caches.delete(key);
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET'||new URL(event.request.url).origin!==self.location.origin)return;
  const url=new URL(event.request.url),scope=new URL(self.registration.scope);
  if(!url.pathname.startsWith(scope.pathname))return;
  event.respondWith((async()=>{
    const cached=await caches.match(event.request,{ignoreSearch:true});
    if(cached)return cached;
    try{return await fetch(event.request);}catch(error){
      if(event.request.mode==='navigate')return (await caches.match('./index.html'))??Response.error();
      throw error;
    }
  })());
});
