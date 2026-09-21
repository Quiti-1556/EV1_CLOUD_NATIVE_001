import {bootstrapApplication} from '@angular/platform-browser';
import {provideHttpClient,withInterceptors} from '@angular/common/http';
import {provideAppInitializer,inject} from '@angular/core';
import {AppComponent} from './app/app.component';
import {SessionService,sessionInterceptor} from './app/session.service';
bootstrapApplication(AppComponent,{providers:[
 provideHttpClient(withInterceptors([sessionInterceptor])),
 provideAppInitializer(()=>inject(SessionService).load())
]}).catch(()=>{document.body.textContent='No se pudo iniciar la aplicación. Verifica la configuración y usa la URL Amplify del despliegue.';});
