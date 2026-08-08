#!/bin/bash
# DevSweep installer — funciona desde un checkout local o vía curl | bash
# Works from a local checkout or via curl | bash
set -uo pipefail

REPO="https://github.com/j0suedaniel/devsweep"
case "${DEVSWEEP_LANG:-${LANG:-en}}" in es*|ES*) L=es ;; *) L=en ;; esac
msg() { if [ "$L" = es ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }

if [ "$(uname -s)" != "Darwin" ]; then
  msg "DevSweep v1 es solo para macOS." "DevSweep v1 is macOS-only."
  exit 1
fi

# ¿Desde checkout o desde curl? / From checkout or curl?
SRC=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/bin/devsweep" ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  msg "Descargando DevSweep…" "Downloading DevSweep…"
  TMP="$(mktemp -d)"
  if ! git clone --depth 1 --quiet "$REPO" "$TMP/devsweep"; then
    msg "✗ No pude clonar $REPO (¿tienes git y conexión?)" \
        "✗ Could not clone $REPO (do you have git and a connection?)"
    exit 1
  fi
  SRC="$TMP/devsweep"
fi

# 1) binario / binary
mkdir -p "$HOME/.local/bin"
cp "$SRC/bin/devsweep" "$HOME/.local/bin/devsweep"
chmod +x "$HOME/.local/bin/devsweep"
msg "✓ Motor instalado: ~/.local/bin/devsweep" "✓ Engine installed: ~/.local/bin/devsweep"

# 2) PATH
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *)
    SHELL_RC="$HOME/.zshrc"; [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"
    if ! grep -qs '\.local/bin' "$SHELL_RC" 2>/dev/null; then
      printf '\nexport PATH="$HOME/.local/bin:$PATH"   # devsweep\n' >> "$SHELL_RC"
      msg "✓ PATH añadido a $SHELL_RC (abre una terminal nueva)" \
          "✓ PATH added to $SHELL_RC (open a new terminal)"
    fi ;;
esac

# 3) skill para Claude Code / Claude Code skill
mkdir -p "$HOME/.claude/skills/devsweep"
cp "$SRC/agent/claude-skill/SKILL.md" "$HOME/.claude/skills/devsweep/SKILL.md"
msg "✓ Skill de Claude Code: ~/.claude/skills/devsweep/ (usa /devsweep)" \
    "✓ Claude Code skill: ~/.claude/skills/devsweep/ (use /devsweep)"

# 4) prompt para Codex CLI / Codex CLI prompt
mkdir -p "$HOME/.codex/prompts"
cp "$SRC/agent/codex-prompt.md" "$HOME/.codex/prompts/devsweep.md"
msg "✓ Prompt de Codex: ~/.codex/prompts/devsweep.md (usa /devsweep)" \
    "✓ Codex prompt: ~/.codex/prompts/devsweep.md (use /devsweep)"

echo ""
msg "Siguientes pasos:" "Next steps:"
msg "  1. devsweep accept     ← lee y acepta el aviso (una sola vez)" \
    "  1. devsweep accept     ← read and accept the notice (one time)"
msg "  2. devsweep            ← asistente interactivo" \
    "  2. devsweep            ← interactive wizard"
msg "  3. devsweep schedule   ← rutina automática (opcional)" \
    "  3. devsweep schedule   ← automatic routine (optional)"
msg "  4. devsweep monitor    ← aviso por poco espacio (opcional)" \
    "  4. devsweep monitor    ← low-space alert (optional)"
