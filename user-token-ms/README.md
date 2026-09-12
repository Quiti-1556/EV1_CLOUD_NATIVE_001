# user-token-ms

Lambda de Cognito **Pre Token Generation V2**. Convierte la pertenencia a los
grupos del User Pool en scopes del access token:

- `SOLICITANTE` → `solicitudes/read`, `solicitudes/write`
- `APROBADOR` → `solicitudes/read`, `solicitudes/approve`

No recibe contraseñas ni reemplaza el login PKCE. Cognito lo invoca después de
autenticar al usuario y antes de firmar un access token nuevo.

```bash
node --test
```
