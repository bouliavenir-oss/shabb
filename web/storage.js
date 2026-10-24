import {createStateStore} from './state-store.js';
const stateStore=createStateStore(indexedDB);
let worker;
let sequence=0;
const pending=new Map();
export async function openStore() {
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
export const readState=()=>stateStore.read();
export const writeState=state=>stateStore.write(state);
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
