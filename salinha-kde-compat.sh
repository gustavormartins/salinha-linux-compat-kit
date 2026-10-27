#!/usr/bin/env bash
# Compatibility/diagnostic launcher for the official Salinha AppImage.
# Disable Chromium's Vulkan feature by default to avoid this build's
# reported Vulkan startup incompatibility.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE="${SALINHA_APPIMAGE:-$SCRIPT_DIR/Salinha-x86_64.appimage}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/salinha"
mkdir -p "$STATE_DIR" || { echo "Não consegui criar $STATE_DIR" >&2; exit 1; }
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$STATE_DIR/compat-$STAMP.log"

if [[ ! -f "$APPIMAGE" ]]; then
  cat >&2 <<EOF
Não encontrei o AppImage:
  $APPIMAGE
Coloque Salinha-x86_64.appimage na mesma pasta deste script ou defina:
  SALINHA_APPIMAGE=/caminho/Salinha-x86_64.appimage
EOF
  exit 2
fi

if [[ ! -x "$APPIMAGE" ]]; then
  chmod u+x "$APPIMAGE" || { echo "Não consegui tornar o AppImage executável." >&2; exit 2; }
fi

ARGS=()
if [[ "${SALINHA_ENABLE_VULKAN:-0}" != "1" ]]; then
  ARGS+=(--disable-features=Vulkan)
fi

BACKEND="${SALINHA_BACKEND:-auto}"
case "$BACKEND" in
  x11) ARGS+=(--ozone-platform=x11) ;;
  wayland) ARGS+=(--ozone-platform=wayland) ;;
  auto)
    # Prefer XWayland on this build when it is available.
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" && -n "${DISPLAY:-}" ]]; then
      ARGS+=(--ozone-platform=x11)
    fi
    ;;
  *) echo "SALINHA_BACKEND deve ser auto, x11 ou wayland." >&2; exit 2 ;;
esac

if [[ "$BACKEND" == "auto" && "${XDG_SESSION_TYPE:-}" == "wayland" && -z "${DISPLAY:-}" ]]; then
  echo "Wayland detectado, mas DISPLAY está vazio; XWayland parece indisponível." >&2
  echo "Tentando o backend padrão. Para selecionar manualmente: SALINHA_BACKEND=wayland." >&2
fi

# Optional fallback for systems where the GPU process prevents startup.
if [[ "${SALINHA_DISABLE_GPU:-0}" == "1" ]]; then
  ARGS+=(--disable-gpu)
fi

# Electron/Chromium logs are kept locally; they are not uploaded. Verbose
# logging dumps large histogram reports on shutdown, so enable it only when
# explicitly requested for troubleshooting.
ARGS+=(--enable-logging --log-level=0)
if [[ "${SALINHA_VERBOSE:-0}" == "1" ]]; then
  ARGS+=(--v=1)
fi

{
  echo "Salinha compatibility launcher"
  echo "Date: $(date --iso-8601=seconds 2>/dev/null || date)"
  echo "AppImage: $APPIMAGE"
  echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}"
  echo "Wayland socket configured: $([[ -n "${WAYLAND_DISPLAY:-}" ]] && echo yes || echo no)"
  echo "X11 DISPLAY configured: $([[ -n "${DISPLAY:-}" ]] && echo yes || echo no)"
  echo "Selected backend mode: $BACKEND"
  echo "Vulkan disabled: $([[ "${SALINHA_ENABLE_VULKAN:-0}" != "1" ]] && echo yes || echo no)"
  echo "Disable GPU fallback: ${SALINHA_DISABLE_GPU:-0}"
  echo "Verbose Chromium logging: ${SALINHA_VERBOSE:-0}"
  printf 'Args:'; printf ' %q' "${ARGS[@]}" "$@"; printf '\n'
  echo "Log file: $LOG"
  echo "------------------------------------------------------------"
} | tee -a "$LOG"

run_appimage() {
  "$APPIMAGE" "${ARGS[@]}" "$@" 2>&1 | tee -a "$LOG"
  return "${PIPESTATUS[0]}"
}

EXTRACT_DIR=""
cleanup_extracted_appimage() {
  if [[ -n "$EXTRACT_DIR" ]]; then
    rm -rf -- "$EXTRACT_DIR"
  fi
}
trap cleanup_extracted_appimage EXIT

run_extracted_appimage() {
  local extracted_appdir extract_status
  EXTRACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/salinha-appimage.XXXXXX")" || {
    echo "Não consegui criar uma pasta temporária para extrair o AppImage." | tee -a "$LOG" >&2
    return 1
  }

  echo "FUSE indisponível; extraindo o AppImage em uma pasta temporária." | tee -a "$LOG"
  if ! (cd -- "$EXTRACT_DIR" && "$APPIMAGE" --appimage-extract) >/dev/null 2>>"$LOG"; then
    echo "Não consegui extrair o AppImage." | tee -a "$LOG" >&2
    return 1
  fi

  extracted_appdir="$EXTRACT_DIR/squashfs-root"
  if [[ ! -x "$extracted_appdir/AppRun" ]]; then
    echo "A extração não contém um AppRun executável." | tee -a "$LOG" >&2
    return 1
  fi

  APPDIR="$extracted_appdir" "$extracted_appdir/AppRun" "${ARGS[@]}" "$@" 2>&1 | tee -a "$LOG"
  extract_status=${PIPESTATUS[0]}
  cleanup_extracted_appimage
  EXTRACT_DIR=""
  return "$extract_status"
}

set +e
run_appimage "$@"
status=$?
if grep -qF 'Cannot mount AppImage' "$LOG"; then
  run_extracted_appimage "$@"
  status=$?
fi
set -e
printf '\nSalinha exit code: %s\n' "$status" | tee -a "$LOG"
printf 'Log salvo em: %s\n' "$LOG"
exit "$status"
