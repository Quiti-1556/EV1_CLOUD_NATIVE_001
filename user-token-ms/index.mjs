const BUSINESS = ['solicitudes/read','solicitudes/write','solicitudes/approve'];
export const handler = async event => {
 const groups=new Set(event.request?.groupConfiguration?.groupsToOverride??[]);
 const scopes=new Set();
 if(groups.has('SOLICITANTE')){scopes.add(BUSINESS[0]);scopes.add(BUSINESS[1]);}
 if(groups.has('APROBADOR')){scopes.add(BUSINESS[0]);scopes.add(BUSINESS[2]);}
 const attributes=event.request?.userAttributes??{};
 const name=String(attributes.name||attributes.email||event.userName||'Usuario').replace(/[\r\n]/g,' ').slice(0,200);
 console.info(JSON.stringify({evento:'permisos-access-token',usuario:attributes.sub??'sin-sub',grupos:[...groups],scopes:[...scopes]}));
 event.response??={};
 event.response.claimsAndScopeOverrideDetails={
  groupOverrideDetails:event.request?.groupConfiguration??{},
  accessTokenGeneration:{claimsToAddOrOverride:{verified_name:name},
    scopesToAdd:[...scopes],scopesToSuppress:BUSINESS.filter(s=>!scopes.has(s))}
 };
 return event;
};
