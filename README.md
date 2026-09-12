# Solicitud — aplicación y despliegue AWS

Proyecto basado en el flujo de **EV1**, adaptado a **solicitudes-seguro**. Conserva Java/Spring Boot, PostgreSQL, contenedores, API Gateway, Cognito, Amplify, scripts Bash y GitHub Actions. El frontend original era JavaScript estático (no Angular); se mantiene su stack y se renueva por completo su interfaz.

**Este paquete prepara el despliegue; no significa que ya exista una instalación en tu cuenta AWS.** Antes de usar datos reales, completa las pruebas autenticadas y revisa las limitaciones de `docs/SEGURIDAD.md`. Consulta `docs/VALIDACION.md` para distinguir comprobaciones ejecutadas de comprobaciones que requieren AWS.

## Qué incluye

- Bandeja responsive en español, búsqueda, filtros, paginación visual, detalle de solicitudes, estados vacíos y errores, diálogos accesibles y gestión por rol.
- Crear, consultar, actualizar y eliminar solicitudes pendientes propias; aprobar/rechazar con comentario y autor de la decisión. Prohibición de autoaprobación, incluso con ambos roles.
- Terraform completo con DEV, QA y PROD aislados por estado y VPC. PROD usa dos tareas, dos NAT y RDS Multi-AZ. DEV y QA usan una tarea y un NAT.
- API Gateway JWT → VPC Link → ALB interno → ECS Fargate privado → RDS privado. La IP del contenedor puede cambiar sin modificar el gateway.
- Cognito: login Authorization Code + PKCE, TOTP obligatorio, usuarios invitados y grupos SOLICITANTE / APROBADOR.
- Credenciales SQL separadas: una tarea efímera aplica Flyway y permisos; la aplicación usa un usuario CRUD sin permisos DDL. Contraseñas en Secrets Manager, sin valores en Terraform ni GitHub.
- GitHub Actions y Bash usan los mismos scripts. ECR con etiquetas inmutables; la tarea ejecuta un digest exacto. Circuit breaker y comprobación de la revisión desplegada.

## 1. Extraer y probar localmente (Ubuntu / WSL)

```bash
unzip solicitud.zip
cd solicitud
chmod +x scripts/*.sh sincronizar-github.sh
bash scripts/local.sh
docker compose logs -f backend
```

Abre **http://localhost:4200**. Requiere Docker Engine con Compose v2. La primera compilación necesita Internet para descargar imágenes, Maven y la CA oficial de RDS.

El modo local permite cambiar de identidad. Crea una solicitud como `solicitante.demo`, cambia a `aprobador.demo` con rol APROBADOR y resuélvela. No utilices la misma identidad para autoaprobar. Este modo se publica solo en `127.0.0.1`, y el frontend bloquea identidades demo en un dominio público.

```bash
# Detener, conservando la BD
docker compose down
# Ver estado
docker compose ps
```

No uses `down -v` si quieres conservar los datos. `scripts/local.sh` restaura la configuración local antes de compilar; `scripts/config-frontend.sh` genera la de AWS antes de publicar.

## 2. Preparar herramientas y credenciales AWS

Necesitas AWS CLI v2, Terraform **1.11.4** (o versión 1.x >=1.11), Node 24, Docker, Python 3, jq, zip y curl. Java 21 y Maven 3.9 son necesarios para ejecutar pruebas fuera de Docker. Para sincronizar GitHub necesitas `gh` autenticado.

```bash
sudo apt-get update
sudo apt-get install -y jq zip unzip curl python3
# Instala AWS CLI v2, Terraform, Node y Docker desde sus instaladores oficiales.
aws configure sso
aws sso login --profile mi-cuenta
export AWS_PROFILE=mi-cuenta
export AWS_REGION=us-east-1
bash scripts/preflight.sh
```

En Learner Lab, usa las tres credenciales temporales de la sesión en vez de SSO. Es necesario que la cuenta autorice Amplify, Cognito, VPC Link, ALB, Fargate, RDS, NAT, SSM y Secrets Manager. El laboratorio puede prohibir algunos servicios o IAM; no se presume que todos estén disponibles.

## 3. Crear el estado remoto una sola vez

Escoge un nombre S3 globalmente único. No incluyas contraseñas en archivos `.tfvars`. Este proyecto usa un estado nuevo: no reutilices el estado de EV1.

