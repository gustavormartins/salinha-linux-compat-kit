#!/usr/bin/env bash
# Install a per-user menu entry that always starts Salinha through the
# Wayland compatibility launcher.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/salinha-kde-compat.sh"
APPIMAGE="${SALINHA_APPIMAGE:-$SCRIPT_DIR/Salinha-x86_64.appimage}"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_FILE="$DESKTOP_DIR/salinha-kde-compat.desktop"

if [[ ! -x "$LAUNCHER" ]]; then
  echo "Lançador não encontrado ou sem permissão de execução: $LAUNCHER" >&2
  exit 2
fi
if [[ ! -f "$APPIMAGE" ]]; then
  echo "AppImage não encontrado: $APPIMAGE" >&2
  echo "Defina SALINHA_APPIMAGE=/caminho/Salinha-x86_64.appimage se necessário." >&2
  exit 2
fi

mkdir -p "$DESKTOP_DIR"
python3 - "$DESKTOP_FILE" "$LAUNCHER" "$APPIMAGE" <<'PY'
import pathlib
import sys

target, launcher, appimage = map(pathlib.Path, sys.argv[1:])

def desktop_quote(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$') + '"'

target.write_text(
    "[Desktop Entry]\n"
    "Type=Application\n"
    "Name=Salinha (Wayland compatível)\n"
    "Comment=Inicia Salinha pelo lançador de compatibilidade Linux\n"
    "Terminal=false\n"
    "Icon=applications-internet\n"
    f"Exec=/usr/bin/env SALINHA_APPIMAGE={desktop_quote(str(appimage.resolve()))} {desktop_quote(str(launcher.resolve()))} %U\n"
    "Categories=Network;\n",
    encoding="utf-8",
)
target.chmod(0o644)
print(f"Atalho instalado: {target}")
PY

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi
