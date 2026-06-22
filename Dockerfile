# PrusaSlicer over WebRTC using Selkies-GStreamer
#
# Build args:
#   DISTRIB_RELEASE   Ubuntu version (default: 24.04)
#   PRUSA_VERSION     PrusaSlicer release tag (default: 2.8.1)
#   SELKIES_BRANCH    Selkies build branch (default: main)

ARG DISTRIB_RELEASE=24.04
ARG SELKIES_BRANCH=main

# Selkies component stages
FROM ghcr.io/selkies-project/selkies-gstreamer/gstreamer:${SELKIES_BRANCH}-ubuntu${DISTRIB_RELEASE} AS gstreamer
FROM ghcr.io/selkies-project/selkies-gstreamer/py-build:${SELKIES_BRANCH}-ubuntu${DISTRIB_RELEASE} AS py-build
FROM ghcr.io/selkies-project/selkies-gstreamer/gst-web:${SELKIES_BRANCH} AS gst-web

# Main image
FROM ubuntu:${DISTRIB_RELEASE}

ARG DISTRIB_RELEASE
ARG PRUSA_VERSION=2.8.1

# Labels for metadata
LABEL org.opencontainers.image.title="PrusaSlicer (Selkies WebRTC)"
LABEL org.opencontainers.image.description="Browser-accessible PrusaSlicer via Selkies-GStreamer WebRTC. No local install required."
LABEL org.opencontainers.image.source="https://github.com/mattmerritt215/prusaslicer-selkies"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL prusaslicer.version="${PRUSA_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# Install system packages
RUN apt-get update && apt-get install --no-install-recommends -y \
    # Utilities
    bash curl wget ca-certificates gnupg tini supervisor \
    # Virtual X11 display
    xvfb x11-utils x11-xkb-utils x11-xserver-utils xserver-xorg-core \
    libx11-xcb1 libxcb-dri3-0 libxkbcommon0 libxdamage1 libxfixes3 \
    libxv1 libxtst6 libxext6 libxrandr2 \
    # Wayland / DRI (needed even in Xvfb mode for VA-API path)
    wayland-protocols libwayland-dev libwayland-egl1 \
    # Lightweight window manager — just enough to host PrusaSlicer
    openbox dbus-x11 at-spi2-core \
    # Audio streaming (Selkies sends Opus to browser)
    pulseaudio \
    # Selkies Ubuntu 22.04+ extra deps
    xcvt libopenh264-dev \
    # Intel VA-API hardware encoding support
    libva2 libva-drm2 intel-media-va-driver-non-free vainfo \
    # Python for Selkies signaling server
    python3 python3-pip \
    # nginx — serves the HTML5 web UI and proxies WebSocket signaling
    nginx \
    # PrusaSlicer AppImage runtime deps
    libgl1 libglu1-mesa libgtk-3-0 libdbus-glib-1-2 \
    libnotify4 libsecret-1-0 libfuse2 fuse \
 && rm -rf /var/lib/apt/lists/*

# Copy Selkies components
COPY --from=gstreamer /opt/gstreamer /opt/gstreamer
COPY --from=gst-web   /opt/gst-web   /opt/gst-web

# Install Selkies Python signaling server wheel
COPY --from=py-build /opt/pypi/*.whl /tmp/
RUN pip3 install --break-system-packages /tmp/*.whl && rm /tmp/*.whl

# Download and set up PrusaSlicer AppImage
RUN set -eux; \
    PRUSA_FILENAME="PrusaSlicer-${PRUSA_VERSION}+linux-x64-GTK3-202410281434.AppImage"; \
    wget -q "https://github.com/prusa3d/PrusaSlicer/releases/download/version_${PRUSA_VERSION}/${PRUSA_FILENAME}" \
         -O /opt/PrusaSlicer.AppImage; \
    chmod +x /opt/PrusaSlicer.AppImage; \
    # Extract the AppImage in place (avoids needing FUSE at runtime)
    cd /opt && /opt/PrusaSlicer.AppImage --appimage-extract; \
    mv /opt/squashfs-root /opt/PrusaSlicer; \
    # Symlink the extracted AppRun as a plain binary for easier execution
    ln -s /opt/PrusaSlicer/AppRun /usr/local/bin/prusaslicer; \
    # Clean up the original AppImage
    rm /opt/PrusaSlicer.AppImage

# Config files
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Persistent volume for PrusaSlicer profiles + Selkies state
VOLUME ["/config"]

# Expose NGINX port
EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