```bash
export TF_STATE_BUCKET="solicitud-tfstate-$(aws sts get-caller-identity --query Account --output text)-us-east-1"
# Cuenta normal: crear también los roles OIDC para tu repositorio.
export GITHUB_REPOSITORY="TU_USUARIO/solicitud"
# Si el proveedor OIDC de GitHub YA existe en IAM, reutilízalo:
# export GITHUB_OIDC_PROVIDER_ARN="arn:aws:iam::TU_CUENTA:oidc-provider/token.actions.githubusercontent.com"
bash scripts/bootstrap-state.sh
```

Este script presenta el plan y aplica el archivo de plan. Crea el bucket con cifrado, versionado, bloqueo de acceso público y exigencia HTTPS. Si se indicó `GITHUB_REPOSITORY`, crea el proveedor OIDC (o reutiliza el indicado) y tres roles. **No ejecuta `terraform destroy`.**

Conserva una copia segura de `terraform/bootstrap/terraform.tfstate`: el estado de bootstrap es local para evitar depender del bucket que todavía se está creando. No lo subas a Git. El estado principal va a S3:

| Ambiente | Estado remoto | Configuración |
|---|---|---|
| DEV | `solicitud/dev/terraform.tfstate` | `terraform/environments/dev.tfvars` |
| QA | `solicitud/qa/terraform.tfstate` | `terraform/environments/qa.tfvars` |
| PROD | `solicitud/prod/terraform.tfstate` | `terraform/environments/prod.tfvars` |

**Learner Lab:** deja `GITHUB_REPOSITORY` vacío (`unset GITHUB_REPOSITORY`) para no crear IAM en bootstrap. En el `.tfvars` del ambiente asigna ambos `existing_*_role_arn` a roles permitidos por tu laboratorio. LabRole debe poder leer ambos secretos, descargar imágenes ECR y escribir logs. Si no tiene esos permisos, el despliegue fallará y debe resolverlo quien administra el laboratorio.

## 4. Desplegar DEV completo desde Bash

Edita primero `terraform/environments/dev.tfvars` si necesitas cambiar el proyecto o la red. `AWS_REGION` selecciona la región efectiva tanto de scripts como de Terraform.

```bash
# Revisar sin crear recursos
bash scripts/infra.sh dev plan
# Crear infraestructura, migrar BD, publicar backend, publicar frontend y comprobar acceso
bash scripts/deploy.sh dev
```

El primer despliegue puede tardar decenas de minutos, principalmente por RDS y VPC Link. Genera recursos facturables: consulta `docs/OPERACION.md`. El proyecto no supone que el nivel gratuito cubra la arquitectura.

```bash
TF_DATA_DIR="$PWD/terraform/.terraform-dev" terraform -chdir=terraform output frontend_url
TF_DATA_DIR="$PWD/terraform/.terraform-dev" terraform -chdir=terraform output api_url
TF_DATA_DIR="$PWD/terraform/.terraform-dev" terraform -chdir=terraform output deployment
```

La configuración del frontend se genera automáticamente con los outputs; no tienes que copiar client IDs ni URLs al código. El usuario no elige el issuer ni el cliente Cognito desde la interfaz.

## 5. Invitar usuarios y probar el flujo

```bash
bash scripts/crear-usuario.sh dev solicitante@tu-dominio.cl SOLICITANTE
bash scripts/crear-usuario.sh dev aprobador@tu-dominio.cl APROBADOR
```

Usa correos reales que controles. Cognito envía una contraseña temporal, obliga a cambiarla y solicita configurar TOTP. Si la invitación falla, revisa límites de correo Cognito/SES y permisos de la cuenta. El script no almacena ni muestra contraseñas.

1. Abre el frontend, inicia sesión como solicitante y crea una solicitud.
2. Verifica detalle, edición y eliminación de una solicitud pendiente.
3. Cierra sesión. Abre como aprobador, entra en **Por aprobar** y resuelve con comentario.
4. Vuelve como solicitante: debe aparecer la respuesta y desaparecer la edición/eliminación.
5. Con una segunda cuenta solicitante, comprueba que no puedes leer ni modificar solicitudes ajenas; el backend debe devolver 403.
6. Ninguna ruta de datos debe responder correctamente sin token. `scripts/smoke.sh dev` verifica esa condición; con `ACCESS_TOKEN` también comprueba lectura autenticada.

Se conserva `/productos` como alias del backend para compatibilidad EV1, con las mismas autorizaciones. El frontend nuevo usa `/solicitudes`; `/datos` entrega el resumen.

## 6. Configurar GitHub Actions

Crea un repositorio y sube **el contenido de la carpeta `solicitud/`**, incluyendo `.github`. No subas el ZIP dentro del repositorio, `target`, `dist`, `.env`, `.runtime`, estados ni planes.

