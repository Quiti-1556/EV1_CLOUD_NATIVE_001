#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need node
if [[ $# -gt 0 ]]; then load_outputs "$1"; fi
: "${FRONTEND_API_URL:?Falta FRONTEND_API_URL; primero Deploy completo}"
: "${REDIRECT_URI:?}" "${COGNITO_DOMAIN:?}" "${COGNITO_CLIENT_ID:?}"
export FRONTEND_API_URL REDIRECT_URI COGNITO_DOMAIN COGNITO_CLIENT_ID SESSION_API_URL
node --input-type=module <<'NODE'
import {writeFileSync} from 'node:fs';
const v=process.env,api=new URL(v.FRONTEND_API_URL),front=new URL(v.REDIRECT_URI),cognito=new URL(v.COGNITO_DOMAIN);
for(const u of [api,front,cognito])if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash)throw Error('Configuración requiere HTTPS sin credenciales ni query');
const session=new URL(v.SESSION_API_URL||v.FRONTEND_API_URL);
if(session.origin!==api.origin||session.pathname!==api.pathname||session.search||session.hash||session.username||session.password)throw Error('Sesión debe usar el mismo API Gateway');
if(!/^[a-zA-Z0-9]+$/.test(v.COGNITO_CLIENT_ID))throw Error('Client ID inválido');
const c={region:v.AWS_REGION||'',apiUrl:v.FRONTEND_API_URL,sessionApiUrl:session.href.replace(/\/$/,''),redirectUri:v.REDIRECT_URI,cognitoDomain:v.COGNITO_DOMAIN,clientId:v.COGNITO_CLIENT_ID,authEnabled:true,resourcePath:'/solicitudes'};
writeFileSync('frontend/src/assets/config.json',JSON.stringify(c,null,2)+'\n');
console.log('Configuración pública Angular generada; sin Access/Refresh ni secretos.');
NODE
