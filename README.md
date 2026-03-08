# MatrixDoc

This repository contains a Docker Compose based deployment of a Matrix stack with:

- Synapse
- Element Web
- LiveKit
- Coturn
- Traefik
- PostgreSQL

Additional documentation is available in the `docs/` directory:

- `docs/ARCHITECTURE.md`
- `docs/SERVICES.md`
- `docs/architecture.mmd`

## Repository layout

```text
.
├── .env
├── .env.example
├── docker-compose.yaml
├── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SERVICES.md
│   └── architecture.mmd
├── scripts/
│   ├── bootstrap_matrixdoc.py
│   └── synapse_user_manage.sh
├── templates/
├── synapse/
│   ├── data/
│   ├── postgres/
│   └── nginx/conf.d/
├── element-web/
├── element-call/livekit/
├── coturn/
└── traefik/data/
```

## Bootstrap

The project includes a bootstrap script:

```bash
sudo python3 scripts/bootstrap_matrixdoc.py
```

The bootstrap script:

- validates `.env`
- verifies Docker and Docker Compose availability
- creates required directories
- creates `traefik-net` if it does not exist
- creates `traefik/data/acme.json` with mode `0600`
- generates the initial Synapse configuration
- extracts and reuses Synapse secrets from the generated config
- renders configuration files from templates
- sets ownership of `synapse/data` to `991:991`

After bootstrap, start the stack with:

```bash
docker compose up -d
```

### Useful bootstrap flags

Verbose mode:

```bash
python3 scripts/bootstrap_matrixdoc.py --verbose
```

Dry run:

```bash
python3 scripts/bootstrap_matrixdoc.py --dry-run
```

Force Synapse base config regeneration:

```bash
python3 scripts/bootstrap_matrixdoc.py --force-regenerate-synapse
```

## First-time deployment

1. Copy the example environment file:

```bash
cp .env.example .env
```

2. Edit `.env` and set all deployment-specific values.

3. Run bootstrap:

```bash
sudo python3 scripts/bootstrap_matrixdoc.py
```

4. Start the stack:

```bash
docker compose up -d
```

## Synapse user management

The repository also includes an interactive helper for Synapse user administration:

```bash
bash scripts/synapse_user_manage.sh
```

This script works with the Synapse Admin API through the running `synapse-app` container.

### Supported operations

- create or update a user
- reset a user password
- suspend a user
- unsuspend a user
- deactivate a user
- fetch user information
- refresh the admin access token during the session

### Authentication methods

The script supports two authentication methods:

1. login with an admin username and password
2. provide an existing Synapse access token

You can also pass the token through the environment:

```bash
export SYNAPSE_ADMIN_TOKEN='...'
bash scripts/synapse_user_manage.sh
```

### Configuration sources

The script reads deployment values from `.env` in the repository root.

The following values are used automatically when present:

- `SYNAPSE_DOMAIN`
- `SYNAPSE_HTTP_PORT`

The following optional overrides are also supported:

- `SYNAPSE_ADMIN_CONTAINER`
- `SYNAPSE_ADMIN_BASE_URL`
- `SYNAPSE_ADMIN_TOKEN`

Default behavior if overrides are not set:

- container: `synapse-app`
- base URL: `http://127.0.0.1:${SYNAPSE_HTTP_PORT:-8008}`

### Requirements for the user management script

Before using the script:

- the `synapse-app` container must be running
- Docker must be installed on the host
- `curl` must be available inside the Synapse container
- the account used for login must have Synapse admin privileges

### Examples

Run with values loaded from `.env`:

```bash
bash scripts/synapse_user_manage.sh
```

Use a custom token without interactive login:

```bash
SYNAPSE_ADMIN_TOKEN='your_token_here' bash scripts/synapse_user_manage.sh
```

Use a custom container name:

```bash
SYNAPSE_ADMIN_CONTAINER='synapse-app' bash scripts/synapse_user_manage.sh
```

## Notes

- Synapse runs in the container as user `991`, therefore the bootstrap script sets ownership of `synapse/data` to `991:991`.
- The repository uses template-generated configuration files.
- Review image tags in `docker-compose.yaml` before production use and pin versions where needed.

## Additional documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Services and Ports](docs/SERVICES.md)
