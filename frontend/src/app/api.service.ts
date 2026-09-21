import {Injectable,inject} from '@angular/core';
import {HttpClient} from '@angular/common/http';
import {firstValueFrom} from 'rxjs';
import {SessionService} from './session.service';
export interface Solicitud{id:string;tipo:string;titulo:string;descripcion:string;estado:string;solicitanteNombre:string;fechaInicio:string|null;fechaFin:string|null;comentarioAprobador?:string;creadoEn?:string;}
export interface Summary{pendientes:number;aprobadas:number;rechazadas:number;mias:number;roles:string[];}
export interface RequestForm{tipo:string;titulo:string;descripcion:string;fechaInicio:string|null;fechaFin:string|null;}
@Injectable({providedIn:'root'})
export class ApiService{
 private http=inject(HttpClient);private session=inject(SessionService);
 private get base(){return this.session.config.apiUrl;}
 summary(){return firstValueFrom(this.http.get<Summary>(this.base+'/datos'));}
 list(approval:boolean){return firstValueFrom(this.http.get<Solicitud[]>(this.base+'/solicitudes/'+(approval?'pendientes':'mias')));}
 save(form:RequestForm,id?:string){const url=this.base+'/solicitudes'+(id?'/'+encodeURIComponent(id):'');return firstValueFrom(id?this.http.put<Solicitud>(url,form):this.http.post<Solicitud>(url,form));}
 delete(id:string){return firstValueFrom(this.http.delete<void>(this.base+'/solicitudes/'+encodeURIComponent(id)));}
 decide(id:string,decision:string,comentario:string){return firstValueFrom(this.http.post<Solicitud>(this.base+'/solicitudes/'+encodeURIComponent(id)+'/decision',{decision,comentario}));}
}
