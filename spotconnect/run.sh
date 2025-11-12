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
BIN_DIR="$CONFIG_DIR/bin"
mkdir -p "$BIN_DIR"
WORKDIR="/tmp/spotconnect_unpack"
mkdir -p "$WORKDIR"

UPSTREAM_API="https://api.github.com/repos/philippe44/SpotConnect/releases/latest"
VERSION_FILE="$CONFIG_DIR/version.txt"
if [ ! -f "$VERSION_FILE" ] && [ -f "/data/spotconnect/version.txt" ]; then
  cp "/data/spotconnect/version.txt" "$VERSION_FILE" 2>/dev/null || true
fi

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
  rm -rf "$WORKDIR"/*
  unzip -q "/tmp/${zip}" -d "$WORKDIR"
  rm "/tmp/${zip}"
  while IFS= read -r f; do
    cp "$f" "$BIN_DIR/" || true
  done < <(find "$WORKDIR" -maxdepth 2 -type f \( -name 'spotraop*' -o -name 'spotupnp*' \))
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
  CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "none")
fi

# Debug-Hinweis zur Versionsdatei
if [ -f "$VERSION_FILE" ]; then
  bashio::log.info "Detected version file: $VERSION_FILE -> $(cat "$VERSION_FILE" 2>/dev/null || echo "<unreadable>")"
else
  bashio::log.info "No version file found at: $VERSION_FILE"
fi

if ! bashio::config.true 'cache_binaries' || [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
  bashio::log.info "Updating SpotConnect from ${CURRENT_VERSION} to ${LATEST_VERSION}"
  download_release "$LATEST_VERSION"
  echo "$LATEST_VERSION" > "$VERSION_FILE"
  chmod 644 "$VERSION_FILE" || true
  bashio::log.info "Wrote version file: $VERSION_FILE"
else
  bashio::log.info "Using cached SpotConnect version ${CURRENT_VERSION}"
fi

select_binary_from_cache() {
  local mode_bin
  case "$SPOTCONNECT_MODE" in
    raop) mode_bin="spotraop" ;;
    upnp) mode_bin="spotupnp" ;;
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
  local p
  for p in "${patterns[@]}"; do
    if [ -f "$BIN_DIR/$p" ]; then
      echo "$BIN_DIR/$p"
      return 0
    fi
  done
  return 1
}

if BIN_PATH=$(select_binary_from_cache); then
  :
else
  BIN_PATH=$(select_binary)
fi
chmod +x "$BIN_PATH"

if [[ "$BIN_PATH" == "$BIN_DIR"/* ]]; then
  rm -rf "$WORKDIR" || true
fi

bashio::log.info "Starting SpotConnect (${LATEST_VERSION}) with mode: $SPOTCONNECT_MODE"

# Setze Arbeitsverzeichnis auf CONFIG_DIR, damit ./config.xml dort landet
cd "$CONFIG_DIR" || true
bashio::log.info "Working directory set to: $(pwd)"

# Gemeinsame Startargumente (ohne -x; wird ggf. später ergänzt)
CMD_ARGS=( -Z -J "$CONFIG_DIR" -I )

# Map optional settings to CLI (gelten sowohl beim Initial-Lauf als auch danach)
if [ -n "${NAME_FORMAT:-}" ]; then
  CMD_ARGS+=( -N "$NAME_FORMAT" )
fi

if [ -n "${VORBIS_RATE:-}" ]; then
  CMD_ARGS+=( -r "$VORBIS_RATE" )
fi

if [ "$SPOTCONNECT_MODE" = "upnp" ] && [ -n "${HTTP_CONTENT_LENGTH:-}" ]; then
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

if [ "$SPOTCONNECT_MODE" = "upnp" ] && [ "${ENABLE_FILECACHE:-false}" = "true" ]; then
  CMD_ARGS+=( -C )
fi

CONFIG_FILE="$CONFIG_DIR/config.xml"
if [ ! -s "$CONFIG_FILE" ]; then
  bashio::log.info "No configuration file yet at: $CONFIG_FILE — starting once to let SpotConnect generate it"
  # Starte ohne -x, damit SpotConnect ./config.xml anlegt
  "$BIN_PATH" "${CMD_ARGS[@]}" &
  GEN_PID=$!
  for i in $(seq 1 30); do
    if [ -s "$CONFIG_FILE" ]; then
      bashio::log.info "Configuration file created: $CONFIG_FILE"
      break
    fi
    sleep 1
  done
  if kill -0 "$GEN_PID" 2>/dev/null; then
    bashio::log.info "Stopping initial SpotConnect instance to relaunch with -x"
    kill "$GEN_PID" 2>/dev/null || true
    wait "$GEN_PID" 2>/dev/null || true
  fi
fi

# Ab hier immer -x nutzen, wenn vorhanden
if [ -s "$CONFIG_FILE" ]; then
  bashio::log.info "Using configuration file: $CONFIG_FILE"
  CMD_ARGS+=( -x "$CONFIG_FILE" )
fi

exec "$BIN_PATH" "${CMD_ARGS[@]}"
