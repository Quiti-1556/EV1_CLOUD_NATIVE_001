import {TestBed} from '@angular/core/testing';
import {HttpClient,provideHttpClient,withInterceptors} from '@angular/common/http';
import {provideHttpClientTesting,HttpTestingController} from '@angular/common/http/testing';
import {firstValueFrom} from 'rxjs';
import {SessionService,sessionInterceptor} from './session.service';
import {afterEach,beforeEach,describe,it,expect} from 'vitest';
describe('Gateway interceptor',()=>{
 let session:SessionService,http:HttpTestingController,client:HttpClient;
 const api='https://api.example.net';
 beforeEach(()=>{
  TestBed.configureTestingModule({providers:[provideHttpClient(withInterceptors([sessionInterceptor])),provideHttpClientTesting()]});
  session=TestBed.inject(SessionService);http=TestBed.inject(HttpTestingController);client=TestBed.inject(HttpClient);
  session.configure({apiUrl:api,authEnabled:true,redirectUri:'https://app.example.com/',clientId:'client',cognitoDomain:'https://login.example.com',resourcePath:'/solicitudes'},'https://app.example.com/');
 });
 afterEach(()=>{session.clear();http.verify();});
 async function access(){const p=session.ensure();http.expectOne(api+'/auth/refresh').flush({accessToken:'access-one',expiresIn:900});await p;}
 it('sesión usa cookie sin Bearer ni renovación recursiva',async()=>{
  const p=firstValueFrom(client.post(api+'/auth/refresh',{}, {withCredentials:true,headers:{'X-CSRF':'1'}}));
  const r=http.expectOne(api+'/auth/refresh');expect(r.request.withCredentials).toBe(true);expect(r.request.headers.has('Authorization')).toBe(false);r.flush({});await p;
 });
 it('Bearer al Gateway pero no a otros destinos',async()=>{
  await access();const p=firstValueFrom(client.get(api+'/datos'));await Promise.resolve();
  const r=http.expectOne(api+'/datos');expect(r.request.headers.get('Authorization')).toBe('Bearer access-one');r.flush({ok:true});await p;
  const external=firstValueFrom(client.get('https://other.example.com/datos'));const e=http.expectOne('https://other.example.com/datos');expect(e.request.headers.has('Authorization')).toBe(false);e.flush({});await external;
 });
 it('401 renueva y reintenta una vez',async()=>{
  await access();const p=firstValueFrom(client.get(api+'/datos'));await Promise.resolve();
  http.expectOne(api+'/datos').flush({}, {status:401,statusText:'Unauthorized'});
  http.expectOne(api+'/auth/refresh').flush({accessToken:'access-two',expiresIn:900});
  await new Promise(resolve=>setTimeout(resolve,0));const r=http.expectOne(api+'/datos');expect(r.request.headers.get('Authorization')).toBe('Bearer access-two');r.flush({ok:true});expect(await p).toEqual({ok:true});
 });
 it('403 no renueva permisos',async()=>{
  await access();const p=firstValueFrom(client.get(api+'/solicitudes/pendientes'));const rejected=expect(p).rejects.toMatchObject({status:403});await Promise.resolve();
  http.expectOne(api+'/solicitudes/pendientes').flush({}, {status:403,statusText:'Forbidden'});await rejected;http.expectNone(api+'/auth/refresh');expect(session.active()).toBe(true);
 });
});
