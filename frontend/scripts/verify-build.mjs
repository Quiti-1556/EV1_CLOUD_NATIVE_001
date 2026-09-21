import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const out=resolve(root,'dist/frontend/browser');
const index=readFileSync(resolve(out,'index.html'),'utf8');
assert.ok(!/\son[a-z]+\s*=/i.test(index),'CSP: index no debe depender de handlers inline');
assert.ok(!/media\s*=\s*["\x27]print["\x27]/i.test(index),'CSS no puede quedar desactivado como print');
assert.ok(!/<style[\s>]/i.test(index),'Los estilos se deben servir desde el archivo local completo');
const links=[...index.matchAll(/<link\b[^>]*>/gi)]
  .filter(([tag])=>/rel=["\x27]stylesheet["\x27]/i.test(tag))
  .map(([tag])=>tag.match(/href=["\x27]([^"\x27]+)["\x27]/i)?.[1]);
assert.ok(links.length>0,'Falta stylesheet de producción');
const css=links.map(href=>{
  assert.ok(href&&!/^(?:https?:)?\/\//i.test(href)&&!href.includes('..'),'CSS debe ser local');
  const path=resolve(out,href);
  assert.ok(existsSync(path),'Falta archivo CSS en el bundle');
  return readFileSync(path,'utf8');
}).join('\n');
for(const selector of ['.btn','.form-control','.sidebar','.stats','.overlay'])
  assert.ok(css.includes(selector),'Falta Bootstrap/diseño: '+selector);
console.log('Build verificado: Bootstrap local, diseño completo y CSS compatible con CSP sin onload.');
