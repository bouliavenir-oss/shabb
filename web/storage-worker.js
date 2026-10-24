const CHUNK=4*1024*1024;
const hex=buffer=>[...new Uint8Array(buffer)].map(b=>b.toString(16).padStart(2,'0')).join('');
self.onmessage=async({data})=>{
  const {request,action,id,file,expected}=data;
  let root,handle,access;
  try {
    if(!/^[a-f0-9-]{36}$/.test(id)) throw Error('Identifiant de fichier invalide.');
    root=await navigator.storage.getDirectory();
    if(action==='remove') {await root.removeEntry(id);postMessage({request,done:true});return;}
    handle=await root.getFileHandle(id,{create:action==='import'});
    const source=action==='import'?file:await handle.getFile();
    if(action==='verify'&&source.size!==expected.size) throw Error('Taille du fichier incorrecte.');
    const hashes=[];
    if(action==='import') {access=await handle.createSyncAccessHandle();access.truncate(0);}
    for(let offset=0;offset<source.size;offset+=CHUNK) {
      const buffer=await source.slice(offset,offset+CHUNK).arrayBuffer();
      const hash=hex(await crypto.subtle.digest('SHA-256',buffer));
      hashes.push(hash);
      if(access) {
        const written=access.write(buffer,{at:offset});
        if(written!==buffer.byteLength) throw Error('Copie incomplète : stockage insuffisant.');
      }
      if(action==='verify'&&hash!==expected.hashes[hashes.length-1]) throw Error('Un bloc vidéo est incomplet ou modifié.');
      postMessage({request,progress:Math.min(1,(offset+buffer.byteLength)/source.size)});
    }
    if(action==='verify'&&hashes.length!==expected.hashes.length) throw Error('Empreintes incomplètes.');
    if(access) {access.flush();access.close();access=null;}
    postMessage({request,done:true,result:{hashes,size:source.size,chunkSize:CHUNK}});
  } catch(error) {
    try {access?.close();}catch{}
    if(action==='import'&&root) {try{await root.removeEntry(id);}catch{}}
    postMessage({request,error:error.name==='QuotaExceededError'?'Stockage insuffisant sur cet appareil.':error.message});
  }
};
