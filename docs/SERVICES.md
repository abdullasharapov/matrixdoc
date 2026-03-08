# Services and Ports

This document describes all services used in the MatrixDoc stack.

  Service           Container     Purpose               Internal Port   External
  ----------------- ------------- --------------------- --------------- -------------
  Traefik           traefik       Reverse proxy / TLS   80, 443         80, 443
  Synapse           synapse-app   Matrix homeserver     8008            via Traefik
  Synapse metrics   synapse-app   Metrics endpoint      8084            internal
  PostgreSQL        synapse-db    Database              5432            internal
  Element Web       element-web   Matrix web client     80              via Traefik
  Coturn            coturn        TURN server           3478 / 5349     public
  LiveKit           livekit       Media server          7880            via Traefik

------------------------------------------------------------------------

# TURN ports

Coturn requires the following ports:

3478 TCP/UDP\
5349 TCP/UDP\
49152--65535 UDP

These must be reachable from the internet.

------------------------------------------------------------------------

# LiveKit ports

7880 TCP -- API\
7881 TCP -- WebRTC fallback\
50100--50200 UDP -- media traffic
