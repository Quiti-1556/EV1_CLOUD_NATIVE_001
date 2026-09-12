#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need aws docker jq
if [[ $# -gt 0 ]]; then load_outputs "$1"; fi
: "${DB_APP_SECRET_ARN:?}" "${ECS_MIGRATION_TEMPLATE_PARAMETER:?}" "${ECS_SUBNETS:?}" "${ECS_SECURITY_GROUP:?}"
: "${AWS_REGION:?}" "${ECR_REPO:?}" "${ECS_CLUSTER:?}" "${ECS_SERVICE:?}" "${ECS_TASK_TEMPLATE_PARAMETER:?}" "${ECS_DESIRED_COUNT:?}"
TAG="${IMAGE_TAG:-$(git rev-parse --short=12 HEAD 2>/dev/null || echo manual)-$(date -u +%Y%m%d%H%M%S)-${RANDOM}}"
[[ "$TAG" =~ ^[a-zA-Z0-9_.-]{1,128}$ ]] || { echo 'Etiqueta inválida'; exit 1; }
REGISTRY="${ECR_REPO%%/*}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker build --platform linux/amd64 -t "$ECR_REPO:$TAG" backend
docker push "$ECR_REPO:$TAG"
DIGEST="$(aws ecr describe-images --repository-name "${ECR_REPO#*/}" --image-ids "imageTag=$TAG" --query 'imageDetails[0].imageDigest' --output text)"
[[ "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]] || { echo 'No se obtuvo digest ECR'; exit 1; }
# La plantilla proviene de una revisión exacta de Terraform, no de la última revisión de la familia.
BASE="$(aws ssm get-parameter --name "$ECS_TASK_TEMPLATE_PARAMETER" --query Parameter.Value --output text)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
aws ecs describe-task-definition --task-definition "$BASE" --query taskDefinition --output json | \
  jq --arg image "$ECR_REPO@$DIGEST" 'del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy,.deregisteredAt) | (.containerDefinitions[] | select(.name=="backend").image)=$image' > "$TMP_DIR/task.json"
# Crear la contraseña inicial en Secrets Manager; no la lee Terraform ni se imprime.
VERSIONS="$(aws secretsmanager describe-secret --secret-id "$DB_APP_SECRET_ARN" --query VersionIdsToStages --output json)"
if ! jq -e '(. // {}) | to_entries | any(.[]; .value | index("AWSCURRENT"))' <<< "$VERSIONS" >/dev/null; then
  umask 077
  aws secretsmanager get-random-password --password-length 40 --exclude-punctuation --output json | jq '{password:.RandomPassword}' > "$TMP_DIR/password.json"
  aws secretsmanager put-secret-value --secret-id "$DB_APP_SECRET_ARN" --secret-string "file://$TMP_DIR/password.json" >/dev/null
  rm -f "$TMP_DIR/password.json"
fi
MIGRATION_BASE="$(aws ssm get-parameter --name "$ECS_MIGRATION_TEMPLATE_PARAMETER" --query Parameter.Value --output text)"
aws ecs describe-task-definition --task-definition "$MIGRATION_BASE" --query taskDefinition --output json | \
  jq --arg image "$ECR_REPO@$DIGEST" 'del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy,.deregisteredAt) | (.containerDefinitions[] | select(.name=="backend").image)=$image' > "$TMP_DIR/migration.json"
MIGRATION_DEF="$(aws ecs register-task-definition --cli-input-json "file://$TMP_DIR/migration.json" --query taskDefinition.taskDefinitionArn --output text)"
RUN="$(aws ecs run-task --cluster "$ECS_CLUSTER" --task-definition "$MIGRATION_DEF" --launch-type FARGATE --platform-version 1.4.0 --network-configuration "awsvpcConfiguration={subnets=[$ECS_SUBNETS],securityGroups=[$ECS_SECURITY_GROUP],assignPublicIp=DISABLED}" --output json)"
MIGRATION_TASK="$(jq -er '.tasks[0].taskArn // empty' <<< "$RUN")"
for attempt in $(seq 1 6); do
  if aws ecs wait tasks-stopped --cluster "$ECS_CLUSTER" --tasks "$MIGRATION_TASK"; then break; fi
  [[ "$attempt" != 6 ]] || { echo 'Timeout de migraciones; no se despliega la aplicación.'; exit 1; }
done
RESULT="$(aws ecs describe-tasks --cluster "$ECS_CLUSTER" --tasks "$MIGRATION_TASK" --output json)"
if ! jq -e '.tasks[0].containers | any(.[]; .name=="backend" and .exitCode==0)' <<< "$RESULT" >/dev/null; then
  echo 'Migraciones fallidas. Servicio anterior conservado; consultar CloudWatch.' >&2; exit 1
fi
TASK="$(aws ecs register-task-definition --cli-input-json "file://$TMP_DIR/task.json" --query taskDefinition.taskDefinitionArn --output text)"
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --task-definition "$TASK" --desired-count "$ECS_DESIRED_COUNT" >/dev/null
# services-stable tiene límite corto; se inspecciona además la revisión para detectar rollback.
for attempt in $(seq 1 6); do
  if aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE"; then
    LIVE="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --output json)"
    if jq -e --arg task "$TASK" --argjson count "$ECS_DESIRED_COUNT" '.services[0] | .taskDefinition==$task and .runningCount==$count and .pendingCount==0 and any(.deployments[]; .status=="PRIMARY" and .rolloutState=="COMPLETED")' <<< "$LIVE" >/dev/null; then
      echo "Backend saludable: $ECR_REPO@$DIGEST"; exit 0
    fi
    echo 'ECS hizo rollback o no ejecuta la revisión solicitada.' >&2; exit 1
  fi
  STATE="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].deployments' --output json)"
  if jq -e --arg task "$TASK" 'any(.[]; .taskDefinition==$task and .rolloutState=="FAILED")' <<< "$STATE" >/dev/null; then
    echo 'Circuit breaker: despliegue fallido.' >&2; exit 1
  fi
done
echo 'Timeout esperando backend; consulta CloudWatch y eventos ECS.' >&2
exit 1
