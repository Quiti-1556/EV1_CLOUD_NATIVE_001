#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export AWS_PAGER=""
need() { for tool in "$@"; do command -v "$tool" >/dev/null || { echo "Falta $tool" >&2; exit 1; }; done; }
check_environment() { case "${1:-}" in dev|qa|prod) ;; *) echo 'Ambiente requerido: dev, qa o prod' >&2; exit 1;; esac; }
load_outputs() {
  need terraform jq
  check_environment "$1"
  export TF_DATA_DIR="$ROOT/terraform/.terraform-$1"
  local data key value
  data="$(terraform -chdir=terraform output -json deployment)"
  while IFS=$'\t' read -r key value; do
    [[ "$key" =~ ^[A-Z_]+$ ]] || { echo 'Output inesperado'; exit 1; }
    export "$key=$value"
  done < <(jq -r 'to_entries[] | [.key,.value] | @tsv' <<< "$data")
  export AWS_DEFAULT_REGION="$AWS_REGION"
}
