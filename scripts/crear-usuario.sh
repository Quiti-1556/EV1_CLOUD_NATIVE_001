#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need aws
ENVIRONMENT="${1:?Ambiente}"
EMAIL="${2:?Email}"
ROLE="${3:?SOLICITANTE o APROBADOR}"
case "$ROLE" in SOLICITANTE|APROBADOR) ;; *) echo 'Rol inválido'; exit 1;; esac
load_outputs "$ENVIRONMENT"
# Cognito genera la contraseña temporal y envía invitación; no se imprime ni se guarda.
aws cognito-idp admin-create-user --user-pool-id "$COGNITO_USER_POOL_ID" --username "$EMAIL" \
  --user-attributes "Name=email,Value=$EMAIL" --desired-delivery-mediums EMAIL --query 'User.Username' --output text
aws cognito-idp admin-add-user-to-group --user-pool-id "$COGNITO_USER_POOL_ID" --username "$EMAIL" --group-name "$ROLE"
echo 'Usuario invitado. Cognito solicitará cambio de contraseña y registro del segundo factor.'
