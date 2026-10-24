import {validate,decision,wallTime,resolveWall,bytes,duration} from './core.js';
import {openStore,readState,writeState,operate,localFile,metadata} from './storage.js';
import {Player} from './player.js';
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const zone=Intl.DateTimeFormat().resolvedOptions().timeZone;
let state={version:1,media:[],plan:{title:'Mon Shabbat',zone,limit:.85,nightLimit:.35,slots:[]}},loaded=false,busy=false,prepared=false,cacheReady=false,editing=null,renaming=null,previewURL=null;
let urls=new Map(),events=[];
try{events=JSON.parse(localStorage.getItem('shabbattv-events')||'[]');if(!Array.isArray(events))events=[];}catch{}
function log(kind,detail){events.push({time:new Date().toISOString(),kind,detail});events=events.slice(-800);try{localStorage.setItem('shabbattv-events',JSON.stringify(events));}catch{}}
let toastTimer;
function toast(text){if(!text)return;$('#toast').textContent=text;$('#toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('#toast').hidden=true,9000);}
const player=new Player({video:$('#video'),screen:$('#screen'),blackout:$('#blackout'),log,onStop:message=>{if(previewURL){URL.revokeObjectURL(previewURL);previewURL=null;}if(message)toast(message);}});
function invalidate(){prepared=false;$('#hardware-confirm').checked=false;$('#launch').disabled=true;for(const url of urls.values())URL.revokeObjectURL(url);urls.clear();}
async function save(next){await writeState(next);state=next;invalidate();render();}
function setBusy(title){busy=true;$('#busy').hidden=false;$('#busy-title').textContent=title;progress(0);}
function progress(value){$('#progress').value=value;$('#progress-label').textContent=Math.round(value*100)+' %';}
function clearBusy(){busy=false;$('#busy').hidden=true;}
function changePage(page){if(player.active||busy)return;$$('.page').forEach(p=>p.hidden=p.id!=='page-'+page);$$('[data-page]').forEach(b=>{b.classList.toggle('selected',b.dataset.page===page);b.setAttribute('aria-current',b.dataset.page===page?'page':'false');});const titles={home:['BIENVENUE CHEZ VOUS','Votre prochain Shabbat'],library:['VOS FILMS, SUR CET APPAREIL','Bibliothèque'],schedule:['CHAQUE MOMENT À SA PLACE','Programmation'],prepare:['AVANT SHABBAT','Prêt pour la séance'],settings:['À VOTRE RYTHME','Paramètres']};$('#page-eyebrow').textContent=titles[page][0];$('#page-title').textContent=titles[page][1];window.scrollTo(0,0);}
const time=t=>new Intl.DateTimeFormat('fr-FR',{timeZone:state.plan.zone,hour:'2-digit',minute:'2-digit'}).format(t);
const date=t=>new Intl.DateTimeFormat('fr-FR',{timeZone:state.plan.zone,day:'numeric',month:'short',year:'numeric'}).format(t);
const title=s=>s.mediaID?state.media.find(m=>m.id===s.mediaID)?.title??'Film manquant':'Écran noir';
function empty(heading,text,button='',page='library'){return `<div class="empty"><span class="empty-symbol">▤</span><h3>${heading}</h3><p>${text}</p>${button?`<button class="text-button" data-goto="${page}">${button} →</button>`:''}</div>`;}
function render(){
  $('#nav-count').textContent=state.media.length;$('#metric-media').textContent=state.media.length+' film'+(state.media.length>1?'s':'');
  $('#metric-size').textContent=state.media.length?bytes(state.media.reduce((n,m)=>n+m.size,0))+' stockés localement':'À vous de choisir la séance';
  $('#metric-slots').textContent=state.plan.slots.length+' créneau'+(state.plan.slots.length>1?'x':'');
  $('#metric-duration').textContent=state.plan.slots.length?duration(state.plan.slots.reduce((n,s)=>n+(s.end-s.start)/1000,0))+' programmées':'Chaque film à son heure';
  $('#metric-ready').textContent=prepared?'Fichiers vérifiés':'À vérifier';
  $('#plan-zone').textContent='Fuseau du programme : '+state.plan.zone;
  const next=[...state.plan.slots].sort((a,b)=>a.start-b.start).find(s=>s.end>Date.now());
  $('#next-programme').innerHTML=next?`<div class="next-item"><span class="date">${esc(date(next.start))} · ${time(next.start)} — ${time(next.end)}</span><h3>${esc(title(next))}</h3><p>${duration((next.end-next.start)/1000)} · ${esc(state.plan.title)}</p><button class="text-button" data-goto="prepare">Vérifier la préparation →</button></div>`:empty('Votre programme commence ici','Choisissez vos films, puis donnez-leur une heure.','Créer mon premier créneau','schedule');
  renderMedia();renderSchedule();renderSettings();
  $('#import-button').disabled=!loaded;$('#add-slot').disabled=!loaded;$('#verify').disabled=!loaded;
}
function renderMedia(){
  const query=$('#search').value.toLocaleLowerCase('fr'),filtered=state.media.filter(m=>m.title.toLocaleLowerCase('fr').includes(query));
  $('#media-list').innerHTML=!state.media.length?empty('Une bibliothèque à votre image','Importez votre premier film depuis Fichiers.'):!filtered.length?empty('Aucun résultat','Essayez un autre titre.'):filtered.map(m=>{
    const locked=state.plan.slots.some(s=>s.mediaID===m.id);
    return `<article class="media-card"><div class="media-cover" aria-hidden="true">▷<span>${m.width} × ${m.height}</span></div><div class="media-info"><h3>${esc(m.title)}</h3><p>${duration(m.duration)} · ${bytes(m.size)}</p><p class="${locked?'protected':''}">${locked?'● Protégé par votre programme':'Copie locale · empreintes enregistrées'}</p><div class="media-actions"><button class="text-button" data-preview="${m.id}">▶ Voir</button><button class="text-button" data-rename="${m.id}">Renommer</button><button class="text-button" data-delete="${m.id}" ${locked?'disabled':''}>Supprimer</button></div></div></article>`;
  }).join('');
}
function renderSchedule(){
  const sorted=[...state.plan.slots].sort((a,b)=>a.start-b.start);let html='';
  sorted.forEach((s,i)=>{
    if(i&&s.start>sorted[i-1].end)html+=`<div class="gap">◐ ${duration((s.start-sorted[i-1].end)/1000)} de noir et de silence</div>`;
    html+=`<article class="slot-row ${s.mediaID?'':'black'}"><div class="slot-time">${esc(date(s.start))}<strong>${time(s.start)} → ${time(s.end)}</strong>${date(s.start)!==date(s.end)?'Fin le '+esc(date(s.end)):''}</div><div class="slot-details"><h3>${esc(title(s))}</h3><p>${duration((s.end-s.start)/1000)} · ${s.mediaID?'Volume '+Math.round(s.volume*100)+' %':'Silence'}</p></div><div class="slot-buttons"><button class="text-button" data-edit="${s.id}">Modifier</button><button class="text-button" data-copy="${s.id}">Copier</button><button class="text-button" data-remove="${s.id}">Retirer</button></div></article>`;
  });$('#schedule-list').innerHTML=html||empty('Votre soirée prend forme ici','Ajoutez un film ou une pause noire avec une heure de début et de fin.');
}
function renderSettings(){
  $('#plan-name').value=state.plan.title;$('#zone').value=state.plan.zone;$('#limit').value=Math.round(state.plan.limit*100);$('#night-limit').value=Math.round(state.plan.nightLimit*100);updateRanges();
  navigator.storage?.estimate?.().then(e=>$('#storage-detail').textContent=bytes(e.usage||0)+' utilisés sur un quota estimé de '+bytes(e.quota||0)+'. Ce quota n’est pas une garantie d’espace libre.').catch(()=>$('#storage-detail').textContent='Estimation du stockage indisponible.');
}
function updateRanges(){$('#limit-value').textContent=$('#limit').value+' %';$('#night-value').textContent=$('#night-limit').value+' %';$('#slot-volume-label').textContent=$('#slot-volume').value+' %';}
function confirmAction(title,text){$('#confirm-title').textContent=title;$('#confirm-text').textContent=text;$('#confirm-dialog').showModal();return new Promise(resolve=>{const done=value=>{$('#confirm-dialog').close();resolve(value);};$('#confirm-yes').onclick=()=>done(true);$('#confirm-no').onclick=()=>done(false);$('#confirm-dialog').oncancel=()=>resolve(false);});}
async function importFiles(files){
  if(!loaded||busy||player.active)return;invalidate();setBusy('Importation');const failures=[];
  for(let i=0;i<files.length;i++){
    const file=files[i],id=crypto.randomUUID();let copied=false;
    $('#busy-title').textContent=`${i+1}/${files.length} · ${file.name}`;progress(0);
    try{
      if(!file.size)throw Error('Fichier vide.');
      const estimate=await navigator.storage.estimate();
      if(estimate.quota&&estimate.quota-(estimate.usage||0)<file.size+128*1024**2)throw Error('Quota du navigateur insuffisant pour cette vidéo.');
      const meta=await metadata(file);
      const integrity=await operate('import',id,{file},progress);copied=true;
      const duplicate=state.media.find(m=>m.size===integrity.size&&JSON.stringify(m.hashes)===JSON.stringify(integrity.hashes));
      if(duplicate){await operate('remove',id);copied=false;continue;}
      const item={id,title:file.name.replace(/\.[^.]+$/,''),type:file.type,...meta,...integrity};
      const next=structuredClone(state);next.media.push(item);await save(next);copied=false;
      log('import',item.title);
    }catch(error){if(copied)try{await operate('remove',id);}catch{}failures.push(file.name+' : '+error.message);}
  }
  clearBusy();render();toast(failures.length?failures.join(' • '):'Import terminé. Les films sont copiés sur cet appareil.');$('#file-input').value='';
}
function editSlot(slot){
  if(!loaded)return;
  const start=Math.ceil((Date.now()+300000)/60000)*60000;
  editing=slot?structuredClone(slot):{id:crypto.randomUUID(),start:Math.max(start,...state.plan.slots.map(s=>s.end)),volume:.65,mediaID:null};
  if(!editing.end)editing.end=editing.start+1800000;
  $('#slot-title').textContent=slot?'Modifier le créneau':'Nouveau créneau';
  $('#slot-media').innerHTML='<option value="">Écran noir / silence</option>'+state.media.map(m=>`<option value="${m.id}">${esc(m.title)}</option>`).join('');
  $('#slot-media').value=editing.mediaID||'';$('#slot-start').value=wallTime(editing.start,state.plan.zone);$('#slot-end').value=wallTime(editing.end,state.plan.zone);$('#slot-volume').value=Math.round(editing.volume*100);$('#slot-error').textContent='';$('#occurrence').value='first';updateRanges();$('#slot-dialog').showModal();
}
function addCheck(text,kind='ok'){const li=document.createElement('li');li.textContent=text;li.className=kind;$('#checks').append(li);}
async function verify(){
  if(!loaded||busy||player.active)return;invalidate();$('#checks').replaceChildren();setBusy('Vérification des vidéos');let errors=validate(state.plan,state.media);
  if(!state.plan.slots.some(s=>s.end>Date.now()))errors.push('Ajoutez au moins un créneau en cours ou à venir.');
  if(!cacheReady)errors.push('L’application n’est pas encore enregistrée pour fonctionner hors ligne. Rechargez une fois avec Internet.');
  const needed=[...new Set(state.plan.slots.map(s=>s.mediaID).filter(Boolean))];
  for(let i=0;i<needed.length;i++){
    const item=state.media.find(m=>m.id===needed[i]);if(!item)continue;
    $('#busy-title').textContent=`${i+1}/${needed.length} · ${item.title}`;progress(0);
    try{await operate('verify',item.id,{expected:item},progress);const file=await localFile(item.id);await metadata(file);urls.set(item.id,URL.createObjectURL(file));addCheck('✓ '+item.title+' : copie locale et tous les blocs SHA-256 vérifiés.');}
    catch(error){errors.push(item.title+' : '+error.message);}
  }
  errors.forEach(e=>addCheck('✕ '+e,'bad'));
  if(cacheReady)addCheck('✓ Interface enregistrée pour une ouverture hors ligne.');
  let persistent=false;try{persistent=await navigator.storage.persisted();}catch{}
  addCheck(persistent?'✓ Le navigateur a accordé la conservation du stockage.':'⚠ Stockage non persistant : gardez les originaux et évitez de libérer les données du site.',persistent?'ok':'warn');
  addCheck('Fuseau : '+state.plan.zone,'warn');
  if(!navigator.wakeLock)addCheck('⚠ Maintien de l’écran indisponible : régler le verrouillage automatique avant diffusion.','warn');
  addCheck('⚠ Un essai en mode avion, avec son et plusieurs transitions, reste indispensable.','warn');
  prepared=errors.length===0;clearBusy();render();updateLaunch();log('verification',prepared?'Fichiers locaux vérifiés.':'Échec : '+errors.join('; '));
}
function updateLaunch(){$('#launch').disabled=!prepared||!$('#hardware-confirm').checked||busy;}
function download(name,data,type='application/json'){const url=URL.createObjectURL(new Blob([data],{type})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),30000);}
document.addEventListener('click',async e=>{
  const b=e.target.closest('button');if(!b||b.disabled)return;
  if(b.dataset.page)changePage(b.dataset.page);if(b.dataset.goto)changePage(b.dataset.goto);if(b.dataset.close)$('#'+b.dataset.close).close();
  if(b.dataset.edit)editSlot(state.plan.slots.find(s=>s.id===b.dataset.edit));
  if(b.dataset.copy){const old=state.plan.slots.find(s=>s.id===b.dataset.copy);editSlot({...old,id:crypto.randomUUID(),start:old.end,end:old.end+(old.end-old.start)});}
  try{
    if(b.dataset.remove){if(await confirmAction('Retirer ce créneau ?','La vidéo reste dans votre bibliothèque.')){const next=structuredClone(state);next.plan.slots=next.plan.slots.filter(s=>s.id!==b.dataset.remove);await save(next);}}
    if(b.dataset.delete){const item=state.media.find(m=>m.id===b.dataset.delete);if(state.plan.slots.some(s=>s.mediaID===item.id))throw Error('Ce film est protégé par le programme.');if(await confirmAction('Supprimer la copie locale ?',item.title+' sera retiré de cet appareil. Votre fichier original reste intact.')){const next=structuredClone(state);next.media=next.media.filter(m=>m.id!==item.id);await save(next);await operate('remove',item.id);}}
    if(b.dataset.rename){renaming=b.dataset.rename;$('#rename-title').value=state.media.find(m=>m.id===renaming).title;$('#rename-dialog').showModal();}
    if(b.dataset.preview){
      // Acquire the local URL asynchronously, then require a new explicit tap for sound.
      const file=await localFile(b.dataset.preview);if(previewURL)URL.revokeObjectURL(previewURL);previewURL=URL.createObjectURL(file);
      if(await confirmAction('Tester ce film','Lancez la lecture avec son. Maintenez le doigt 3 secondes sur la vidéo pour revenir.')){player.preview(previewURL);}
    }
  }catch(error){toast(error.message);}
});
$('#hero-plan').onclick=()=>changePage(state.media.length?'schedule':'library');$('#install-help').onclick=()=>$('#install-dialog').showModal();
$('#import-button').onclick=()=>$('#file-input').click();$('#file-input').onchange=e=>importFiles([...e.target.files]);$('#search').oninput=renderMedia;
$('#add-slot').onclick=()=>editSlot();$('#slot-volume').oninput=updateRanges;$('#limit').oninput=updateRanges;$('#night-limit').oninput=updateRanges;
$('#match-duration').onclick=()=>{try{const m=state.media.find(m=>m.id===$('#slot-media').value);if(!m)throw Error('Choisissez un film.');$('#slot-end').value=wallTime(resolveWall($('#slot-start').value,state.plan.zone,$('#occurrence').value)+Math.ceil(m.duration/60)*60000,state.plan.zone);}catch(e){$('#slot-error').textContent=e.message;}};
$('#slot-form').onsubmit=async e=>{
  e.preventDefault();try{
    const slot={...editing,mediaID:$('#slot-media').value||null,start:resolveWall($('#slot-start').value,state.plan.zone,$('#occurrence').value),end:resolveWall($('#slot-end').value,state.plan.zone,$('#occurrence').value),volume:Number($('#slot-volume').value)/100};
    if(!slot.mediaID)slot.volume=0;
    const next=structuredClone(state);next.plan.slots=next.plan.slots.filter(s=>s.id!==slot.id);next.plan.slots.push(slot);
    const problems=validate(next.plan,next.media);if(problems.length)throw Error(problems.join(' '));await save(next);$('#slot-dialog').close();toast('Créneau enregistré.');
  }catch(error){$('#slot-error').textContent=error.message;}
};
$('#rename-form').onsubmit=async e=>{e.preventDefault();try{const next=structuredClone(state);next.media.find(m=>m.id===renaming).title=$('#rename-title').value.trim()||'Film sans titre';await save(next);$('#rename-dialog').close();}catch(error){toast(error.message);}};
$('#settings-form').onsubmit=async e=>{e.preventDefault();if(!loaded)return;try{const next=structuredClone(state);Object.assign(next.plan,{title:$('#plan-name').value.trim()||'Mon Shabbat',zone:$('#zone').value,limit:Number($('#limit').value)/100,nightLimit:Number($('#night-limit').value)/100});await save(next);toast('Paramètres enregistrés.');}catch(error){toast(error.message);}};
$('#verify').onclick=verify;$('#hardware-confirm').onchange=updateLaunch;
$('#launch').onclick=()=>{if(prepared&&$('#hardware-confirm').checked){try{player.start(state.plan,state.media,urls);}catch(error){player.stop();toast(error.message);}}};
$('#persist').onclick=async()=>{try{const kept=await navigator.storage.persist();toast(kept?'Conservation du stockage accordée.':'Le navigateur n’a pas accordé la conservation. Ouvrez depuis l’icône de l’écran d’accueil et réessayez.');}catch(e){toast('Cette demande n’est pas disponible dans votre navigateur.');}};
$('#export-plan').onclick=()=>download('ShabbatTV-programme.json',JSON.stringify({version:1,plan:state.plan,media:state.media.map(({id,title,duration})=>({id,title,duration}))},null,2));
$('#export-log').onclick=()=>download('ShabbatTV-journal.json',JSON.stringify(events,null,2));
function network(){const el=$('#connection');el.textContent=navigator.onLine?'● En ligne':'● Hors connexion';el.classList.toggle('offline',!navigator.onLine);}
window.addEventListener('online',network);window.addEventListener('offline',network);network();
window.addEventListener('beforeunload',e=>{if(busy||player.active){e.preventDefault();e.returnValue='';}});
async function init(){
  const zones=Intl.supportedValuesOf?.('timeZone')??['UTC','Europe/Paris','Asia/Jerusalem','America/New_York'];if(!zones.includes(zone))zones.unshift(zone);
  $('#zone').innerHTML=zones.map(z=>`<option value="${esc(z)}">${esc(z)}</option>`).join('');render();
  try{
    if(!isSecureContext||!navigator.storage?.getDirectory)throw Error('Stockage local indisponible. Utilisez Safari récent, hors navigation privée, avec cette adresse HTTPS.');
    await openStore();const saved=await readState();
    if(saved){if(saved.version!==1||!Array.isArray(saved.media)||!Array.isArray(saved.plan?.slots))throw Error('Bibliothèque non reconnue. Aucune donnée n’a été écrasée.');state=saved;}
    loaded=true;render();
  }catch(error){toast(error.message);$('#cache-status').textContent='Stockage indisponible';log('storage-error',error.message);}
  if('serviceWorker'in navigator){try{
    await navigator.serviceWorker.register('./sw.js',{scope:'./'});await navigator.serviceWorker.ready;
    const cache=await caches.open('shabbattv-shell-v3');const keys=await cache.keys();cacheReady=keys.length>=14;
    $('#cache-status').textContent=cacheReady?'Application disponible hors ligne':'Cache incomplet : recharger avec Internet';
  }catch(error){$('#cache-status').textContent='Cache hors ligne indisponible';log('cache-error',error.message);}}
  else $('#cache-status').textContent='Mode hors ligne non pris en charge';
}
init();
