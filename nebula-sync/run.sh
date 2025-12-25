#!/usr/bin/env bash
set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_fatal() { echo "[FATAL] $*"; exit 1; }

OPTIONS_FILE="/data/options.json"

get_opt() {
  local key=$1; local def=${2-}
  if command -v jq >/dev/null 2>&1 && [ -s "$OPTIONS_FILE" ]; then
    jq -r --arg k "$key" 'try .[$k] // empty' "$OPTIONS_FILE" 2>/dev/null || echo "${def}"
  else
    local env_key
    env_key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
    eval echo "\${$env_key:-$def}"
  fi
}

PRIMARY=$(get_opt 'primary' '')
REPLICAS=$(get_opt 'replicas' '')
FULL_SYNC=$(get_opt 'full_sync' 'false')
RUN_GRAVITY=$(get_opt 'run_gravity' 'false')
CRON=$(get_opt 'cron' '')

# Export so upstream binary can read them from environment
[ -n "$PRIMARY" ] && export PRIMARY
[ -n "$REPLICAS" ] && export REPLICAS
[ -n "$FULL_SYNC" ] && export FULL_SYNC
[ -n "$RUN_GRAVITY" ] && export RUN_GRAVITY
[ -n "$CRON" ] && export CRON

log_info "Starting Nebula-Sync with PRIMARY=${PRIMARY:-<unset>} REPLICAS=${REPLICAS:-<unset>}"

# If the upstream image provides an entrypoint binary, try to exec it.
# Common binary name is `nebula-sync`. Fall back to executing any args passed.
if command -v nebula-sync >/dev/null 2>&1; then
  exec nebula-sync
fi

# If arguments were provided to the container, run them
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

log_fatal "Could not find nebula-sync binary and no command passed. Image may have changed."
