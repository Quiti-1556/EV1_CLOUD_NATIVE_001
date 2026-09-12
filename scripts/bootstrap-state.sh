#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need terraform aws
unset TF_DATA_DIR
: "${TF_STATE_BUCKET:?Exporta TF_STATE_BUCKET (nombre S3 único)}"
: "${AWS_REGION:?Exporta AWS_REGION}"
terraform -chdir=terraform/bootstrap init -input=false
terraform -chdir=terraform/bootstrap plan -input=false -var="bucket_name=$TF_STATE_BUCKET" -var="aws_region=$AWS_REGION" -var="github_repository=${GITHUB_REPOSITORY:-}" -var="github_oidc_provider_arn=${GITHUB_OIDC_PROVIDER_ARN:-}" -out=bootstrap.tfplan
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
printf 'Estado remoto creado. Conserva terraform/bootstrap/terraform.tfstate fuera de Git.\n'
