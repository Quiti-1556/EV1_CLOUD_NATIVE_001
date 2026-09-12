const SCOPES_BY_GROUP = Object.freeze({
  SOLICITANTE: ['solicitudes/read', 'solicitudes/write'],
  APROBADOR: ['solicitudes/read', 'solicitudes/approve'],
});

export const handler = async (event) => {
  const groups = event.request?.groupConfiguration?.groupsToOverride ?? [];
  const scopes = [...new Set(
    groups.flatMap((group) => SCOPES_BY_GROUP[String(group).toUpperCase()] ?? []),
  )];

  console.log(JSON.stringify({
    user: event.request?.userAttributes?.email ?? event.userName,
    groups,
    scopes,
  }));

  event.response = {
    ...(event.response ?? {}),
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: {
        scopesToAdd: scopes,
      },
    },
  };

  return event;
};
