import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

os.environ["CLAUDE_REED_NO_PREPARE"] = "1"  # los tests no generan audio

RAIZ = Path(__file__).resolve().parent.parent
HOOK = RAIZ / "hooks" / "guardar_respuesta.py"
HOOK_CONFIG = RAIZ / "lib" / "hook_config.py"

spec = importlib.util.spec_from_file_location("guardar_respuesta", HOOK)
gr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gr)


class TestLimpiar(unittest.TestCase):
    def test_quita_markdown(self):
        t = "# Título\n\n**negrita** y `código` y [enlace](http://x)\n- item"
        self.assertEqual(gr.limpiar(t), "Título\nnegrita y código y enlace\nitem")

    def test_bloques_de_codigo(self):
        t = "Mira:\n```python\nprint(1)\n```\nFin"
        self.assertEqual(gr.limpiar(t), "Mira:\n(bloque de código)\nFin")


class TestTranscript(unittest.TestCase):
    def test_solo_el_ultimo_turno(self):
        lineas = [
            {"type": "user", "message": {"content": "hola"}},
            {"type": "assistant", "message": {"content": [{"type": "text", "text": "viejo"}]}},
            {"type": "user", "message": {"content": "otra"}},
            {"type": "assistant", "message": {"content": [{"type": "text", "text": "uno"}]}},
            {"type": "user", "message": {"content": [{"type": "tool_result", "content": "x"}]}},
            {"type": "assistant", "message": {"content": [{"type": "text", "text": "dos"}]}},
        ]
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as f:
            f.write("\n".join(json.dumps(l) for l in lineas) + "\nbasura\n")
        try:
            self.assertEqual(gr.desde_transcript(f.name), "uno\ndos")
        finally:
            os.unlink(f.name)


class TestHookCompleto(unittest.TestCase):
    def test_guarda_el_texto(self):
        with tempfile.TemporaryDirectory() as d:
            salida = Path(d) / "out.txt"
            subprocess.run([sys.executable, HOOK],
                           input=json.dumps({"last_assistant_message": "**Hola**"}),
                           text=True, check=True,
                           env={**os.environ, "CLAUDE_REED_TEXTO": str(salida)})
            self.assertEqual(salida.read_text(encoding="utf-8"), "Hola")

    def test_entrada_invalida_no_falla(self):
        r = subprocess.run([sys.executable, HOOK], input="no es json", text=True)
        self.assertEqual(r.returncode, 0)


class TestHookConfig(unittest.TestCase):
    def ejecutar(self, *args):
        subprocess.run([sys.executable, HOOK_CONFIG, *args], check=True)

    def test_add_idempotente_migra_y_remove(self):
        with tempfile.TemporaryDirectory() as d:
            s = Path(d) / "settings.json"
            s.write_text(json.dumps({
                "model": "x",
                "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "viejo"}]}]},
            }))
            self.ejecutar("add", str(s), "nuevo", "viejo")
            self.ejecutar("add", str(s), "nuevo", "viejo")
            cfg = json.loads(s.read_text())
            cmds = [h["command"] for g in cfg["hooks"]["Stop"] for h in g["hooks"]]
            self.assertEqual(cmds, ["nuevo"])
            self.assertEqual(cfg["model"], "x")

            self.ejecutar("remove", str(s), "nuevo")
            self.assertEqual(json.loads(s.read_text()), {"model": "x"})


if __name__ == "__main__":
    unittest.main()
