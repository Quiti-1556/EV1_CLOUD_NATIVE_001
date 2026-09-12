#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
ENVIRONMENT="${1:?Uso: deploy.sh dev|qa|prod}"
check_environment "$ENVIRONMENT"
bash scripts/preflight.sh
bash scripts/infra.sh "$ENVIRONMENT" apply
bash scripts/publicar-ecs.sh "$ENVIRONMENT"
bash scripts/deploy-frontend.sh "$ENVIRONMENT"
bash scripts/smoke.sh "$ENVIRONMENT"
