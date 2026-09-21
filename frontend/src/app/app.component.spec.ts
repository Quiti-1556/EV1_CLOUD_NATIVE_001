import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {provideHttpClientTesting} from '@angular/common/http/testing';
import {AppComponent} from './app.component';
import {SessionService} from './session.service';
import {it,expect} from 'vitest';
it('renderiza componente Angular con pantalla de login',()=>{
 TestBed.configureTestingModule({imports:[AppComponent],providers:[provideHttpClient(),provideHttpClientTesting()]});
 const session=TestBed.inject(SessionService);
 session.configure({apiUrl:'https://app.example.com/api',authEnabled:true,redirectUri:'https://app.example.com/',clientId:'c',cognitoDomain:'https://login.example.com',resourcePath:'/solicitudes'},'https://app.example.com/');
 const fixture=TestBed.createComponent(AppComponent);fixture.detectChanges();
 expect(fixture.nativeElement.textContent).toContain('Iniciar sesión');expect(fixture.nativeElement.querySelector('app-root')).toBeNull();
 session.clear();fixture.destroy();
});

it('recupera sidebar y abre/cierra formulario como diálogo Angular',()=>{
 TestBed.configureTestingModule({imports:[AppComponent],providers:[provideHttpClient(),provideHttpClientTesting()]});
 const session=TestBed.inject(SessionService);
 session.configure({apiUrl:'https://api.example.net',authEnabled:true,redirectUri:'https://app.example.com/',clientId:'c',cognitoDomain:'https://login.example.com',resourcePath:'/solicitudes'},'https://app.example.com/');
 const fixture=TestBed.createComponent(AppComponent);fixture.detectChanges();
 expect(fixture.nativeElement.querySelector('.sidebar')).not.toBeNull();
 expect(fixture.nativeElement.querySelector('.overlay')).toBeNull();
 fixture.componentInstance.newRequest();fixture.detectChanges();
 const dialog=fixture.nativeElement.querySelector('[role="dialog"]');
 expect(dialog.textContent).toContain('Nueva solicitud');
 expect(dialog.querySelector('.form-control')).not.toBeNull();
 dialog.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));fixture.detectChanges();
 expect(fixture.nativeElement.querySelector('.overlay')).toBeNull();
 session.clear();fixture.destroy();
});
