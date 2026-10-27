#!/usr/bin/env bash
# Non-invasive network/session checks for the Salinha desktop wrapper.
set -u
HOST="salinha.live"

printf '%s\n' '=== Salinha Linux diagnostics ==='
printf 'Date: '; date --iso-8601=seconds 2>/dev/null || date
printf 'Kernel: '; uname -sr
printf 'Desktop: %s\n' "${XDG_CURRENT_DESKTOP:-unset}"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unset}"
printf 'Wayland socket configured: %s\n' "$([[ -n "${WAYLAND_DISPLAY:-}" ]] && echo yes || echo no)"
printf 'X11 DISPLAY configured: %s\n' "$([[ -n "${DISPLAY:-}" ]] && echo yes || echo no)"
printf 'curl: '; command -v curl || true
printf 'getent: '; command -v getent || true
printf '\n%s\n' '--- DNS lookup ---'
if command -v getent >/dev/null 2>&1; then
  if dns_results="$(getent ahosts "$HOST" 2>/dev/null)" && [[ -n "$dns_results" ]]; then
    printf '%s\n' "$dns_results" | head -n 6
  else
    echo 'DNS lookup failed.'
  fi
else
  echo 'getent is unavailable.'
fi
printf '\n%s\n' '--- HTTPS test (15 second timeout) ---'
if command -v curl >/dev/null 2>&1; then
  curl -sS -o /dev/null --connect-timeout 5 --max-time 15 \
    -w 'HTTP=%{http_code} DNS_seconds=%{time_namelookup} Connect_seconds=%{time_connect} TLS_seconds=%{time_appconnect} Total_seconds=%{time_total}\n' \
    "https://$HOST/" || echo 'HTTPS request failed; check the error above.'
else
  echo 'curl is unavailable.'
fi
printf '\n%s\n' '--- Proxy variables (values intentionally hidden) ---'
for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy; do
  if [[ -n "${!name:-}" ]]; then printf '%s=set\n' "$name"; fi
done
printf '\n%s\n' '--- Electron-related variables (values intentionally hidden) ---'
for name in ELECTRON_OZONE_PLATFORM_HINT ELECTRON_ENABLE_LOGGING ELECTRON_RUN_AS_NODE; do
  if [[ -n "${!name:-}" ]]; then printf '%s=set\n' "$name"; fi
done
printf '\nIf sharing this output publicly, review it first; do not include cookies, tokens, or private network details.\n'
