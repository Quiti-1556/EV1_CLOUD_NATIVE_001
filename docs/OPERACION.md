# Paso a paso: GitHub y despliegue completo sin CloudFront propio

## 1. Resguardar y reemplazar el proyecto

Usar el repositorio y bucket de estado EXISTENTES. No borrar tfstate, RDS ni usuarios.
Esta edición conserva modelos, migraciones y nombres de infraestructura del entregable original.

1. Respaldar tu copia o trabajar en una rama nueva.
2. Descomprimir el ZIP.
3. Copiar el CONTENIDO de DSY1107-EP1-Acevedo-Sin-CloudFront a la raíz del repositorio.
4. Incluir .github y .gitignore. No subir una carpeta anidada que deje .github fuera de la raíz.
5. No reemplazar el directorio .git de tu repositorio.

Git no elimina archivos viejos por copiar un ZIP. Retirar los siguientes si todavía existen:

```bash
git status --short
git rm --ignore-unmatch backend/src/main/java/cl/solicitudes/security/CognitoAccessTokenValidator.java backend/src/test/java/cl/solicitudes/security/CognitoAccessTokenValidatorTest.java
git rm --ignore-unmatch frontend/build.mjs frontend/src/js/app.js frontend/src/js/auth.js frontend/tests/auth.test.mjs frontend/src/css/styles.css backend-build.log
```

Si git informa modificaciones locales en esos archivos, revisar/resguardar antes; no usar -f.
terraform/cloudfront.tf debe contener SOLO comentarios de retiro; se incluye para reemplazar el archivo viejo al copiar.
No conservar recursos CloudFront en otro .tf.

## 2. Revisar cuenta y roles

En terraform/environments/dev.tfvars, qa.tfvars y prod.tfvars revisar los tres ARN LabRole.
La cuenta incluida es 674334406872, correspondiente al entregable; cambiarla si el laboratorio rotó la cuenta.
Conservar roles actuales si corresponden: no crear roles arbitrarios ni modificar permisos del laboratorio.
Lambda sesión necesita un rol autorizado para Lambda, Secrets Manager y CloudWatch Logs.
Este código no pide cloudfront:ListCachePolicies ni cloudfront:ListOriginRequestPolicies.
Amplify usa hosting administrado: no se gestiona una distribución propia.

Si YA se aplicó la edición CloudFront y esos recursos están en el estado, Terraform puede intentar refrescarlos/eliminarlos al retirarlos del código.
Una denegación de permisos debe resolverla un administrador con autoridad para retirar esos recursos.
No hacer terraform state rm para ocultar recursos ni recrear el estado.
Si el error ocurrió durante plan antes de crear CloudFront, esta edición no crea ni consulta sus políticas.

## 3. Configurar GitHub

Settings → Environments → crear/revisar DEV. Después QA y PROD según corresponda.

| Tipo | Nombre | Valor |
|---|---|---|
| Variable | AWS_REGION | us-east-1 o tu región actual |
| Variable | TF_STATE_BUCKET | Bucket existente de tu estado, por ejemplo amzn-s3-aronbuckett si sigue siendo el correcto |
| Variable opcional | AWS_ROLE_ARN | Solo si usas OIDC autorizado |
| Secret | AWS_ACCESS_KEY_ID | Credencial vigente Learner Lab |
| Secret | AWS_SECRET_ACCESS_KEY | Credencial vigente Learner Lab |
| Secret | AWS_SESSION_TOKEN | Token de sesión vigente Learner Lab |

Si usas credenciales temporales, dejar AWS_ROLE_ARN vacío para no seleccionar un rol OIDC antiguo.
Los secretos del laboratorio caducan; renovar los tres juntos cuando corresponda.
No introducir Access Token o Refresh Token de usuarios en YAML, config.json ni GitHub.
API_URL, client ID, callback y configuración Angular se leen automáticamente desde outputs Terraform.
Conservar la misma clave remota de estado: solicitud/dev/terraform.tfstate (qa/prod equivalentes).
Si tu repositorio original cambió esa clave, verificar scripts/terraform-init.sh antes del deploy.

## 4. Subir cambios

Desde la raíz de tu repositorio:

```bash
git status --short
node scripts/test-policy.mjs
git add .
git diff --cached --stat
git commit -m "Angular Cognito Gateway y sesión HttpOnly sin CloudFront propio"
git push origin TU_RAMA
```

