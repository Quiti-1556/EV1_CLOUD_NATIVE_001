import {Component,inject,signal,computed,effect,OnDestroy} from '@angular/core';
import {CommonModule} from '@angular/common';
import {FormsModule} from '@angular/forms';
import {HttpErrorResponse} from '@angular/common/http';
import {SessionService} from './session.service';
import {ApiService,Solicitud,Summary,RequestForm} from './api.service';
@Component({selector:'app-root',standalone:true,imports:[CommonModule,FormsModule],templateUrl:'./app.component.html'})
export class AppComponent implements OnDestroy{
 readonly session=inject(SessionService);
 private api=inject(ApiService);
 readonly summary=signal<Summary>({pendientes:0,aprobadas:0,rechazadas:0,mias:0,roles:[]});
 readonly items=signal<Solicitud[]>([]);
 readonly busy=signal(false);
 readonly error=signal('');
 readonly message=signal('');
 readonly approval=signal(false);
 readonly search=signal('');
 readonly status=signal('');
 readonly page=signal(1);
 readonly modal=signal<'form'|'detail'|'decision'|null>(null);
 readonly selected=signal<Solicitud|null>(null);
 readonly canCreate=computed(()=>this.summary().roles.includes('SOLICITANTE'));
 readonly canApprove=computed(()=>this.summary().roles.includes('APROBADOR'));
 readonly filtered=computed(()=>{const q=this.search().toLowerCase();return this.items().filter(s=>(!this.status()||s.estado===this.status())&&(!q||[s.titulo,s.tipo,s.solicitanteNombre,s.id].some(x=>x.toLowerCase().includes(q))));});
 readonly pages=computed(()=>Math.max(1,Math.ceil(this.filtered().length/8)));
 readonly visible=computed(()=>this.filtered().slice((Math.min(this.page(),this.pages())-1)*8,Math.min(this.page(),this.pages())*8));
 readonly types=['VACACIONES','PERMISO','COMPRA','TELETRABAJO','OTRO'];
 form:RequestForm=this.emptyForm();
 decision='APROBAR';comment='';
 private revision=0;
 private returnFocus:HTMLElement|null=null;
 constructor(){effect(()=>{
  const opened=this.modal();document.body.classList.toggle('dialog-open',!!opened);
  if(opened){this.returnFocus=document.activeElement instanceof HTMLElement?document.activeElement:null;queueMicrotask(()=>{if(this.modal())document.querySelector<HTMLElement>('.dialog input, .dialog select, .dialog textarea, .dialog button')?.focus();});}
  else queueMicrotask(()=>{if(!this.modal())this.returnFocus?.focus();});
 });effect(()=>{const active=this.session.active();this.session.demoRole();this.session.demoUser();if(active){void this.load();}else{this.items.set([]);this.summary.set({pendientes:0,aprobadas:0,rechazadas:0,mias:0,roles:[]});}});}
 ngOnDestroy(){document.body.classList.remove('dialog-open');}
 dialogKeys(e:KeyboardEvent){
  if(e.key==='Escape'){e.preventDefault();this.modal.set(null);return;}
  if(e.key!=='Tab')return;
  const dialog=e.currentTarget as HTMLElement;
  const nodes=Array.from(dialog.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex="0"]')).filter(n=>n.getClientRects().length>0);
  const first=nodes[0],last=nodes.at(-1);if(!first||!last)return;
  if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}
  else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}
 }
 private emptyForm():RequestForm{return {tipo:'OTRO',titulo:'',descripcion:'',fechaInicio:null,fechaFin:null};}
 private fail(e:unknown){this.error.set(e instanceof HttpErrorResponse?(e.error?.error||('HTTP '+e.status+' — no se pudo completar la operación')):e instanceof Error?e.message:'Error inesperado');}
 async load(){
  const revision=++this.revision;this.busy.set(true);this.error.set('');
  try{
   const summary=await this.api.summary();
   if(revision!==this.revision||!this.session.active())return;
   this.summary.set(summary);
   if(this.approval()&&!summary.roles.includes('APROBADOR'))this.approval.set(false);
   const items=await this.api.list(this.approval());
   if(revision===this.revision&&this.session.active())this.items.set(items);
  }catch(e){if(revision===this.revision)this.fail(e);}finally{if(revision===this.revision)this.busy.set(false);}
 }
 tab(approval:boolean){this.approval.set(approval);this.page.set(1);this.status.set('');void this.load();}
 newRequest(){this.selected.set(null);this.form=this.emptyForm();this.modal.set('form');this.error.set('');}
 edit(s:Solicitud){this.selected.set(s);this.form={tipo:s.tipo,titulo:s.titulo,descripcion:s.descripcion,fechaInicio:s.fechaInicio,fechaFin:s.fechaFin};this.modal.set('form');this.error.set('');}
 detail(s:Solicitud){this.selected.set(s);this.modal.set('detail');}
 decisionFor(s:Solicitud){this.selected.set(s);this.decision='APROBAR';this.comment='';this.modal.set('decision');this.error.set('');}
 async save(){
  if(!this.form.titulo.trim()||!this.form.descripcion.trim())return;
  if(this.form.fechaInicio&&this.form.fechaFin&&this.form.fechaFin<this.form.fechaInicio){this.error.set('La fecha final no puede ser anterior a la inicial');return;}
  this.busy.set(true);this.error.set('');
  try{await this.api.save({...this.form,fechaInicio:this.form.fechaInicio||null,fechaFin:this.form.fechaFin||null},this.selected()?.id);this.modal.set(null);this.message.set('Solicitud guardada');await this.load();}catch(e){this.fail(e);}finally{this.busy.set(false);}
 }
 async remove(s:Solicitud){
  if(!confirm('¿Eliminar la solicitud '+s.titulo+'?'))return;
  this.busy.set(true);this.error.set('');
  try{await this.api.delete(s.id);this.message.set('Solicitud eliminada');await this.load();}catch(e){this.fail(e);}finally{this.busy.set(false);}
 }
 async decide(){
  const s=this.selected();if(!s||!this.comment.trim())return;
  this.busy.set(true);this.error.set('');
  try{await this.api.decide(s.id,this.decision,this.comment);this.modal.set(null);this.message.set('Decisión registrada');await this.load();}catch(e){this.fail(e);}finally{this.busy.set(false);}
 }
 async logout(){try{await this.session.logout();}catch(e){this.fail(e);}}
 async recover(){try{await this.session.refresh();}catch(e){this.fail(e);}}
}
