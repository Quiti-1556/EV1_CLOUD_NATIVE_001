import {validateConfig,getSession,clearSession,login,logout,callback} from './auth.js';
const $=id=>document.getElementById(id);
const esc=(value='')=>String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const labels={PENDIENTE:'Pendiente',APROBADA:'Aprobada',RECHAZADA:'Rechazada',VACACIONES:'Vacaciones',PERMISO:'Permiso',COMPRA:'Compra',TELETRABAJO:'Teletrabajo',OTRO:'Otro'};
const day=value=>value?new Intl.DateTimeFormat('es-CL',{day:'2-digit',month:'short',year:'numeric'}).format(new Date(value+'T12:00:00')):'Sin fecha';
const instant=value=>value?new Intl.DateTimeFormat('es-CL',{dateStyle:'medium',timeStyle:'short'}).format(new Date(value)):'—';
let config,items=[],roles=[],view='mine',page=1,generation=0,mutating=false,toastTimer,expiryTimer;
const PAGE_SIZE=8;
const demo=()=>{try{return JSON.parse(localStorage.getItem('solicitud.demo'))||{user:'solicitante.demo',role:'SOLICITANTE'}}catch{return{user:'solicitante.demo',role:'SOLICITANTE'}}};
const ready=()=>config && (!config.authEnabled||!!getSession());
function message(id,text=''){ $(id).textContent=text;$(id).hidden=!text; }
function notify(text){clearTimeout(toastTimer);message('toast',text);toastTimer=setTimeout(()=>message('toast'),4000);}
function clearData(){$('loading').hidden=true;generation++;items=[];roles=[];for(const id of ['statPending','statApproved','statRejected','statMine'])$(id).textContent='—';render();}
function expire(){clearSession();clearData();for(const dialog of document.querySelectorAll('dialog[open]'))dialog.close();sessionUi();message('errorBox','Tu sesión terminó. Inicia sesión para continuar.');}
async function api(path,options={}){
  if(!ready()){expire();throw new Error('Inicia sesión para continuar.');}
  const headers=new Headers({'Accept':'application/json',...options.headers});
  if(options.body)headers.set('Content-Type','application/json');
  if(config.authEnabled)headers.set('Authorization','Bearer '+getSession().accessToken);
  else{const d=demo();headers.set('X-Demo-User',d.user);headers.set('X-Demo-Role',d.role);headers.set('X-Demo-Name',d.user);}
  const r=await fetch(config.apiUrl+path,{...options,headers,cache:'no-store',credentials:'omit',signal:AbortSignal.timeout(15000)});
  if(r.status===401){expire();throw new Error('La sesión ya no es válida. Inicia sesión nuevamente.');}
  if(r.status===204)return null;
  const body=await r.json().catch(()=>({}));
  if(!r.ok)throw new Error(r.status===403?'Tu cuenta no tiene permiso para realizar esta acción.':(body.error||'No se pudo completar la operación. Inténtalo nuevamente.'));
  return body;
}
function sessionUi(){
  const authenticated=ready();
  $('loginBtn').hidden=!config.authEnabled||authenticated;$('logoutBtn').hidden=!config.authEnabled||!authenticated;
  $('localIdentity').hidden=config.authEnabled;
  $('sessionBadge').textContent=config.authEnabled?(authenticated?'Sesión activa':'Sin sesión'):'Demostración local';
  $('sessionLabel').textContent=authenticated?'Espacio personal':'Inicia sesión para continuar';
  $('roleName').textContent=roles.includes('APROBADOR')?'Aprobador':authenticated?'Solicitante':'Tu espacio';
  $('approvalTab').hidden=!roles.includes('APROBADOR');
  $('newBtn').disabled=!authenticated||!roles.includes('SOLICITANTE');
  $('newBtn').hidden=view==='approval';$('refreshBtn').disabled=!authenticated;
  $('footerSession').textContent=config.authEnabled?'Acceso con cuenta de tu organización':'Entorno local · Datos de prueba';
  if(!config.authEnabled){const d=demo();$('demoUser').value=d.user;$('demoRole').value=d.role;}
}
function statusBadge(s){return `<span class="status status-${['PENDIENTE','APROBADA','RECHAZADA'].includes(s.estado)?s.estado:'PENDIENTE'}">${esc(labels[s.estado]||s.estado)}</span>`;}
function render(){
  const approval=view==='approval';
  $('mineTab').classList.toggle('active',!approval);$('approvalTab').classList.toggle('active',approval);
  for(const [id,active] of [['mineTab',!approval],['approvalTab',approval]]){if(active)$(id).setAttribute('aria-current','page');else $(id).removeAttribute('aria-current');}
  $('pageTitle').textContent=approval?'Por aprobar':'Mis solicitudes';
  $('pageSubtitle').textContent=approval?'Revisa el detalle y deja una respuesta clara para cada persona.':'Crea una solicitud y sigue cada paso hasta su resolución.';
  $('tableTitle').textContent=approval?'Bandeja de aprobación':'Bandeja de solicitudes';
  const query=$('searchInput').value.trim().toLocaleLowerCase('es');
  const filter=$('statusFilter').value;
  const filtered=items.filter(s=>(!filter||s.estado===filter)&&[s.titulo,s.descripcion,s.solicitanteNombre].some(x=>String(x||'').toLocaleLowerCase('es').includes(query)));
  const pages=Math.max(1,Math.ceil(filtered.length/PAGE_SIZE));page=Math.min(page,pages);
  $('rows').innerHTML=filtered.slice((page-1)*PAGE_SIZE,page*PAGE_SIZE).map(s=>`<tr><td><div class="request-title">${esc(s.titulo)}</div><div class="request-meta">${esc(labels[s.tipo]||s.tipo)} · #${esc(s.id.slice(0,8))}</div></td><td><div class="person"><span class="person-avatar" aria-hidden="true">${esc(s.solicitanteNombre.slice(0,2).toUpperCase())}</span><span>${esc(s.solicitanteNombre)}</span></div></td><td class="period">${esc(day(s.fechaInicio))}<br>${s.fechaFin?'a '+esc(day(s.fechaFin)):''}</td><td>${statusBadge(s)}</td><td class="right"><div class="row-actions"><button class="link-button" data-detail="${esc(s.id)}">Ver</button>${approval?`<button class="button small primary" data-decide="${esc(s.id)}">Revisar</button>`:(s.estado==='PENDIENTE'&&roles.includes('SOLICITANTE')?`<button class="link-button" data-edit="${esc(s.id)}">Editar</button><button class="link-button destructive" data-delete="${esc(s.id)}">Eliminar</button>`:'')}</div></td></tr>`).join('');
  $('empty').hidden=filtered.length>0;
  $('emptyTitle').textContent=!ready()?'Tu próxima solicitud empieza aquí':items.length?'Sin coincidencias':approval?'No hay solicitudes pendientes':'Aún no tienes solicitudes';
  $('emptyText').textContent=!ready()?'Inicia sesión para ver tus solicitudes y crear una nueva.':items.length?'Prueba con otro término o cambia el filtro.':approval?'Las nuevas solicitudes aparecerán en esta bandeja.':'Usa Nueva solicitud para enviar tu primera petición.';
  $('resultCount').textContent=`${filtered.length} solicitud${filtered.length===1?'':'es'}`;
  $('pageCount').textContent=`${page} / ${pages}`;$('prevPage').disabled=page<=1;$('nextPage').disabled=page>=pages;
}
async function refresh(){
  if(!ready()){clearData();sessionUi();return;}
  const current=++generation;message('errorBox');$('loading').hidden=false;$('refreshBtn').disabled=true;
  try{
    const stats=await api('/datos');if(current!==generation)return;
    roles=stats.roles||[];
    if(view==='approval'&&!roles.includes('APROBADOR'))view='mine';
    const list=await api('/solicitudes/'+(view==='approval'?'pendientes':'mias'));if(current!==generation)return;
    items=list;render();
    for(const [id,key] of [['statPending','pendientes'],['statApproved','aprobadas'],['statRejected','rechazadas'],['statMine','mias']])$(id).textContent=stats[key];
    $('navCount').textContent=stats.pendientes;
    $('scopeNote').textContent=roles.includes('APROBADOR')?'Pendientes, aprobadas y rechazadas: toda la organización. Mis solicitudes: tu cuenta.':'Los indicadores corresponden únicamente a tus solicitudes.';
    $('lastUpdated').textContent='Actualizado a las '+new Intl.DateTimeFormat('es-CL',{hour:'2-digit',minute:'2-digit'}).format(new Date());
  }catch(e){if(current===generation){items=[];render();message('errorBox',e.name==='TimeoutError'?'La conexión tardó demasiado. Vuelve a actualizar.':e.message);}}
  finally{if(current===generation){$('loading').hidden=true;sessionUi();}}
}
function openRequest(id){
  if(!ready()||!roles.includes('SOLICITANTE'))return;
  $('requestForm').reset();message('requestError');$('requestId').value=id||'';
  $('requestModalTitle').textContent=id?'Editar solicitud':'Nueva solicitud';
  if(id){const item=items.find(s=>s.id===id);if(!item)return;for(const field of ['tipo','titulo','descripcion','fechaInicio','fechaFin'])$(field).value=item[field]||'';}
  $('requestModal').showModal();$('titulo').focus();
}
async function mutation(form,errorId,action){
  if(mutating)return;mutating=true;message(errorId);
  const buttons=[...form.querySelectorAll('button')];buttons.forEach(b=>b.disabled=true);
  try{await action();}catch(e){message(errorId,e.name==='TimeoutError'?'No se confirmó el resultado. Actualiza la lista antes de volver a enviar.':e.message);}
  finally{buttons.forEach(b=>b.disabled=false);mutating=false;}
}
async function save(event){
  event.preventDefault();
  const start=$('fechaInicio').value,end=$('fechaFin').value;
  if(start&&end&&end<start){message('requestError','La fecha final debe ser igual o posterior a la inicial.');return;}
  const body={tipo:$('tipo').value,titulo:$('titulo').value.trim(),descripcion:$('descripcion').value.trim(),fechaInicio:start||null,fechaFin:end||null};
  if(!body.titulo||!body.descripcion){message('requestError','Completa el título y la descripción.');return;}
  const id=$('requestId').value;
  await mutation(event.currentTarget,'requestError',async()=>{await api('/solicitudes'+(id?'/'+encodeURIComponent(id):''),{method:id?'PUT':'POST',body:JSON.stringify(body)});$('requestModal').close();notify(id?'Solicitud actualizada.':'Solicitud creada.');await refresh();});
}
function detail(id){const s=items.find(x=>x.id===id);if(!s)return;$('detailTitle').textContent=s.titulo;$('detailBody').innerHTML=`${statusBadge(s)}<p class="description">${esc(s.descripcion)}</p><dl class="detail-grid"><div><dt>Solicitante</dt><dd>${esc(s.solicitanteNombre)}</dd></div><div><dt>Tipo</dt><dd>${esc(labels[s.tipo])}</dd></div><div><dt>Desde</dt><dd>${esc(day(s.fechaInicio))}</dd></div><div><dt>Hasta</dt><dd>${esc(day(s.fechaFin))}</dd></div><div><dt>Creada</dt><dd>${esc(instant(s.creadoEn))}</dd></div><div><dt>Última actualización</dt><dd>${esc(instant(s.actualizadoEn))}</dd></div></dl>${s.comentarioAprobador?`<div class="decision-summary"><strong>Respuesta de ${esc(s.aprobadorNombre)}</strong><p class="description">${esc(s.comentarioAprobador)}</p><span class="muted">${esc(instant(s.decididoEn))}</span></div>`:''}`;$('detailModal').showModal();}
function decision(id){const s=items.find(x=>x.id===id);if(!s)return;$('decisionForm').reset();message('decisionError');$('decisionId').value=id;$('decisionSummary').innerHTML=`<strong>${esc(s.titulo)}</strong><p class="request-meta">${esc(s.solicitanteNombre)} · ${esc(labels[s.tipo])}</p><p class="description">${esc(s.descripcion)}</p><p class="muted">${esc(day(s.fechaInicio))} — ${esc(day(s.fechaFin))}</p>`;$('decisionModal').showModal();}
async function boot(){
  // Quitar tokens persistidos por la versión anterior, sin tocar datos de otras aplicaciones.
  sessionStorage.removeItem('flow_auth');
  const response=await fetch('assets/config.json',{cache:'no-store'});if(!response.ok)throw new Error('No se pudo cargar la configuración.');
  config=validateConfig(await response.json(),location.href);
  $('loginBtn').onclick=()=>login(config).catch(e=>message('errorBox',e.message));
  $('logoutBtn').onclick=()=>{clearData();logout(config);};
  for(const b of document.querySelectorAll('[data-close]'))b.onclick=()=>$(b.dataset.close).close();
  $('newBtn').onclick=()=>openRequest();$('requestForm').onsubmit=save;$('refreshBtn').onclick=refresh;
  $('mineTab').onclick=()=>{view='mine';page=1;refresh();};$('approvalTab').onclick=()=>{view='approval';page=1;refresh();};
  for(const id of ['searchInput','statusFilter'])$(id).addEventListener('input',()=>{page=1;render();});
  $('prevPage').onclick=()=>{page--;render();};$('nextPage').onclick=()=>{page++;render();};
  $('applyIdentity').onclick=()=>{const user=$('demoUser').value.trim();if(!/^[a-zA-Z0-9_.@-]{1,60}$/.test(user)){message('errorBox','Usa letras, números, punto, guion o @ para la identidad local.');return;}localStorage.setItem('solicitud.demo',JSON.stringify({user,role:$('demoRole').value}));clearData();view=$('demoRole').value==='APROBADOR'?'approval':'mine';refresh();};
  $('rows').onclick=event=>{const button=event.target.closest('button');if(!button)return;const d=button.dataset;if(d.detail)detail(d.detail);if(d.edit)openRequest(d.edit);if(d.decide)decision(d.decide);if(d.delete){const s=items.find(x=>x.id===d.delete);$('deleteId').value=s.id;$('deleteSummary').textContent=s.titulo;message('deleteError');$('deleteModal').showModal();}};
  $('decisionForm').onsubmit=event=>{event.preventDefault();const value=event.submitter?.value,comment=$('comentario').value.trim();if(!['APROBAR','RECHAZAR'].includes(value)||!comment)return;mutation(event.currentTarget,'decisionError',async()=>{await api('/solicitudes/'+encodeURIComponent($('decisionId').value)+'/decision',{method:'POST',body:JSON.stringify({decision:value,comentario:comment})});$('decisionModal').close();notify(value==='APROBAR'?'Solicitud aprobada.':'Solicitud rechazada.');await refresh();});};
  $('deleteForm').onsubmit=event=>{event.preventDefault();mutation(event.currentTarget,'deleteError',async()=>{await api('/solicitudes/'+encodeURIComponent($('deleteId').value),{method:'DELETE'});$('deleteModal').close();notify('Solicitud eliminada.');await refresh();});};
  sessionUi();render();
  try{if(config.authEnabled)await callback(config);}catch(e){message('errorBox',e.message);sessionUi();return;}
  if(getSession()){clearTimeout(expiryTimer);expiryTimer=setTimeout(expire,getSession().expiresAt-Date.now());}
  await refresh();
}
boot().catch(e=>message('errorBox',e.message));
