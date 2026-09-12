#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need node
if [[ $# -gt 0 ]]; then load_outputs "$1"; fi
export CLIENT_ID="${COGNITO_CLIENT_ID:-${CLIENT_ID:-}}"
: "${API_URL:?Falta API_URL}"
: "${REDIRECT_URI:?Falta REDIRECT_URI}"
: "${COGNITO_DOMAIN:?Falta COGNITO_DOMAIN}"
: "${CLIENT_ID:?Falta COGNITO_CLIENT_ID}"
export API_URL REDIRECT_URI COGNITO_DOMAIN
node --input-type=module <<'NODE'
import {writeFileSync} from 'node:fs';
const v=process.env;
for(const key of ['API_URL','REDIRECT_URI','COGNITO_DOMAIN']){
 const u=new URL(v[key]);if(u.protocol!=='https:' || u.username || u.password || u.hash || u.search)throw new Error(key+' debe ser URL HTTPS sin credenciales, query ni fragmento');
}
if(!/^[a-zA-Z0-9]+$/.test(v.CLIENT_ID))throw new Error('Client ID inválido');
const c={region:v.AWS_REGION||'',cognitoDomain:v.COGNITO_DOMAIN.replace(/\/$/,''),clientId:v.CLIENT_ID,
 redirectUri:v.REDIRECT_URI,apiUrl:v.API_URL.replace(/\/$/,''),authEnabled:true,resourcePath:'/solicitudes'};
writeFileSync('frontend/src/assets/config.json',JSON.stringify(c,null,2)+'\n');
console.log('Configuración pública generada; autenticación obligatoria.');
NODE
