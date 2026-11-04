#!/usr/bin/env bash
# Motor Kokoro: local, más natural que Piper, pide más CPU (usa kokoro-onnx, sin PyTorch).
#   kokoro.sh install                 instala kokoro-onnx y descarga el modelo (~330 MB)
#   kokoro.sh speak TEXTO.txt OUT.wav genera el audio
#
# Config: KOKORO_VOICE (por defecto ef_dora; en español también em_alex, em_santa)
#         KOKORO_LANG  (por defecto es)
#         KOKORO_SPEED (por defecto 1.0)
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/.local/share/claude-reed}"
DIR="$APP_DIR/kokoro"
VENV="$DIR/venv"
BASE_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
MODELO="kokoro-v1.0.onnx"
VOCES="voices-v1.0.bin"

case "${1:-}" in
  install)
    mkdir -p "$DIR"
    [[ -x "$VENV/bin/python" ]] || python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade pip kokoro-onnx soundfile
    for f in "$MODELO" "$VOCES"; do
      if [[ ! -f "$DIR/$f" ]]; then
        echo "    Descargando $f..."
        "$VENV/bin/python" -c 'import sys, urllib.request; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])' \
          "$BASE_URL/$f" "$DIR/$f.part"
        mv "$DIR/$f.part" "$DIR/$f"
      fi
    done
    ;;
  speak)
    [[ -f "$DIR/$MODELO" ]] || { echo "Falta el modelo: ejecuta ./install.sh --engine kokoro" >&2; exit 1; }
    "$VENV/bin/python" - "$2" "$3" "$DIR/$MODELO" "$DIR/$VOCES" \
      "${KOKORO_VOICE:-ef_dora}" "${KOKORO_LANG:-es}" "${KOKORO_SPEED:-1.0}" <<'PY'
import sys
from pathlib import Path
import soundfile as sf
from kokoro_onnx import Kokoro

texto, wav, modelo, voces, voz, lang, speed = sys.argv[1:]
kokoro = Kokoro(modelo, voces)
samples, sr = kokoro.create(Path(texto).read_text(encoding="utf-8"),
                            voice=voz, speed=float(speed), lang=lang)
sf.write(wav, samples, sr)
PY
    ;;
  *)
    echo "Uso: $0 install | speak TEXTO.txt OUT.wav" >&2; exit 2 ;;
esac
