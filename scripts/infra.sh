#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
ENVIRONMENT="${1:?Uso: infra.sh dev|qa|prod plan|apply}"
ACTION="${2:-plan}"
check_environment "$ENVIRONMENT"
case "$ACTION" in plan|apply) ;; *) echo 'Acción inválida'; exit 1;; esac
bash scripts/terraform-init.sh "$ENVIRONMENT"
export TF_DATA_DIR="$ROOT/terraform/.terraform-$ENVIRONMENT"
mkdir -p .runtime
terraform -chdir=terraform validate
terraform -chdir=terraform plan -input=false -lock-timeout=5m \
  -var-file="environments/$ENVIRONMENT.tfvars" -var="aws_region=$AWS_REGION" \
  -out="$ROOT/.runtime/$ENVIRONMENT.tfplan"
if [[ "$ACTION" == apply ]]; then
  terraform -chdir=terraform apply -input=false -lock-timeout=5m "$ROOT/.runtime/$ENVIRONMENT.tfplan"
  terraform -chdir=terraform output -json deployment > ".runtime/$ENVIRONMENT.outputs.json"
fi
