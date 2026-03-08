#!/usr/bin/env python3
"""
Production-ready bootstrap script for the matrixdoc project.

What it does:
- Loads variables from .env in the project root
- Validates required variables
- Verifies Docker and Docker Compose availability
- Creates required directories
- Ensures Traefik ACME storage exists with mode 0600
- Ensures external Docker network exists (traefik-net by default)
- Generates the initial Synapse homeserver.yaml via the official Docker flow
- Reuses secrets from the generated/existing homeserver.yaml
- Renders all project config files from templates
- Is safe to run repeatedly

This script uses only Python standard library modules.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import textwrap
from pathlib import Path
from string import Template
from typing import Dict, Iterable, List, Mapping, MutableMapping


PROJECT_DIR = Path(__file__).resolve().parents[1]
ENV_FILE = PROJECT_DIR / ".env"
TEMPLATES_DIR = PROJECT_DIR / "templates"
SYNAPSE_DATA_DIR = PROJECT_DIR / "synapse" / "data"

DEFAULTS = {
    "TRAEFIK_EXTERNAL_NETWORK": "traefik-net",
    "SYNAPSE_IMAGE": "docker.io/matrixdotorg/synapse:latest",
    "SYNAPSE_CONFIG_PATH": "/data/homeserver.yaml",
    "SYNAPSE_REPORT_STATS": "no",
    "TRAEFIK_ACME_FILE": "traefik/data/acme.json",
    "TRAEFIK_SERVICE_FILE": "traefik/data/custom/service.yml",
    "COTURN_HOST": "coturn",
    "COTURN_PORT": "3478",
    "POSTGRES_DB": "synapse",
    "POSTGRES_PORT": "5432",
    "POSTGRES_HOST": "synapse-db",
    "SYNAPSE_HTTP_PORT": "8008",
    "SYNAPSE_METRICS_PORT": "8084",
    "LIVEKIT_JWT_PORT": "8080",
    "LIVEKIT_PORT": "7880",
    "LIVEKIT_RTC_TCP_PORT": "7881",
    "LIVEKIT_RTC_UDP_PORT_START": "50100",
    "LIVEKIT_RTC_UDP_PORT_END": "50200",
    "TURN_TLS_PORT": "5349",
    "TURN_MIN_PORT": "49152",
    "TURN_MAX_PORT": "65535",
    "TURN_CERT_DIR": "/certs",
}

REQUIRED_VARS = [
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "SYNAPSE_DOMAIN",
    "ELEMENT_URL",
    "LIVEKIT_KEY",
    "LIVEKIT_SECRET",
    "LIVEKIT_BASE_URL",
    "LIVEKIT_FULL_ACCESS_HOMESERVERS",
    "TURN_DOMAIN",
    "TURN_EXTERNAL_IP",
    "TURN_SHARED_SECRET",
    "TURN_USER",
    "TURN_PASSWORD",
]

TEMPLATE_TARGETS = {
    "homeserver.yaml.tpl": PROJECT_DIR / "synapse" / "data" / "homeserver.yaml",
    "element-config.json.tpl": PROJECT_DIR / "element-web" / "config.json",
    "matrix.conf.tpl": PROJECT_DIR / "synapse" / "nginx" / "conf.d" / "matrix.conf",
    "turnserver.conf.tpl": PROJECT_DIR / "coturn" / "turnserver.conf",
    "livekit.yaml.tpl": PROJECT_DIR / "element-call" / "livekit" / "config.yaml",
    "traefik-service.yml.tpl": PROJECT_DIR / "traefik" / "data" / "custom" / "service.yml",
}

DIRECTORIES = [
    PROJECT_DIR / "scripts",
    PROJECT_DIR / "templates",
    PROJECT_DIR / "synapse" / "data",
    PROJECT_DIR / "synapse" / "postgres",
    PROJECT_DIR / "synapse" / "nginx" / "conf.d",
    PROJECT_DIR / "element-web",
    PROJECT_DIR / "element-call" / "livekit",
    PROJECT_DIR / "coturn",
    PROJECT_DIR / "traefik" / "data",
    PROJECT_DIR / "traefik" / "data" / "custom",
    PROJECT_DIR / "traefik" / "data" / "certs",
]

SECRET_KEYS = [
    "registration_shared_secret",
    "macaroon_secret_key",
    "form_secret",
]


class BootstrapError(RuntimeError):
    pass


class Logger:
    def __init__(self, verbose: bool = False) -> None:
        self.verbose = verbose

    def info(self, message: str) -> None:
        print(f"[INFO] {message}")

    def warn(self, message: str) -> None:
        print(f"[WARN] {message}")

    def error(self, message: str) -> None:
        print(f"[ERROR] {message}", file=sys.stderr)

    def debug(self, message: str) -> None:
        if self.verbose:
            print(f"[DEBUG] {message}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Bootstrap a matrixdoc deployment into a docker-compose-ready state."
    )
    parser.add_argument(
        "--project-dir",
        default=str(PROJECT_DIR),
        help="Path to the matrixdoc project root. Default: script parent root.",
    )
    parser.add_argument(
        "--env-file",
        default=None,
        help="Path to the .env file. Default: <project-dir>/.env",
    )
    parser.add_argument(
        "--force-regenerate-synapse",
        action="store_true",
        help="Regenerate the initial Synapse config even if homeserver.yaml already exists.",
    )
    parser.add_argument(
        "--skip-docker-checks",
        action="store_true",
        help="Skip Docker, Docker Compose, and Docker network checks.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and print planned actions without writing files or invoking Docker.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    log = Logger(verbose=args.verbose)

    project_dir = Path(args.project_dir).resolve()
    env_file = Path(args.env_file).resolve() if args.env_file else project_dir / ".env"

    try:
        run_bootstrap(
            project_dir=project_dir,
            env_file=env_file,
            force_regenerate_synapse=args.force_regenerate_synapse,
            skip_docker_checks=args.skip_docker_checks,
            dry_run=args.dry_run,
            log=log,
        )
    except BootstrapError as exc:
        log.error(str(exc))
        return 1
    except KeyboardInterrupt:
        log.error("Interrupted.")
        return 130
    return 0


def run_bootstrap(
    *,
    project_dir: Path,
    env_file: Path,
    force_regenerate_synapse: bool,
    skip_docker_checks: bool,
    dry_run: bool,
    log: Logger,
) -> None:
    log.info(f"Project directory: {project_dir}")
    log.info(f"Environment file: {env_file}")

    ensure_exists(project_dir, "Project directory")
    ensure_exists(env_file, ".env file")

    env = load_env_file(env_file)
    apply_defaults(env)
    env["PROJECT_DIR"] = str(project_dir)

    validate_required_vars(env)
    validate_templates(project_dir)
    validate_value_shapes(env)

    if not skip_docker_checks:
        ensure_docker_available(log)
        ensure_docker_compose_available(log)

    create_directories(project_dir, dry_run, log)
    ensure_acme_storage(project_dir, env, dry_run, log)

    if not skip_docker_checks:
        ensure_external_network(env["TRAEFIK_EXTERNAL_NETWORK"], dry_run, log)

    synapse_secrets = obtain_synapse_secrets(
        project_dir=project_dir,
        env=env,
        force_regenerate=force_regenerate_synapse,
        skip_docker_checks=skip_docker_checks,
        dry_run=dry_run,
        log=log,
    )
    env.update(synapse_secrets)

    render_all_templates(project_dir, env, dry_run, log)
    write_bootstrap_marker(project_dir, dry_run, log)

    log.info("Bootstrap completed successfully.")
    log.info("The project should now be ready for: docker compose up -d")


def ensure_exists(path: Path, label: str) -> None:
    if not path.exists():
        raise BootstrapError(f"{label} not found: {path}")


def load_env_file(path: Path) -> Dict[str, str]:
    env: Dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            raise BootstrapError(f"Invalid .env line without '=': {raw_line}")
        key, value = line.split("=", 1)
        key = key.strip()
        value = strip_env_quotes(value.strip())
        env[key] = value
    return env


def strip_env_quotes(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def apply_defaults(env: MutableMapping[str, str]) -> None:
    for key, value in DEFAULTS.items():
        env.setdefault(key, value)


def validate_required_vars(env: Mapping[str, str]) -> None:
    missing = [key for key in REQUIRED_VARS if not env.get(key)]
    if missing:
        raise BootstrapError(
            "Missing required variables in .env: " + ", ".join(sorted(missing))
        )


def validate_templates(project_dir: Path) -> None:
    missing = []
    for template_name in TEMPLATE_TARGETS:
        template_path = project_dir / "templates" / template_name
        if not template_path.exists():
            missing.append(str(template_path))
    if missing:
        raise BootstrapError(
            "The following template files are missing:\n" + "\n".join(missing)
        )


def validate_value_shapes(env: Mapping[str, str]) -> None:
    host_like = [
        "SYNAPSE_DOMAIN",
        "ELEMENT_URL",
        "LIVEKIT_BASE_URL",
        "TURN_DOMAIN",
    ]
    for key in host_like:
        value = env.get(key, "")
        if "://" in value or "/" in value:
            raise BootstrapError(
                f"{key} must contain a hostname only, without scheme or path: {value}"
            )

    integer_like = [
        "COTURN_PORT",
        "POSTGRES_PORT",
        "SYNAPSE_HTTP_PORT",
        "SYNAPSE_METRICS_PORT",
        "LIVEKIT_JWT_PORT",
        "LIVEKIT_PORT",
        "LIVEKIT_RTC_TCP_PORT",
        "LIVEKIT_RTC_UDP_PORT_START",
        "LIVEKIT_RTC_UDP_PORT_END",
        "TURN_TLS_PORT",
        "TURN_MIN_PORT",
        "TURN_MAX_PORT",
    ]
    for key in integer_like:
        value = env.get(key, "")
        if not value.isdigit():
            raise BootstrapError(f"{key} must be an integer, got: {value}")


def ensure_docker_available(log: Logger) -> None:
    docker_path = shutil.which("docker")
    if not docker_path:
        raise BootstrapError("Docker is not installed or not available in PATH.")
    log.debug(f"Docker binary: {docker_path}")
    run_command(["docker", "version"], check=True, capture_output=True)
    log.info("Docker is available.")


def ensure_docker_compose_available(log: Logger) -> None:
    run_command(["docker", "compose", "version"], check=True, capture_output=True)
    log.info("Docker Compose plugin is available.")


def create_directories(project_dir: Path, dry_run: bool, log: Logger) -> None:
    log.info("Ensuring required directories exist.")
    rel_dirs = [
        Path("scripts"),
        Path("templates"),
        Path("synapse/data"),
        Path("synapse/postgres"),
        Path("synapse/nginx/conf.d"),
        Path("element-web"),
        Path("element-call/livekit"),
        Path("coturn"),
        Path("traefik/data"),
        Path("traefik/data/custom"),
        Path("traefik/data/certs"),
    ]
    for rel_dir in rel_dirs:
        target = project_dir / rel_dir
        log.debug(f"Directory: {target}")
        if not dry_run:
            target.mkdir(parents=True, exist_ok=True)


def ensure_acme_storage(project_dir: Path, env: Mapping[str, str], dry_run: bool, log: Logger) -> None:
    acme_rel = Path(env["TRAEFIK_ACME_FILE"])
    acme_file = project_dir / acme_rel
    log.info(f"Ensuring Traefik ACME file exists with mode 0600: {acme_file}")

    if dry_run:
        return

    acme_file.parent.mkdir(parents=True, exist_ok=True)
    if not acme_file.exists():
        acme_file.write_text("{}\n", encoding="utf-8")
    os.chmod(acme_file, 0o600)

    current_mode = stat.S_IMODE(acme_file.stat().st_mode)
    if current_mode != 0o600:
        raise BootstrapError(
            f"Failed to set permissions 0600 on {acme_file}. Current mode: {oct(current_mode)}"
        )


def ensure_external_network(network_name: str, dry_run: bool, log: Logger) -> None:
    log.info(f"Ensuring Docker network exists: {network_name}")
    result = run_command(
        ["docker", "network", "inspect", network_name],
        check=False,
        capture_output=True,
    )
    if result.returncode == 0:
        log.info(f"Docker network already exists: {network_name}")
        return

    if dry_run:
        log.info(f"[dry-run] Would create Docker network: {network_name}")
        return

    run_command(["docker", "network", "create", network_name], check=True)
    log.info(f"Created Docker network: {network_name}")


def obtain_synapse_secrets(
    *,
    project_dir: Path,
    env: Mapping[str, str],
    force_regenerate: bool,
    skip_docker_checks: bool,
    dry_run: bool,
    log: Logger,
) -> Dict[str, str]:
    homeserver_file = project_dir / "synapse" / "data" / "homeserver.yaml"

    if homeserver_file.exists() and not force_regenerate:
        log.info(f"Using existing Synapse config for secret extraction: {homeserver_file}")
        return extract_synapse_secrets(homeserver_file, log)

    if dry_run:
        log.info("[dry-run] Would generate Synapse base config via official Docker flow.")
        return {
            "REGISTRATION_SHARED_SECRET": "__dry_run__",
            "MACAROON_SECRET_KEY": "__dry_run__",
            "FORM_SECRET": "__dry_run__",
        }

    if skip_docker_checks:
        raise BootstrapError(
            "Cannot generate Synapse config because Docker checks were skipped and no homeserver.yaml exists."
        )

    generate_synapse_config(project_dir=project_dir, env=env, log=log)
    if not homeserver_file.exists():
        raise BootstrapError(
            f"Synapse config generation did not produce {homeserver_file}"
        )
    return extract_synapse_secrets(homeserver_file, log)


def generate_synapse_config(*, project_dir: Path, env: Mapping[str, str], log: Logger) -> None:
    log.info("Generating initial Synapse config via official Docker flow.")

    data_dir = project_dir / "synapse" / "data"
    image = env["SYNAPSE_IMAGE"]

    command = [
        "docker",
        "run",
        "--rm",
        "-e",
        f"SYNAPSE_SERVER_NAME={env['SYNAPSE_DOMAIN']}",
        "-e",
        f"SYNAPSE_REPORT_STATS={env['SYNAPSE_REPORT_STATS']}",
        "-e",
        f"SYNAPSE_CONFIG_PATH={env['SYNAPSE_CONFIG_PATH']}",
        "-v",
        f"{data_dir}:/data",
        image,
        "generate",
    ]

    result = run_command(command, check=False, capture_output=True)
    if result.returncode != 0:
        raise BootstrapError(
            "Synapse config generation failed.\n"
            f"Command: {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
    log.info("Synapse base config generation completed.")


def extract_synapse_secrets(homeserver_file: Path, log: Logger) -> Dict[str, str]:
    text = homeserver_file.read_text(encoding="utf-8")
    result: Dict[str, str] = {}
    mapping = {
        "registration_shared_secret": "REGISTRATION_SHARED_SECRET",
        "macaroon_secret_key": "MACAROON_SECRET_KEY",
        "form_secret": "FORM_SECRET",
    }

    for source_key, env_key in mapping.items():
        value = extract_yaml_scalar(text, source_key)
        if not value:
            raise BootstrapError(
                f"Could not extract '{source_key}' from {homeserver_file}."
            )
        result[env_key] = value
        log.debug(f"Extracted Synapse secret: {env_key}")

    return result


def extract_yaml_scalar(text: str, key: str) -> str | None:
    pattern = re.compile(rf"(?m)^\s*{re.escape(key)}\s*:\s*(.+?)\s*$")
    match = pattern.search(text)
    if not match:
        return None

    raw_value = match.group(1).strip()
    if raw_value.startswith(("'", '"')) and raw_value.endswith(("'", '"')) and len(raw_value) >= 2:
        return raw_value[1:-1]
    return raw_value


def render_all_templates(project_dir: Path, env: Mapping[str, str], dry_run: bool, log: Logger) -> None:
    log.info("Rendering configuration files from templates.")
    for template_name, output_path in TEMPLATE_TARGETS.items():
        template_path = project_dir / "templates" / template_name
        render_template(template_path, output_path, env, dry_run, log)


def render_template(
    template_path: Path,
    output_path: Path,
    env: Mapping[str, str],
    dry_run: bool,
    log: Logger,
) -> None:
    log.info(f"Rendering {output_path}")
    template_content = template_path.read_text(encoding="utf-8")

    try:
        rendered = Template(template_content).substitute(env)
    except KeyError as exc:
        raise BootstrapError(
            f"Template {template_path} requires missing variable: {exc.args[0]}"
        ) from exc

    if dry_run:
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered.rstrip() + "\n", encoding="utf-8")


def write_bootstrap_marker(project_dir: Path, dry_run: bool, log: Logger) -> None:
    marker = project_dir / ".bootstrap.state.json"
    payload = {
        "status": "completed",
        "files": [str(path.relative_to(project_dir)) for path in TEMPLATE_TARGETS.values()],
    }
    log.info(f"Writing bootstrap state marker: {marker}")
    if dry_run:
        return
    marker.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def run_command(
    command: List[str],
    *,
    check: bool,
    capture_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    kwargs = {
        "text": True,
        "encoding": "utf-8",
    }
    if capture_output:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE

    result = subprocess.run(command, **kwargs)  # noqa: S603,S607
    if check and result.returncode != 0:
        stdout = getattr(result, "stdout", "") or ""
        stderr = getattr(result, "stderr", "") or ""
        raise BootstrapError(
            "Command failed.\n"
            f"Command: {' '.join(command)}\n"
            f"Exit code: {result.returncode}\n"
            f"stdout:\n{stdout}\n"
            f"stderr:\n{stderr}"
        )
    return result


if __name__ == "__main__":
    sys.exit(main())
