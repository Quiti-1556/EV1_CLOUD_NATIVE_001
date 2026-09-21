#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need npm node
(cd session-ms && npm ci --ignore-scripts && npm test && npm run build)
