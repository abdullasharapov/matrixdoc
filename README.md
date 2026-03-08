# MatrixDoc Deployment Bootstrap

This repository contains a template-driven deployment for a Matrix
communication stack using Docker Compose.

The stack includes:

-   Synapse (Matrix homeserver)
-   Element Web (Matrix client)
-   Coturn (TURN server for WebRTC)
-   LiveKit (media server for Element Call)
-   Traefik (reverse proxy and TLS)
-   PostgreSQL (Synapse database)

All configuration files are generated from templates using a bootstrap
script.

------------------------------------------------------------------------

# What the bootstrap script does

`scripts/bootstrap_matrixdoc.py` prepares the repository for running
with Docker Compose.

The script automatically:

-   Loads configuration from `.env`
-   Validates required environment variables
-   Verifies Docker and Docker Compose availability
-   Creates required directories
-   Ensures Traefik ACME storage exists (`traefik/data/acme.json`) with
    permission `0600`
-   Ensures the external Docker network exists (`traefik-net` by
    default)
-   Generates the initial Synapse configuration using the official
    Synapse Docker workflow
-   Extracts generated secrets from Synapse
-   Renders configuration files from templates
-   Sets correct ownership (`991:991`) on `synapse/data`
-   Writes `.bootstrap.state.json` marker file

The bootstrap script is safe to run multiple times.

------------------------------------------------------------------------

# Repository layout

├── .env
├── docker-compose.yaml
├── scripts/
│   └── bootstrap_matrixdoc.py
├── templates/
│   ├── homeserver.yaml.tpl
│   ├── element-config.json.tpl
│   ├── matrix.conf.tpl
│   ├── turnserver.conf.tpl
│   └── livekit.yaml.tpl
├── synapse/
│   ├── data/
│   ├── postgres/
│   └── nginx/conf.d/
├── element-web/
├── element-call/livekit/
├── coturn/
└── traefik/data/
└── docs
------------------------------------------------------------------------

# Prerequisites

The following software must be installed:

-   Docker Engine
-   Docker Compose plugin

The bootstrap script will automatically verify these requirements.

------------------------------------------------------------------------

# First-time deployment

1.  Copy the environment template

cp .env.example .env

2.  Edit `.env` and configure all required variables.

3.  Run the bootstrap script

sudo python3 scripts/bootstrap_matrixdoc.py

The script will:

-   create required directories
-   create the Docker network `traefik-net` if needed
-   generate the Synapse configuration
-   render all configuration templates

4.  Start the stack

docker compose up -d

------------------------------------------------------------------------

# Regenerating Synapse configuration

If you want to regenerate the Synapse base configuration:

python3 scripts/bootstrap_matrixdoc.py --force-regenerate-synapse

------------------------------------------------------------------------

# Additional documentation

See the docs directory:

-   docs/ARCHITECTURE.md
-   docs/SERVICES.md
