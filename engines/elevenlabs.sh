#!/usr/bin/env bash
# Motor ElevenLabs: en la nube, de pago por uso (tiene plan gratuito pequeño).
# OJO: el texto de la respuesta se envía a los servidores de ElevenLabs.
#   elevenlabs.sh install                 comprueba que hay API key
#   elevenlabs.sh speak TEXTO.txt OUT.wav genera el audio
#
# Config: ELEVENLABS_API_KEY  (variable de entorno o en ~/.config/claude-reed/config,
#                              NUNCA en el repositorio)
#         ELEVENLABS_VOICE_ID (por defecto JBFqnCBsd6RMkjVDRZzb)
#         ELEVENLABS_MODEL    (por defecto eleven_multilingual_v2)
set -euo pipefail

case "${1:-}" in
  install)
    if [[ -z "${ELEVENLABS_API_KEY:-}" ]]; then
      echo "    Aviso: falta ELEVENLABS_API_KEY. Ponla en ~/.config/claude-reed/config"
      echo "    o expórtala en tu shell antes de usar este motor."
    fi
    ;;
  speak)
    [[ -n "${ELEVENLABS_API_KEY:-}" ]] || { echo "Falta ELEVENLABS_API_KEY" >&2; exit 1; }
    export ELEVENLABS_API_KEY   # por si viene de la config sin exportar
    python3 - "$2" "$3" "${ELEVENLABS_VOICE_ID:-JBFqnCBsd6RMkjVDRZzb}" \
      "${ELEVENLABS_MODEL:-eleven_multilingual_v2}" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request
import wave
from pathlib import Path

texto, wav, voz, modelo = sys.argv[1:]
RATE = 24000  # PCM 16 bits mono; lo envolvemos en WAV para reproducirlo sin dependencias

req = urllib.request.Request(
    f"https://api.elevenlabs.io/v1/text-to-speech/{voz}?output_format=pcm_{RATE}",
    data=json.dumps({"text": Path(texto).read_text(encoding="utf-8"),
                     "model_id": modelo}).encode(),
    headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"],
             "Content-Type": "application/json"},
)
try:
    with urllib.request.urlopen(req, timeout=120) as r:
        pcm = r.read()
except urllib.error.HTTPError as e:
    sys.exit(f"ElevenLabs respondió {e.code}: {e.read().decode(errors='replace')[:300]}")

with wave.open(wav, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(pcm)
PY
    ;;
  *)
    echo "Uso: $0 install | speak TEXTO.txt OUT.wav" >&2; exit 2 ;;
esac
