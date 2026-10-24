let db, worker;
let sequence=0;
const pending=new Map();
export async function openStore() {
  db=await new Promise((resolve,reject)=>{
    const r=indexedDB.open('shabbattv-web',1);
    r.onupgradeneeded=()=>r.result.createObjectStore('state');
    r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);
  });
  worker=new Worker('./storage-worker.js');
  worker.onmessage=({data})=>{
    const p=pending.get(data.request);if(!p)return;
    if(data.error){pending.delete(data.request);p.reject(Error(data.error));}
    else if(data.done){pending.delete(data.request);p.resolve(data.result);}
    else p.progress?.(data.progress);
  };
  worker.onerror=()=>{for(const p of pending.values())p.reject(Error('Le stockage local n’a pas répondu.'));pending.clear();};
  const root=await navigator.storage.getDirectory();
  return root;
}
export function readState() {
  return new Promise((resolve,reject)=>{const r=db.transaction('state').objectStore('state').get('library');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
}
export function writeState(state) {
  return new Promise((resolve,reject)=>{
    const tx=db.transaction('state','readwrite');tx.objectStore('state').put(state,'library');
    tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error??Error('Sauvegarde interrompue.'));
  });
}
export function operate(action,id,details={},progress) {
  return new Promise((resolve,reject)=>{const request=++sequence;pending.set(request,{resolve,reject,progress});worker.postMessage({request,action,id,...details});});
}
export async function localFile(id) {const root=await navigator.storage.getDirectory();return (await root.getFileHandle(id)).getFile();}
export async function metadata(file) {
  const video=document.createElement('video'),url=URL.createObjectURL(file);
  video.preload='metadata';video.playsInline=true;
  try {
    return await new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>reject(Error('Analyse vidéo trop longue. Essayez un fichier MP4 H.264/AAC.')),20000);
      video.onloadedmetadata=()=>{clearTimeout(timer);if(!Number.isFinite(video.duration)||video.duration<=0||!video.videoWidth)reject(Error('Format vidéo non lisible.'));else resolve({duration:video.duration,width:video.videoWidth,height:video.videoHeight});};
      video.onerror=()=>{clearTimeout(timer);reject(Error('Safari ne peut pas lire cette vidéo. Privilégiez MP4 H.264/AAC.'));};
      video.src=url;
    });
  } finally {video.removeAttribute('src');video.load();URL.revokeObjectURL(url);}
}
