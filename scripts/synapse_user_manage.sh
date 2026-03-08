#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$PROJECT_DIR/.env}"

CONTAINER="${SYNAPSE_ADMIN_CONTAINER:-synapse-app}"
DOMAIN="${SYNAPSE_DOMAIN:-}"
HTTP_PORT="${SYNAPSE_HTTP_PORT:-8008}"
BASE_URL="${SYNAPSE_ADMIN_BASE_URL:-http://127.0.0.1:${HTTP_PORT}}"
TOKEN="${SYNAPSE_ADMIN_TOKEN:-}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 2
  }
}

strip_quotes() {
  local value="$1"
  if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^'.*'$ ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

load_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    local line="$raw_line"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue

    if [[ "$line" == export* ]]; then
      line="${line#export }"
      line="${line#"${line%%[![:space:]]*}"}"
    fi

    [[ "$line" == *=* ]] || continue

    local key="${line%%=*}"
    local value="${line#*=}"

    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="$(strip_quotes "$value")"

    case "$key" in
      SYNAPSE_DOMAIN)
        [[ -z "${SYNAPSE_DOMAIN:-}" ]] && DOMAIN="$value"
        ;;
      SYNAPSE_HTTP_PORT)
        [[ -z "${SYNAPSE_HTTP_PORT:-}" ]] && HTTP_PORT="$value"
        ;;
      SYNAPSE_ADMIN_CONTAINER)
        [[ -z "${SYNAPSE_ADMIN_CONTAINER:-}" ]] && CONTAINER="$value"
        ;;
      SYNAPSE_ADMIN_BASE_URL)
        [[ -z "${SYNAPSE_ADMIN_BASE_URL:-}" ]] && BASE_URL="$value"
        ;;
      SYNAPSE_ADMIN_TOKEN)
        [[ -z "${SYNAPSE_ADMIN_TOKEN:-}" ]] && TOKEN="$value"
        ;;
    esac
  done < "$file"

  if [[ -z "${SYNAPSE_ADMIN_BASE_URL:-}" ]]; then
    BASE_URL="http://127.0.0.1:${HTTP_PORT}"
  fi
}

prompt() {
  local text="$1"
  local var
  read -r -p "$text" var
  echo "$var"
}

prompt_hidden() {
  local text="$1"
  local var
  read -r -s -p "$text" var
  printf '\n' >&2
  printf '%s' "$var"
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  echo "$s"
}

normalize_user() {
  local input="$1"
  if [[ "$input" == @*:* ]]; then
    echo "$input"
  else
    input="${input#@}"
    echo "@${input}:${DOMAIN}"
  fi
}

docker_curl() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local cmd=(docker exec -i "$CONTAINER" sh -lc)

  if [[ -n "$body" ]]; then
    "${cmd[@]}" "curl -sS -w '\nHTTP_CODE:%{http_code}\n' -X $method       -H \"Authorization: Bearer $TOKEN\"       -H \"Content-Type: application/json\"       \"$url\"       --data-binary '$body'"
  else
    "${cmd[@]}" "curl -sS -w '\nHTTP_CODE:%{http_code}\n' -X $method       -H \"Authorization: Bearer $TOKEN\"       -H \"Content-Type: application/json\"       \"$url\""
  fi
}

print_result() {
  local out="$1"
  local code
  local body

  code="$(echo "$out" | sed -n 's/^HTTP_CODE:\([0-9][0-9][0-9]\)$/\1/p' | tail -n1)"
  body="$(echo "$out" | sed '/^HTTP_CODE:/,$d')"

  if [[ -n "$body" ]]; then
    echo "$body"
  fi

  if [[ -z "$code" ]]; then
    echo "ERROR: could not parse HTTP code" >&2
    return 1
  fi

  if [[ "$code" =~ ^2 ]]; then
    echo "OK (HTTP $code)"
    return 0
  fi

  echo "ERROR (HTTP $code)" >&2
  return 1
}

