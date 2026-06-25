# syntax=docker/dockerfile:1
#
# PrusaSlicer via Selkies-GStreamer WebRTC
# Browser-accessible PrusaSlicer with low-latency WebRTC streaming.
# Supports Intel VA-API hardware acceleration (software fallback included).
#
# Build args:
#   DISTRIB_RELEASE   Ubuntu version (default: 24.04)
#   PRUSA_VERSION     PrusaSlicer release tag (default: 2.8.1)

ARG DISTRIB_RELEASE=24.04

####################################################
# Selkies component stages                         #
####################################################
FROM ghcr.io/selkies-project/selkies-gstreamer/gstreamer:main-ubuntu${DISTRIB_RELEASE} AS gstreamer
FROM ghcr.io/selkies-project/selkies-gstreamer/py-build:main AS py-build
FROM ghcr.io/selkies-project/selkies-gstreamer/gst-web:main AS gst-web

####################################################
# Main image                                       #
####################################################
FROM ubuntu:${DISTRIB_RELEASE}

ARG DISTRIB_RELEASE
ARG PRUSA_VERSION=2.8.1

LABEL org.opencontainers.image.title="PrusaSlicer (Selkies WebRTC)"
LABEL org.opencontainers.image.description="Browser-accessible PrusaSlicer via Selkies-GStreamer WebRTC. No local install required."
LABEL org.opencontainers.image.source="https://github.com/mattmerritt215/prusaslicer-selkies"
LABEL org.opencontainers.image.licenses="AGPL-3.0"
LABEL prusaslicer.version="${PRUSA_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

####################################################
# System packages                                  #
####################################################
RUN apt-get update && apt-get install --no-install-recommends -y \
    # Utilities
    bash curl wget ca-certificates gnupg tini supervisor \
    # Locales (fixes PrusaSlicer "Switching language failed" dialog)
    locales \
    # Virtual X11 display
    xvfb x11-utils x11-xkb-utils x11-xserver-utils xserver-xorg-core \
    libx11-xcb1 libxcb-dri3-0 libxkbcommon0 libxdamage1 libxfixes3 \
    libxv1 libxtst6 libxext6 libxrandr2 \
    # Wayland / DRI (needed even in Xvfb mode for VA-API path)
    wayland-protocols libwayland-dev libwayland-egl1 \
    # Lightweight window manager
    openbox dbus-x11 at-spi2-core \
    # Clipboard support for Selkies
    xsel xclip \
    # Audio streaming (Selkies sends Opus to browser)
    pulseaudio \
    # Selkies Ubuntu 22.04+ extra deps
    xcvt libopenh264-dev \
    # Intel VA-API hardware encoding support
    libva2 libva-drm2 \
    # Python for Selkies signaling server + GStreamer bindings
    python3 python3-pip python3-dev build-essential \
    python3-gi python3-gi-cairo \
    gir1.2-glib-2.0 \
    gir1.2-gstreamer-1.0 \
    gir1.2-gst-plugins-base-1.0 \
    gir1.2-gst-plugins-bad-1.0 \
    # Kernel headers (needed to build evdev Python dep)
    linux-headers-generic \
    # PrusaSlicer AppImage runtime deps
    libgl1 libglu1-mesa libgtk-3-0 libdbus-glib-1-2 \
    libnotify4 libsecret-1-0 libfuse2 fuse \
    # WebKit required by PrusaSlicer 2.8.1 newer-distros AppImage
    libwebkit2gtk-4.1-0 \
 && locale-gen en_US.UTF-8 \
 && dpkg-reconfigure --frontend=noninteractive locales \
 && rm -rf /var/lib/apt/lists/*

####################################################
# Intel VA-API driver (requires non-free repo)     #
####################################################
RUN sed -i 's/^Types: deb$/Types: deb\nComponents: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources \
 && apt-get update \
 && apt-get install --no-install-recommends -y intel-media-va-driver-non-free vainfo \
 && rm -rf /var/lib/apt/lists/*

####################################################
# Selkies GStreamer components                     #
####################################################
COPY --from=gstreamer /opt/gstreamer /opt/gstreamer
COPY --from=gst-web   /usr/share/nginx/html /opt/gst-web

####################################################
# Selkies Python wheel                             #
####################################################
COPY --from=py-build /opt/pypi/dist/selkies_gstreamer-0.0.0.dev0-py3-none-any.whl /tmp/selkies_gstreamer-0.0.0.dev0-py3-none-any.whl
RUN apt-get update && apt-get install --no-install-recommends -y \
    linux-headers-generic python3-dev build-essential \
 && rm -rf /var/lib/apt/lists/* \
 && pip3 install --break-system-packages /tmp/selkies_gstreamer-0.0.0.dev0-py3-none-any.whl \
 && rm /tmp/selkies_gstreamer-0.0.0.dev0-py3-none-any.whl

####################################################
# Patch gst-web appName                            #
####################################################  
COPY docker/patch-appname.py /tmp/patch-appname.py
RUN python3 /tmp/patch-appname.py && rm /tmp/patch-appname.py

####################################################
# PrusaSlicer                                      #
####################################################
RUN set -eux; \
    wget -q "https://github.com/prusa3d/PrusaSlicer/releases/download/version_${PRUSA_VERSION}/PrusaSlicer-${PRUSA_VERSION}+linux-x64-newer-distros-GTK3-202409181416.AppImage" \
         -O /opt/PrusaSlicer.AppImage; \
    chmod +x /opt/PrusaSlicer.AppImage; \
    cd /opt && /opt/PrusaSlicer.AppImage --appimage-extract; \
    mv /opt/squashfs-root /opt/PrusaSlicer; \
    rm /opt/PrusaSlicer.AppImage; \
    ln -s /opt/PrusaSlicer/AppRun /usr/local/bin/prusa-slicer

####################################################
# Config files                                     #
#################################################### 
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh    /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Persistent volume for PrusaSlicer profiles + config
VOLUME ["/config"]

# Selkies serves everything directly on 8080
EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
