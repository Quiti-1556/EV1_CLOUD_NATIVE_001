#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need gh jq
ENVIRONMENT="${1:?Uso: sincronizar-github.sh dev|qa|prod OWNER/REPO}"
REPOSITORY="${2:?Indica OWNER/REPO}"
load_outputs "$ENVIRONMENT"
GH_ENV="${ENVIRONMENT^^}"
: "${TF_STATE_BUCKET:?Falta TF_STATE_BUCKET}"
gh api --method PUT "repos/$REPOSITORY/environments/$GH_ENV" >/dev/null
# Solo configuración pública; las credenciales se configuran aparte.
while IFS=$'\t' read -r key value; do
  gh variable set "$key" --env "$GH_ENV" --repo "$REPOSITORY" --body "$value"
done < <(terraform -chdir=terraform output -json deployment | jq -r 'to_entries[]|[.key,.value]|@tsv')
gh variable set TF_STATE_BUCKET --env "$GH_ENV" --repo "$REPOSITORY" --body "$TF_STATE_BUCKET"
echo "Variables de $GH_ENV sincronizadas. Configura OIDC o credenciales temporales según README."
