#!/bin/sh
set -eu

# Minimal wrapper to export options.json values as environment variables
# Works with `jq` if present, otherwise uses a crude fallback parser for simple
# string/boolean values. This keeps compatibility with minimal upstream images.

OPTIONS_FILE="/data/options.json"

get_opt() {
  key="$1"
  def="${2-}"
  if command -v jq >/dev/null 2>&1 && [ -s "$OPTIONS_FILE" ]; then
    jq -r --arg k "$key" 'try .[$k] // empty' "$OPTIONS_FILE" 2>/dev/null || echo "$def"
    return
  fi
  if [ -s "$OPTIONS_FILE" ]; then
    # crude fallback: find "key": "value" or "key": value
    val=$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"\?[^\",}]*\"\?" "$OPTIONS_FILE" | head -n1 | sed -E "s/^[^:]*:[[:space:]]*\"?([^"]*)\"?$/\1/") || true
    if [ -n "$val" ]; then
      echo "$val"
      return
    fi
  fi
  # Fallback to environment variable (uppercase)
  env_key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
  eval echo "\${$env_key:-$def}"
}

PRIMARY=$(get_opt primary "")
REPLICAS=$(get_opt replicas "")
FULL_SYNC=$(get_opt full_sync "false")
RUN_GRAVITY=$(get_opt run_gravity "false")
CRON=$(get_opt cron "")

if [ -n "$PRIMARY" ]; then export PRIMARY; fi
if [ -n "$REPLICAS" ]; then export REPLICAS; fi
export FULL_SYNC
export RUN_GRAVITY
if [ -n "$CRON" ]; then export CRON; fi

echo "[INFO] Starting Nebula-Sync with PRIMARY=${PRIMARY:-<unset>} REPLICAS=${REPLICAS:-<unset>}"

if command -v nebula-sync >/dev/null 2>&1; then
  exec nebula-sync "$@"
else
  echo "[FATAL] nebula-sync binary not found in image"
  exit 1
fi
