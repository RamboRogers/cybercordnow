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

  fail "README 2.1 Highlights must include a bullet for $description"
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

highlight_count="$(awk '$0 == "## ✦ 2.1 Highlights" { count++ } END { print count + 0 }' "$README")"
[[ "$highlight_count" == "1" ]] || fail "README must contain exactly one heading: ## ✦ 2.1 Highlights"

highlights="$(awk '
  $0 == "## ✦ 2.1 Highlights" { in_highlights = 1; next }
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
  fail "README 2.1 Highlights must contain exactly five bullet entries"

require_highlight_bullet "Settings Audio selected low-bandwidth Opus and independent CPU Light" \
  'Voice[[:space:]]+bandwidth' \
  'Low[[:space:]]+bandwidth' \
  'selected' \
  '12[[:space:]]*kbps' \
  'Auto' \
  'CPU[[:space:]]+Light'
require_highlight_bullet "voice diagnostics, Opus recovery, and mute/deafen preservation" \
  'diagnostics' \
  'Opus' \
  '(recovery|recover)' \
  '(mute/deafen|mute.*deafen|deafen.*mute)'
require_highlight_bullet "accessible unread shimmer and counts" \
  'unread' \
  'accessible' \
  'shimmer' \
  'counts'
require_highlight_bullet "directed mentions, toast/ding, and opt-in notifications" \
  '@username' \
  'current-room[[:space:]]+members' \
  'toast' \
  'ding' \
  'Settings[[:space:]]+→[[:space:]]+Notifications' \
  'browser/OS'
require_highlight_bullet "server-only 2.1 update with retained desktop downloads" \
  'server/WebUI' \
  '2\.1\.2' \
  '(reload|restart)' \
  'Windows/Linux[[:space:]]+desktop[[:space:]]+v2\.0\.0' \
  'macOS[[:space:]]+v0\.1\.2' \
  'unchanged'

for implementation_led_term in \
  'previous PCM path' \
  'libopus-wasm' \
  'WebCodecs' \
  'wazero' \
  'fMP4' \
  'WEBKIT_DISABLE_DMABUF_RENDERER'; do
  if grep -Fqi -- "$implementation_led_term" <<< "$highlights"; then
    fail "README 2.1 Highlights must not expose implementation-led term: $implementation_led_term"
  fi
done

intro_line="$(awk '/^CyberCord is / { print NR; exit }' "$README")"
highlight_line="$(awk '$0 == "## ✦ 2.1 Highlights" { print NR; exit }' "$README")"
why_line="$(awk '$0 == "## ✦ Why CyberCord" { print NR; exit }' "$README")"
[[ -n "$intro_line" ]] || fail "README product introduction is missing"
[[ -n "$why_line" ]] || fail "README Why CyberCord heading is missing"
[[ "$intro_line" -lt "$highlight_line" && "$highlight_line" -lt "$why_line" ]] || \
  fail "2.1 Highlights must appear after the product introduction and before Why CyberCord"

for required_phrase in \
  'No client changes are needed: 2.1.2 is a server update.' \
  'Settings → Audio → Voice bandwidth' \
  'Low bandwidth — selected' \
  '12 kbps up and 12 kbps down' \
  'CPU Light is independent of bandwidth' \
  'voice diagnostics panel reports the current codec' \
  'retains mute/deafen during reconnects' \
  'not a guarantee on weak networks, acoustic quality, or unqualified physical devices' \
  'accessible unread shimmer' \
  '`@username`' \
  'current-room members' \
  'directed toast' \
  'rate-limited ding' \
  'Settings → Notifications' \
  'browser/OS notifications' \
  'app, tab, PWA, or desktop shell is running' \
  'CyberCord does not provide closed-app push notifications' \
  'server binary defaults the advanced 2.1.2 voice-resilience gates to `false`' \
  'Compose stack and `docker run` example set them to `true` explicitly' \
  'Windows/Linux desktop v2.0.0 and macOS v0.1.2 downloads remain unchanged' \
  'Voice protection can still remain visible for 30–60 seconds'; do
  require_literal "$required_phrase" "2.1.2 user-facing release detail"
done

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
  require_literal "$release_base/$public_artifact" "the retained public v2.0.0 artifact URL"
done

macos_release_base='https://github.com/RamboRogers/cybercordnow/releases/download/v0.1.2'
require_literal "$macos_release_base/CyberCord-Desktop-macOS-Apple-Silicon.dmg" "the retained macOS DMG URL"
require_literal "$macos_release_base/CyberCord-Desktop-macOS-Apple-Silicon.zip" "the retained macOS ZIP URL"
if ! grep -Eqi -- 'macOS.*unchanged[[:space:]]+for[[:space:]]+2\.1|unchanged[[:space:]]+for[[:space:]]+2\.1.*macOS' "$README"; then
  fail "README must label the macOS client unchanged for 2.1"
fi
if grep -Eqi -- 'releases/download/v2\.1\.2/.*CyberCord-Desktop|CyberCord-Desktop[^[:cntrl:]]*2\.1\.2' "$README"; then
  fail "README must not copy or relabel desktop downloads as v2.1.2"
fi

server_image='ghcr.io/ramborogers/cybercord-server'
versioned_references="$(grep -Eo -- "$server_image:[0-9]+\\.[0-9]+\\.[0-9]+" "$README" || true)"
versioned_count="$(printf '%s\n' "$versioned_references" | awk 'NF { count++ } END { print count + 0 }')"
[[ "$versioned_count" == "3" ]] || fail "README must contain exactly three versioned server image references"
while IFS= read -r versioned_reference; do
  [[ -z "$versioned_reference" ]] && continue
  [[ "$versioned_reference" == "$server_image:2.1.2" ]] || \
    fail "README server image reference must use v2.1.2: $versioned_reference"
done <<< "$versioned_references"

if ! grep -Eqi -- 'latest[^[:cntrl:]]*(tracks?|means|refers[[:space:]]+to|points[[:space:]]+to|is)[^[:cntrl:]]*newest[^[:cntrl:]]*verified[^[:cntrl:]]*public[^[:cntrl:]]*server[[:space:]-]+release' "$README"; then
  fail "README must state that latest tracks the newest verified public server release"
fi

printf 'PASS: README exposes the public CyberCord v2.1.2 server-only release contract\n'
