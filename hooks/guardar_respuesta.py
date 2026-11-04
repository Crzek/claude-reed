#!/usr/bin/env python3
"""Hook Stop de Claude Code: guarda la última respuesta en texto plano (no la lee).

Claude Code ejecuta este script al terminar cada respuesta y le pasa por stdin
un JSON con `last_assistant_message` y/o `transcript_path`. El texto limpio se
guarda en ~/.cache/claude-reed/ultima-respuesta.txt para que `claude-reed` lo lea
cuando se lo pidas.
"""
import json
import os
import re
import sys
from pathlib import Path

SALIDA = Path(os.environ.get("CLAUDE_REED_TEXTO",
                             Path.home() / ".cache" / "claude-reed" / "ultima-respuesta.txt"))


def textos(content):
    if isinstance(content, str):
        return [content]
    return [b.get("text", "") for b in content or []
            if isinstance(b, dict) and b.get("type") == "text"]


def es_mensaje_usuario(e):
    """Un mensaje real del usuario (no un resultado de herramienta ni un mensaje interno)."""
    if e.get("type") != "user" or e.get("isMeta"):
        return False
    content = e.get("message", {}).get("content")
    if isinstance(content, str):
        return True
    return any(isinstance(b, dict) and b.get("type") == "text" for b in content or [])


def desde_transcript(ruta):
    """Junta todos los textos del asistente desde el último mensaje del usuario."""
    turno = []
    for linea in Path(ruta).read_text(encoding="utf-8").splitlines():
        try:
            e = json.loads(linea)
        except json.JSONDecodeError:
            continue
        if es_mensaje_usuario(e):
            turno = []
        elif e.get("type") == "assistant":
            turno += textos(e.get("message", {}).get("content"))
    return "\n".join(t for t in turno if t.strip())


def limpiar(t):
    """Quita el markdown para que la voz no lea asteriscos ni almohadillas."""
    t = re.sub(r"```.*?```", "\n(bloque de código)\n", t, flags=re.S)
    t = re.sub(r"`([^`]*)`", r"\1", t)
    t = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", t)
    t = re.sub(r"^[ \t]*([#>*\-|]+[ \t]*)+", "", t, flags=re.M)
    t = re.sub(r"[*_#|]", "", t)
    return re.sub(r"\n{2,}", "\n", t).strip()


def main():
    datos = json.load(sys.stdin)
    texto = datos.get("last_assistant_message") or ""
    ruta = datos.get("transcript_path")
    if not texto and ruta and Path(ruta).exists():
        texto = desde_transcript(ruta)
    texto = limpiar(texto)
    if texto:
        SALIDA.parent.mkdir(parents=True, exist_ok=True)
        SALIDA.write_text(texto, encoding="utf-8")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # nunca bloquear a Claude Code por un fallo del hook
