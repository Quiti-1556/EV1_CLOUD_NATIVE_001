# Seguridad y responsabilidades

## Identidad

Cognito valida credenciales y MFA.
Pre Token Generation V2 recibe grupos resueltos por Cognito; no consulta el directorio ni valida un JWT ya emitido.
Agrega scopes permitidos y suprime todos los scopes de solicitudes no autorizados.
Registra sub, grupos y scopes para evidencia, nunca tokens ni contraseñas.
Cognito firma el token después de aplicar la respuesta del trigger.

API Gateway HTTP API valida firma, issuer, audience/client_id y fechas del JWT; exige scopes por ruta.
El ID Token no se usa como Bearer de datos.
Las rutas de sesión no usan autorizador JWT: necesitan permitir login y refresh cuando no hay Access Token válido.
El código de autorización o Refresh Token se valida en el endpoint HTTPS de Cognito.

## Backend

Java no revalida el JWT y no usa Authorization para construir la identidad.
Gateway sobrescribe X-Verified-User, X-Verified-Name y X-Verified-Scopes desde los claims ya verificados.
X-Gateway-Request-Id permite correlacionar la llamada con el backend.
El backend exige identidad Gateway, aplica reglas de negocio y no expone acceso directo.
Grupos de seguridad: VPC Link → ALB interno → ECS → RDS. Mantener esta separación.

## Sesión HTTP

session-ms es una Lambda separada del trigger, accesible por API Gateway.
Canjea Authorization Code con verifier PKCE S256 y valida state contra una cookie de transacción cifrada.
El callback fijo proviene de SESSION_API_ORIGIN, no del Host proporcionado por el cliente.
Refresh Token cifrado con AES-256-GCM y clave aleatoria en Secrets Manager.
Cookie host-only, Path=/auth, HttpOnly, Secure y SameSite=None.
Cookie PKCE de transacción SameSite=Lax para el retorno GET desde Cognito.
Rotación Cognito con período de gracia 10 segundos; no se amplía la fecha límite inicial de sesión.
La respuesta de refresh contiene únicamente Access Token y expiresIn.

POST /auth/refresh y /auth/logout exigen Origin exacto del frontend y X-CSRF: 1.
CORS de Gateway permite solo los orígenes configurados, métodos y headers explícitos, con credenciales.
El preflight OPTIONS de Gateway no exige JWT; no abre rutas de negocio sin autorización.
No se impone Sec-Fetch-Site=same-origin porque Amplify y Gateway son cross-site en esta edición.
No hay clave de origen CloudFront ni distribución propia.

## Limitaciones

Las URLs gratuitas son cross-site: SameSite=Lax no funcionaría para refresh por XHR.
SameSite=None no obliga al navegador a aceptar cookies de terceros.
La sesión requiere una política del navegador que permita esa cookie; probarlo explícitamente.
El ZIP no configura dominios propios ni promete compatibilidad universal.
Para producción, configurar HTTPS con frontend/API bajo un mismo sitio y revisar SameSite/CORS.
No cambiar Refresh Token a localStorage, sessionStorage ni document.cookie.

Access Token en memoria reduce persistencia, pero un XSS puede usarlo o llamar a la API.
La CSP limita scripts a self y conexiones HTTPS a API Gateway de la región configurada (el interceptor envía Bearer solo a la URL exacta del ambiente); Angular requiere estilos inline.
Evitar HTML no confiable, bypassSecurityTrustHtml y exposición de datos sensibles.

## Configuración y secretos

PUBLIC_ORIGIN: URL Amplify.
SESSION_API_ORIGIN: URL API Gateway.
COGNITO_DOMAIN y COGNITO_CLIENT_ID: datos públicos.
COOKIE_SECRET_ARN: referencia privada; clave leída en runtime por Lambda.
config.json y workflows no contienen tokens reales.
Proteger estado remoto S3: contiene la clave de cifrado generada.
Credenciales Learner Lab temporales solo como GitHub Secrets; no incluirlas en commits/capturas.

Referencias:
- https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html
- https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html
- https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-cors.html
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie
