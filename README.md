# MatrixDoc deployment bootstrap

This package converts the repository into a template-driven deployment.

## What is included

- `docker-compose.yaml` aligned with the repository directory layout.
- `scripts/bootstrap_matrixdoc.py` to generate and render configs.
- `.env.example` with deployment-specific variables.
- Templates for:
  - `synapse/data/homeserver.yaml`
  - `element-web/config.json`
  - `synapse/nginx/conf.d/matrix.conf`
  - `coturn/turnserver.conf`
  - `element-call/livekit/config.yaml`

## Directory layout expected by the compose file

```text
.
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
```

## Prerequisites

- Docker Engine with Docker Compose plugin.
- A pre-created external Docker network named `traefik-net`.
- DNS records for the Synapse, Element, LiveKit, and TURN domains.
- Traefik configuration and certificate storage under `traefik/data/`.

## First-time setup

1. Copy `.env.example` to `.env`.
2. Update all values in `.env`.
3. Make sure the external Docker network exists:

   ```bash
   docker network create traefik-net
   ```

4. Run the bootstrap script:

   ```bash
   python3 scripts/bootstrap_matrixdoc.py
   ```

   The script will:
   - create missing directories;
   - generate the initial Synapse config using the official Synapse Docker workflow;
   - reuse the generated Synapse secrets;
   - render all final configs from templates.

5. Start the stack:

   ```bash
   docker compose up -d
   ```

## Regenerating the Synapse base config

If you want to regenerate the Synapse-generated base file before rendering templates, run:

```bash
python3 scripts/bootstrap_matrixdoc.py --force-generate
```

## Important notes

- `synapse/data/homeserver.yaml` is generated from the template after the Synapse `generate` step.
- Secrets such as `registration_shared_secret`, `macaroon_secret_key`, and `form_secret` are taken from the generated Synapse file and reused.
- Coturn certificates are expected at:

  ```text
  traefik/data/certs/${TURN_CERT_DOMAIN}/fullchain.crt
  traefik/data/certs/${TURN_CERT_DOMAIN}/privkey.key
  ```

- The compose file still uses several `latest` tags. Pin image versions before using this in production.
- The template values for Element still include upstream defaults such as Scalar and PostHog endpoints. Review them before production use.

## Generated files

After a successful bootstrap, these files will exist or be updated:

- `synapse/data/homeserver.yaml`
- `element-web/config.json`
- `synapse/nginx/conf.d/matrix.conf`
- `coturn/turnserver.conf`
- `element-call/livekit/config.yaml`

## Minimal deployment flow

```bash
cp .env.example .env
vi .env
python3 scripts/bootstrap_matrixdoc.py
docker compose up -d
```
