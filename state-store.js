// Safari can close an idle connection while the file picker or a long copy runs.
// Open a short-lived connection for each operation; retry an interrupted operation
// with the same key/value. Never delete or recreate an existing database.
export function createStateStore(factory) {
  function connect() {
    return new Promise((resolve,reject)=>{
      const request=factory.open('shabbattv-web',1);
      request.onupgradeneeded=()=>{
        if(!request.result.objectStoreNames.contains('state'))request.result.createObjectStore('state');
      };
      request.onsuccess=()=>resolve(request.result);
      request.onerror=()=>reject(request.error);
    });
  }
  async function transact(mode,value) {
    for(let attempt=0;attempt<3;attempt++) {
      let connection;
      try {
        connection=await connect();
        return await new Promise((resolve,reject)=>{
          connection.onclose=()=>reject(new DOMException('Stockage interrompu.','InvalidStateError'));
          connection.onversionchange=()=>{connection.close();reject(new DOMException('Stockage renouvelé.','InvalidStateError'));};
          const tx=connection.transaction('state',mode), store=tx.objectStore('state');
          const request=mode==='readonly'?store.get('library'):store.put(value,'library');
          let result;
          request.onsuccess=()=>{result=request.result;};
          tx.oncomplete=()=>resolve(result);
          tx.onabort=()=>reject(tx.error??new DOMException('Sauvegarde interrompue.','AbortError'));
          tx.onerror=()=>{}; // onabort is the final transaction outcome.
        });
      } catch(error) {
        if(attempt===2||!['InvalidStateError','AbortError','UnknownError'].includes(error?.name))throw error;
      } finally {
        if(connection){connection.onclose=null;connection.onversionchange=null;connection.close();}
      }
    }
  }
  return {read:()=>transact('readonly'),write:value=>transact('readwrite',value)};
}