```bash
git init
git add .
git commit -m "Aplicación Solicitud y despliegue AWS"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/solicitud.git
git push -u origin main
```

En **Settings → Environments**, crea **DEV**, **QA** y **PROD**. Para los tres restringe las ramas de despliegue a `main`; en PROD configura revisores requeridos y deshabilita el bypass de administradores si tu plan GitHub lo permite. La confianza OIDC está restringida al repositorio y Environment, por lo que la restricción de rama es parte necesaria de la configuración.

Variables mínimas por Environment:

| Variable | Ejemplo / origen | Secreta |
|---|---|---|
| `AWS_REGION` | `us-east-1` | No |
| `TF_STATE_BUCKET` | El bucket creado en paso 3 | No |
| `AWS_ROLE_ARN` | Output `github_roles` del bootstrap, rol correspondiente al ambiente | No |

```bash
terraform -chdir=terraform/bootstrap output github_roles
# Ejemplo con gh, autenticado previamente:
gh variable set AWS_REGION --env DEV --body us-east-1 --repo TU_USUARIO/solicitud
gh variable set TF_STATE_BUCKET --env DEV --body "$TF_STATE_BUCKET" --repo TU_USUARIO/solicitud
gh variable set AWS_ROLE_ARN --env DEV --body arn:aws:iam::TU_CUENTA:role/github-solicitud-dev --repo TU_USUARIO/solicitud
# Tras desplegar, sincronizar también todos los outputs públicos:
bash sincronizar-github.sh dev TU_USUARIO/solicitud
```

`sincronizar-github.sh` no configura credenciales ni elimina reglas de protección existentes. Repite para QA/PROD con sus propios outputs. Para un primer despliegue íntegro desde Actions solo son necesarias las tres variables mínimas y que exista el bucket.

**Alternativa Learner Lab:** deja `AWS_ROLE_ARN` vacío y configura Secrets por Environment llamados `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`. Actualiza los tres al renovar la sesión. No se transfieren al navegador. Los roles existentes del `.tfvars` deben corresponder a la misma cuenta.

| Workflow | Activación | Resultado |
|---|---|---|
| `backend_compile.yml` | PR / push main / manual | Maven verify con pruebas |
| `frontend_compile.yml` | PR / push main / manual | Pruebas OAuth y build |
| `terraform_validate.yml` | PR / push main / manual | Sintaxis, validación Terraform y Bash |
| `security.yml` | PR / main / semanal / reutilizable | Trivy secretos, dependencias e imagen; bloquea HIGH/CRITICAL |
| `deploy.yml` | Push a main → DEV; manual → DEV/QA/PROD | Escaneo, pruebas, Terraform, migración, backend, frontend y smoke |
| `backend_deploy.yml` | Manual | Escaneo y publicación solo backend sobre infraestructura existente |
| `frontend_deploy.yml` | Manual | Escaneo y publicación solo frontend sobre infraestructura existente |

Todos los deploys de un Environment usan el mismo grupo de concurrencia. Un fallo del escáner impide publicar: actualiza la dependencia afectada y revisa su aviso. No se incluyen excepciones que silencien vulnerabilidades.

## 7. QA y PROD

```bash
bash scripts/deploy.sh qa
bash scripts/deploy.sh prod
```

O ejecuta **Deploy completo → Run workflow → QA / PROD** desde main. Cada ambiente tiene su propia BD, usuarios Cognito y datos; no se copian datos de DEV a PROD. PROD mantiene protección contra borrado de RDS, Cognito y ALB.

## Estructura

```text
backend/                  Spring Boot 4.1.1, Java 21, pruebas y Flyway
frontend/                 HTML/CSS/JS, login PKCE, pruebas y build estático
terraform/                Infraestructura principal
terraform/bootstrap/      Bucket de estado y OIDC opcional
terraform/environments/   dev.tfvars, qa.tfvars, prod.tfvars
scripts/                  Mismo recorrido para terminal y Actions
.github/workflows/        CI, seguridad y despliegues
.github/actions/aws-auth/ OIDC o credenciales temporales
docs/                     Seguridad, operación y validaciones
```

No se copia el microservicio `user-token-ms` de EV1: esta aplicación obtiene access tokens directamente de Cognito mediante PKCE y la API comprueba su firma. No se agrega un proxy de contraseñas.

Referencias utilizadas: [integraciones privadas de API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-private.html), [claims de access tokens Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-the-access-token.html), [estado S3 y bloqueo nativo de Terraform](https://developer.hashicorp.com/terraform/language/backend/s3).
