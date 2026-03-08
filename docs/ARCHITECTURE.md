# Architecture Overview

This deployment provides a full Matrix communication stack.

Main components:

-   Synapse --- Matrix homeserver
-   Element Web --- web client
-   Coturn --- TURN server for WebRTC
-   LiveKit --- real-time media server for Element Call
-   Traefik --- reverse proxy and TLS termination
-   PostgreSQL --- Synapse database

------------------------------------------------------------------------

# Traffic Flow

1.  Clients connect via HTTPS.
2.  Traefik handles TLS termination.
3.  Requests are routed to backend services.

Services behind Traefik:

-   Synapse
-   Element Web
-   LiveKit

WebRTC media traffic may use Coturn when direct peer connections fail.

------------------------------------------------------------------------

# Data persistence

Persistent directories:

synapse/data synapse/postgres traefik/data

Generated configuration files:

synapse/data/homeserver.yaml element-web/config.json
coturn/turnserver.conf element-call/livekit/config.yaml

------------------------------------------------------------------------

# Bootstrap workflow

The bootstrap script performs the following steps:

1.  Load `.env`
2.  Validate variables
3.  Verify Docker
4.  Create directories
5.  Ensure Traefik ACME storage
6.  Ensure Docker network
7.  Generate Synapse configuration
8.  Extract Synapse secrets
9.  Render configuration templates
10. Fix Synapse data ownership
