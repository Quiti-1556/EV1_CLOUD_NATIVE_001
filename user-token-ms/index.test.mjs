import assert from 'node:assert/strict';
import test from 'node:test';

import { handler } from './index.mjs';

const eventFor = (groups) => ({
  version: '2',
  triggerSource: 'TokenGeneration_HostedAuth',
  userName: 'test-user',
  request: {
    userAttributes: { email: 'test@example.invalid' },
    groupConfiguration: { groupsToOverride: groups },
  },
  response: {},
});

test('SOLICITANTE recibe lectura y escritura', async () => {
  const result = await handler(eventFor(['SOLICITANTE']));
  assert.deepEqual(
    result.response.claimsAndScopeOverrideDetails.accessTokenGeneration.scopesToAdd,
    ['solicitudes/read', 'solicitudes/write'],
  );
});

test('APROBADOR recibe lectura y aprobación', async () => {
  const result = await handler(eventFor(['APROBADOR']));
  assert.deepEqual(
    result.response.claimsAndScopeOverrideDetails.accessTokenGeneration.scopesToAdd,
    ['solicitudes/read', 'solicitudes/approve'],
  );
});

test('combina grupos sin duplicar scopes', async () => {
  const result = await handler(eventFor(['SOLICITANTE', 'APROBADOR']));
  assert.deepEqual(
    result.response.claimsAndScopeOverrideDetails.accessTokenGeneration.scopesToAdd,
    ['solicitudes/read', 'solicitudes/write', 'solicitudes/approve'],
  );
});

test('un grupo desconocido no concede permisos', async () => {
  const result = await handler(eventFor(['DESCONOCIDO']));
  assert.deepEqual(
    result.response.claimsAndScopeOverrideDetails.accessTokenGeneration.scopesToAdd,
    [],
  );
});

test('solicitante suprime approve aunque el cliente lo solicite', async () => {
  const event=eventFor(['SOLICITANTE']);event.request.scopes=['openid','solicitudes/approve'];
  const result=await handler(event),access=result.response.claimsAndScopeOverrideDetails.accessTokenGeneration;
  assert.deepEqual(access.scopesToSuppress,['solicitudes/approve']);
  assert.equal(access.claimsToAddOrOverride.verified_name,'test@example.invalid');
});

test('grupos especiales o ausencia de grupos no conceden scopes', async()=>{
 for(const groups of [[],['constructor','__proto__','toString']]){
  const access=(await handler(eventFor(groups))).response.claimsAndScopeOverrideDetails.accessTokenGeneration;
  assert.deepEqual(access.scopesToAdd,[]);
  assert.deepEqual(access.scopesToSuppress,['solicitudes/read','solicitudes/write','solicitudes/approve']);
 }
});
