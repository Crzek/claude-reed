#!/usr/bin/env bash
# Motor Piper: local, libre y ligero (por defecto).
#   piper.sh install                 instala piper-tts y descarga la voz
#   piper.sh speak TEXTO.txt OUT.wav genera el audio
#
# Config: PIPER_VOICE (por defecto es_ES-davefx-medium)
#         Voces: https://huggingface.co/rhasspy/piper-voices
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/.local/share/claude-reed}"
DIR="$APP_DIR/piper"
VENV="$DIR/venv"
PIPER_VOICE="${PIPER_VOICE:-es_ES-davefx-medium}"

case "${1:-}" in
  install)
    mkdir -p "$DIR/voces"
    [[ -x "$VENV/bin/python" ]] || python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade pip piper-tts
    if [[ ! -f "$DIR/voces/$PIPER_VOICE.onnx" ]]; then
      ( cd "$DIR/voces" && "$VENV/bin/python" -m piper.download_voices "$PIPER_VOICE" )
    fi
    ;;
  speak)
    texto="$2" wav="$3"
    modelo="$DIR/voces/$PIPER_VOICE.onnx"
    [[ -f "$modelo" ]] || { echo "Falta la voz $PIPER_VOICE: ejecuta ./install.sh --engine piper" >&2; exit 1; }
    "$VENV/bin/piper" -m "$modelo" -f "$wav" -- "$(cat "$texto")" >/dev/null 2>&1
    ;;
  *)
    echo "Uso: $0 install | speak TEXTO.txt OUT.wav" >&2; exit 2 ;;
esac
