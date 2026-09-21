# Paso a paso para capturas EP1

Primero completar el deploy de OPERACION.md. Abrir frontend_url de Amplify.
Usar datos de demo sin contraseñas/tokens visibles. Las pruebas locales no reemplazan estas capturas reales.

## 1. Mostrar la cuenta y usuarios AWS

- Consola AWS: capturar ID de cuenta/región, sin credenciales.
- Cognito → User Pools → tu pool: nombre e ID.
- Users: usuarios de prueba. Groups: SOLICITANTE y APROBADOR y sus miembros.
- AWS no usa el tenant Azure: presentar cuenta AWS + User Pool Cognito como contexto de identidad.
- No mostrar QR MFA, contraseñas ni datos personales innecesarios.

## 2. Demostrar Authorization Code + PKCE

1. Abrir Angular Amplify. F12 → Network → Preserve log.
2. Pulsar Iniciar sesión.
3. Capturar GET API_URL/auth/login: 302, cookie de transacción y Location Cognito.
4. En la petición /oauth2/authorize mostrar response_type=code, code_challenge_method=S256, code_challenge y state.
5. Completar login/MFA.
6. Capturar GET API_URL/auth/callback con code/state: 303 hacia Angular; ocultar valores completos.
7. El verifier NO pasa por Angular: session-ms lo envía a Cognito mediante HTTPS servidor a servidor.
8. Para complementar, mostrar código y prueba del Lambda que compara challenge/verifier. No presentar una prueba simulada como captura de Cognito real.

## 3. Tokens y cookie

1. F12 → Application → Cookies → seleccionar el dominio execute-api de la API.
2. Mostrar __Secure-solicitudes-rt con HttpOnly, Secure, SameSite=None y Path=/auth. Ocultar Value.
3. La transacción __Secure-solicitudes-tx usa SameSite=Lax; se elimina después del callback.
4. Local Storage y Session Storage: no deben contener tokens.
5. Network → POST API_URL/auth/refresh: 200, credentials/cookie presente, respuesta accessToken y expiresIn. Ocultar Access Token completo.
6. No aparece refresh_token ni id_token en la respuesta JSON Angular.
7. Recargar F5: nuevo refresh 200 y GET API_URL/datos 200 sin login adicional.

Si refresh da 401 luego de un login correcto, revisar Cookies/Issues: el navegador podría bloquear la cookie de terceros.
SameSite=None no evita esa política. Usar un perfil/política que permita esa cookie para la demo si está autorizado; no quitar HttpOnly ni pasar el token a storage.
Esta edición gratuita no promete refresh en navegadores que bloquean cookies de terceros.

## 4. Obtener Access Tokens para Postman

- Iniciar sesión SOLICITANTE y copiar localmente el Bearer desde GET /datos en Network.
- Usar otro perfil de navegador para iniciar APROBADOR; copiar su Access Token por separado.
- No usar dos pestañas del mismo perfil para identidades distintas: comparten cookies.
- Los Access Tokens duran 15 minutos; renovar si caducan.
- No usar el ID Token ni el Refresh Token como Bearer.
- No pegar tokens en capturas, repositorio ni servicios externos.

## 5. Importar y ejecutar Postman

Import → postman/EP1.postman_collection.json.
Variables de colección:
- api_url: API_URL, sin /api y sin slash final.
- token_solicitante: Access Token solicitante.
- token_aprobador: Access Token aprobador.
- solicitud_id: la petición Crear lo completa.

Ejecutar en orden:

| Petición | Resultado |
|---|---|
| 01 GET /datos sin JWT | 401 |
| 02 GET /datos solicitante | 200 |
| 03 POST /solicitudes solicitante | 201 |
| 04 GET /solicitudes/{id} | 200 |
| 05 GET /solicitudes/pendientes solicitante | 403 |
| 06 POST /solicitudes/{id}/decision solicitante | 403 |
| 07 GET pendientes aprobador | 200 |
| 08 Decidir con aprobador distinto del propietario | 200 |

Capturar URL de Gateway, método, status y respuesta/test. Ocultar Authorization.
No cambiar la expectativa de creación a 200: este backend responde 201 correctamente.
Para errores de permisos usar un JWT válido; un JWT vencido da 401, no evidencia autorización por rol.
Si un usuario está en ambos grupos recibe ambos permisos: usar usuarios con un solo grupo para demostrar 403.

## 6. Demostrar que API Manager llega al backend

API Manager aquí es Amazon API Gateway.

1. API Gateway → Routes: mostrar JWT Authorizer y scopes por ruta.
2. Integrations: mostrar integración privada VPC Link → listener ALB.
3. VPC Link: estado AVAILABLE.
4. EC2 → Target Groups: target de backend Healthy.
5. ECS: tarea RUNNING y servicio estable.
6. Crear una solicitud con título único desde Postman.
7. Abrir Angular con el MISMO usuario solicitante y actualizar: aparece el mismo ID/título.
8. Capturar X-Gateway-Request-Id de respuesta y correlacionar con CloudWatch Gateway/backend cuando esté disponible.

La combinación integración + registro compartido + requestId demuestra el recorrido, no solo una respuesta falsa del frontend.

## 7. Demostrar Angular consume Gateway

1. Abrir frontend_url Amplify.
2. F12 → Network: filtrar execute-api.
3. Mostrar GET API_URL/datos y /solicitudes con 200.
4. Crear una solicitud desde Angular: POST API_URL/solicitudes con 201.
5. Mostrar que el host es API Gateway, no el ALB ni una URL local.
6. Comprobar el mismo registro desde Postman.

Capturar también OPTIONS /auth/refresh o la ruta de datos:
Access-Control-Allow-Origin coincide con Amplify; Allow-Credentials=true.
El preflight no es una llamada de negocio y no necesita JWT.

## 8. Demostrar Lambda grupos y backend sin JWT

- Cognito: trigger Pre Token Generation V2 enlazado al Lambda correcto.
- CloudWatch del Lambda: sub/grupos/scopes (sin tokens).
- Scope del Access Token: read/write para solicitante, read/approve para aprobador.
- Workflow: pruebas de grupos y comprobación del Lambda desplegado.
- Backend: mostrar ausencia de validador JWT y Resource Server; GatewayIdentityFilter/CurrentUserService reciben identidad verificada.
- node scripts/test-policy.mjs complementa la evidencia, pero es un análisis estático.

## 9. Sesión y CSRF adicionales

Usar API_URL/auth/refresh:
- POST sin cookie pero Origin correcto y X-CSRF: 1 → 401.
- POST con Origin incorrecto → 403.
- POST sin X-CSRF → 403.
- GET API_URL/auth/login directo → 302 a Cognito, permitido en esta edición sin CloudFront.
- Logout borra cookies locales e intenta revocar el Refresh Token.
