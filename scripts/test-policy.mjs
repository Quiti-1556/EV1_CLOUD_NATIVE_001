import {readFileSync,readdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'),read=p=>readFileSync(resolve(root,p),'utf8');
let checks=0;function check(ok,why){assert.ok(ok,why);checks++;}
const api=read('terraform/apigateway.tf'),frontend=read('frontend/src/app/session.service.ts'),session=read('session-ms/index.mjs');
for(const [header,claim] of [['X-Verified-User','sub'],['X-Verified-Name','verified_name'],['X-Verified-Scopes','scope']])check(api.includes('overwrite:header.'+header)&&api.includes('$context.authorizer.claims.'+claim),'Gateway sobrescribe '+header);
check(/authorization_type\s*=\s*"JWT"/.test(api)&&/authorization_scopes\s*=\s*each.value/.test(api),'JWT + scopes obligatorios');
check(/"GET \/solicitudes\/pendientes"\s*=\s*\["solicitudes\/approve"\]/.test(api),'Pendientes protegido por approve');
check(!api.includes('{proxy+}')&&!api.includes('ANY /'),'Sin rutas catch-all');
check(read('terraform/ecs.tf').includes('APP_IDENTITY_MODE')&&!read('terraform/ecs.tf').includes('APP_SECURITY_ENABLED'),'ECS confía en Gateway, sin modo anterior');
check(read('backend/src/main/resources/application-aws.properties').includes('app.identity-mode=gateway'),'Perfil AWS jamás demo');
check(!read('backend/pom.xml').includes('starter-security')&&!read('backend/pom.xml').includes('resource-server'),'Sin dependencias validadoras JWT');
function java(dir){return readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?java(resolve(dir,e.name)):e.name.endsWith('.java')?[resolve(dir,e.name)]:[]);}
for(const f of java(resolve(root,'backend/src/main/java')))check(!/JwtDecoder|NimbusJwt|CognitoAccessTokenValidator|oauth2ResourceServer|SecurityContextHolder/.test(readFileSync(f,'utf8')),'Java no valida JWT: '+f);
check(!/localStorage|sessionStorage|document.cookie/.test(frontend),'Frontend no persiste tokens');
check(session.includes('HttpOnly; Secure; SameSite=')&&session.includes("name===RT?'None':'Lax'"),'Refresh cross-site seguro; transacción Lax');
check(session.includes("h.origin!==origin")&&session.includes("h['x-csrf']!=='1'"),'CSRF validado');
check(session.includes("code_challenge_method:'S256'")&&session.includes('code_verifier:tx.verifier'),'PKCE S256');
check(api.includes('cors_configuration')&&api.includes('allow_credentials = true')&&api.includes('allow_origins     = local.origins'),'CORS con credenciales y origen explícito');
check(!readdirSync(resolve(root,'terraform')).some(f=>f.endsWith('.tf')&&/aws_cloudfront_/.test(read('terraform/'+f))),'Sin recursos CloudFront propios');
check(!session.includes('edgeKey')&&session.includes('SESSION_API_ORIGIN'),'Sesión directa en Gateway');
console.log(checks+' comprobaciones de política correctas (estáticas, no integración AWS).');
