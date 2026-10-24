import {decision} from './core.js';
export class Player {
  constructor({video,screen,blackout,log,onStop}) {
    Object.assign(this,{video,screen,blackout,log,onStop});
    this.active=false;this.failed=new Set();this.retries=new Map();this.mode='idle';this.token=0;
    video.addEventListener('error',()=>{if(this.active&&this.mode==='schedule')this.fail('Erreur de décodage vidéo.');});
    document.addEventListener('visibilitychange',()=>{
      if(!this.active)return;
      this.log('visibility',document.visibilityState);
      if(document.hidden){this.token++;this.cover();video.pause();}
      else {this.acquireWake();this.current=null;this.tick();}
    });
    let hold;
    screen.addEventListener('pointerdown',()=>{hold=setTimeout(()=>this.stop(),3000);});
    for(const type of ['pointerup','pointercancel','pointerleave'])screen.addEventListener(type,()=>clearTimeout(hold));
    document.addEventListener('keydown',e=>{if(e.key==='Escape'&&this.active)this.stop();});
  }
  audio() {
    if(!this.context){
      const Audio=window.AudioContext||window.webkitAudioContext;
      if(!Audio)throw Error('Le réglage audio nécessaire n’est pas disponible dans ce navigateur.');
      this.context=new Audio();this.source=this.context.createMediaElementSource(this.video);
      this.gain=this.context.createGain();this.source.connect(this.gain).connect(this.context.destination);
      this.gain.gain.value=0;
    }
    return this.context.resume();
  }
  show() {
    document.body.classList.add('running');this.screen.hidden=false;
    document.querySelector('#workspace').inert=true;
    const hint=document.querySelector('#exit-hint');hint.hidden=false;
    clearTimeout(this.hintTimer);this.hintTimer=setTimeout(()=>hint.hidden=true,5000);
  }
  cover(){this.blackout.hidden=false;if(this.gain){this.gain.gain.cancelScheduledValues(this.context.currentTime);this.gain.gain.setValueAtTime(0,this.context.currentTime);}}
  async acquireWake() {
    if(!navigator.wakeLock){this.log('wake-lock','Indisponible : vérifier le verrouillage automatique.');return;}
    try{if(!this.lock||this.lock.released)this.lock=await navigator.wakeLock.request('screen');}
    catch(error){this.log('wake-lock',error.message);}
  }
  start(plan,media,urls) {
    // Called directly by the launch button, with files/URLs already prepared.
    this.plan=structuredClone(plan);this.media=structuredClone(media);this.urls=urls;
    const launch=++this.token;
    this.active=true;this.mode='schedule';this.current=null;this.failed.clear();this.retries.clear();
    this.show();this.cover();this.video.controls=false;this.video.muted=false;
    this.acquireWake();
    const audioReady=this.audio();
    const initial=decision(Date.now(),plan,media);
    const first=initial.kind==='video'?media.find(m=>m.id===initial.mediaID):media.find(m=>urls.has(m.id));
    // Unlock this same media element during the user's tap, silently under black.
    let permission=Promise.resolve();
    if(first){this.video.src=urls.get(first.id);permission=this.video.play();}
    Promise.all([audioReady,permission]).then(()=>{
      if(!this.active||launch!==this.token)return;this.video.pause();
      this.log('start','Programmation locale démarrée.');this.timer=setInterval(()=>this.tick(),250);this.tick();
    }).catch(error=>{
      if(launch!==this.token)return;
      this.log('start-error',error.message);this.stop();
      this.onStop('Safari n’a pas autorisé la lecture. Testez un film avec son et relancez avant Shabbat.');
    });
  }
  preview(url) {
    const launch=++this.token;
    this.active=true;this.mode='preview';this.show();this.cover();
    this.video.controls=true;this.video.src=url;this.video.muted=false;
    Promise.all([this.audio(),this.video.play()]).then(()=>{
      if(!this.active||document.hidden||launch!==this.token)return;this.gain.gain.value=.65;this.blackout.hidden=true;
    }).catch(e=>{if(launch!==this.token)return;this.stop();this.onStop('Prévisualisation impossible : '+e.message);});
  }
  tick() {
    if(!this.active||document.hidden||this.mode!=='schedule')return;
    const d=decision(Date.now(),this.plan,this.media);
    if(d.kind==='black'){
      if(this.current!==null){this.log('black','Pause noire / fin de film.');this.token++;this.current=null;}
      this.cover();this.video.pause();return;
    }
    if(this.failed.has(d.slotID)){this.cover();this.video.pause();return;}
    if(this.context.state!=='running'){this.fail('Session audio interrompue.');return;}
    if(this.current!==d.slotID){this.load(d);return;}
    if(this.loading){if(Date.now()-this.loadedAt>15000)this.fail('Chargement vidéo supérieur à 15 secondes.');return;}
    if(this.video.seeking){if(Date.now()-this.lastProgress>15000)this.fail('Repositionnement bloqué.');return;}
    const pos=this.video.currentTime;
    if(pos>this.lastPosition+.1){this.lastProgress=Date.now();this.lastPosition=pos;}
    if(Date.now()-this.lastProgress>12000){this.fail('La lecture ne progresse plus.');return;}
    if(Math.abs(pos-d.offset)>2){
      this.video.currentTime=d.offset;this.lastPosition=d.offset;
      this.log('seek','Recalage sur l’horloge : '+d.offset.toFixed(1)+' s.');
    }
    this.gain.gain.setTargetAtTime(d.volume,this.context.currentTime,.08);
    if(this.video.paused&&!this.playPending){this.playPending=true;this.video.play().catch(e=>this.fail(e.message)).finally(()=>this.playPending=false);}
  }
  load(d) {
    this.cover();this.video.pause();this.current=d.slotID;this.loading=true;this.loadedAt=Date.now();
    this.lastProgress=Date.now();this.lastPosition=-1;
    const token=++this.token;
    const ready=()=>{
      if(token!==this.token||!this.active)return;
      const current=decision(Date.now(),this.plan,this.media);
      if(current.kind!=='video'||current.slotID!==d.slotID){this.loading=false;this.tick();return;}
      this.video.currentTime=current.offset;this.lastPosition=current.offset;
      this.video.play().then(()=>{
        if(token!==this.token||!this.active||document.hidden)return;
        const latest=decision(Date.now(),this.plan,this.media);
        if(latest.kind!=='video'||latest.slotID!==d.slotID)return;
        this.loading=false;this.lastProgress=Date.now();this.gain.gain.value=latest.volume;this.blackout.hidden=true;
        this.log('playing',this.media.find(m=>m.id===latest.mediaID)?.title??latest.mediaID);
      }).catch(error=>{if(token===this.token)this.fail(error.message);});
    };
    this.video.onloadedmetadata=ready;
    this.video.src=this.urls.get(d.mediaID);this.video.load();
  }
  fail(reason) {
    if(!this.active||this.mode!=='schedule')return;
    const d=decision(Date.now(),this.plan,this.media);this.cover();this.video.pause();this.token++;
    if(d.kind!=='video')return;
    const count=this.retries.get(d.slotID)||0;
    this.log('error',reason+' · tentative '+count);
    if(count>=2){this.failed.add(d.slotID);this.log('failed','Noir jusqu’au prochain créneau.');}
    else{this.retries.set(d.slotID,count+1);this.current=null;}
  }
  stop() {
    this.active=false;this.mode='idle';this.token++;clearInterval(this.timer);clearTimeout(this.hintTimer);
    this.cover();this.video.pause();this.video.onloadedmetadata=null;this.video.removeAttribute('src');this.video.load();
    this.screen.hidden=true;document.body.classList.remove('running');document.querySelector('#workspace').inert=false;
    this.lock?.release().catch(()=>{});this.lock=null;this.log('stop','Arrêt manuel.');this.onStop();
  }
}
