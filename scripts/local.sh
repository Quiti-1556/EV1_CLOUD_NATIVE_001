#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need docker
# El build local no reutiliza la configuración AWS generada por otro despliegue.
cp frontend/config.local.json frontend/src/assets/config.json
docker compose up --build -d
echo 'Local: http://localhost:4200 — identidades demo, solo loopback.'