confirm() {
  local text="$1"
  local ans
  read -r -p "$text [y/N]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

get_access_token_by_login() {
  local localpart pass mxid u_e p_e body url out token_line

  localpart="$(prompt "Admin login (localpart, e.g. admin): ")"
  localpart="${localpart#@}"
  mxid="@${localpart}:${DOMAIN}"

  pass="$(prompt_hidden "Password (hidden): ")"

  u_e="$(json_escape "$mxid")"
  p_e="$(json_escape "$pass")"
  body="{\"type\":\"m.login.password\",\"user\":\"$u_e\",\"password\":\"$p_e\"}"
  url="$BASE_URL/_matrix/client/r0/login"

  echo
  echo "Logging in as: $mxid"
  out="$(docker exec -i "$CONTAINER" sh -lc     "curl -sS -w '\nHTTP_CODE:%{http_code}\n' -X POST       -H \"Content-Type: application/json\"       \"$url\"       --data-binary '$body'")"

  if ! print_result "$out"; then
    return 1
  fi

  token_line="$(echo "$out" | sed '/^HTTP_CODE:/,$d' | tr -d '\n' | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  if [[ -z "$token_line" ]]; then
    echo "ERROR: access_token not found in response" >&2
    return 1
  fi

  TOKEN="$token_line"
  echo
  echo "Token acquired and stored in memory for this session."
}

ensure_auth() {
  if [[ -n "${TOKEN:-}" ]]; then
    return 0
  fi

  echo "No token set. Choose auth method:"
  echo "1) Login with password (localpart)"
  echo "2) Paste existing access_token"
  local choice
  read -r -p "Select [1/2]: " choice

  case "$choice" in
    1) get_access_token_by_login ;;
    2) TOKEN="$(prompt_hidden "Paste access_token (hidden): ")" ;;
    *) echo "Unknown choice" >&2; exit 2 ;;
  esac

  if [[ -z "${TOKEN:-}" ]]; then
    echo "ERROR: token is empty" >&2
    exit 2
  fi
}

preflight() {
  need_cmd docker

  if [[ -z "$DOMAIN" ]]; then
    echo "ERROR: SYNAPSE_DOMAIN is not set. Define it in .env or export SYNAPSE_DOMAIN." >&2
    exit 2
  fi

  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "ERROR: container not running or not found: $CONTAINER" >&2
    exit 2
  fi

  if ! docker exec -i "$CONTAINER" sh -lc 'command -v curl >/dev/null 2>&1'; then
    echo "ERROR: curl not found inside container $CONTAINER" >&2
    exit 2
  fi

  ensure_auth
}

action_create_user() {
  local u_raw mxid pass disp admin_flag admin_json pass_e disp_e body url out
  u_raw="$(prompt "New user (localpart or full @user:domain): ")"
  mxid="$(normalize_user "$u_raw")"

  pass="$(prompt_hidden "Password (hidden): ")"
  disp="$(prompt "Display name (optional, press Enter to skip): ")"
  admin_flag="$(prompt "Admin? (y/N): ")"

  admin_json="false"
  if [[ "$admin_flag" == "y" || "$admin_flag" == "Y" ]]; then
    admin_json="true"
  fi

  pass_e="$(json_escape "$pass")"
  disp_e="$(json_escape "$disp")"

  if [[ -n "$disp" ]]; then
    body="{\"password\":\"$pass_e\",\"displayname\":\"$disp_e\",\"admin\":$admin_json}"
  else
    body="{\"password\":\"$pass_e\",\"admin\":$admin_json}"
  fi

  echo
  echo "Creating or updating user: $mxid"
  url="$BASE_URL/_synapse/admin/v2/users/$mxid"
  out="$(docker_curl PUT "$url" "$body")"
  print_result "$out"
}

