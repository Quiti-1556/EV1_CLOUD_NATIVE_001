# Seguridad y límites operativos

## Controles incluidos

| Capa | Control aplicado |
|---|---|
| Red | VPC por ambiente, ECS/ALB/RDS privados, RDS sin ruta a Internet. SG: Link→ALB:80, ALB→ECS:8080, ECS→RDS:5432; salida HTTPS ECS para ECR/Cognito/AWS. |
| Autenticación | Cognito Authorization Code + PKCE S256, state aleatorio y transacción de 10 minutos consumida una vez, MFA TOTP obligatorio. Invitaciones administradas, sin usuarios/contraseñas demo AWS. |
| Tokens | Access token en memoria, nunca localStorage/sessionStorage. Solo state/verifier temporal en sessionStorage. Firma, issuer, exp/nbf, token_use=access y client_id validados en backend; JWT y scope openid también en gateway. |
| Autorización | Grupos explícitos; cuenta sin grupo no tiene permisos API. Dueño y estado pendiente para editar/borrar; aprobador para resolver; autoaprobación prohibida; resumen personal para solicitante. |
| Persistencia | @Version detecta escrituras simultáneas sobre el mismo registro; conflictos devuelven 409. Flyway aplica el esquema antes de promover una versión. Usuario runtime con CRUD solo en solicitudes, sin DDL. |
| Secretos | RDS gestiona el secreto administrador. Secreto aplicación creado mediante generador AWS, sin valor en tfstate. Solo tarea efímera de migración recibe credenciales administrativas. Rol IAM de aplicación sin permisos AWS por defecto. |
| SQL / TLS | Jdbc PostgreSQL con sslmode=verify-full y CA RDS. Consulta parametrizada y escaping PostgreSQL al aprovisionar rol. Almacenamiento RDS cifrado, respaldos 7 días DEV/QA y 14 PROD. |
| Frontend | Cero CDN, sin eval/inline scripts, contenido escapado, CSP restrictiva generada con orígenes reales, frame-ancestors por cabecera, HSTS, nosniff, no-referrer y permisos de cámara/micrófono bloqueados. |
| Contenedor | Usuario no root, filesystem raíz readonly, capabilities eliminadas en ECS, imagen distroless, secretos fuera de imagen, temporal /tmp montado. |
| CI/CD | ECR inmutable, digest en tareas, escaneo Trivy antes de publicar, pruebas, rollback ECS y verificación de revisión. Estado remoto cifrado, versionado y bloqueado. OIDC por repo/Environment, alternativa de credenciales temporales para Lab. |

El JWT identifica al dueño con `sub`, un identificador estable de Cognito. Si migras registros reales de una instalación anterior que guardaba `username`, debes convertir `solicitante_id` y `aprobador_id` a sus `sub` correspondientes antes del corte. El paquete crea instalaciones nuevas; no modifica una base remota existente.

## Límites que debes conocer

- **No es una certificación ni una auditoría de producción.** No se ejecutó pentest contra un despliegue real. Las pruebas de infraestructura reales dependen de tu cuenta y las verificaciones detalladas están en VALIDACION.md.
- Las URLs públicas usan HTTPS y SQL valida el certificado RDS. **VPC Link→ALB→ECS usa HTTP dentro de las subredes privadas.** Si tu política exige cifrado en todo salto, se necesita dominio/certificado privado y configuración TLS adicional. No se afirma cifrado extremo a extremo de todos los saltos.
- Los tokens en memoria reducen persistencia pero no eliminan el riesgo de XSS. Al recargar se pierde la sesión del frontend; Cognito puede reutilizar su sesión al pulsar Iniciar sesión. El logout no invalida instantáneamente un access token robado: verificadores JWT sin introspección pueden aceptarlo hasta su expiración (15 minutos).
- No existe WAF adjunto. El gateway HTTP aplica límites de tasa, que no equivalen a protección completa contra abuso. Para WAF en la entrada API se debe diseñar REST API o una distribución CloudFront con origen protegido; no basta con añadir un Web ACL a un HTTP API.
- Las listas actuales conservan el contrato EV1 y se cargan completas; la paginación es visual. Para volúmenes grandes, añadir paginación real en SQL/API antes de crecer. No se anuncian cifras de rendimiento que no se midieron.
- @Version protege actualizaciones simultáneas dentro de transacciones. No se incluye un ETag/version obligatoria enviada por el cliente para detectar formularios abiertos mucho tiempo ni claves de idempotencia para crear solicitudes. Ante timeout de una escritura, revisar la lista antes de reintentar.
- Se conserva el contrato DELETE de la aplicación original. No hay historial inmutable completo de ediciones/borrados ni auditoría regulatoria WORM. Se registran autor y fecha de creación/decisión y logs de acceso sin bearer tokens; ampliarlo según retención requerida.
- El rol OIDC de **infraestructura** tiene permisos amplios sobre los servicios que aprovisiona; no es el rol runtime. En una organización con cuentas compartidas, aplicar permission boundaries/SCP y cuentas separadas por ambiente, reducir permisos según planes reales. Los roles tienen acceso a su prefijo de estado; los recursos AWS de servicios no están todos limitados por tags.
- Quien pueda modificar el workflow protegido y desplegar tiene poder para cambiar la aplicación e infraestructura. Configura revisión de PR, checks requeridos y protección de Environments. Los escaneos en ramas de PR no deben recibir secrets de producción.
- Las acciones e imágenes base usan versiones de release mantenibles, no todos sus SHA/digests. Para supply chain estricta, fijar cada acción a commit verificado y cada imagen base a digest verificado, con actualizaciones periódicas. Dependabot está configurado.
- RDS rota su contraseña maestra administrada. Las tareas de migración nuevas obtienen el valor vigente; la app usa un secreto separado y no depende de esa rotación. La contraseña de aplicación **no tiene rotación automática**. Su rotación debe coordinar secreto, ALTER ROLE y reciclado de tareas; no cambies solo el secreto.
- El código Flyway mantiene compatibilidad hacia atrás durante un despliegue. Una migración destructiva no se deshace automáticamente con rollback del contenedor.
- La CA de RDS se descarga desde HTTPS oficial al construir la imagen. Al renovar certificados, reconstruye y despliega la imagen. Verifica permisos y cifrado KMS adicional si añades claves administradas por tu organización.

## Pruebas de autorización mínimas antes de datos reales

Usa dos solicitantes diferentes y un aprobador. Comprueba: petición sin JWT→401; ID token→401; access token de otro client→401; cuenta sin grupos→403; lectura/edición/borrado ajeno→403; solicitante decidiendo→403; cuenta con ambos roles autoaprobando→403; segunda decisión→409; estado resuelto no editable. Prueba caracteres HTML en título y comentario: deben mostrarse como texto.

Verifica tanto `/solicitudes` como su alias `/productos`. La UI oculta acciones según rol, pero la autoridad definitiva es el backend.