Revisar antes que no se agreguen secretos, tfstate, node_modules ni builds.
Si trabajaste en una rama nueva, abrir PR hacia main y revisar los workflows.
El deploy automático ocurre por push/merge a main; también puede ejecutarse manualmente.
No usar push --force.
Si falló un workflow de un commit viejo, ejecutar sobre el commit nuevo: Re-run no cambia su código.

## 5. Ejecutar deploy completo

GitHub → Actions → Deploy completo → Run workflow → branch main → environment DEV.

El pipeline:
1. Verifica política: backend sin JWT, Gateway con scopes y CORS, cookies/PKCE.
2. Prueba Angular y construye con Angular CLI.
3. Prueba Lambda de grupos.
4. Prueba y empaqueta Lambda de sesión Node 22.
5. Maven verify con Java 21.
6. Terraform init, validate, plan y apply usando estado remoto.
7. Ejecuta migración Flyway y despliega imagen ECS; espera servicio saludable.
8. Genera configuración Angular pública desde Terraform, compila y publica en Amplify.
9. Prueba frontend, 401 sin JWT, CSRF, inicio PKCE y preflight CORS.
10. Verifica vínculo Cognito V2 y scopes del Lambda desplegado mediante invocación controlada.

Ese smoke no sustituye el login real ni valida compatibilidad de cookies en tu navegador.
Ante AccessDenied, detenerse y solicitar al administrador permisos para el recurso concreto.
No borrar RDS ni usar terraform destroy como solución.
Deploy Frontend aislado no crea sesión/CORS nuevos: primero Deploy completo.

## 6. Abrir Angular

Los outputs aparecen en el resumen del deploy.
También puedes consultarlos localmente con credenciales y Terraform:

```bash
export AWS_REGION=us-east-1
export TF_STATE_BUCKET=TU_BUCKET_EXISTENTE
bash scripts/terraform-init.sh dev
export TF_DATA_DIR="$PWD/terraform/.terraform-dev"
terraform -chdir=terraform output -raw frontend_url
terraform -chdir=terraform output -json deployment
```

frontend_url: https://main.APP_ID.amplifyapp.com.
API_URL y FRONTEND_API_URL: https://API_ID.execute-api.REGION.amazonaws.com, SIN /api.
Callback Cognito: API_URL/auth/callback.
El botón de login Angular abre API_URL/auth/login; la Lambda redirige a Cognito.
Cognito vuelve a la Lambda callback, que coloca la cookie y regresa a Angular.

## 7. Comprobar cookies del navegador

La edición usa URLs gratuitas de sitios distintos.
No podemos garantizar refresh si el navegador bloquea cookies de terceros.
Para la demo, usar un perfil normal de navegador que permita la cookie para este sitio, si tu política lo permite.
Revisar F12 → Network → POST API_URL/auth/refresh y el motivo de bloqueo en Cookies/Issues.
No desactivar HTTPS, HttpOnly, CSRF ni guardar el Refresh Token en JavaScript.
Si el login finaliza pero refresh da 401, comprobar primero la cookie y su bloqueo.
Para producción sin esta dependencia, configurar frontend/API con dominios HTTPS del mismo sitio; este ZIP no los crea.

## 8. Usuarios y evidencias

Conservar usuarios existentes en Cognito. Grupos: SOLICITANTE y APROBADOR.
Crear solo usuarios que falten y usar correos propios/controlados:

```bash
bash scripts/crear-usuario.sh dev TU_CORREO SOLICITANTE
bash scripts/crear-usuario.sh dev OTRO_CORREO APROBADOR
```

Completar contraseña temporal y MFA TOTP. No mostrar contraseña, QR ni tokens en capturas.
Seguir EVIDENCIAS.md y completar variables de la colección Postman.

## 9. Desarrollo local

```bash
bash scripts/local.sh
```

Requiere Docker. http://localhost:4200 usa identidades demo; no emula Cognito/cookies seguras.
No publicar config.local.json en Amplify; el script de publicación lo rechaza.
En AWS APP_IDENTITY_MODE=gateway es obligatorio.

Pruebas independientes, con Node 24 y Java 21:

```bash
node scripts/test-policy.mjs
node --test user-token-ms/index.test.mjs
(cd session-ms && npm ci --ignore-scripts && npm test && npm run build)
(cd frontend && npm ci --ignore-scripts && npm test && npm run build)
(cd backend && mvn --batch-mode --no-transfer-progress verify)
```
