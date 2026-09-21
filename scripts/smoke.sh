#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need curl
load_outputs "${1:?Indica ambiente}"
curl --retry 5 --retry-all-errors --retry-delay 3 --fail --silent --show-error "$REDIRECT_URI" -o /dev/null
for path in /datos /solicitudes /solicitudes/pendientes /productos; do
  code="$(curl --silent --show-error -o /dev/null -w '%{http_code}' "$API_URL$path")"
  [[ "$code" == 401 ]] || { echo "$path: esperaba 401 sin JWT; recibió $code"; exit 1; }
done
origin="${REDIRECT_URI%/}"
code="$(curl --silent --show-error -o /dev/null -w '%{http_code}' -X POST "$API_URL/auth/refresh" -H "Origin: $origin" -H 'X-CSRF: 1')"
[[ "$code" == 401 ]] || { echo "Refresh sin cookie: esperaba 401; recibió $code"; exit 1; }
code="$(curl --silent --show-error -o /dev/null -w '%{http_code}' -X POST "$API_URL/auth/refresh" -H 'Origin: https://evil.example' -H 'X-CSRF: 1')"
[[ "$code" == 403 ]] || { echo "CSRF: esperaba 403; recibió $code"; exit 1; }
login="$(curl --silent --show-error --dump-header - --output /dev/null "$API_URL/auth/login")"
for attribute in HttpOnly Secure SameSite=Lax code_challenge_method=S256; do
  grep -Fqi "$attribute" <<< "$login" || { echo "Login: falta $attribute"; exit 1; }
done
if [[ -n "${ACCESS_TOKEN:-}" ]]; then
  curl --fail --silent --show-error -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL/datos" >/dev/null
  curl --fail --silent --show-error -H "Authorization: Bearer $ACCESS_TOKEN" "$FRONTEND_API_URL/datos" >/dev/null
fi
preflight="$(curl --silent --show-error --dump-header - --output /dev/null -X OPTIONS "$API_URL/auth/refresh" -H "Origin: $origin" -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: x-csrf,content-type')"
grep -Fqi "access-control-allow-origin: $origin" <<< "$preflight" || { echo 'CORS: falta origen frontend'; exit 1; }
grep -Fqi 'access-control-allow-credentials: true' <<< "$preflight" || { echo 'CORS: faltan credenciales'; exit 1; }
echo 'Smoke OK: Angular accesible, Gateway protege rutas, sesión PKCE y CSRF.'
