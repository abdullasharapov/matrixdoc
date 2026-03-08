# Services and Ports

This document describes the services used in the MatrixDoc stack.

| Service | Container | Purpose | Internal Port | External Exposure |
|---|---|---|---|---|
| Traefik | `traefik` | Reverse proxy and TLS termination | 80, 443 | 80, 443 |
| Synapse | `synapse-app` | Matrix homeserver | 8008 | via Traefik |
| Synapse metrics | `synapse-app` | Prometheus metrics endpoint | 8084 | internal |
| PostgreSQL | `synapse-db` | Synapse database | 5432 | internal |
| Element Web | `element-web` | Matrix web client | 80 | via Traefik |
| Coturn | `coturn` | TURN server for WebRTC | 3478 / 5349 | public |
| LiveKit | `livekit` | Media server for Element Call | 7880 | via Traefik |

## TURN ports

Coturn typically requires these ports:

| Port | Protocol | Purpose |
|---|---|---|
| 3478 | TCP/UDP | TURN |
| 5349 | TCP/UDP | TURN TLS |
| 49152-65535 | UDP | Media relay |

These ports should be reachable from the internet.

## LiveKit ports

| Port | Protocol | Purpose |
|---|---|---|
| 7880 | TCP | API |
| 7881 | TCP | WebRTC fallback |
| 50100-50200 | UDP | WebRTC media |

## Internal-only services

These services are not expected to be exposed directly to the internet:

- PostgreSQL
- Synapse metrics
- internal container-to-container communication
