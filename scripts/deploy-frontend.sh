#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
load_outputs "${1:?Indica ambiente}"
bash scripts/config-frontend.sh
(cd frontend && npm ci --ignore-scripts && npm test && npm run build)
bash scripts/publicar-amplify.sh "$AMPLIFY_APP_ID" "$AMPLIFY_BRANCH" frontend/dist/frontend/browser
