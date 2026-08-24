#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -x "$INSTALLER" ]] || fail "install.sh is missing or not executable"

TMP="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

FIXTURE="$TMP/fixture"
MOCK_BIN="$TMP/bin"
HOME_DIR="$TMP/home"
INSTALL_DIR="$TMP/install"
mkdir -p "$FIXTURE/caddy" "$MOCK_BIN" "$HOME_DIR"
cp "$ROOT/compose.yaml" "$FIXTURE/compose.yaml"
cp "$ROOT/.env.example" "$FIXTURE/.env.example"
cp "$ROOT/caddy/Caddyfile" "$FIXTURE/caddy/Caddyfile"

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
printf '%s\n' "$relative" >>"$CURL_LOG"
MOCK_CURL

cat >"$MOCK_BIN/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$DOCKER_LOG"
if [[ "$*" == "compose version" ]]; then
  printf 'Docker Compose version v2.test\n'
fi
MOCK_DOCKER
chmod +x "$MOCK_BIN/curl" "$MOCK_BIN/docker"

export PATH="$MOCK_BIN:/usr/bin:/bin"
export HOME="$HOME_DIR"
export FIXTURE_ROOT="$FIXTURE"
export CURL_LOG="$TMP/curl.log"
export DOCKER_LOG="$TMP/docker.log"
export CYBERCORD_RAW_BASE='https://downloads.example.test/cybercordnow'
export CYBERCORD_INSTALL_DIR="$INSTALL_DIR"

"$INSTALLER" chat.example.com owner@example.com >/dev/null

cmp -s "$FIXTURE/compose.yaml" "$INSTALL_DIR/compose.yaml" || fail "compose.yaml was not installed"
cmp -s "$FIXTURE/.env.example" "$INSTALL_DIR/.env.example" || fail ".env.example was not installed"
cmp -s "$FIXTURE/caddy/Caddyfile" "$INSTALL_DIR/caddy/Caddyfile" || fail "Caddyfile was not installed"
[[ "$(stat -f '%Lp' "$INSTALL_DIR/.env" 2>/dev/null || stat -c '%a' "$INSTALL_DIR/.env")" == "600" ]] || fail ".env mode is not 600"
grep -qx 'CYBERCORD_DOMAIN=chat.example.com' "$INSTALL_DIR/.env" || fail "domain was not written"
grep -qx 'ACME_EMAIL=owner@example.com' "$INSTALL_DIR/.env" || fail "ACME email was not written"
grep -qx 'CYBERCORD_IMAGE=ghcr.io/ramborogers/cybercord-server:0.1.2' "$INSTALL_DIR/.env" || fail "default image was not written"
[[ "$(wc -l <"$CURL_LOG" | tr -d ' ')" == "3" ]] || fail "installer did not download exactly three files"
grep -q 'compose version' "$DOCKER_LOG" || fail "Docker Compose prerequisite was not checked"
grep -q 'config --quiet' "$DOCKER_LOG" || fail "Compose config was not validated"
grep -q ' pull$' "$DOCKER_LOG" || fail "images were not pulled"
grep -q ' up -d$' "$DOCKER_LOG" || fail "stack was not started"

printf 'PASS: one-line installer downloads, configures, validates, and starts CyberCord\n'

: >"$DOCKER_LOG"
if "$INSTALLER" 'https://chat.example.com/path' 'not-an-email' >/dev/null 2>&1; then
  fail "invalid domain and email were accepted"
fi
[[ ! -s "$DOCKER_LOG" ]] || fail "invalid input reached Docker"

printf 'PASS: invalid domain and email fail before Docker\n'

printf 'CUSTOM_SETTING=preserve-me\n' >>"$INSTALL_DIR/.env"
"$INSTALLER" other.example.com other@example.com >/dev/null
grep -qx 'CYBERCORD_DOMAIN=chat.example.com' "$INSTALL_DIR/.env" || fail "rerun replaced the existing domain"
grep -qx 'ACME_EMAIL=owner@example.com' "$INSTALL_DIR/.env" || fail "rerun replaced the existing ACME email"
grep -qx 'CUSTOM_SETTING=preserve-me' "$INSTALL_DIR/.env" || fail "rerun replaced custom configuration"

printf 'PASS: rerun preserves existing .env configuration\n'
