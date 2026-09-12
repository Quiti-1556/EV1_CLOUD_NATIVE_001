# Validación de la entrega

Fecha: 2026-09-10. Validación efectuada sobre el código incluido en este ZIP.

| Comprobación | Resultado real |
|---|---|
| Maven `verify`, Java 21, Spring Boot 4.1.1 | **BUILD SUCCESS**; JAR generado correctamente. |
| Pruebas backend | **7 pasaron**, 0 fallos, 0 errores, 0 omitidas. |
| Pruebas frontend, Node 24.19.0 | **3 pasaron**, 0 fallos. |
| Build frontend local | Correcto. |
| Generación de config AWS y build con orígenes HTTPS de prueba | Correcto; authEnabled=true, ruta /solicitudes y CSP sin marcadores pendientes. Se restauró config local antes de empaquetar. |
| IDs del DOM y referencias locales de assets | Correctos; sin IDs duplicados ni referencias literales faltantes. |
| Sintaxis JavaScript y XML del POM | Correcta. |
| GitHub workflows, actionlint 1.7.7 | Correctos, sin errores reportados. |
| Scripts Bash y ShellCheck 0.10.0, severidad error | Correctos, sin errores reportados. |
| Terraform 1.11.4 `fmt -check -recursive` | Correcto: sintaxis HCL y formato. |
| Proveedor AWS 5.100.0 | Descargado; SHA256 comparado con sumas oficiales. Lockfiles incluidos con checksums de plataformas publicadas. |
| Terraform `validate` con esquemas de proveedor | **No completado**: este entorno bloquea `listen unix /tmp/plugin…: socket: operation not permitted`. La validación con el proveedor debe ejecutarse en Ubuntu/Actions. |
| Terraform plan/apply en AWS | **No ejecutado**: no se conectó una cuenta AWS ni se aprovisionaron recursos. |
| Docker Compose, Docker build, Trivy y login Cognito en vivo | **No ejecutados aquí**. Docker/servicios de red no disponibles para estas comprobaciones; pasos incluidos en scripts/workflows. |
| PostgreSQL real, migración/GRANT, ECS, Amplify y restauración RDS | **Pendientes de integración en AWS o Docker local**. Las pruebas unitarias no sustituyen estas verificaciones. |
| QA visual en navegador, navegación con teclado y lectores de pantalla | **No ejecutada**. Se implementaron responsive, etiquetas, diálogos nativos, foco y reduced-motion; verificar con navegadores objetivo. |

## Qué cubren las pruebas backend

- Access token del cliente correcto; rechazo de ID token y de cliente distinto.
- Bloqueo de lectura y borrado de solicitudes ajenas.
- Bloqueo de autoaprobación incluso con ambos roles.
- Bloqueo de decisiones sin rol APROBADOR.
- Rechazo de segunda decisión.
- Resumen personal sin consultar contadores globales del solicitante.
- Decisión de aprobador válido y registro del autor y fecha.

Se corrigió el error de compilación original del convertidor JWT: `Set<SimpleGrantedAuthority>` no era compatible con el contrato `Collection<GrantedAuthority>` en la versión de Spring Security utilizada. Además se ajustaron los starters a los módulos de Spring Boot 4.1.1 y se agregó el starter Flyway.

## Qué cubren las pruebas frontend

- PKCE S256 contra el vector de ejemplo de RFC 7636.
- Rechazo de state ausente/distinto y de transacciones OAuth vencidas.
- Bloqueo de modo demo público, HTTP fuera de loopback, credenciales en URL y callback de otro origen.

## Repetir las comprobaciones

Desde la raíz del proyecto, con las herramientas instaladas:

```bash
(cd backend && mvn --batch-mode --no-transfer-progress verify)
(cd frontend && npm ci --ignore-scripts && npm test && npm run build)
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
terraform -chdir=terraform/bootstrap init -input=false
terraform -chdir=terraform/bootstrap validate
for script in scripts/*.sh sincronizar-github.sh; do bash -n "$script"; done
shellcheck -S error scripts/*.sh sincronizar-github.sh
actionlint .github/workflows/*.yml
```

No se declara un despliegue productivo validado. `scripts/deploy.sh` falla si las validaciones de infraestructura, migraciones o publicación no se completan; los workflows agregan el escaneo de vulnerabilidades previo a publicar. Antes de usar información real completa la lista autenticada de SEGURIDAD.md.
