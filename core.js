export function validate(plan, media) {
  const errors = [], ids = new Set();
  if (!Array.isArray(plan.slots)) return ['Programmation invalide.'];
  try { new Intl.DateTimeFormat('fr', {timeZone: plan.zone}).format(); }
  catch { errors.push('Fuseau horaire invalide.'); }
  const sorted = [...plan.slots].sort((a,b) => a.start-b.start);
  for (let i=0;i<sorted.length;i++) {
    const s=sorted[i];
    if (!s.id || ids.has(s.id)) errors.push('Identifiant de créneau invalide ou dupliqué.');
    ids.add(s.id);
    if (!Number.isFinite(s.start)||!Number.isFinite(s.end)||s.end<=s.start) errors.push('La fin doit suivre le début.');
    if (!Number.isFinite(s.volume)||s.volume<0||s.volume>1) errors.push('Volume invalide.');
    if (s.mediaID && !media.some(m=>m.id===s.mediaID && Number.isFinite(m.duration) && m.duration>0)) errors.push('Un film du programme est absent ou invalide.');
    if (sorted.slice(0,i).some(p=>Math.max(p.start,s.start)<Math.min(p.end,s.end))) errors.push('Deux créneaux se chevauchent.');
  }
  return [...new Set(errors)];
}
export function decision(now, plan, media) {
  const active=plan.slots.filter(s=>s.start<=now&&now<s.end);
  if(active.length!==1) return {kind:'black'};
  const s=active[0], m=media.find(m=>m.id===s.mediaID), offset=(now-s.start)/1000;
  if(!m || offset>=m.duration) return {kind:'black'};
  const hour=Number(new Intl.DateTimeFormat('en-GB',{timeZone:plan.zone,hour:'2-digit',hourCycle:'h23'}).format(now));
  const night=hour>=23||hour<7;
  return {kind:'video',slotID:s.id,mediaID:m.id,offset,volume:Math.max(0,Math.min(s.volume,plan.limit??0.85,night?(plan.nightLimit??0.35):1))};
}
export function wallTime(date,zone) {
  const parts=new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(date);
  const p=Object.fromEntries(parts.map(p=>[p.type,p.value]));
  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}
export function resolveWall(value, zone, occurrence='first') {
  if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) throw Error('Date et heure invalides.');
  const [y,mo,d,h,mi]=value.split(/[-T:]/).map(Number), base=Date.UTC(y,mo-1,d,h,mi);
  const offsets=new Set();
  // Sample nearby offsets to include both sides of a daylight-saving transition.
  for(let hours=-48;hours<=48;hours+=6) {
    const sample=base+hours*3600000, displayed=wallTime(sample,zone);
    offsets.add(Date.parse(displayed+'Z')-sample);
  }
  const choices=[...offsets].map(o=>base-o).filter(t=>wallTime(t,zone)===value).sort((a,b)=>a-b);
  if(!choices.length) throw Error('Cette heure locale n’existe pas (date invalide ou changement d’heure).');
  return occurrence==='last'?choices.at(-1):choices[0];
}
export const bytes=n=>new Intl.NumberFormat('fr-FR',{maximumFractionDigits:1}).format(n/(n>=1024**3?1024**3:1024**2))+(n>=1024**3?' Go':' Mo');
export const duration=n=>n<60?`${Math.floor(n)} s`:`${Math.floor(n/3600)?Math.floor(n/3600)+' h ':''}${Math.floor(n/60)%60} min`;
