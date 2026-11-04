# claude-reed

Escucha las respuestas de [Claude Code](https://claude.com/claude-code) **solo cuando tú quieras**.
Pulsas un atajo de teclado y te lee la última respuesta en voz alta; lo vuelves a pulsar y se calla.

- 🔇 **Bajo demanda**: no lee nada automáticamente.
- 🔌 **Motor de voz intercambiable**: Piper, Kokoro o ElevenLabs, y añadir otro es meter un script.
- 🧹 **Limpia el markdown** antes de leer: nada de "asterisco asterisco" ni "almohadilla".
- 🏠 **Local por defecto**: con Piper o Kokoro el texto no sale de tu ordenador.

## Cómo funciona

```
Claude Code ──(hook Stop)──► guardar_respuesta.py ──► ~/.cache/claude-reed/ultima-respuesta.txt
                                                                  │
Ctrl+Alt+V ──► claude-reed ──► engines/$ENGINE.sh ──► WAV ──► altavoces
```

1. Un **hook `Stop`** de Claude Code guarda la última respuesta en texto plano, sin markdown.
2. El comando **`claude-reed`** la convierte en audio con el motor configurado y la reproduce.
   Si ya está leyendo, la para.

## Instalación

Requisitos: Linux, `python3` (con `venv`) y un reproductor de audio (`paplay`, `pw-play` o `aplay`).

```bash
git clone https://github.com/<tu-usuario>/claude-reed.git
cd claude-reed
./install.sh                     # Piper con voz es_ES-davefx-medium
```

Otras opciones:

```bash
./install.sh --engine kokoro                    # voz local más natural
./install.sh --engine piper --voice es_MX-claude-high
./install.sh --engine elevenlabs                # nube, necesita API key
./install.sh --no-shortcut                      # sin atajo de teclado
```

Después **reinicia Claude Code**, pregúntale algo y pulsa **Ctrl+Alt+V**.

El atajo se configura solo en XFCE. En otros escritorios (GNOME, KDE...) crea un atajo de teclado
personalizado que ejecute `~/.local/bin/claude-reed`.

## Uso

| Comando                   | Qué hace                                         |
| ------------------------- | ------------------------------------------------ |
| `claude-reed`             | Lee la última respuesta, o la para si ya lee     |
| `claude-reed stop`        | Para la lectura                                  |
| `claude-reed say "texto"` | Lee un texto cualquiera (para probar un motor)   |
| `claude-reed engine`      | Muestra el motor configurado                     |

## Motores de voz

| Motor        | Dónde corre | Calidad     | Coste          | Notas                                    |
| ------------ | ----------- | ----------- | -------------- | ---------------------------------------- |
| `piper`      | Local       | Buena       | Gratis         | Ligero, por defecto                      |
| `kokoro`     | Local       | Muy buena   | Gratis         | Más CPU; descarga ~330 MB de modelo      |
| `elevenlabs` | Nube        | Excelente   | Pago por uso   | El texto se envía a ElevenLabs           |

Cambiar de motor es una línea en `~/.config/claude-reed/config`:

```bash
ENGINE=kokoro
```

y, si es la primera vez que usas ese motor, `./install.sh` para instalarlo.

### ElevenLabs y tu API key

La API key **nunca va en el repositorio**. Ponla en una de estas dos ubicaciones:

- En tu shell: `export ELEVENLABS_API_KEY=...` (en `~/.bashrc`, `~/.zshrc`...). Ojo: un atajo de
  teclado del escritorio puede no heredar las variables de tu shell; en ese caso usa la opción siguiente.
- En `~/.config/claude-reed/config` (fuera del repo, con permisos `600`):

  ```bash
  ELEVENLABS_API_KEY=sk_...
  ```

### Añadir un motor nuevo

Crea `engines/<nombre>.sh` con dos subcomandos:

```bash
engines/<nombre>.sh install                    # instala dependencias / modelos (idempotente)
engines/<nombre>.sh speak TEXTO.txt SALIDA.wav # genera el audio en WAV
```

El script recibe como variables de entorno todo lo definido en la config y `APP_DIR`
(`~/.local/share/claude-reed`), donde puede guardar su venv y sus modelos.
Luego `ENGINE=<nombre>` y `./install.sh`.

## Estructura

```
claude-reed/
├── install.sh                 # instalador
├── uninstall.sh               # desinstalador (--purge borra también la config)
├── bin/claude-reed            # lee / para; elige motor según la config
├── hooks/guardar_respuesta.py # hook Stop: guarda la última respuesta sin markdown
├── engines/
│   ├── piper.sh               # local, ligero (por defecto)
│   ├── kokoro.sh              # local, más natural
│   └── elevenlabs.sh          # nube, usa ELEVENLABS_API_KEY
├── lib/hook_config.py         # añade/quita el hook en ~/.claude/settings.json
├── tests/                     # tests (python -m unittest discover -s tests)
└── config.example             # ENGINE=piper, voces...
```

## Qué toca en tu sistema

| Ruta                                   | Contenido                          |
| -------------------------------------- | ---------------------------------- |
| `~/.local/share/claude-reed/`          | Scripts, venvs y modelos de voz    |
| `~/.local/bin/claude-reed`             | Enlace al comando                  |
| `~/.config/claude-reed/config`         | Tu configuración                   |
| `~/.claude/settings.json`              | Entrada del hook `Stop` (con `.bak`) |
| `~/.cache/claude-reed/ultima-respuesta.txt` | Última respuesta en texto plano    |

## Desinstalar

```bash
./uninstall.sh            # conserva ~/.config/claude-reed
./uninstall.sh --purge    # lo borra todo
```

## Licencia

[MIT](LICENSE)
