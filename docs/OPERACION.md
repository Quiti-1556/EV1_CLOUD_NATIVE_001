# Operación

## Flujo de publicación

1. Validar configuración y crear/aplicar plan Terraform con lock S3.
2. Terraform crea ECS con cero tareas; registra plantilla, no intenta ejecutar `:bootstrap`.
3. Construir imagen y ejecutar pruebas; subir etiqueta única a ECR; resolver digest.
4. Leer desde SSM las revisiones exactas de plantilla administradas por Terraform.
5. Crear una contraseña aleatoria en el secreto aplicación si no tiene versión AWSCURRENT.
6. Registrar/ejecutar tarea de migración privada con la nueva imagen. Flyway migra y aprovisiona el rol SQL de aplicación. Exigir exitCode 0.
7. Registrar tarea runtime sustituyendo solo imagen por digest; actualizar servicio al task_count configurado.
8. Esperar estabilidad y verificar ARN de revisión, tareas saludables y rollout COMPLETED. Un rollback a versión anterior no se reporta como éxito.
9. Generar configuración pública del frontend, probar, compilar, subir ZIP y esperar Amplify SUCCEED.
10. Comprobar página accesible y rechazo de rutas sin token.

No se modifican IPs de integraciones. Terraform mantiene red, roles, variables y plantillas; scripts mantienen la revisión e imagen activa y número de tareas. Después de modificar infraestructura, ejecuta `deploy.sh`, no únicamente `terraform apply`: de lo contrario los cambios de plantilla no llegan al servicio. La concurrencia compartida de workflows evita carreras; no ejecutes manualmente dos despliegues simultáneos del mismo ambiente.

## Comandos independientes

```bash
bash scripts/infra.sh dev plan
bash scripts/infra.sh dev apply
bash scripts/publicar-ecs.sh dev
bash scripts/deploy-frontend.sh dev
bash scripts/smoke.sh dev

# Logs
aws logs tail /ecs/solicitud-dev --follow --region us-east-1
# Eventos ECS
aws ecs describe-services --cluster solicitud-dev --services solicitud-dev-backend --query 'services[0].events[:10]'
# Revisiones registradas
aws ecs list-task-definitions --family-prefix solicitud-dev-backend --sort DESC
# Rollback: usar ARN existente devuelto por AWS
bash scripts/rollback-ecs.sh dev ARN_COMPLETO_DE_LA_REVISION
```

Para migraciones fallidas, busca logs del contenedor de la tarea efímera; no se promueve el runtime nuevo. Si Flyway aplicó cambios antes de fallar otra operación, corrige la causa y reintenta con una migración nueva cuando corresponda; no borres el historial para ocultar el fallo.

## Costos y disponibilidad

Se factura Amplify según uso, Fargate por tareas, ALB, NAT Gateway (hora y tráfico), RDS/almacenamiento/backups, Secrets Manager, API Gateway, ECR y CloudWatch. PROD tiene dos NAT y RDS Multi-AZ; es más resistente y más costoso. No hay presupuestos numéricos ni supuestos de gratuidad. Configura AWS Budgets con límites de tu cuenta antes de mantener los ambientes encendidos.

DEV/QA usan un NAT; si falla su zona puede afectar salida de tareas en ambas zonas. PROD usa un NAT por zona y dos tareas. No se incluyen autoscaling, despliegue multirregión ni recuperación automática entre regiones.

## Eliminación planificada

No se incluye un comando automático que borre todos los recursos. RDS conserva snapshot final, ECR exige vaciar imágenes explícitamente y los secretos mantienen recuperación de siete días. PROD bloquea borrado de DB/Cognito/ALB y el bucket bootstrap tiene prevent_destroy.

Para retirar un ambiente, revisa/exporta lo que necesites, prepara respaldo y revisa un plan de destroy con la región y estado correctos. Si ya existe el identificador de snapshot `<proyecto>-<ambiente>-final`, elige un nuevo identificador antes del siguiente retiro. Eliminar/provisionar de inmediato el mismo nombre de secreto puede fallar durante su ventana de recuperación; restaura el secreto o usa un nombre nuevo y reconcilia el estado. No borres locks S3 de un despliegue activo.

## Problemas frecuentes

| Síntoma | Comprobación |
|---|---|
| OIDC no puede asumir rol | Repo/Environment exactos, audiencia sts.amazonaws.com, variable AWS_ROLE_ARN y rama permitida en Environment. |
| Acceso denegado en Lab | Las tres credenciales no expiraron; roles ECS existentes tienen permisos; el laboratorio permite los servicios. |
| redirect_mismatch | La URL abierta coincide exactamente con output frontend_url y redirectUri termina en `/`. |
| 403 después del login | Usuario pertenece a SOLICITANTE o APROBADOR; al cambiar grupos iniciar sesión otra vez. |
| ECS no descarga imagen | NAT/rutas/salida 443, rol ejecución y ECR; arquitectura linux/amd64. |
| Migración no puede leer secreto | Permisos de ejecución a ambos secretos; AWSCURRENT aplicación creada. |
| Runtime SQL falla | Migración exitosa, grants de solicitudes_app, certificado CA y hostname RDS, contraseña sincronizada. |
| Backend hace rollback | Revisar CloudWatch y salud del target; esperar no basta, la revisión solicitada debe quedar activa. |
| Front no inicia | config.json existe en assets; configuración AWS HTTPS, CSP con orígenes exactos; no publicar config.local.json. |
| VPC Link recién creado responde lento | Esperar disponibilidad; puede tardar varios minutos, también al reactivarse tras inactividad prolongada. |
| Scan bloquea deploy | Revisar CVE de severidad HIGH/CRITICAL y actualizar dependencia/imagen; no ignorarlo sin evaluación. |

## Verificaciones adicionales de datos

El perfil runtime AWS desactiva Flyway y valida el esquema. Si se agregan nuevas tablas, añade permisos puntuales del rol runtime en DatabaseBootstrap y pruebas correspondientes; no concedas CREATE o privilegios administrativos al runtime. Antes de cambios incompatibles, define estrategia expand/contract para mantener la versión antigua operativa durante rolling deployment.
