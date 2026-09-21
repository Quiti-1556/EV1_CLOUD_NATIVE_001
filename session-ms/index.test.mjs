import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {makeHandler,seal,unseal,cookie} from './index.mjs';
const RT='__Secure-solicitudes-rt',TX='__Secure-solicitudes-tx',secret='a'.repeat(64),time=1000000;
const config={origin:'https://app.example.com',domain:'https://login.example.com',clientId:'public-client',apiOrigin:'https://api.example.net'};
const event=(route,c=[],extra={})=>({routeKey:route,cookies:c,headers:{origin:config.origin,'x-csrf':'1','sec-fetch-site':'cross-site'},...extra});
const token=(overrides={})=>new Response(JSON.stringify({access_token:'access-value',refresh_token:'refresh-value',id_token:'id-value',token_type:'Bearer',expires_in:900,...overrides}),{status:200});
const make=(fetcher=async()=>token())=>makeHandler({config,getSecret:async()=>secret,fetcher,now:()=>time});
const pair=c=>c.split(';')[0],value=c=>pair(c).slice(pair(c).indexOf('=')+1);
test('AES-GCM: propósito, alteración y expiración',()=>{
 const sealed=seal({token:'r',exp:time+1000},secret,RT);
 assert.equal(unseal(sealed,secret,RT,time).token,'r');
 assert.throws(()=>unseal(sealed,secret,TX,time));assert.throws(()=>unseal(sealed,secret,RT,time+1000));
 const bytes=Buffer.from(sealed,'base64url');bytes[30]^=1;assert.throws(()=>unseal(bytes.toString('base64url'),secret,RT,time));
});
test('refresh HttpOnly Secure None y transacción Lax, sin Domain',()=>{
 const c=cookie(RT,'abc',900);for(const a of ['HttpOnly','Secure','SameSite=None','Path=/auth','Max-Age=900'])assert.ok(c.includes(a));assert.ok(!c.includes('Domain='));assert.ok(cookie(TX,'abc',600).includes('SameSite=Lax'));
});
test('login/callback: PKCE S256, state y refresh nunca visible en JSON',async()=>{
 let received;const h=make(async(url,options)=>{received=options.body;return token();});
 const login=await h(event('GET /auth/login')),u=new URL(login.headers.Location);
 assert.equal(u.searchParams.get('redirect_uri'),config.apiOrigin+'/auth/callback');
 assert.equal(login.statusCode,302);assert.equal(u.searchParams.get('code_challenge_method'),'S256');
 const tx=unseal(value(login.cookies[0]),secret,TX,time);
 assert.equal(u.searchParams.get('code_challenge'),createHash('sha256').update(tx.verifier).digest('base64url'));
 const callback=await h(event('GET /auth/callback',[pair(login.cookies[0])],{queryStringParameters:{state:tx.state,code:'authorization-code'}}));
 assert.equal(callback.statusCode,303);assert.equal(received.get('code_verifier'),tx.verifier);
 assert.equal(received.get('grant_type'),'authorization_code');assert.equal(callback.headers.Location,config.origin+'/?auth=success');
 assert.ok(!callback.body.includes('refresh'));assert.equal(unseal(value(callback.cookies[1]),secret,RT,time).token,'refresh-value');
});
test('state incorrecto no canjea código',async()=>{
 let calls=0;const h=make(async()=>{calls++;return token();});
 const r=await h(event('GET /auth/callback',[RT+'=unused',TX+'='+seal({state:'correct',verifier:'v',exp:time+1000},secret,TX)],{queryStringParameters:{state:'wrong',code:'code'}}));
 assert.equal(calls,0);assert.equal(r.statusCode,303);assert.ok(r.headers.Location.endsWith('auth=error'));
});
test('refresh rota cookie y conserva fecha límite original',async()=>{
 let body;const h=make(async(url,o)=>{body=o.body;return token({refresh_token:'rotated'});});
 const exp=time+3600000,r=await h(event('POST /auth/refresh',[RT+'='+seal({token:'old',exp},secret,RT)]));
 assert.equal(r.statusCode,200);assert.deepEqual(JSON.parse(r.body),{accessToken:'access-value',expiresIn:900});
 assert.equal(body.get('refresh_token'),'old');assert.deepEqual(unseal(value(r.cookies[0]),secret,RT,time),{token:'rotated',exp});
});
test('sin refresh 401, CSRF 403 y login directo permitido',async()=>{
 const h=make();assert.equal((await h(event('POST /auth/refresh'))).statusCode,401);
 assert.equal((await h(event('POST /auth/refresh',[],{headers:{origin:'https://evil.example','x-csrf':'1'}}))).statusCode,403);
 assert.equal((await h(event('GET /auth/login',[],{headers:{}}))).statusCode,302);
 assert.equal((await h(event('POST /auth/refresh',[],{headers:{origin:config.origin}}))).statusCode,403);
});
test('503 transitorio no elimina cookie de refresh',async()=>{
 const h=make(async()=>{throw Error('Offline');});
 const r=await h(event('POST /auth/refresh',[RT+'='+seal({token:'old',exp:time+1000},secret,RT)]));
 assert.equal(r.statusCode,503);assert.equal(r.cookies.length,0);
});
test('logout elimina cookies incluso si revocación falla',async()=>{
 const h=make(async()=>{throw Error('Offline');});
 const r=await h(event('POST /auth/logout',[RT+'='+seal({token:'old',exp:time+1000},secret,RT)]));
 assert.equal(r.statusCode,200);assert.equal(r.cookies.length,2);assert.ok(r.cookies.every(c=>c.includes('Max-Age=0')));
 assert.ok(JSON.parse(r.body).logoutUrl.startsWith(config.domain+'/logout?'));
});
