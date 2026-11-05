#!/usr/bin/env bash
# Instala claude-reed: "leer en voz alta bajo demanda" para Claude Code.
#
#  - Copia hooks, motores y el comando a ~/.local/share/claude-reed
#  - Crea ~/.local/bin/claude-reed
#  - Crea ~/.config/claude-reed/config (si no existe)
#  - Instala el motor de voz elegido
#  - Registra el hook Stop en ~/.claude/settings.json (con copia de seguridad)
#  - Configura el atajo Ctrl+Alt+V en XFCE (si xfconf-query existe)
#
# Uso: ./install.sh [--engine piper|kokoro|elevenlabs] [--voice VOZ] [--no-shortcut]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/.local/share/claude-reed"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-reed"
CONFIG="$CONFIG_DIR/config"
SETTINGS="$HOME/.claude/settings.json"
# Con "~" el comando funciona aunque tu HOME tenga espacios o cambie de máquina.
HOOK_CMD="python3 ~/.local/share/claude-reed/hooks/guardar_respuesta.py"
# Hooks de instalaciones anteriores que se sustituyen por el nuevo.
HOOKS_ANTIGUOS=(
  "python3 ~/.claude/hooks/guardar_respuesta.py"                       # script original
  "python3 $HOME/.local/share/claude-leer/hooks/guardar_respuesta.py"  # versión claude-leer
)
ATAJO="/commands/custom/<Primary><Alt>v"

ENGINE_ARG="" VOICE_ARG="" SHORTCUT=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)      ENGINE_ARG="$2"; shift 2 ;;
    --voice)       VOICE_ARG="$2"; shift 2 ;;
    --no-shortcut) SHORTCUT=0; shift ;;
    -h|--help)     sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
done

# Cambia (o añade) una variable en el archivo de config.
set_config() {
  if grep -qE "^#? *$1=" "$CONFIG"; then
    sed -i -E "s|^#? *$1=.*|$1=$2|" "$CONFIG"
  else
    echo "$1=$2" >> "$CONFIG"
  fi
}

command -v python3 >/dev/null || { echo "Necesitas python3" >&2; exit 1; }

echo "==> 1/5 Copiando archivos a $APP_DIR"
mkdir -p "$APP_DIR" "$BIN_DIR"
cp -r "$REPO/bin" "$REPO/hooks" "$REPO/engines" "$REPO/lib" "$APP_DIR/"
chmod +x "$APP_DIR"/bin/* "$APP_DIR"/engines/*.sh "$APP_DIR"/hooks/*.py
ln -sf "$APP_DIR/bin/claude-reed" "$BIN_DIR/claude-reed"

echo "==> 2/5 Configuración en $CONFIG"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG" ]]; then
  cp "$REPO/config.example" "$CONFIG"
  echo "    Creada desde config.example"
fi
chmod 600 "$CONFIG"
[[ -n "$ENGINE_ARG" ]] && set_config ENGINE "$ENGINE_ARG"
# shellcheck source=/dev/null
ENGINE="$(source "$CONFIG"; echo "${ENGINE:-piper}")"
if [[ ! -f "$APP_DIR/engines/$ENGINE.sh" ]]; then
  echo "Motor desconocido: $ENGINE (disponibles: $(find "$APP_DIR/engines" -name "*.sh" -printf "%f " | sed "s/\.sh//g"))" >&2
  exit 1
fi
if [[ -n "$VOICE_ARG" ]]; then
  case "$ENGINE" in
    piper)      set_config PIPER_VOICE "$VOICE_ARG" ;;
    kokoro)     set_config KOKORO_VOICE "$VOICE_ARG" ;;
    elevenlabs) set_config ELEVENLABS_VOICE_ID "$VOICE_ARG" ;;
    *) echo "    --voice no se aplica automáticamente al motor $ENGINE; edita $CONFIG" ;;
  esac
fi
echo "    Motor: $ENGINE"

echo "==> 3/5 Instalando el motor $ENGINE"
set -a   # exporta las variables de la config al script del motor
# shellcheck source=/dev/null
source "$CONFIG"
set +a
export APP_DIR
"$APP_DIR/engines/$ENGINE.sh" install

echo "==> 4/5 Registrando el hook en $SETTINGS"
[[ -f "$SETTINGS" ]] && cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"
python3 "$APP_DIR/lib/hook_config.py" add "$SETTINGS" "$HOOK_CMD" "${HOOKS_ANTIGUOS[@]}"

echo "==> 5/5 Atajo de teclado"
if [[ $SHORTCUT -eq 1 ]] && command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xfce4-keyboard-shortcuts -p "$ATAJO" -n -t string -s "$BIN_DIR/claude-reed" 2>/dev/null \
    || xfconf-query -c xfce4-keyboard-shortcuts -p "$ATAJO" -s "$BIN_DIR/claude-reed"
  echo "    Ctrl+Alt+V configurado en XFCE."
else
  echo "    Crea a mano un atajo de teclado que ejecute: $BIN_DIR/claude-reed"
fi

case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo; echo "Aviso: $BIN_DIR no está en tu PATH." ;; esac

echo
echo "Listo. Reinicia Claude Code, pregúntale algo y pulsa Ctrl+Alt+V."
echo "Probar el motor: claude-reed say \"Hola, soy Claude\""
