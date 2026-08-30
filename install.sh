#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install.sh <domain> <acme-email>

Example:
  install.sh chat.example.com owner@example.com

Environment overrides:
  CYBERCORD_INSTALL_DIR  Destination directory (default: $HOME/cybercord)
  CYBERCORD_IMAGE        Server image (default: ghcr.io/ramborogers/cybercord-server:2.0.0)
USAGE
}

[[ "$#" -eq 2 ]] || {
  usage >&2
  exit 2
}

DOMAIN="$1"
EMAIL="$2"
INSTALL_DIR="${CYBERCORD_INSTALL_DIR:-$HOME/cybercord}"
CYBERCORD_IMAGE="${CYBERCORD_IMAGE:-ghcr.io/ramborogers/cybercord-server:2.0.0}"
RAW_BASE="${CYBERCORD_RAW_BASE:-https://raw.githubusercontent.com/RamboRogers/cybercordnow/main}"

if [[ "${#DOMAIN}" -gt 253 ]] || ! [[ "$DOMAIN" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
  printf 'error: domain must be a DNS name such as chat.example.com (no scheme or path)\n' >&2
  exit 2
fi
if ! [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$ ]]; then
  printf 'error: ACME email is invalid\n' >&2
  exit 2
fi

for command_name in curl docker mktemp install; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$command_name" >&2
    exit 1
  }
done
docker compose version >/dev/null 2>&1 || {
  printf 'error: Docker Compose v2 is required (docker compose)\n' >&2
  exit 1
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cybercord-install.XXXXXX")"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

for relative_path in compose.yaml .env.example caddy/Caddyfile; do
  destination="$WORK_DIR/$relative_path"
  mkdir -p "$(dirname "$destination")"
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
    "$RAW_BASE/$relative_path" -o "$destination"
  [[ -s "$destination" ]] || {
    printf 'error: downloaded file is empty: %s\n' "$relative_path" >&2
    exit 1
  }
done

mkdir -p "$INSTALL_DIR/caddy"
install -m 0644 "$WORK_DIR/compose.yaml" "$INSTALL_DIR/compose.yaml"
install -m 0644 "$WORK_DIR/.env.example" "$INSTALL_DIR/.env.example"
install -m 0644 "$WORK_DIR/caddy/Caddyfile" "$INSTALL_DIR/caddy/Caddyfile"

cat >"$WORK_DIR/.env" <<EOF
CYBERCORD_DOMAIN=$DOMAIN
ACME_EMAIL=$EMAIL
CYBERCORD_IMAGE=$CYBERCORD_IMAGE
CYBERCORD_HTTP_PORT=80
CYBERCORD_HTTPS_PORT=443
CYBERCORD_INTERNAL_SUBNET=172.30.239.0/24
CADDY_INTERNAL_IP=172.30.239.2
CYBERCORD_INTERNAL_IP=172.30.239.3
EOF
if [[ ! -e "$INSTALL_DIR/.env" ]]; then
  install -m 0600 "$WORK_DIR/.env" "$INSTALL_DIR/.env"
else
  [[ -f "$INSTALL_DIR/.env" && ! -L "$INSTALL_DIR/.env" ]] || {
    printf 'error: existing .env is not a regular file: %s\n' "$INSTALL_DIR/.env" >&2
    exit 1
  }
  printf 'Using existing configuration: %s\n' "$INSTALL_DIR/.env"
fi

docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.yaml" config --quiet
docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.yaml" pull
docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.yaml" up -d

printf '\nCyberCord is starting.\n'
printf 'Install directory: %s\n' "$INSTALL_DIR"
printf 'URL: https://%s\n' "$DOMAIN"
printf 'Status: docker compose --env-file %q -f %q ps\n' "$INSTALL_DIR/.env" "$INSTALL_DIR/compose.yaml"
printf '\nForward WAN TCP 80 and 443 to this host. UDP 443 is optional for HTTP/3.\n'
printf 'Do not forward CyberCord port 8080.\n'