action_reset_password() {
  local u_raw mxid newpass logout_ans logout_json np_e body url out
  u_raw="$(prompt "User (localpart or full @user:domain): ")"
  mxid="$(normalize_user "$u_raw")"

  newpass="$(prompt_hidden "New password (hidden): ")"
  logout_ans="$(prompt "Logout devices? (Y/n): ")"

  logout_json="true"
  if [[ "$logout_ans" == "n" || "$logout_ans" == "N" ]]; then
    logout_json="false"
  fi

  np_e="$(json_escape "$newpass")"
  body="{\"new_password\":\"$np_e\",\"logout_devices\":$logout_json}"

  echo
  echo "Resetting password for: $mxid"
  url="$BASE_URL/_synapse/admin/v1/reset_password/$mxid"
  out="$(docker_curl POST "$url" "$body")"
  print_result "$out"
}

action_suspend() {
  local u_raw mxid body url out
  u_raw="$(prompt "User (localpart or full @user:domain): ")"
  mxid="$(normalize_user "$u_raw")"

  body='{"suspend":true}'
  echo
  echo "Suspending user: $mxid"
  url="$BASE_URL/_synapse/admin/v1/suspend/$mxid"
  out="$(docker_curl PUT "$url" "$body")"
  print_result "$out"
}

action_unsuspend() {
  local u_raw mxid body url out
  u_raw="$(prompt "User (localpart or full @user:domain): ")"
  mxid="$(normalize_user "$u_raw")"

  body='{"suspend":false}'
  echo
  echo "Unsuspending user: $mxid"
  url="$BASE_URL/_synapse/admin/v1/suspend/$mxid"
  out="$(docker_curl PUT "$url" "$body")"
  print_result "$out"
}

action_deactivate() {
  local u_raw mxid erase_ans erase_json body url out
  u_raw="$(prompt "User (localpart or full @user:domain): ")"
  mxid="$(normalize_user "$u_raw")"

  echo
  echo "WARNING: deactivation is a destructive action."
  if ! confirm "Proceed to deactivate $mxid?"; then
    echo "Cancelled."
    return 0
  fi

  erase_ans="$(prompt "Erase user data? (y/N): ")"
  erase_json="false"
  if [[ "$erase_ans" == "y" || "$erase_ans" == "Y" ]]; then
    erase_json="true"
  fi

  body="{\"erase\":$erase_json}"

  echo
  echo "Deactivating user: $mxid (erase=$erase_json)"
  url="$BASE_URL/_synapse/admin/v1/deactivate/$mxid"
  out="$(docker_curl POST "$url" "$body")"
  print_result "$out"
}

action_get_user() {
  local u_raw mxid url out
  u_raw="$(prompt "User (localpart or full @user:domain): ")"
  mxid="$(normalize_user "$u_raw")"

  echo
  echo "Fetching user info: $mxid"
  url="$BASE_URL/_synapse/admin/v2/users/$mxid"
  out="$(docker_curl GET "$url")"
  print_result "$out"
}

action_relogin() {
  TOKEN=""
  get_access_token_by_login
}

menu() {
  cat <<EOF

Synapse Admin
  container : $CONTAINER
  domain    : $DOMAIN
  base URL  : $BASE_URL
  env file  : $ENV_FILE

1) Create user
2) Reset password
3) Suspend user
4) Unsuspend user
5) Deactivate user (dangerous)
6) Get user info
7) Re-login (refresh token)
0) Exit

EOF
}

main() {
  load_env_file "$ENV_FILE"
  preflight

  while true; do
    menu
    local choice
    read -r -p "Select: " choice
    case "$choice" in
      1) action_create_user ;;
      2) action_reset_password ;;
      3) action_suspend ;;
      4) action_unsuspend ;;
      5) action_deactivate ;;
      6) action_get_user ;;
      7) action_relogin ;;
      0) echo "Bye."; exit 0 ;;
      *) echo "Unknown option: $choice" ;;
    esac
  done
}

main
