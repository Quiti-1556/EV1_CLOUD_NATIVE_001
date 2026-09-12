import {cp,mkdir,readFile,writeFile,rm} from 'node:fs/promises';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {validateConfig} from './src/js/auth.js';
const here=dirname(fileURLToPath(import.meta.url)),out=resolve(here,'dist/frontend/browser');
const cfg=JSON.parse(await readFile(resolve(here,'src/assets/config.json'),'utf8'));
validateConfig(cfg,cfg.redirectUri);
await rm(resolve(here,'dist'),{recursive:true,force:true});await mkdir(out,{recursive:true});await cp(resolve(here,'src'),out,{recursive:true});
const connect=new Set(["'self'",new URL(cfg.apiUrl).origin]),form=new Set(["'self'"]);
if(cfg.authEnabled){connect.add(new URL(cfg.cognitoDomain).origin);form.add(new URL(cfg.cognitoDomain).origin);}
let html=await readFile(resolve(out,'index.html'),'utf8');
html=html.replace('__CSP_CONNECT__',[...connect].join(' ')).replace('__CSP_FORM__',[...form].join(' '));
if(html.includes('__CSP_'))throw new Error('CSP incompleta');
await writeFile(resolve(out,'index.html'),html);
console.log('Build listo: '+out);
