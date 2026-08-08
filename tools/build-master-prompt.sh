#!/bin/bash
# Regenera PROMPT-MAESTRO.md desde los archivos canónicos del kit.
# Regenerates PROMPT-MAESTRO.md from the kit's canonical files.
# Así el prompt maestro NUNCA se desvía del código real.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/PROMPT-MAESTRO.md"
VER="$(sed -nE 's/^KNIFESWEEP_VERSION="(.*)"/\1/p' "$ROOT/bin/dev-knifesweep")"

{
cat <<'HEADER'
# PROMPT MAESTRO — instala DEV-KnifeSweep sin acceso a GitHub
# MASTER PROMPT — installs DEV-KnifeSweep without GitHub access

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
2. `chmod +x ~/.local/bin/dev-knifesweep`
3. Verifica: `dev-knifesweep --version` y `dev-knifesweep status`.
4. Dile al usuario que corra ÉL MISMO `dev-knifesweep accept` en su terminal
   (es interactivo a propósito — la aceptación es humana), y después
   `dev-knifesweep` para el asistente.
5. NUNCA ejecutes una limpieza (`--run`) sin la confirmación explícita del
   usuario en el chat, y jamás borres artefactos con `rm -rf` a mano.

HEADER

echo "## Archivo 1/3: \`~/.local/bin/dev-knifesweep\`  (v$VER)"
echo ""
echo '````bash'
cat "$ROOT/bin/dev-knifesweep"
echo '````'
echo ""
echo "## Archivo 2/3: \`~/.claude/skills/dev-knifesweep/SKILL.md\`  (skill de Claude Code)"
echo ""
echo '````markdown'
cat "$ROOT/agent/claude-skill/SKILL.md"
echo '````'
echo ""
echo "## Archivo 3/3: \`~/.codex/prompts/dev-knifesweep.md\`  (prompt de Codex CLI)"
echo ""
echo '````markdown'
cat "$ROOT/agent/codex-prompt.md"
echo '````'
echo ""
cat <<'FOOTER'
---

**Agente:** al terminar, muestra al usuario este resumen:

- Motor: `~/.local/bin/dev-knifesweep` (añade `~/.local/bin` al PATH si hace falta)
- Primer paso humano: `dev-knifesweep accept` (leer y aceptar el aviso)
- Asistente: `dev-knifesweep` · Rutina: `dev-knifesweep schedule` · Monitor: `dev-knifesweep monitor`
- Todo borrado pasa por 8 salvaguardas y siempre hay reporte antes de ejecutar.
- Repo canónico (para actualizaciones): https://github.com/j0suedaniel/DEV-KnifeSweep
FOOTER
} > "$OUT"

echo "✓ PROMPT-MAESTRO.md regenerado ($(wc -l < "$OUT" | tr -d ' ') líneas, v$VER)"
