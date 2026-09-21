import {randomBytes,createHash,createCipheriv,createDecipheriv,timingSafeEqual} from 'node:crypto';
import {SecretsManagerClient,GetSecretValueCommand} from '@aws-sdk/client-secrets-manager';
const RT='__Secure-solicitudes-rt',TX='__Secure-solicitudes-tx';
class HttpError extends Error{constructor(status,message){super(message);this.status=status;}}
export function seal(payload,secret,purpose){
 const iv=randomBytes(12),c=createCipheriv('aes-256-gcm',createHash('sha256').update(secret).digest(),iv);
 c.setAAD(Buffer.from(purpose));
 const data=Buffer.concat([c.update(JSON.stringify(payload),'utf8'),c.final()]);
 return Buffer.concat([iv,c.getAuthTag(),data]).toString('base64url');
}
export function unseal(value,secret,purpose,now=Date.now()){
 try{
  if(!value||value.length>3800)throw Error();
  const b=Buffer.from(value,'base64url'),d=createDecipheriv('aes-256-gcm',createHash('sha256').update(secret).digest(),b.subarray(0,12));
  d.setAAD(Buffer.from(purpose));d.setAuthTag(b.subarray(12,28));
  const p=JSON.parse(Buffer.concat([d.update(b.subarray(28)),d.final()]).toString());
  if(!Number.isFinite(p.exp)||p.exp<=now)throw Error();
  return p;
 }catch{throw new HttpError(401,'Sesión inválida o expirada');}
}
export function cookie(name,value,seconds){
 if(value.length>3800)throw new HttpError(503,'Cookie de sesión demasiado grande');
 const sameSite=name===RT?'None':'Lax';
 return name+'='+value+'; Path=/auth; HttpOnly; Secure; SameSite='+sameSite+'; Max-Age='+Math.max(0,Math.floor(seconds));
}
function same(a,b){if(typeof a!=='string'||typeof b!=='string')return false;const x=Buffer.from(a),y=Buffer.from(b);return x.length===y.length&&timingSafeEqual(x,y);}
function cookies(event){
 const c={};
 for(const entry of event.cookies??[])for(const pair of entry.split(';')){
  const i=pair.indexOf('=');if(i>0){const k=pair.slice(0,i).trim();if(c[k]!==undefined)throw new HttpError(401,'Cookie duplicada');c[k]=pair.slice(i+1).trim();}
 }return c;
}
function response(status,payload={},setCookies=[],headers={}){
 return {statusCode:status,headers:{'Cache-Control':'no-store','Pragma':'no-cache','Content-Type':'application/json','Referrer-Policy':'no-referrer',...headers},cookies:setCookies,body:JSON.stringify(payload)};
}
export function makeHandler({config,getSecret,fetcher=fetch,now=Date.now}){
 const origin=new URL(config.origin).origin,domain=new URL(config.domain).origin,apiOrigin=new URL(config.apiOrigin).origin,callback=apiOrigin+'/auth/callback';
 if(!origin.startsWith('https://')||!domain.startsWith('https://')||!apiOrigin.startsWith('https://')||!config.clientId)throw Error('Configuración de sesión incompleta');
 async function token(body){
  let r;try{r=await fetcher(domain+'/oauth2/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams(body),signal:AbortSignal.timeout(12000)});}catch{throw new HttpError(503,'Cognito no está disponible');}
  if([400,401].includes(r.status))throw new HttpError(401,'Sesión inválida o expirada');
  if(!r.ok)throw new HttpError(503,'Cognito no está disponible');
  const p=await r.json();
  if(typeof p.access_token!=='string'||p.token_type?.toLowerCase()!=='bearer'||!Number.isFinite(p.expires_in)||p.expires_in<=30)throw new HttpError(503,'Respuesta de Cognito inválida');
  return p;
 }
 return async event=>{
  try{
   const h=Object.fromEntries(Object.entries(event.headers??{}).map(([k,v])=>[k.toLowerCase(),v]));
   const route=event.routeKey;
   if(route?.startsWith('POST ')&&(h.origin!==origin||h['x-csrf']!=='1'))throw new HttpError(403,'Origen de solicitud no autorizado');
   const secret=await getSecret(),c=cookies(event),t=now();
   if(route==='GET /auth/login'){
    const verifier=randomBytes(48).toString('base64url'),state=randomBytes(32).toString('base64url');
    const u=new URL(domain+'/oauth2/authorize');
    u.search=new URLSearchParams({response_type:'code',client_id:config.clientId,redirect_uri:callback,scope:'openid email profile',state,code_challenge_method:'S256',code_challenge:createHash('sha256').update(verifier).digest('base64url')});
    return response(302,{},[cookie(TX,seal({verifier,state,exp:t+600000},secret,TX),600)],{Location:u.href});
   }
   if(route==='GET /auth/callback'){
    const q=event.queryStringParameters??{},tx=unseal(c[TX],secret,TX,t);
    if(!same(q.state,tx.state)||q.error||!q.code)throw new HttpError(401,'Autenticación no completada');
    const p=await token({grant_type:'authorization_code',client_id:config.clientId,redirect_uri:callback,code:q.code,code_verifier:tx.verifier});
    if(typeof p.refresh_token!=='string')throw new HttpError(503,'Cognito no entregó Refresh Token');
    return response(303,{},[cookie(TX,'',0),cookie(RT,seal({token:p.refresh_token,exp:t+86400000},secret,RT),86400)],{Location:origin+'/?auth=success'});
   }
   if(route==='POST /auth/refresh'){
    const rt=unseal(c[RT],secret,RT,t);
    const p=await token({grant_type:'refresh_token',client_id:config.clientId,refresh_token:rt.token});
    const rotated=typeof p.refresh_token==='string'?p.refresh_token:rt.token;
    return response(200,{accessToken:p.access_token,expiresIn:p.expires_in},[cookie(RT,seal({token:rotated,exp:rt.exp},secret,RT),(rt.exp-t)/1000)]);
   }
   if(route==='POST /auth/logout'){
    if(c[RT])try{const rt=unseal(c[RT],secret,RT,t);await fetcher(domain+'/oauth2/revoke',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({token:rt.token,client_id:config.clientId}),signal:AbortSignal.timeout(12000)});}catch{/* Siempre eliminar cookies locales. */}
    const u=new URL(domain+'/logout');u.search=new URLSearchParams({client_id:config.clientId,logout_uri:origin+'/'});
    return response(200,{logoutUrl:u.href},[cookie(RT,'',0),cookie(TX,'',0)]);
   }
   return response(404,{error:'Ruta no encontrada'});
  }catch(e){
   if(event.routeKey==='GET /auth/callback')return response(303,{},[cookie(TX,'',0),cookie(RT,'',0)],{Location:origin+'/?auth=error'});
   const status=e instanceof HttpError?e.status:503;
   return response(status,{error:e instanceof HttpError?e.message:'Servicio de sesión no disponible'},status===401?[cookie(RT,'',0)]:[]);
  }
 };
}
let secret,loading,deployed;
async function getSecret(){
 if(secret)return secret;
 if(!loading)loading=(async()=>{
  const r=await new SecretsManagerClient({}).send(new GetSecretValueCommand({SecretId:process.env.COOKIE_SECRET_ARN}));
  if(!r.SecretString||r.SecretString.length<43)throw Error('Clave inválida');
  return secret=r.SecretString;
 })().finally(()=>{loading=undefined;});
 return loading;
}
export const handler=event=>{
 deployed??=makeHandler({config:{origin:process.env.PUBLIC_ORIGIN,domain:process.env.COGNITO_DOMAIN,clientId:process.env.COGNITO_CLIENT_ID,apiOrigin:process.env.SESSION_API_ORIGIN},getSecret});
 return deployed(event);
};
