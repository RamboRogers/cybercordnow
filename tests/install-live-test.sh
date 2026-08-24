#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
PROJECT="cybercord-install-live-test"
TMP="$(mktemp -d)"
INSTALL_DIR="$TMP/install"
MOCK_BIN="$TMP/bin"
REAL_CURL="$(command -v curl)"
mkdir -p "$INSTALL_DIR" "$MOCK_BIN"

cleanup() {
  if [[ -f "$INSTALL_DIR/.env" && -f "$INSTALL_DIR/compose.yaml" ]]; then
    COMPOSE_PROJECT_NAME="$PROJECT" docker compose \
      --env-file "$INSTALL_DIR/.env" \
      -f "$INSTALL_DIR/compose.yaml" \
      down -v >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

cat >"$INSTALL_DIR/.env" <<'ENV'
CYBERCORD_DOMAIN=http://localhost
ACME_EMAIL=test@example.com
CYBERCORD_IMAGE=ghcr.io/ramborogers/cybercord-server:0.1.2
CYBERCORD_HTTP_PORT=0
CYBERCORD_HTTPS_PORT=0
CYBERCORD_INTERNAL_SUBNET=172.30.241.0/24
CADDY_INTERNAL_IP=172.30.241.2
CYBERCORD_INTERNAL_IP=172.30.241.3
ENV
chmod 0600 "$INSTALL_DIR/.env"

cat >"$MOCK_BIN/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
set -euo pipefail
out=""
url=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    http://*|https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$out" && -n "$url" ]]
relative="${url#"$CYBERCORD_RAW_BASE/"}"
mkdir -p "$(dirname "$out")"
cp "$FIXTURE_ROOT/$relative" "$out"
MOCK_CURL
chmod +x "$MOCK_BIN/curl"

export PATH="$MOCK_BIN:$PATH"
export FIXTURE_ROOT="$ROOT"
export CYBERCORD_RAW_BASE='https://downloads.example.test/cybercordnow'
export CYBERCORD_INSTALL_DIR="$INSTALL_DIR"
export COMPOSE_PROJECT_NAME="$PROJECT"

"$INSTALLER" chat.example.com owner@example.com >/dev/null

server_ready=0
for _attempt in $(seq 1 90); do
  if docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.yaml" \
    logs --no-color cybercord 2>/dev/null | grep -q 'CyberCord server listening'; then
    server_ready=1
    break
  fi
  sleep 0.5
done
[[ "$server_ready" == 1 ]]

port_line="$(docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.yaml" port caddy 80)"
host_port="${port_line##*:}"
base="http://localhost:$host_port"
health="$("$REAL_CURL" -fsS "$base/healthz")"
ready="$("$REAL_CURL" -fsS "$base/readyz")"
root="$("$REAL_CURL" -fsS "$base/")"
[[ "$health" == *'"status":"ok"'* ]]
[[ "$ready" == *'"status":"ready"'* ]]
[[ "$root" == *'<title>CyberCord</title>'* ]]

published_backend="$(docker inspect "${PROJECT}-cybercord-1" --format '{{json .NetworkSettings.Ports}}')"
[[ "$published_backend" == '{}' ]]

printf 'PASS: real installer launched CyberCord through Caddy\n'
printf 'PASS: health, readiness, WebUI, and private backend verified\n'
