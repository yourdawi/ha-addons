#!/usr/bin/with-contenv bashio

set -euo pipefail

SPOTCONNECT_MODE=$(bashio::config 'spotconnect_mode')
LOG_LEVEL=$(bashio::config 'log_level')
NETWORK_SELECT=$(bashio::config 'network_select')
PREFER_STATIC=$(bashio::config 'prefer_static')
CACHE_BINARIES=$(bashio::config 'cache_binaries')
NAME_FORMAT=$(bashio::config 'name_format')
VORBIS_RATE=$(bashio::config 'vorbis_rate')
HTTP_CONTENT_LENGTH=$(bashio::config 'http_content_length')
HTTP_PORT_RANGE=$(bashio::config 'http_port_range')
UPNP_PORT=$(bashio::config 'upnp_port')
ENABLE_FILECACHE=$(bashio::config 'enable_filecache')

ARCH=$(bashio::info.arch)

CONFIG_DIR="/config/spotconnect"
mkdir -p "$CONFIG_DIR"
WORKDIR="/opt/spotconnect"
mkdir -p "$WORKDIR"

UPSTREAM_API="https://api.github.com/repos/philippe44/SpotConnect/releases/latest"
VERSION_FILE="/config/spotconnect/.version"

fetch_latest_version() {
  local tag
  tag=$(curl -sSL -H 'Accept: application/vnd.github+json' "$UPSTREAM_API" | jq -r '.tag_name // empty') || true
  if [ -z "$tag" ] || [ "$tag" = "null" ]; then
    bashio::log.fatal "Could not fetch latest SpotConnect release tag"
    exit 1
  fi
  echo "$tag"
}

download_release() {
  local version="$1"
  local zip="SpotConnect-${version}.zip"
  local url="https://github.com/philippe44/SpotConnect/releases/download/${version}/${zip}"
  bashio::log.info "Downloading SpotConnect release ${version}" 
  curl -sSL "$url" -o "/tmp/${zip}"
  if [ ! -s "/tmp/${zip}" ]; then
    bashio::log.fatal "Failed to download: $url"
    exit 1
  fi
  unzip -q "/tmp/${zip}" -d "$WORKDIR"
  rm "/tmp/${zip}"
}

arch_candidates() {
  case "$ARCH" in
    aarch64) echo "aarch64 arm64" ;;
    armhf) echo "armhf armv6 armv6l arm" ;;
    armv7) echo "armv7 armv7l arm" ;;
    amd64) echo "x86_64 amd64" ;;
    i386) echo "i386 i686 x86" ;;
    *) echo "$ARCH" ;;
  esac
}

select_binary() {
  local mode_bin
  case "$SPOTCONNECT_MODE" in
    raop) mode_bin="spotraop" ;;
    upnp) mode_bin="spotupnp" ;;
    *) bashio::log.fatal "Unknown spotconnect_mode: $SPOTCONNECT_MODE (expected raop|upnp)"; exit 1 ;;
  esac

  local candidates
  candidates=$(arch_candidates)
  local patterns=()
  if [ "$PREFER_STATIC" = "yes" ]; then
    for a in $candidates; do
      patterns+=("${mode_bin}-linux-${a}-static" "${mode_bin}-${a}-static")
    done
  fi
  for a in $candidates; do
    patterns+=("${mode_bin}-linux-${a}" "${mode_bin}-${a}")
  done
  patterns+=("${mode_bin}")

  local p file
  for p in "${patterns[@]}"; do
    file=$(find "$WORKDIR" -type f -name "$p" -o -name "$p.exe" | head -n1 || true)
    if [ -n "$file" ] && [ -f "$file" ]; then
      chmod +x "$file" || true
      echo "$file"
      return
    fi
  done
  bashio::log.fatal "No suitable SpotConnect binary found (arch: $ARCH, mode: $SPOTCONNECT_MODE)"
  exit 1
}

LATEST_VERSION=$(fetch_latest_version)
CURRENT_VERSION="none"
if [ -f "$VERSION_FILE" ]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
fi

if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ] || [ "$CACHE_BINARIES" != "true" ]; then
  bashio::log.info "Updating SpotConnect from ${CURRENT_VERSION} to ${LATEST_VERSION}" 
  rm -rf "$WORKDIR"/*
  download_release "$LATEST_VERSION"
  echo "$LATEST_VERSION" > "$VERSION_FILE"
else
  bashio::log.info "Using cached SpotConnect version ${CURRENT_VERSION}"
fi

BIN_PATH=$(select_binary)
chmod +x "$BIN_PATH"

CONFIG_FILE="$CONFIG_DIR/config.xml"
if [ ! -f "$CONFIG_FILE" ]; then
  bashio::log.info "Generating default config file at $CONFIG_FILE"
  # Try generating reference config; ignore failure for minimal binary
  "$BIN_PATH" -i "$CONFIG_FILE" -Z || true
fi

bashio::log.info "Starting SpotConnect (${LATEST_VERSION}) with mode: $SPOTCONNECT_MODE"

CMD_ARGS=( -Z -x "$CONFIG_FILE" -J "$CONFIG_DIR" -I )

# Map optional settings to CLI
if [ -n "${NAME_FORMAT:-}" ]; then
  CMD_ARGS+=( -N "$NAME_FORMAT" )
fi

if [ -n "${VORBIS_RATE:-}" ]; then
  CMD_ARGS+=( -r "$VORBIS_RATE" )
fi

if [ -n "${HTTP_CONTENT_LENGTH:-}" ]; then
  case "$HTTP_CONTENT_LENGTH" in
    chunked) CMD_ARGS+=( -g -3 ) ;;
    no_length) CMD_ARGS+=( -g -1 ) ;;
    fake_length) CMD_ARGS+=( -g 0 ) ;;
    auto) CMD_ARGS+=( -g -2 ) ;;
  esac
fi

if [ -n "${HTTP_PORT_RANGE:-}" ]; then
  # Expect format "<port>" or "<port>:<count>"
  CMD_ARGS+=( -a "$HTTP_PORT_RANGE" )
fi

if [ -n "$NETWORK_SELECT" ]; then
  bashio::log.info "Using network interface: $NETWORK_SELECT"
  if [ "$SPOTCONNECT_MODE" = "upnp" ] && [ -n "${UPNP_PORT:-}" ] && [ "$UPNP_PORT" -gt 0 ] 2>/dev/null; then
    CMD_ARGS+=( -b "${NETWORK_SELECT}:${UPNP_PORT}" )
  else
    CMD_ARGS+=( -b "$NETWORK_SELECT" )
  fi
fi

if [ "${ENABLE_FILECACHE:-false}" = "true" ]; then
  CMD_ARGS+=( -C )
fi

exec "$BIN_PATH" "${CMD_ARGS[@]}"
