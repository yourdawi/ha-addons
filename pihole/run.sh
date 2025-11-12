#!/usr/bin/env bash
set -euo pipefail

# Simple logger
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_fatal() { echo "[FATAL] $*"; exit 1; }

OPTIONS_FILE="/data/options.json"
if [ ! -s "$OPTIONS_FILE" ]; then
  log_warn "No options.json found at $OPTIONS_FILE; using defaults where possible"
fi

JQ_AVAILABLE=true
if ! command -v jq >/dev/null 2>&1; then
  JQ_AVAILABLE=false
  log_warn "jq not found in base image; will read options from environment if provided"
fi

get_opt() {
  local key=$1; local def=${2-}
  if [ "$JQ_AVAILABLE" = true ] && [ -s "$OPTIONS_FILE" ]; then
    jq -r --arg k "$key" 'try .[$k] // empty' "$OPTIONS_FILE"
  else
    # Fallback: ENV variable with uppercased key
    local env_key
    env_key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
    eval echo "\${$env_key:-$def}"
  fi
}

# Read options via jq
LOG_LEVEL=$(get_opt 'log_level' 'info')
TZ_OPT=$(get_opt 'tz' 'UTC')
WEB_PASS=$(get_opt 'web_password' '')
DNS_LISTEN=$(get_opt 'dns_listening_mode' 'all')
ENABLE_DHCP=$(get_opt 'enable_dhcp' 'false')
ENABLE_NTP=$(get_opt 'enable_ntp' 'false')
PERSIST_DNSMASQ_D=$(get_opt 'persist_dnsmasq_d' 'false')

CONFIG_DIR="/config/pihole"
PIHOLE_ETC="$CONFIG_DIR/etc-pihole"
DNSMASQ_D="$CONFIG_DIR/etc-dnsmasq.d"
mkdir -p "$PIHOLE_ETC" "$DNSMASQ_D"

log_info "Starting Pi-hole add-on (log level: ${LOG_LEVEL})"

# Map persistence into expected paths (bind mount style inside container)
if [ ! -L /etc/pihole ] && [ -d /etc/pihole ]; then
  rm -rf /etc/pihole || true
fi
ln -snf "$PIHOLE_ETC" /etc/pihole

if [ ! -L /etc/dnsmasq.d ] && [ -d /etc/dnsmasq.d ]; then
  rm -rf /etc/dnsmasq.d || true
fi
ln -snf "$DNSMASQ_D" /etc/dnsmasq.d

# Environment variables consumed by upstream Pi-hole entrypoint
export TZ="${TZ_OPT}"
if [ -n "${WEB_PASS:-}" ] && [ "$WEB_PASS" != "null" ]; then
  export FTLCONF_webserver_api_password="${WEB_PASS}"
fi
case "${DNS_LISTEN}" in
  all|local|single) export FTLCONF_dns_listeningMode="${DNS_LISTEN}" ;;
  *) log_warn "Unknown dns_listening_mode '${DNS_LISTEN}', defaulting to 'all'"; export FTLCONF_dns_listeningMode="all" ;;
esac

# Optional features requiring capabilities and ports
if [ "${ENABLE_DHCP}" = "true" ]; then
  export FTLCONF_dhcp_enabled="true"
else
  export FTLCONF_dhcp_enabled="false"
fi

if [ "${ENABLE_NTP}" = "true" ]; then
  export FTLCONF_ntp_enabled="true"
else
  export FTLCONF_ntp_enabled="false"
fi

# Use external /etc/dnsmasq.d directory (mostly for migration from v5)
if [ "${PERSIST_DNSMASQ_D}" = "true" ]; then
  export FTLCONF_misc_etc_dnsmasq_d="true"
fi

# SYS_NICE capability provided via add-on privileges; no extra handling needed

# Ensure correct permissions
chown -R root:root "$PIHOLE_ETC" "$DNSMASQ_D" || true
chmod -R u+rwX,go-rwx "$PIHOLE_ETC" "$DNSMASQ_D" || true

# Pi-hole upstream uses s6-overlay; typical entrypoint is /s6-init
if command -v /s6-init >/dev/null 2>&1; then
  exec /s6-init
fi
if [ -x /init ]; then
  exec /init
fi

# Fallback: run pihole-FTL foreground
if command -v pihole-FTL >/dev/null 2>&1; then
  exec pihole-FTL no-daemon
fi

log_fatal "Could not find Pi-hole init process (s6-init or FTL). Image may have changed."
