#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need bash aws terraform docker node npm jq zip curl python3
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}'
terraform version
node --version
docker info >/dev/null
[[ "$(node -p 'Number(process.versions.node.split(".")[0]) >= 22')" == true ]] || { echo 'Node >=22 requerido'; exit 1; }
echo 'Herramientas y credenciales disponibles. La autorización para cada servicio se verifica en plan/apply.'
