let session = null;
const KEY = 'solicitud.oauth';
export const isLoopback = hostname => ['localhost', '127.0.0.1', '[::1]'].includes(hostname);
export function validateConfig(config, pageUrl) {
  const page = new URL(pageUrl);
  for (const name of ['apiUrl', 'redirectUri']) {
    const url = new URL(config[name]);
    if (url.username || url.password || url.hash || url.search) throw new Error('Configuración de URL inválida');
    if (url.protocol !== 'https:' && !(url.protocol === 'http:' && isLoopback(url.hostname) && isLoopback(page.hostname))) throw new Error('Se requiere una conexión HTTPS');
  }
  if (config.authEnabled !== true && !(config.authEnabled === false && isLoopback(page.hostname) && isLoopback(new URL(config.apiUrl).hostname))) throw new Error('El modo de demostración solo funciona en localhost');
  if (config.authEnabled) {
    const domain = new URL(config.cognitoDomain);
    if (domain.protocol !== 'https:' || domain.origin !== config.cognitoDomain || !/^[a-zA-Z0-9]+$/.test(config.clientId)) throw new Error('Configuración de autenticación inválida');
    if (new URL(config.redirectUri).origin !== page.origin) throw new Error('Esta dirección no coincide con el sitio autorizado');
  }
  if(config.resourcePath !== '/solicitudes') throw new Error('Ruta de API inválida');
  return config;
}
const base64url = bytes => btoa(String.fromCharCode(...bytes)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
export const random = (length=32) => base64url(crypto.getRandomValues(new Uint8Array(length)));
export async function challenge(verifier) { return base64url(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier)))); }
export function getSession() { if (session && Date.now() >= session.expiresAt) session=null; return session; }
export function clearSession() { session=null; sessionStorage.removeItem(KEY); }
export async function login(config) {
  const verifier=random(48), state=random();
  sessionStorage.setItem(KEY, JSON.stringify({verifier,state,createdAt:Date.now()}));
  const url = new URL(config.cognitoDomain+'/oauth2/authorize');
  url.search = new URLSearchParams({response_type:'code',client_id:config.clientId,redirect_uri:config.redirectUri,scope:'openid email profile',state,code_challenge_method:'S256',code_challenge:await challenge(verifier)});
  location.assign(url);
}
export function validateTransaction(transaction, state, now=Date.now()) {
  if (!transaction || !state || state!==transaction.state || typeof transaction.verifier!=='string' || !/^[A-Za-z0-9_-]{43,128}$/.test(transaction.verifier) || !Number.isFinite(transaction.createdAt) || now-transaction.createdAt>600000 || now<transaction.createdAt) throw new Error('La autenticación expiró o no corresponde a esta sesión. Vuelve a iniciar sesión.');
}
export async function callback(config) {
  const url=new URL(location.href);
  if (!url.searchParams.has('code') && !url.searchParams.has('error')) return false;
  let transaction;
  try { transaction=JSON.parse(sessionStorage.getItem(KEY)||'null'); } catch { transaction=null; }
  sessionStorage.removeItem(KEY);
  history.replaceState({},'',new URL(config.redirectUri).pathname);
  validateTransaction(transaction,url.searchParams.get('state'));
  if (url.searchParams.has('error')) throw new Error('No se completó el inicio de sesión. Inténtalo nuevamente.');
  const response=await fetch(config.cognitoDomain+'/oauth2/token',{method:'POST',credentials:'omit',cache:'no-store',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'authorization_code',client_id:config.clientId,redirect_uri:config.redirectUri,code:url.searchParams.get('code'),code_verifier:transaction.verifier})});
  if (!response.ok) throw new Error('No fue posible validar la sesión. Inténtalo nuevamente.');
  const token=await response.json();
  if (!token.access_token || !Number.isFinite(token.expires_in) || token.expires_in<=30 || token.token_type?.toLowerCase()!=='bearer') throw new Error('Respuesta de autenticación inválida');
  // Ningún access, ID o refresh token se guarda en almacenamiento del navegador.
  session={accessToken:token.access_token,expiresAt:Date.now()+(token.expires_in-30)*1000};
  return true;
}
export function logout(config) {
  clearSession();
  const url=new URL(config.cognitoDomain+'/logout');
  url.search=new URLSearchParams({client_id:config.clientId,logout_uri:config.redirectUri});
  location.assign(url);
}
