# 🔪🧹 DEV-KnifeSweep

**ES** — Mantenimiento y optimización de directorios de proyectos para macOS.
Limpia **únicamente artefactos de build regenerables** y te devuelve los GB que
el building constante se come, sin tocar jamás tu código ni tu progreso.

**EN** — Project-directory maintenance & optimization for macOS. It cleans
**only regenerable build artifacts** and gives you back the GB that constant
building eats, while never touching your code or your progress.

---

## ⚠️ Aviso / Notice

> **ES:** DEV-KnifeSweep se ofrece TAL CUAL, sin garantías; sus autores **no se hacen
> responsables de pérdida de datos**. Todo lo que borra es regenerable con un
> build o una instalación de dependencias — el costo real es tiempo (el próximo
> build será completo), no trabajo. Aun así: **haz commit y push antes de
> limpiar**. DEV-KnifeSweep te lo ofrece en cada ejecución.
>
> **EN:** DEV-KnifeSweep is provided AS IS, without warranty; its authors are **not
> responsible for data loss**. Everything it deletes is regenerable by a build
> or a dependency install — the real cost is time (your next build will be a
> full one), not work. Still: **commit and push before cleaning**. DEV-KnifeSweep
> offers this on every run.

La primera limpieza exige leer y aceptar este aviso: `dev-knifesweep accept`.
The first cleanup requires reading and accepting this notice: `dev-knifesweep accept`.

---

## Instalación / Install

**Una línea / One-liner:**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/j0suedaniel/DEV-KnifeSweep/main/install.sh)"
```

**Con tu agente / With your agent** (Claude Code o Codex CLI) — pégale esto:

> Instala DEV-KnifeSweep desde https://github.com/j0suedaniel/DEV-KnifeSweep (clona el repo
> y corre ./install.sh). Después muéstrame `dev-knifesweep status` y explícame los
> comandos. No ejecutes ninguna limpieza sin mi confirmación.

**Desde un zip / From a zip:** descomprime y corre `./install.sh`.

El instalador coloca / The installer puts:
- `~/.local/bin/dev-knifesweep` — el motor / the engine
- `~/.claude/skills/dev-knifesweep/` — skill para Claude Code (`/dev-knifesweep`)
- `~/.codex/prompts/dev-knifesweep.md` — prompt para Codex CLI (`/dev-knifesweep`)

---

## Uso / Usage

```bash
dev-knifesweep              # asistente interactivo / interactive wizard
dev-knifesweep scan  --root ~/Proyectos
dev-knifesweep clean --root ~/Proyectos --safe --report   # dry-run (nada se borra)
dev-knifesweep clean --root ~/Proyectos --deep --run      # pide confirmación escrita
dev-knifesweep schedule     # rutina automática: diaria / cada 3 días / semanal
dev-knifesweep monitor      # notificación cuando el disco libre baje del umbral
dev-knifesweep status       # estado de todo
```

| Nivel / Level | Qué limpia / What it cleans |
|---|---|
| `--safe` | Artefactos sin tocar en +7 días. Los builds recientes siguen incrementales. / Artifacts untouched for 7+ days. Recent builds stay incremental. |
| `--deep` | TODOS los artefactos regenerables. Máximo espacio; el próximo build es completo. / ALL regenerable artifacts. Max space; next build is a full one. |

El asistente detecta tus proyectos (Xcode, SwiftPM, Node, Gradle, Flutter,
Rust), muestra cuánto ocupa cada uno y cuánto es recuperable, te deja elegir,
te ofrece hacer commit antes, enseña un reporte y solo borra tras confirmar
`[S/N]`. La rutina programada usa **solo** nivel safe.

The wizard detects your projects, shows size vs. reclaimable per project, lets
you choose, offers a git checkpoint first, shows a report, and only deletes
after a `[Y/N]` confirmation. The scheduled routine uses the **safe** level only.

---

## Salvaguardas / Safety guards

**Nunca se toca / Never touched:** tu código fuente y archivos de proyecto ·
`.git` e historial · Xcode Archives · llaves y credenciales (`*.keystore`,
`*.p12`, `.env`…) · Android SDK, AVDs y simuladores · `node_modules` (solo su
`.cache` interno se limpia) · puntos de montaje virtuales (CoreDevice).

1. **Dry-run por defecto** — sin `--run` nada se borra. / Dry-run by default.
2. **Regla de gitignore** — en repos git solo se borra lo que git IGNORA; lo
   rastreado es intocable. / In git repos, only gitignored paths are deletable.
3. **Regla de node_modules** — `dist/`/`build/` de paquetes npm son código
   publicado, no artefactos. / Package `dist`/`build` are published code.
4. **Regla de montajes** — nada que viva bajo un punto de montaje en `$HOME`
   (p. ej. CoreDevice reporta 65GB falsos). / Nothing under a `$HOME` mount.
5. **Confirmación explícita [S/N]** + aceptación única del aviso por el humano.
   / Explicit [Y/N] confirmation + one-time human acceptance of the notice.
6. **Rutinas solo safe** — lo automático nunca corre `--deep`.
7. **Log completo** en `~/Library/Logs/dev-knifesweep.log`.
8. **Lista protegida absoluta** codificada en el motor (arriba).

---

## Para agentes / For agents

La skill (Claude) y el prompt (Codex) convierten a tu agente en la capa
conversacional: escanea, recomienda, pide tu confirmación y ejecuta a través
del motor — nunca con `rm -rf` a mano. La aceptación del aviso y la
programación de rutinas son siempre humanas (son comandos interactivos).

The skill (Claude) and prompt (Codex) make your agent the conversational
layer: it scans, recommends, asks for your confirmation and executes through
the engine — never with a manual `rm -rf`. Accepting the notice and scheduling
routines are always human actions (interactive commands).

¿Sin acceso a GitHub? Usa `PROMPT-MAESTRO.md`: un solo texto que le pegas a
cualquier agente y reconstruye e instala el kit completo.
No GitHub access? Use `PROMPT-MAESTRO.md`: one text you paste to any agent to
rebuild and install the whole kit.

---

## Desinstalar / Uninstall

```bash
dev-knifesweep uninstall
```

---

**Creado por / Created by [j0suedaniel](https://github.com/j0suedaniel) · JDMC.TECH**

MIT © 2026 JDMC.TECH
