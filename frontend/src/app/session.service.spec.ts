import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {provideHttpClientTesting,HttpTestingController} from '@angular/common/http/testing';
import {SessionService,validateRuntimeConfig} from './session.service';
import {afterEach,beforeEach,describe,it,expect} from 'vitest';
const cfg={apiUrl:'https://api.example.net',authEnabled:true,redirectUri:'https://app.example.com/',clientId:'client',cognitoDomain:'https://login.example.com',resourcePath:'/solicitudes'};
describe('SessionService',()=>{
 let session:SessionService,http:HttpTestingController;
 beforeEach(()=>{TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting()]});session=TestBed.inject(SessionService);http=TestBed.inject(HttpTestingController);session.configure(cfg,'https://app.example.com/');});
 afterEach(()=>{session.clear();http.verify();});
 it('una renovación para peticiones concurrentes; Access solo memoria',async()=>{
  const a=session.ensure(),b=session.ensure();expect(a).toBe(b);
  const r=http.expectOne(cfg.apiUrl+'/auth/refresh');expect(r.request.withCredentials).toBe(true);expect(r.request.headers.get('X-CSRF')).toBe('1');
  r.flush({accessToken:'access',expiresIn:900});expect(await a).toBe('access');expect(await b).toBe('access');expect(await session.ensure()).toBe('access');
  expect(localStorage.length).toBe(0);expect(sessionStorage.length).toBe(0);
 });
 it('401 borra sesión',async()=>{const p=session.ensure();http.expectOne(cfg.apiUrl+'/auth/refresh').flush({}, {status:401,statusText:'Unauthorized'});await expect(p).rejects.toBeDefined();expect(session.active()).toBe(false);});
 it('refresh pendiente no resucita sesión cerrada',async()=>{const p=session.ensure();session.clear();http.expectOne(cfg.apiUrl+'/auth/refresh').flush({accessToken:'late',expiresIn:900});await expect(p).rejects.toThrow('Sesión cerrada');expect(session.active()).toBe(false);});
 it('permite Gateway cross-site HTTPS y rechaza demo pública',()=>{expect(()=>validateRuntimeConfig(cfg,'https://app.example.com/')).not.toThrow();expect(()=>validateRuntimeConfig({...cfg,apiUrl:'http://other.example.com'},'https://app.example.com/')).toThrow();expect(()=>validateRuntimeConfig({...cfg,authEnabled:false},'https://app.example.com/')).toThrow();});
});
