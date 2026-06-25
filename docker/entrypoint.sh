#!/bin/bash
set -euo pipefail

# Defaults 
# SELKIES_ENCODER:
#   vah264enc  → Intel/AMD VA-API H.264 (hardware, fastest)
#   nvh264enc  → NVIDIA NVENC H.264 (hardware)
#   x264enc    → software H.264 (always works, higher CPU)
: "${SELKIES_ENCODER:=vah264enc}"
: "${DISPLAY_RESOLUTION:=1920x1080x24}"
: "${TURN_HOST:=}"
: "${TURN_PORT:=3478}"
: "${TURN_SECRET:=}"
: "${TURN_PROTOCOL:=udp}"

export DISPLAY=:10
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Locale setup 
locale-gen en_US.UTF-8 2>/dev/null || true

# Validate TURN config 
if [[ -z "$TURN_HOST" ]]; then
    echo "WARNING: TURN_HOST is not set."
    echo "  WebRTC will only work on the same LAN segment or with --network=host."
    echo "  Set TURN_HOST, TURN_PORT, and TURN_SECRET for remote access."
fi

# Probe VA-API, fall back to software if unavailable
if [[ "$SELKIES_ENCODER" == "vah264enc" ]]; then
    if ! vainfo --display drm --device /dev/dri/renderD128 &>/dev/null; then
        echo "INFO: VA-API not available — falling back to software encoder (x264enc)."
        SELKIES_ENCODER=x264enc
    else
        echo "INFO: VA-API available — using hardware encoder (${SELKIES_ENCODER})."
    fi
fi

# Resolve env vars into supervisord.conf
# supervisord %(ENV_...)s interpolation is unreliable with Docker env injection,
# so we substitute our placeholder tokens with actual values at runtime.
sed -i \
    -e "s|SELKIES_ENCODER_VALUE|${SELKIES_ENCODER}|g" \
    -e "s|TURN_HOST_VALUE|${TURN_HOST}|g" \
    -e "s|TURN_PORT_VALUE|${TURN_PORT}|g" \
    -e "s|TURN_SECRET_VALUE|${TURN_SECRET}|g" \
    -e "s|TURN_PROTOCOL_VALUE|${TURN_PROTOCOL}|g" \
    /etc/supervisor/conf.d/supervisord.conf

# Persistent config dirs 
mkdir -p /config/prusaslicer
export XDG_CONFIG_HOME=/config

echo "INFO: Starting PrusaSlicer-Selkies"
echo "INFO:   encoder=${SELKIES_ENCODER}"
echo "INFO:   resolution=${DISPLAY_RESOLUTION}"
echo "INFO:   turn=${TURN_HOST}:${TURN_PORT}"

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
