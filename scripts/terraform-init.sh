#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need terraform
ENVIRONMENT="${1:?Uso: terraform-init.sh dev|qa|prod}"
check_environment "$ENVIRONMENT"
: "${TF_STATE_BUCKET:?Falta TF_STATE_BUCKET}"
: "${AWS_REGION:?Falta AWS_REGION (región del bucket y despliegue)}"
export TF_DATA_DIR="$ROOT/terraform/.terraform-$ENVIRONMENT"
terraform -chdir=terraform init -input=false -reconfigure \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=solicitud/$ENVIRONMENT/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="encrypt=true" -backend-config="use_lockfile=true"
