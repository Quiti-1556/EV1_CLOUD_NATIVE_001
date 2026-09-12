#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
load_outputs "${1:?Ambiente}"
TASK="${2:?ARN completo de una revisión anterior}"
[[ "$TASK" == *":task-definition/$ECS_SERVICE:"* ]] || { echo 'La revisión no corresponde a este servicio'; exit 1; }
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --task-definition "$TASK" >/dev/null
aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE"
ACTUAL="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].taskDefinition' --output text)"
[[ "$ACTUAL" == "$TASK" ]] || { echo 'Rollback no aplicado'; exit 1; }
echo 'Rollback completado. Las migraciones de BD deben ser compatibles con ambas versiones.'
