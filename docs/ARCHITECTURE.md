# Architecture Overview

This deployment provides a full Matrix communication stack.

Main components:

- Synapse — Matrix homeserver
- Element Web — web client
- Coturn — TURN server for WebRTC
- LiveKit — real-time media server for Element Call
- Traefik — reverse proxy and TLS termination
- PostgreSQL — Synapse database

## Traffic flow

1. Clients connect via HTTPS.
2. Traefik handles TLS termination and routing.
3. Requests are forwarded to backend services:
   - Synapse
   - Element Web
   - LiveKit
4. WebRTC traffic may use Coturn when direct peer-to-peer connectivity is unavailable.

## Data persistence

Persistent directories:

```text
synapse/data
synapse/postgres
traefik/data
```

Generated configuration files:

```text
synapse/data/homeserver.yaml
element-web/config.json
synapse/nginx/conf.d/matrix.conf
coturn/turnserver.conf
element-call/livekit/config.yaml
traefik/data/custom/service.yml
```

## Bootstrap workflow

The bootstrap script performs the following steps:

1. Load `.env`
2. Validate required variables
3. Verify Docker and Docker Compose availability
4. Create required directories
5. Ensure Traefik ACME storage exists with mode `0600`
6. Ensure Docker network `traefik-net` exists
7. Generate the initial Synapse configuration
8. Extract generated Synapse secrets
9. Render configuration files from templates
10. Set ownership of `synapse/data` to `991:991`

After bootstrap, the stack is ready to start with:

```bash
docker compose up -d
```
