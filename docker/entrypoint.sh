#!/bin/bash

set -euo pipefail

# Defaults
# SELKIES_ENCODER:
#   vah264enc  → Intel/AMD VA-API H.264 (hardware)
#   nvh264enc  → NVIDIA NVENC H.264 (hardware)
#   x264enc    → software H.264 (always works, higher CPU)
#   vp8enc     → software VP8
: "${SELKIES_ENCODER:=vah264enc}"

# Resolution passed to Xvfb and Selkies initial size
: "${DISPLAY_RESOLUTION:=1920x1080x24}"

# TURN server — required for WebRTC when not using --network=host
: "${TURN_HOST:=}"
: "${TURN_PORT:=3478}"
: "${TURN_SECRET:=}"
: "${TURN_PROTOCOL:=udp}"

export SELKIES_ENCODER DISPLAY_RESOLUTION TURN_HOST TURN_PORT TURN_SECRET TURN_PROTOCOL
export DISPLAY=:10

# Validate TURN config
if [[ -z "$TURN_HOST" ]]; then
    echo "WARNING: TURN_HOST is not set."
    echo "  WebRTC will only work if the container uses --network=host,"
    echo "  or if client and server are on the same LAN segment."
    echo "  Set TURN_HOST, TURN_PORT, and TURN_SECRET for remote access."
fi

# Probe VA-API, fall back to software
if [[ "$SELKIES_ENCODER" == "vah264enc" ]]; then
    if ! vainfo --display drm --device /dev/dri/renderD128 &>/dev/null; then
        echo "INFO: VA-API not available (no GPU device or drivers missing)."
        echo "INFO: Falling back to software encoder (x264enc)."
        export SELKIES_ENCODER=x264enc
    else
        echo "INFO: VA-API available — using hardware encoder (${SELKIES_ENCODER})."
    fi
fi

# Persistent config dirs
mkdir -p /config/prusaslicer
export XDG_CONFIG_HOME=/config

echo "INFO: Starting PrusaSlicer-Selkies (encoder=${SELKIES_ENCODER}, resolution=${DISPLAY_RESOLUTION})"