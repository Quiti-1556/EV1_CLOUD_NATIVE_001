# Validación de esta edición sin CloudFront propio

Fecha: 2026-09-13.

## Ejecutado localmente

| Componente | Resultado |
|---|---|
| Backend Java 21, Maven verify | 11 pruebas, 0 fallos; JAR construido |
| Angular | 9 pruebas, 0 fallos; build de producción correcto |
| Pre Token Generation | 6 pruebas, 0 fallos |
| Lambda de sesión | 8 pruebas, 0 fallos; bundle Node 22 correcto |
| Política estática | 36 comprobaciones correctas |
| Workflows | Actionlint sin errores |
| Bash | bash -n y ShellCheck severidad error sin errores |
| Terraform | fmt -check correcto |
| ZIP | Integridad y archivos fuente verificados antes de entregar |

Total: 34 pruebas automatizadas de componentes, más 36 comprobaciones estáticas.
Angular incluye prueba explícita para evitar renovación recursiva en las rutas de sesión.
Lambda de sesión prueba callback en API Gateway, PKCE, state, rotación, CSRF y cookies.
Grupos desconocidos/especiales no reciben permisos; se suprimen scopes no autorizados.

## No verificado en tu cuenta

No se ejecutaron terraform apply, Docker, RDS, ALB, ECS, Cognito real, Amplify real ni login E2E de navegador.
Terraform validate no se completó en este entorno: el proveedor intenta usar sockets Unix, bloqueados por la plataforma. Ejecutarlo en GitHub Actions.
No se modificaron permisos del laboratorio ni se usaron credenciales de tu cuenta.

El pipeline de GitHub ejecuta validate/plan/apply y smoke; aun así hay que verificar login real, permisos por ruta y política del navegador.
Las URLs gratuitas requieren cookies de terceros permitidas para renovar sesión.
No hay distribución CloudFront propia; Amplify mantiene su infraestructura de hosting administrada.

## Condiciones necesarias para deploy

- Credenciales AWS vigentes y permisos autorizados para recursos usados.
- Bucket y clave de estado remoto correctos; ARN LabRole de cuenta actual.
- Backend privado, SG y targets saludables.
- Cognito Essentials/V2 habilitado y usuarios/grupos/MFA configurados.
- Navegador que permita la cookie cross-site en la edición gratuita.

No afirmar 100% funcional en AWS sin esas verificaciones; los resultados anteriores son locales.
