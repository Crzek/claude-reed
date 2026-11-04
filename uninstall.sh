#!/usr/bin/env bash
# Desinstala claude-reed. Conserva tu config salvo que pases --purge.
# Uso: ./uninstall.sh [--purge]
set -euo pipefail

APP_DIR="$HOME/.local/share/claude-reed"
BIN="$HOME/.local/bin/claude-reed"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-reed"
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="python3 ~/.local/share/claude-reed/hooks/guardar_respuesta.py"
HOOKS_ANTIGUOS=(
  "python3 ~/.claude/hooks/guardar_respuesta.py"
  "python3 $HOME/.local/share/claude-leer/hooks/guardar_respuesta.py"
)
ATAJO="/commands/custom/<Primary><Alt>v"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$BIN" stop 2>/dev/null || true

if [[ -f "$SETTINGS" ]]; then
  echo "==> Quitando el hook de $SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"
  python3 "$REPO/lib/hook_config.py" remove "$SETTINGS" "$HOOK_CMD" "${HOOKS_ANTIGUOS[@]}"
fi

if command -v xfconf-query >/dev/null 2>&1 \
   && [[ "$(xfconf-query -c xfce4-keyboard-shortcuts -p "$ATAJO" 2>/dev/null)" == "$BIN" ]]; then
  echo "==> Quitando el atajo Ctrl+Alt+V"
  xfconf-query -c xfce4-keyboard-shortcuts -p "$ATAJO" -r
fi

echo "==> Borrando $APP_DIR y $BIN"
rm -rf "$APP_DIR"
rm -f "$BIN"
rm -rf "$HOME/.cache/claude-reed"

if [[ "${1:-}" == "--purge" ]]; then
  echo "==> Borrando la configuración $CONFIG_DIR"
  rm -rf "$CONFIG_DIR"
else
  echo "    Tu configuración sigue en $CONFIG_DIR (bórrala con --purge)."
fi
echo "Desinstalado."
