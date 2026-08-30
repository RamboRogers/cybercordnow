#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT/README.md"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

require_literal() {
  local expected="$1"
  local description="$2"
  grep -Fq -- "$expected" "$README" || fail "README must include $description: $expected"
}

absolute_local_path_check() {
  local file="$1"
  local absolute_local_path_pattern='/(Users|home)/[^[:space:]]+'
  local grep_status=0

  grep -Eqi -- "$absolute_local_path_pattern" "$file" >/dev/null || grep_status=$?
  case "$grep_status" in
    0) return 1 ;;
    1) return 0 ;;
    *) fail "could not inspect README for absolute local filesystem paths" ;;
  esac
}

require_highlight_bullet() {
  local description="$1"
  shift

  local bullet expected matches
  while IFS= read -r bullet; do
    [[ "$bullet" =~ ^[-*+][[:space:]] ]] || continue
    matches=1
    for expected in "$@"; do
      if ! grep -Eqi -- "$expected" <<< "$bullet"; then
        matches=0
        break
      fi
    done
    [[ "$matches" == "1" ]] && return
  done <<< "$highlights"

  fail "README 2.0 Highlights must include a bullet for $description"
}

[[ -f "$README" ]] || fail "README.md is missing"

TMP="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

README_SOURCE_HASH="$(cksum "$README")"
README_PROBE="$TMP/readme-contract-probe.md"
cp "$README" "$README_PROBE"
cmp -s "$README" "$README_PROBE" || fail "README probe must start as an exact source snapshot"
printf '\n/%s/%s\n' 'home' 'readme-contract-probe' >>"$README_PROBE"
if absolute_local_path_check "$README_PROBE"; then
  fail "absolute local path detector must reject the generic README probe"
fi
[[ "$(cksum "$README")" == "$README_SOURCE_HASH" ]] || fail "README source changed during probe"

if ! absolute_local_path_check "$README"; then
  fail "README must not expose absolute local filesystem paths"
fi

highlight_count="$(awk '$0 == "## ✦ 2.0 Highlights" { count++ } END { print count + 0 }' "$README")"
[[ "$highlight_count" == "1" ]] || fail "README must contain exactly one heading: ## ✦ 2.0 Highlights"

highlights="$(awk '
  $0 == "## ✦ 2.0 Highlights" { in_highlights = 1; next }
  in_highlights {
    compact = $0
    gsub(/[[:space:]]/, "", compact)
    if ($0 ~ /^#{1,6}[[:space:]]/ || compact ~ /^---+$/ || compact ~ /^\*\*\*+$/ || compact ~ /^___+$/) {
      exit
    }
    print
  }
' "$README")"
highlight_bullet_count="$(awk '/^[-*+][[:space:]]+/ { count++ } END { print count + 0 }' <<< "$highlights")"
[[ "$highlight_bullet_count" == "5" ]] || \
  fail "README 2.0 Highlights must contain exactly five bullet entries"

require_highlight_bullet "Opus voice with less bandwidth and a compatibility fallback" \
  'Opus' \
  'less[[:space:]]+bandwidth' \
  'compatib' \
  'fallback'
require_highlight_bullet "screen sharing, camera video, shared audio, and safe compatibility" \
  '(share|screen)' \
  'camera' \
  'shared[[:space:]]+audio' \
  'safe' \
  'compatib'
require_highlight_bullet "quiet reconnects without a distracting leave/join sound burst" \
  'reconnect' \
  '(leave.*join|join.*leave)' \
  'sound' \
  '(distract|disrupt|unwanted)' \
  'burst'
require_highlight_bullet "improved compatibility for NVIDIA and Wayland" \
  'NVIDIA' \
  'Wayland' \
  '(improved|better|enhanced|sturdier)' \
  'compatib'
require_highlight_bullet "independent voice and sharing compatibility or rollback controls" \
  'voice' \
  'shar(e|ing)' \
  'independ' \
  'compatib' \
  '(operator|admin|rollout|control|rollback|revert|return)'

for implementation_led_term in \
  'previous PCM path' \
  'libopus-wasm' \
  'WebCodecs' \
  'wazero' \
  'fMP4' \
  'WEBKIT_DISABLE_DMABUF_RENDERER'; do
  if grep -Fqi -- "$implementation_led_term" <<< "$highlights"; then
    fail "README 2.0 Highlights must not expose implementation-led term: $implementation_led_term"
  fi
done

intro_line="$(awk '/^CyberCord is / { print NR; exit }' "$README")"
highlight_line="$(awk '$0 == "## ✦ 2.0 Highlights" { print NR; exit }' "$README")"
why_line="$(awk '$0 == "## ✦ Why CyberCord" { print NR; exit }' "$README")"
[[ -n "$intro_line" ]] || fail "README product introduction is missing"
[[ -n "$why_line" ]] || fail "README Why CyberCord heading is missing"
[[ "$intro_line" -lt "$highlight_line" && "$highlight_line" -lt "$why_line" ]] || \
  fail "2.0 Highlights must appear after the product introduction and before Why CyberCord"

if ! grep -Eqi -- 'Opus' "$README"; then
  fail "README must describe Opus"
fi
if ! grep -Eqi -- 'less bandwidth' "$README"; then
  fail "README must state the less bandwidth benefit"
fi

for internal_term in \
  'libopus-wasm' \
  'WebCodecs' \
  'wazero' \
  'fMP4' \
  'WEBKIT_DISABLE_DMABUF_RENDERER'; do
  if grep -Fqi -- "$internal_term" "$README"; then
    fail "README must not expose internal term: $internal_term"
  fi
done

release_base='https://github.com/RamboRogers/cybercordnow/releases/download/v2.0.0'
for public_artifact in \
  'CyberCord-Desktop-Windows-x64-setup.exe' \
  'CyberCord-Desktop-Windows-x64.msi' \
  'CyberCord-Desktop-Debian-amd64.deb' \
  'CyberCord-Desktop-Arch-x86_64.pkg.tar.zst'; do
  require_literal "$release_base/$public_artifact" "the public v2.0.0 artifact URL"
done

macos_release_base='https://github.com/RamboRogers/cybercordnow/releases/download/v0.1.2'
require_literal "$macos_release_base/CyberCord-Desktop-macOS-Apple-Silicon.dmg" "the retained macOS DMG URL"
require_literal "$macos_release_base/CyberCord-Desktop-macOS-Apple-Silicon.zip" "the retained macOS ZIP URL"
if ! grep -Eqi -- 'macOS.*unchanged[[:space:]]+for[[:space:]]+2\.0|unchanged[[:space:]]+for[[:space:]]+2\.0.*macOS' "$README"; then
  fail "README must label the macOS client unchanged for 2.0"
fi

server_image='ghcr.io/ramborogers/cybercord-server'
versioned_references="$(grep -Eo -- "$server_image:[0-9]+\\.[0-9]+\\.[0-9]+" "$README" || true)"
versioned_count="$(printf '%s\n' "$versioned_references" | awk 'NF { count++ } END { print count + 0 }')"
[[ "$versioned_count" == "3" ]] || fail "README must contain exactly three versioned server image references"
while IFS= read -r versioned_reference; do
  [[ -z "$versioned_reference" ]] && continue
  [[ "$versioned_reference" == "$server_image:2.0.0" ]] || \
    fail "README server image reference must use v2.0.0: $versioned_reference"
done <<< "$versioned_references"

if ! grep -Eqi -- 'latest[^[:cntrl:]]*(tracks?|means|refers[[:space:]]+to|points[[:space:]]+to|is)[^[:cntrl:]]*newest[^[:cntrl:]]*verified[^[:cntrl:]]*public[^[:cntrl:]]*server[[:space:]-]+release' "$README"; then
  fail "README must state that latest tracks the newest verified public server release"
fi

printf 'PASS: README exposes the public CyberCord v2.0.0 release contract\n'
