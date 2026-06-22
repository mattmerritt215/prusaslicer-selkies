# PrusaSlicer — Selkies WebRTC

Browser-accessible PrusaSlicer via [Selkies-GStreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC. 
Run PrusaSlicer in the cloud and slice from any device with a browser — phone, tablet, Chromebook, whatever.

[![Build & Publish](https://github.com/mattmerritt215/prusaslicer-selkies/actions/workflows/build.yml/badge.svg)](https://github.com/YOUR_USER/prusaslicer-selkies/actions/workflows/build.yml)

## Registries

```
ghcr.io/mattmerritt215/prusaslicer-selkies:latest
```

Tags follow PrusaSlicer releases: `:2.8.1`, `:2.9.0`, etc. `:latest` always tracks the most recent stable build.

## Quick start (LAN only, no TURN needed)

```bash
docker run -d \
  --name prusaslicer \
  --network host \
  --shm-size 1gb \
  -v prusaslicer-config:/config \
  ghcr.io/mattmerritt215/prusaslicer-selkies:latest
```

Open `http://YOUR_SERVER_IP:8080` in your browser.

## Full deployment (internet access, with TURN)

```yaml
services:
  prusaslicer:
    image: ghcr.io/mattmerritt215/prusaslicer-selkies:latest
    container_name: prusaslicer
    restart: unless-stopped
    shm_size: "1gb"
    environment:
      - TURN_HOST=your.turn.server
      - TURN_PORT=3478
      - TURN_SECRET=your_secret
      - SELKIES_ENCODER=vah264enc   # or x264enc for software
      - DISPLAY_RESOLUTION=1920x1080x24
    devices:
      - /dev/dri/renderD128:/dev/dri/renderD128   # Intel/AMD VA-API (optional)
    volumes:
      - prusaslicer-config:/config
    ports:
      - "127.0.0.1:8080:8080"

volumes:
  prusaslicer-config:
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `SELKIES_ENCODER` | `vah264enc` | Video encoder. `vah264enc` (Intel/AMD VA-API), `nvh264enc` (NVIDIA), `x264enc` (software) |
| `DISPLAY_RESOLUTION` | `1920x1080x24` | Virtual display resolution passed to Xvfb |
| `TURN_HOST` | *(none)* | Hostname/IP of your TURN server. Required for WebRTC outside LAN |
| `TURN_PORT` | `3478` | TURN server port |
| `TURN_SECRET` | *(none)* | TURN shared secret (time-limited credential mechanism) |
| `TURN_PROTOCOL` | `udp` | `udp` or `tcp` |

## GPU acceleration

### Intel / AMD (VA-API)
Pass the render node into the container:
```yaml
devices:
  - /dev/dri/renderD128:/dev/dri/renderD128
environment:
  - SELKIES_ENCODER=vah264enc
```

### NVIDIA
```yaml
environment:
  - SELKIES_ENCODER=nvh264enc
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

### Software fallback
If no GPU device is present (or VA-API probe fails), the entrypoint automatically falls back to `x264enc`. You can also force it explicitly:
```yaml
environment:
  - SELKIES_ENCODER=x264enc
```

## TURN server

WebRTC requires a TURN server for connections that traverse NAT (i.e. anything outside your LAN). If you're self-hosting, [coTURN](https://github.com/coturn/coturn) is the standard choice.

Minimal `/etc/turnserver.conf`:
```
listening-port=3478
fingerprint
use-auth-secret
static-auth-secret=your_secret
realm=your.domain
min-port=49152
max-port=65535
```

Open UDP 3478 and 49152–65535 on your server.

## Persistent data

All PrusaSlicer profiles, printer configs, filament settings, and sliced files are stored in `/config` inside the container. Mount a named volume or host path to persist them across rebuilds:

```yaml
volumes:
  - /your/host/path:/config
```