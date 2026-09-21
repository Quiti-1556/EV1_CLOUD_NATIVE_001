import {Injectable,inject,signal} from '@angular/core';
import {HttpClient,HttpErrorResponse,HttpInterceptorFn} from '@angular/common/http';
import {firstValueFrom,from,switchMap,catchError,throwError} from 'rxjs';
export interface RuntimeConfig{apiUrl:string;sessionApiUrl?:string;authEnabled:boolean;redirectUri:string;clientId:string;cognitoDomain:string;resourcePath:string;region?:string;}
export function validateRuntimeConfig(c:RuntimeConfig,pageUrl:string):RuntimeConfig{
 const page=new URL(pageUrl),api=new URL(c.apiUrl);
 const local=(u:URL)=>['localhost','127.0.0.1','[::1]'].includes(u.hostname);
 if(c.authEnabled!==true&&!(c.authEnabled===false&&local(page)&&local(api)))throw Error('Demo solo localhost');
 if(c.authEnabled&&(page.protocol!=='https:'||api.protocol!=='https:'||new URL(c.redirectUri).origin!==page.origin))throw Error('Se requieren URLs HTTPS y redirect del frontend actual');
 if(api.username||api.password||api.search||api.hash||c.resourcePath!=='/solicitudes')throw Error('Configuración inválida');
 if(c.authEnabled){const auth=new URL(c.sessionApiUrl||c.apiUrl);if(auth.protocol!=='https:'||auth.origin!==api.origin||auth.pathname!==api.pathname||auth.search||auth.hash||auth.username||auth.password)throw Error('Sesión debe usar el API Gateway configurado');}
 if(c.authEnabled&&new URL(c.cognitoDomain).protocol!=='https:')throw Error('Cognito requiere HTTPS');
 return c;
}
@Injectable({providedIn:'root'})
export class SessionService{
 private http=inject(HttpClient);
 config!:RuntimeConfig;
 readonly active=signal(false);
 readonly notice=signal('');
 readonly demoRole=signal('SOLICITANTE');
 readonly demoUser=signal('solicitante.demo');
 private accessToken:string|null=null;
 private expiresAt=0;
 private generation=0;
 private refreshing:Promise<string>|null=null;
 private timer:ReturnType<typeof setTimeout>|undefined;
 configure(c:RuntimeConfig,pageUrl=location.href){this.config=validateRuntimeConfig(c,pageUrl);}
 async load(){
  this.configure(await firstValueFrom(this.http.get<RuntimeConfig>('assets/config.json')));
  if(!this.config.authEnabled){this.active.set(true);return;}
  const result=new URL(location.href).searchParams.get('auth');
  if(result==='success')history.replaceState({},'','/');
  if(result==='error'){this.notice.set('No se completó el inicio de sesión. Inténtalo nuevamente.');history.replaceState({},'','/');}
  try{await this.refresh();}catch(e){if(result==='success'&&e instanceof HttpErrorResponse&&e.status===401)this.notice.set('Cognito completó el login, pero no llegó la cookie de sesión. Revisa el bloqueo de cookies de terceros para este sitio.');else if(!(e instanceof HttpErrorResponse&&e.status===401))this.notice.set('El servicio de sesión no está disponible. Reintenta en unos momentos.');}
 }
 private authUrl(path:string){return (this.config.sessionApiUrl||this.config.apiUrl).replace(/\/$/,'')+path;}
 login(){location.assign(this.authUrl('/auth/login'));}
 clear(){this.generation++;this.accessToken=null;this.expiresAt=0;this.active.set(false);clearTimeout(this.timer);}
 async logout(){
  this.clear();
  const r=await firstValueFrom(this.http.post<{logoutUrl:string}>(this.authUrl('/auth/logout'),{}, {headers:{'X-CSRF':'1'},withCredentials:true}));
  if(new URL(r.logoutUrl).origin!==new URL(this.config.cognitoDomain).origin)throw Error('Destino de salida inválido');
  location.assign(r.logoutUrl);
 }
 ensure():Promise<string>{
  if(this.accessToken&&Date.now()<this.expiresAt-10000)return Promise.resolve(this.accessToken);
  return this.refresh();
 }
 refresh():Promise<string>{
  if(this.refreshing)return this.refreshing;
  const generation=this.generation;
  this.refreshing=(async()=>{
   try{
    const renew=()=>firstValueFrom(this.http.post<{accessToken:string;expiresIn:number}>(this.authUrl('/auth/refresh'),{}, {headers:{'X-CSRF':'1'},withCredentials:true}));
    const r=navigator.locks?await navigator.locks.request('solicitudes-refresh',renew):await renew();
    if(generation!==this.generation)throw Error('Sesión cerrada');
    if(!r.accessToken||!Number.isFinite(r.expiresIn)||r.expiresIn<=30)throw Error('Respuesta inválida');
    this.accessToken=r.accessToken;this.expiresAt=Date.now()+r.expiresIn*1000;this.active.set(true);this.notice.set('');
    clearTimeout(this.timer);
    this.timer=setTimeout(()=>{void this.refresh().catch(e=>{
     if(!(e instanceof HttpErrorResponse&&e.status===401)&&generation===this.generation)
      this.timer=setTimeout(()=>{void this.refresh().catch(()=>{});},30000);
    });},Math.max(1000,(r.expiresIn-60)*1000));
    return r.accessToken;
   }catch(e){if(e instanceof HttpErrorResponse&&e.status===401&&generation===this.generation)this.clear();throw e;}
  })().finally(()=>{this.refreshing=null;});
  return this.refreshing;
 }
}
export const sessionInterceptor:HttpInterceptorFn=(req,next)=>{
 const session=inject(SessionService);
 if(!session.config||!req.url.startsWith(session.config.apiUrl+'/'))return next(req);
 // Las rutas de sesión usan cookies; nunca intentar conseguir un Bearer para renovar el propio Bearer.
 const auth=(session.config.sessionApiUrl||session.config.apiUrl).replace(/\/$/,'')+'/auth/';
 if(req.url.startsWith(auth))return next(req);
 if(!session.config.authEnabled)return next(req.clone({setHeaders:{'X-Demo-User':session.demoUser(),'X-Demo-Role':session.demoRole()}}));
 const authenticated=(token:string)=>req.clone({setHeaders:{Authorization:'Bearer '+token}});
 return from(session.ensure()).pipe(switchMap(token=>next(authenticated(token))),catchError(e=>{
  if(!(e instanceof HttpErrorResponse)||e.status!==401)return throwError(()=>e);
  return from(session.refresh()).pipe(switchMap(token=>next(authenticated(token))));
 }));
};
