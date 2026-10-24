import test from 'node:test';
import assert from 'node:assert/strict';
import {createStateStore} from '../state-store.js';

function database(failures=[]) {
  let saved, opens=0, closes=0;
  const factory={open(){
    const request={}, failure=failures[opens++];
    const connection={close(){closes++;},transaction(){
      if(failure==='closing')throw new DOMException('The database connection is closing.','InvalidStateError');
      const tx={objectStore:()=>({get:()=>operation(false),put:value=>operation(true,value)})};
      function operation(write,value){
        const req={};queueMicrotask(()=>{
          if(failure==='closed'){connection.onclose?.();return;}
          if(failure==='quota'){tx.error=new DOMException('Full','QuotaExceededError');tx.onabort();return;}
          // Request success does not imply transaction commit.
          req.result=write?'library':saved;req.onsuccess?.();
          queueMicrotask(()=>{
            if(failure==='abort'){tx.error=new DOMException('Interrupted','AbortError');tx.onabort();return;}
            if(write)saved=value;tx.oncomplete();
          });
        });return req;
      }
      return tx;
    }};
    queueMicrotask(()=>{request.result=connection;request.onsuccess();});return request;
  }};
  return {store:createStateStore(factory),get saved(){return saved;},get opens(){return opens;},get closes(){return closes;}};
}
for(const failure of ['closing','closed','abort'])test('reopens after '+failure+' and commits the same library',async()=>{
  const db=database([failure]);const library={media:[{id:'film'}]};
  await db.store.write(library);assert.deepEqual(db.saved,library);assert.equal(db.opens,2);
  assert.deepEqual(await db.store.read(),library);assert.equal(db.closes,3);
});
test('bounded retry does not report success after repeated aborts',async()=>{
  const db=database(['abort','abort','abort']);await assert.rejects(db.store.write({media:[]}),{name:'AbortError'});
  assert.equal(db.opens,3);assert.equal(db.saved,undefined);
});
test('quota failure is not retried or reported as saved',async()=>{
  const db=database(['quota']);await assert.rejects(db.store.write({}),{name:'QuotaExceededError'});
  assert.equal(db.opens,1);assert.equal(db.saved,undefined);
});
