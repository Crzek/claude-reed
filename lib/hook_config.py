#!/usr/bin/env python3
"""Añade o quita el hook Stop de claude-reed en ~/.claude/settings.json.

Uso: hook_config.py add|remove SETTINGS COMANDO [COMANDO_ANTIGUO ...]

- add:    registra COMANDO (sin duplicar) y elimina los COMANDO_ANTIGUO
          (instalaciones previas con otra ruta).
- remove: elimina COMANDO y los COMANDO_ANTIGUO.
"""
import json
import sys
from pathlib import Path


def quitar(stop, comandos):
    for grupo in stop:
        grupo["hooks"] = [h for h in grupo.get("hooks", [])
                          if h.get("command") not in comandos]
    return [g for g in stop if g.get("hooks")]


def main():
    accion, ruta, cmd, *antiguos = sys.argv[1:]
    p = Path(ruta).expanduser()
    texto = p.read_text(encoding="utf-8") if p.exists() else ""
    cfg = json.loads(texto) if texto.strip() else {}

    hooks = cfg.setdefault("hooks", {})
    stop = quitar(hooks.get("Stop", []), set(antiguos))

    if accion == "add":
        if not any(h.get("command") == cmd for g in stop for h in g.get("hooks", [])):
            stop.append({"hooks": [{"type": "command", "command": cmd}]})
    elif accion == "remove":
        stop = quitar(stop, {cmd})
    else:
        sys.exit(f"Acción desconocida: {accion}")

    if stop:
        hooks["Stop"] = stop
    else:
        hooks.pop("Stop", None)
    if not hooks:
        cfg.pop("hooks", None)

    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
