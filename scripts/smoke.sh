#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need curl
load_outputs "${1:?Indica ambiente}"
curl --retry 5 --retry-all-errors --retry-delay 3 --fail --silent --show-error "$REDIRECT_URI" -o /dev/null

FRONTEND_ORIGIN="${REDIRECT_URI%/}"
preflight() {
  local path="$1" method="$2" requested_headers="$3" response
  response="$(curl --retry 5 --retry-all-errors --retry-delay 3 \
    --fail --silent --show-error --dump-header - --output /dev/null \
    --request OPTIONS "$API_URL$path" \
    --header "Origin: $FRONTEND_ORIGIN" \
    --header "Access-Control-Request-Method: $method" \
    --header "Access-Control-Request-Headers: $requested_headers")"

  grep -Fqi "access-control-allow-origin: $FRONTEND_ORIGIN" <<< "$response" || {
    echo "$path: el preflight no autorizó el origen del frontend" >&2
    return 1
  }
}

preflight "/solicitudes/mias" "GET" "authorization,cache-control,pragma"
preflight "/solicitudes" "POST" "authorization,content-type,cache-control,pragma"

for path in /datos /solicitudes /solicitudes/pendientes /productos; do
  CODE="$(curl --silent --show-error -o /dev/null -w '%{http_code}' "$API_URL$path")"
  [[ "$CODE" == 401 ]] || { echo "$path: esperaba 401 sin token, recibió $CODE"; exit 1; }
done
# Para verificar el recorrido autenticado, proporciona un access token de corta duración.
if [[ -n "${ACCESS_TOKEN:-}" ]]; then
  curl --fail --silent --show-error -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL/datos" >/dev/null
  curl --fail --silent --show-error -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL/solicitudes/mias" >/dev/null
fi
echo 'Smoke OK: frontend accesible y API rechaza peticiones anónimas.'
