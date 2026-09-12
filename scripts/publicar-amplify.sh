#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need aws jq zip curl node
APP_ID="${1:?Uso: publicar-amplify.sh APP_ID RAMA DIRECTORIO}"
BRANCH="${2:?Falta rama}"
BUILD_DIR="$(realpath "${3:?Falta directorio}")"
[[ -f "$BUILD_DIR/index.html" && -f "$BUILD_DIR/assets/config.json" ]] || { echo 'Bundle incompleto'; exit 1; }
node --input-type=module - "$BUILD_DIR/assets/config.json" <<'NODE'
import {readFileSync} from 'node:fs';
const c=JSON.parse(readFileSync(process.argv[2]));
if(c.authEnabled!==true || !c.clientId || !c.cognitoDomain.startsWith('https://') || !c.apiUrl.startsWith('https://') || !c.redirectUri.startsWith('https://'))throw new Error('Publicación bloqueada: configuración insegura');
NODE
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
(cd "$BUILD_DIR" && zip -qr "$TMP_DIR/frontend.zip" .)
DEPLOYMENT="$(aws amplify create-deployment --app-id "$APP_ID" --branch-name "$BRANCH" --output json)"
JOB="$(jq -er .jobId <<< "$DEPLOYMENT")"
UPLOAD="$(jq -er .zipUploadUrl <<< "$DEPLOYMENT")"
curl --silent --show-error --fail --proto '=https' -X PUT -T "$TMP_DIR/frontend.zip" "$UPLOAD" >/dev/null
aws amplify start-deployment --app-id "$APP_ID" --branch-name "$BRANCH" --job-id "$JOB" >/dev/null
for attempt in $(seq 1 120); do
  STATUS="$(aws amplify get-job --app-id "$APP_ID" --branch-name "$BRANCH" --job-id "$JOB" --query job.summary.status --output text)"
  case "$STATUS" in SUCCEED) echo "Frontend publicado; job $JOB"; exit 0;; FAILED|CANCELLED) echo "Amplify: $STATUS"; exit 1;; esac
  sleep 5
done
echo 'Timeout de Amplify'; exit 1
