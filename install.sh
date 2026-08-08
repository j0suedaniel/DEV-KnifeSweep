#!/bin/bash
# DEV-KnifeSweep installer — funciona desde un checkout local o vía curl | bash
# Works from a local checkout or via curl | bash
set -uo pipefail

REPO="https://github.com/j0suedaniel/DEV-KnifeSweep"
case "${KNIFESWEEP_LANG:-${LANG:-en}}" in es*|ES*) L=es ;; *) L=en ;; esac
msg() { if [ "$L" = es ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }

if [ "$(uname -s)" != "Darwin" ]; then
  msg "DEV-KnifeSweep v1 es solo para macOS." "DEV-KnifeSweep v1 is macOS-only."
  exit 1
fi

# ¿Desde checkout o desde curl? / From checkout or curl?
SRC=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/bin/dev-knifesweep" ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  msg "Descargando DEV-KnifeSweep…" "Downloading DEV-KnifeSweep…"
  TMP="$(mktemp -d)"
  if ! git clone --depth 1 --quiet "$REPO" "$TMP/dev-knifesweep"; then
    msg "✗ No pude clonar $REPO (¿tienes git y conexión?)" \
        "✗ Could not clone $REPO (do you have git and a connection?)"
    exit 1
  fi
  SRC="$TMP/dev-knifesweep"
fi

# 1) binario / binary
mkdir -p "$HOME/.local/bin"
cp "$SRC/bin/dev-knifesweep" "$HOME/.local/bin/dev-knifesweep"
chmod +x "$HOME/.local/bin/dev-knifesweep"
msg "✓ Motor instalado: ~/.local/bin/dev-knifesweep" "✓ Engine installed: ~/.local/bin/dev-knifesweep"

# 2) PATH
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *)
    SHELL_RC="$HOME/.zshrc"; [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"
    if ! grep -qs '\.local/bin' "$SHELL_RC" 2>/dev/null; then
      printf '\nexport PATH="$HOME/.local/bin:$PATH"   # dev-knifesweep\n' >> "$SHELL_RC"
      msg "✓ PATH añadido a $SHELL_RC (abre una terminal nueva)" \
          "✓ PATH added to $SHELL_RC (open a new terminal)"
    fi ;;
esac

# 3) skill para Claude Code / Claude Code skill
mkdir -p "$HOME/.claude/skills/dev-knifesweep"
cp "$SRC/agent/claude-skill/SKILL.md" "$HOME/.claude/skills/dev-knifesweep/SKILL.md"
msg "✓ Skill de Claude Code: ~/.claude/skills/dev-knifesweep/ (usa /dev-knifesweep)" \
    "✓ Claude Code skill: ~/.claude/skills/dev-knifesweep/ (use /dev-knifesweep)"

# 4) prompt para Codex CLI / Codex CLI prompt
mkdir -p "$HOME/.codex/prompts"
cp "$SRC/agent/codex-prompt.md" "$HOME/.codex/prompts/dev-knifesweep.md"
msg "✓ Prompt de Codex: ~/.codex/prompts/dev-knifesweep.md (usa /dev-knifesweep)" \
    "✓ Codex prompt: ~/.codex/prompts/dev-knifesweep.md (use /dev-knifesweep)"

echo ""
msg "Siguientes pasos:" "Next steps:"
msg "  1. dev-knifesweep accept     ← lee y acepta el aviso (una sola vez)" \
    "  1. dev-knifesweep accept     ← read and accept the notice (one time)"
msg "  2. dev-knifesweep            ← asistente interactivo" \
    "  2. dev-knifesweep            ← interactive wizard"
msg "  3. dev-knifesweep schedule   ← rutina automática (opcional)" \
    "  3. dev-knifesweep schedule   ← automatic routine (optional)"
msg "  4. dev-knifesweep monitor    ← aviso por poco espacio (opcional)" \
    "  4. dev-knifesweep monitor    ← low-space alert (optional)"
