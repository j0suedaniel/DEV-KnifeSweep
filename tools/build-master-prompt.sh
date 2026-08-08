#!/bin/bash
# Regenera PROMPT-MAESTRO.md desde los archivos canónicos del kit.
# Regenerates PROMPT-MAESTRO.md from the kit's canonical files.
# Así el prompt maestro NUNCA se desvía del código real.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/PROMPT-MAESTRO.md"
VER="$(sed -nE 's/^DEVSWEEP_VERSION="(.*)"/\1/p' "$ROOT/bin/devsweep")"

{
cat <<'HEADER'
# PROMPT MAESTRO — instala DevSweep sin acceso a GitHub
# MASTER PROMPT — installs DevSweep without GitHub access

**ES — Instrucciones para ti (humano):** copia TODO este archivo y pégaselo a
tu agente (Claude Code o Codex CLI) en una carpeta cualquiera. El agente creará
los archivos EXACTOS y te dirá cómo terminar. No requiere internet.

**EN — Instructions for you (human):** copy this WHOLE file and paste it to
your agent (Claude Code or Codex CLI) in any folder. The agent will create the
EXACT files and tell you how to finish. No internet required.

---

**Agente / Agent:** sigue estos pasos AL PIE DE LA LETRA. No "mejores" ni
modifiques el código — escríbelo EXACTAMENTE como aparece (es una herramienta
de borrado con salvaguardas auditadas; cualquier cambio tuyo puede romperlas).
Follow these steps TO THE LETTER. Do not "improve" or modify the code — write
it EXACTLY as shown (it is a deletion tool with audited safety guards; any
change of yours may break them).

1. Escribe cada bloque de abajo en la ruta indicada (crea las carpetas).
2. `chmod +x ~/.local/bin/devsweep`
3. Verifica: `devsweep --version` y `devsweep status`.
4. Dile al usuario que corra ÉL MISMO `devsweep accept` en su terminal
   (es interactivo a propósito — la aceptación es humana), y después
   `devsweep` para el asistente.
5. NUNCA ejecutes una limpieza (`--run`) sin la confirmación explícita del
   usuario en el chat, y jamás borres artefactos con `rm -rf` a mano.

HEADER

echo "## Archivo 1/3: \`~/.local/bin/devsweep\`  (v$VER)"
echo ""
echo '````bash'
cat "$ROOT/bin/devsweep"
echo '````'
echo ""
echo "## Archivo 2/3: \`~/.claude/skills/devsweep/SKILL.md\`  (skill de Claude Code)"
echo ""
echo '````markdown'
cat "$ROOT/agent/claude-skill/SKILL.md"
echo '````'
echo ""
echo "## Archivo 3/3: \`~/.codex/prompts/devsweep.md\`  (prompt de Codex CLI)"
echo ""
echo '````markdown'
cat "$ROOT/agent/codex-prompt.md"
echo '````'
echo ""
cat <<'FOOTER'
---

**Agente:** al terminar, muestra al usuario este resumen:

- Motor: `~/.local/bin/devsweep` (añade `~/.local/bin` al PATH si hace falta)
- Primer paso humano: `devsweep accept` (leer y aceptar el aviso)
- Asistente: `devsweep` · Rutina: `devsweep schedule` · Monitor: `devsweep monitor`
- Todo borrado pasa por 8 salvaguardas y siempre hay reporte antes de ejecutar.
- Repo canónico (para actualizaciones): https://github.com/j0suedaniel/devsweep
FOOTER
} > "$OUT"

echo "✓ PROMPT-MAESTRO.md regenerado ($(wc -l < "$OUT" | tr -d ' ') líneas, v$VER)"
