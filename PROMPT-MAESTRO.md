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

## Archivo 1/3: `~/.local/bin/dev-knifesweep`  (v0.2.2)

````bash
#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
#  DEV-KnifeSweep — mantenimiento y optimización de directorios de proyectos (macOS)
#  DEV-KnifeSweep — project-directory maintenance & optimization (macOS)
# ═══════════════════════════════════════════════════════════════════════════
#  ES: Limpia SOLO artefactos de build regenerables (DerivedData, build/,
#      dist/, cachés de Gradle/SPM/npm…). NUNCA toca tu código fuente, .git,
#      archivos de proyecto, llaves, ni releases archivados.
#  EN: Cleans ONLY regenerable build artifacts (DerivedData, build/, dist/,
#      Gradle/SPM/npm caches…). It NEVER touches your source code, .git,
#      project files, keys, or archived releases.
#
#  AVISO / DISCLAIMER:
#  ES: Esta herramienta se ofrece TAL CUAL, sin garantías. Sus autores NO se
#      hacen responsables de pérdida de datos. Todo lo que borra es
#      regenerable con un build/instalación, pero SIEMPRE haz commit de tu
#      trabajo antes de ejecutar una limpieza.
#  EN: This tool is provided AS IS, without warranty. Its authors are NOT
#      responsible for data loss. Everything it deletes is regenerable by a
#      build/install, but ALWAYS commit your work before running a cleanup.
#
#  Uso / Usage:
#    dev-knifesweep                  asistente interactivo / interactive wizard
#    dev-knifesweep scan  [--root D] descubre proyectos / discover projects
#    dev-knifesweep clean [--root D] --safe|--deep [--report|--run] [--yes]
#                              [--global|--no-global]
#    dev-knifesweep schedule         programar rutina / set up a routine (launchd)
#    dev-knifesweep monitor          monitor de espacio libre / free-space monitor
#    dev-knifesweep status           estado / status
#    dev-knifesweep accept           leer y aceptar el aviso / read & accept notice
#    dev-knifesweep unschedule       quitar rutina y monitor / remove agents
#    dev-knifesweep uninstall        desinstalar todo / uninstall everything
#
#  Creado por / Created by: j0suedaniel · JDMC.TECH
#  https://github.com/j0suedaniel/DEV-KnifeSweep
# ═══════════════════════════════════════════════════════════════════════════

set -uo pipefail

KNIFESWEEP_VERSION="0.2.2"
STATE_DIR="$HOME/.dev-knifesweep"
ACCEPT_FILE="$STATE_DIR/disclaimer-accepted"
LOG="$HOME/Library/Logs/dev-knifesweep.log"
PLIST_ROUTINE="$HOME/Library/LaunchAgents/com.dev-knifesweep.routine.plist"
PLIST_MONITOR="$HOME/Library/LaunchAgents/com.dev-knifesweep.monitor.plist"

# TTL (días/days) del nivel safe / for the safe level
SAFE_TTL=7

# ── Idioma / Language ─────────────────────────────────────────────────────
# KNIFESWEEP_LANG=es|en fuerza el idioma; si no, se detecta de $LANG.
case "${KNIFESWEEP_LANG:-${LANG:-en}}" in
  es*|ES*) L=es ;;
  *)       L=en ;;
esac
# msg "texto español" "english text"
msg() { if [ "$L" = es ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }
txt() { if [ "$L" = es ]; then printf '%s' "$1";  else printf '%s' "$2";  fi; }

# ── Utilidades / Helpers ──────────────────────────────────────────────────
ts()   { date '+%Y-%m-%d %H:%M:%S'; }
logln(){ mkdir -p "$(dirname "$LOG")"; echo "$(ts)  $*" >> "$LOG"; }
rule() { printf '%s\n' "───────────────────────────────────────────────────────────────"; }
size_of() { [ -e "$1" ] && du -sk "$1" 2>/dev/null | awk 'NR==1{printf "%.0f", $1}' || echo 0; }
human() { awk -v k="${1:-0}" 'BEGIN{ s="KMGT"; i=1; while(k>=1024 && i<4){k/=1024;i++} printf "%.1f%sB", k, substr(s,i,1) }'; }
free_now() { df -h / 2>/dev/null | awk 'NR==2{print $4}'; }
free_gb()  { df -g / 2>/dev/null | awk 'NR==2{print $4}'; }
is_tty()   { [ -t 0 ] && [ -t 1 ]; }

# ═══════════════════════════════════════════════════════════════════════════
#  SALVAGUARDAS / SAFETY GUARDS
# ═══════════════════════════════════════════════════════════════════════════

# 1) Puntos de montaje bajo $HOME (p.ej. CoreDevice/DeviceFS es un devicefs
#    virtual: du reporta GB enormes pero NO es espacio real, y borrar ahí
#    borraría datos DENTRO del dispositivo). Jamás borrar bajo un montaje.
# 1) Mount points under $HOME (e.g. CoreDevice/DeviceFS is a virtual devicefs:
#    du reports huge GB but it is NOT real disk space, and deleting there
#    would delete data INSIDE the device). Never delete under a mount.
MOUNTS_UNDER_HOME=$(mount 2>/dev/null | sed -nE "s|^.* on ($HOME[^ ]*) \(.*|\1|p")
is_under_mount() {
  local p="$1" m
  [ -n "$MOUNTS_UNDER_HOME" ] || return 1
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    case "$p" in "$m"|"$m"/*) return 0 ;; esac
  done <<< "$MOUNTS_UNDER_HOME"
  return 1
}

# 2) En repos git, un candidato solo se borra si git lo IGNORA (si está en
#    .gitignore no es fuente de verdad). Lo rastreado jamás se toca.
# 2) In git repos, a candidate is only deleted if git IGNORES it (if it's in
#    .gitignore it is not source of truth). Tracked paths are never touched.
git_root_of() { git -C "$1" rev-parse --show-toplevel 2>/dev/null; }
is_git_ignored() { # $1=git_root $2=abs_path
  git -C "$1" check-ignore -q "$2" 2>/dev/null
}

# 3) Dentro de node_modules, build/ y dist/ son el CÓDIGO PUBLICADO del
#    paquete (pdf-lib/dist, googleapis/build…), no artefactos. Se excluyen
#    en cada find, y del() lo re-verifica por si acaso.
# 3) Inside node_modules, build/ and dist/ are the package's PUBLISHED CODE
#    (pdf-lib/dist, googleapis/build…), not artifacts. Excluded in every
#    find, and del() re-checks just in case.

# Contadores / Counters
FREED_K=0; ITEMS=0
SEEN_TARGETS=""
already_counted() {
  case "$SEEN_TARGETS" in *"|$1|"*) return 0 ;; esac
  SEEN_TARGETS="$SEEN_TARGETS|$1|"
  return 1
}

# Borrado con todas las salvaguardas / Deletion with every guard.
#   del <ruta/path> <descripción/description> [git_root]
del() {
  local target="$1" desc="$2" groot="${3:-}"
  # node_modules: la ÚNICA ruta borrable ahí dentro es node_modules/.cache;
  # todo lo demás (dist/build de paquetes) es código publicado, intocable.
  # node_modules: the ONLY deletable path inside is node_modules/.cache;
  # everything else (package dist/build) is published code, untouchable.
  case "$target" in
    */node_modules/.cache) : ;;
    */node_modules/*) return ;;
  esac
  # Lista protegida absoluta / absolute protected list
  case "$target" in
    */.git|*/.git/*|\
    "$HOME/Library/Developer/Xcode/Archives"*|\
    "$HOME/Library/Developer/CoreDevice"*|\
    "$HOME/Library/Developer/CoreSimulator/Devices"*|\
    "$HOME/Library/Android/sdk"*|\
    "$HOME/.gradle/wrapper"*|\
    "$HOME/.android/avd"*|\
    "$HOME/.android/adbkey"*|\
    "$HOME/.android/debug.keystore"*|\
    *.jks|*.keystore|*.p12|*.mobileprovision|*.env|*/.env|*/.env.*)
      return ;;
  esac
  if is_under_mount "$target"; then
    msg "  [MONTAJE] omitido (no es espacio real): $target" \
        "  [MOUNT] skipped (not real disk space): $target"
    return
  fi
  if [ -n "$groot" ] && ! is_git_ignored "$groot" "$target"; then
    msg "  ⋯ omitido (no está en .gitignore — podría ser fuente): ${target#$groot/}" \
        "  ⋯ skipped (not gitignored — could be source): ${target#$groot/}"
    return
  fi
  [ -e "$target" ] || return
  already_counted "$target" && return
  local sz; sz=$(size_of "$target")
  FREED_K=$(( FREED_K + sz )); ITEMS=$(( ITEMS + 1 ))
  if [ "$MODE" = "run" ]; then
    if rm -rf "$target" 2>/dev/null; then
      msg "  ✓ borrado ($(human "$sz")): $desc" "  ✓ deleted ($(human "$sz")): $desc"
      logln "deleted ($(human "$sz")): $target"
    else
      msg "  ✗ NO se pudo borrar: $desc" "  ✗ could NOT delete: $desc"
    fi
  else
    msg "  • liberaría $(human "$sz"): $desc" "  • would free $(human "$sz"): $desc"
  fi
}

show_protections() {
  msg "  Protegido SIEMPRE (nunca se toca):" "  ALWAYS protected (never touched):"
  msg "    · tu código fuente y archivos de proyecto" "    · your source code and project files"
  msg "    · .git e historial completo"              "    · .git and full history"
  msg "    · Xcode Archives (releases firmados)"     "    · Xcode Archives (signed releases)"
  msg "    · llaves y credenciales (*.keystore, *.p12, .env…)" "    · keys & credentials (*.keystore, *.p12, .env…)"
  msg "    · Android SDK, AVDs y simuladores iOS"    "    · Android SDK, AVDs and iOS simulators"
  msg "    · node_modules (solo su .cache interno se limpia)" "    · node_modules (only its internal .cache is cleaned)"
  msg "    · todo lo rastreado por git o fuera de .gitignore" "    · anything git-tracked or not gitignored"
  msg "    · puntos de montaje virtuales (CoreDevice)" "    · virtual mount points (CoreDevice)"
}

# ═══════════════════════════════════════════════════════════════════════════
#  AVISO LEGAL / DISCLAIMER
# ═══════════════════════════════════════════════════════════════════════════
show_disclaimer() {
  echo "═══════════════════════════════════════════════════════════════"
  msg "  AVISO IMPORTANTE — léelo una vez, en serio" \
      "  IMPORTANT NOTICE — read it once, seriously"
  echo "═══════════════════════════════════════════════════════════════"
  msg "  1. DEV-KnifeSweep borra ÚNICAMENTE artefactos regenerables de build." \
      "  1. DEV-KnifeSweep deletes ONLY regenerable build artifacts."
  msg "     Tu proyecto, tu código y tu progreso NO se tocan." \
      "     Your project, your code and your progress are NOT touched."
  msg "  2. El costo real es tiempo: el próximo build será completo" \
      "  2. The real cost is time: your next build will be a full one"
  msg "     (no incremental) y npm/pod/gradle re-descargarán cachés." \
      "     (not incremental) and npm/pod/gradle will re-download caches."
  msg "  3. AUN ASÍ: haz commit y push de tu trabajo antes de limpiar." \
      "  3. STILL: commit and push your work before cleaning."
  msg "     DEV-KnifeSweep te lo ofrecerá cada vez; acéptalo." \
      "     DEV-KnifeSweep will offer this every time; take it."
  msg "  4. Esta herramienta se ofrece TAL CUAL, sin garantía de ningún" \
      "  4. This tool is provided AS IS, with no warranty of any kind."
  msg "     tipo. Los autores NO se hacen responsables de pérdida de" \
      "     The authors are NOT responsible for data loss of any kind."
  msg "     datos. Úsala bajo tu propio riesgo." \
      "     Use it at your own risk."
  echo ""
  show_protections
  echo "═══════════════════════════════════════════════════════════════"
}

is_accepted() { [ -f "$ACCEPT_FILE" ]; }

cmd_accept() {
  show_disclaimer
  if ! is_tty; then
    msg "Para aceptar, corre 'dev-knifesweep accept' en una terminal interactiva (tú, no tu agente)." \
        "To accept, run 'dev-knifesweep accept' in an interactive terminal (you, not your agent)."
    exit 1
  fi
  printf '%s' "$(txt '  ¿Aceptas estos términos? [S/N]: ' '  Do you accept these terms? [Y/N]: ')"
  local r; read -r r
  r=$(printf '%s' "$r" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
  case "$r" in
    s|si|sí|y|yes|acepto|accept)
      mkdir -p "$STATE_DIR"
      { echo "accepted=$(ts)"; echo "version=$KNIFESWEEP_VERSION"; echo "user=$USER"; } > "$ACCEPT_FILE"
      msg "  ✓ Aceptado. Registrado en $ACCEPT_FILE" "  ✓ Accepted. Recorded at $ACCEPT_FILE" ;;
    *)
      msg "  No aceptado. DEV-KnifeSweep no ejecutará limpiezas." "  Not accepted. DEV-KnifeSweep will not run cleanups."
      exit 1 ;;
  esac
}

require_accept() {
  is_accepted && return 0
  msg "Antes de la primera limpieza debes leer y aceptar el aviso:" \
      "Before the first cleanup you must read and accept the notice:"
  if is_tty; then
    cmd_accept
  else
    msg "    dev-knifesweep accept   (córrelo tú en la terminal)" \
        "    dev-knifesweep accept   (run it yourself in the terminal)"
    exit 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  DESCUBRIMIENTO DE PROYECTOS / PROJECT DISCOVERY
# ═══════════════════════════════════════════════════════════════════════════
# Marcadores: .git, *.xcodeproj, Package.swift, package.json, build.gradle*,
# settings.gradle*, pubspec.yaml, Cargo.toml. Se queda con la raíz más alta
# (un repo con ios/ + android/ dentro cuenta como UN proyecto).
PROJ_ROOTS=(); PROJ_TYPES=(); PROJ_GITS=()

detect_type() {
  local r="$1" t=""
  [ -n "$(ls -d "$r"/*.xcodeproj 2>/dev/null | head -1)" ] && t="${t}Xcode+"
  [ -f "$r/Package.swift" ]    && t="${t}SwiftPM+"
  { [ -f "$r/build.gradle" ] || [ -f "$r/build.gradle.kts" ] || [ -f "$r/settings.gradle" ] || [ -f "$r/settings.gradle.kts" ]; } && t="${t}Gradle+"
  [ -f "$r/pubspec.yaml" ]     && t="${t}Flutter+"
  [ -f "$r/Cargo.toml" ]       && t="${t}Rust+"
  [ -f "$r/package.json" ]     && t="${t}Node+"
  t="${t%+}"
  [ -z "$t" ] && t="Git"
  printf '%s' "$t"
}

discover_projects() {
  local root="$1"
  PROJ_ROOTS=(); PROJ_TYPES=(); PROJ_GITS=()
  local hits accepted="" p r depth
  # Un solo find: poda directorios pesados, imprime marcadores.
  hits=$(find "$root" -maxdepth 5 \
      \( -type d \( -name node_modules -o -name Pods -o -name build -o -name dist \
         -o -name .next -o -name DerivedData -o -name .gradle -o -name Library \) -prune \) -o \
      \( -type d -name .git -print -prune \) -o \
      \( -type d -name '*.xcodeproj' -print -prune \) -o \
      \( -type f \( -name package.json -o -name Package.swift -o -name pubspec.yaml \
         -o -name Cargo.toml -o -name build.gradle -o -name build.gradle.kts \
         -o -name settings.gradle -o -name settings.gradle.kts \) -print \) \
      2>/dev/null)
  [ -n "$hits" ] || return
  # marcador → raíz candidata; orden por profundidad; sin raíces anidadas
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    local skip=0 a
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      case "$r" in "$a"|"$a"/*) skip=1; break ;; esac
    done <<< "$accepted"
    [ "$skip" -eq 1 ] && continue
    accepted="$accepted$r
"
    PROJ_ROOTS[${#PROJ_ROOTS[@]}]="$r"
    PROJ_TYPES[${#PROJ_TYPES[@]}]="$(detect_type "$r")"
    PROJ_GITS[${#PROJ_GITS[@]}]="$([ -d "$r/.git" ] && printf '%s' "$r" || git_root_of "$r" || true)"
  done < <(printf '%s\n' "$hits" | sed 's|/[^/]*$||' | sort -u \
           | awk -F/ '{print NF"\t"$0}' | sort -n | cut -f2-)
}

# ═══════════════════════════════════════════════════════════════════════════
#  ANÁLISIS Y LIMPIEZA POR PROYECTO / PER-PROJECT ANALYSIS & CLEANING
# ═══════════════════════════════════════════════════════════════════════════
# Artefactos reconocidos dentro de un proyecto (regenerables por definición):
ARTIFACT_NAMES='build dist .next .nuxt .output .turbo .parcel-cache .gradle .dart_tool .build coverage out'

project_artifacts() { # $1=root  → imprime rutas candidatas / prints candidate paths
  local r="$1" names args=() n first=1
  for n in $ARTIFACT_NAMES; do
    if [ "$first" -eq 1 ]; then args=( -name "$n" ); first=0
    else args=( "${args[@]}" -o -name "$n" ); fi
  done
  find "$r" -type d -not -path '*/node_modules/*' -not -path '*/.git/*' \
       \( "${args[@]}" \) -prune -print 2>/dev/null
  # target/ solo para proyectos Rust (evita falsos positivos)
  [ -f "$r/Cargo.toml" ] && find "$r" -maxdepth 3 -type d -name target \
       -not -path '*/node_modules/*' -prune -print 2>/dev/null
  # el único rincón de node_modules que SÍ es caché
  find "$r" -type d -path '*/node_modules/.cache' -prune -print 2>/dev/null
}

clean_project() { # $1=root $2=level(1=safe,2=deep)
  local r="$1" lvl="$2" groot d
  groot="$([ -d "$r/.git" ] && printf '%s' "$r" || git_root_of "$r" || true)"
  if [ -z "$groot" ]; then
    msg "  (sin git: solo artefactos de la lista conocida)" \
        "  (no git: known-artifact list only)"
  fi
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ "$lvl" -eq 1 ]; then
      # safe: solo artefactos sin tocar en SAFE_TTL días
      find "$d" -maxdepth 0 -mtime +$SAFE_TTL 2>/dev/null | grep -q . || continue
    fi
    del "$d" "${d#$r/}" "$groot"
  done < <(project_artifacts "$r")
}

# ═══════════════════════════════════════════════════════════════════════════
#  CACHÉS GLOBALES DE DESARROLLO / GLOBAL DEV CACHES (macOS)
# ═══════════════════════════════════════════════════════════════════════════
clean_global() { # $1=level $2=scan_root (para detectar versiones gradle en uso)
  local lvl="$1" root="$2"
  msg "▸ Cachés globales de desarrollo" "▸ Global development caches"

  # Simuladores de runtimes ya desinstalados
  if command -v xcrun >/dev/null 2>&1; then
    if [ "$MODE" = "run" ]; then
      xcrun simctl delete unavailable >/dev/null 2>&1 \
        && msg "  ✓ simuladores 'unavailable' eliminados" "  ✓ 'unavailable' simulators deleted"
    else
      local n; n=$(xcrun simctl list devices 2>/dev/null | grep -ci unavailable || true)
      [ "${n:-0}" -gt 0 ] && msg "  • $n simulador(es) de runtimes desinstalados" "  • $n simulator(s) from uninstalled runtimes"
    fi
  fi

  # Xcode DerivedData
  local DD="$HOME/Library/Developer/Xcode/DerivedData" d
  if [ -d "$DD" ]; then
    if [ "$lvl" -ge 2 ]; then
      while IFS= read -r -d '' d; do del "$d" "DerivedData/$(basename "$d")"; done \
        < <(find "$DD" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    else
      while IFS= read -r -d '' d; do del "$d" "DerivedData/$(basename "$d")"; done \
        < <(find "$DD" -mindepth 1 -maxdepth 1 -type d -mtime +$SAFE_TTL -print0 2>/dev/null)
    fi
  fi

  # Cachés SPM / Xcode
  del "$HOME/Library/Caches/org.swift.swiftpm" "Swift Package Manager cache"
  del "$HOME/Library/Caches/com.apple.dt.Xcode" "Xcode cache"
  [ "$lvl" -ge 2 ] && del "$HOME/Library/Developer/Xcode/CodingAssistant" "Xcode CodingAssistant"

  # Workspaces de XcodeBuildMCP (el servidor MCP que compila para los agentes).
  # 2026-08-24: uno solo habia crecido a 28 GB sin que nada lo limpiara y llevo
  # el disco al 100%. Son DerivedData por workspace: regenerables.
  if [ "$lvl" -ge 2 ] && [ -d "$HOME/Library/Developer/XcodeBuildMCP/workspaces" ]; then
    for d in "$HOME/Library/Developer/XcodeBuildMCP/workspaces"/*; do
      [ -d "$d" ] || continue
      del "$d" "XcodeBuildMCP workspace $(basename "$d")"
    done
  fi

  # Gradle: SOLO versiones que ningún wrapper del root usa + build-cache + logs
  local GC="$HOME/.gradle/caches" KEEP ver
  if [ -d "$GC" ]; then
    KEEP=$(find "$root" -name gradle-wrapper.properties -not -path '*/node_modules/*' 2>/dev/null \
           -exec grep -h distributionUrl {} \; \
           | sed -nE 's/.*gradle-([0-9]+\.[0-9]+(\.[0-9]+)?)-.*/\1/p' | sort -u)
    if [ -n "$KEEP" ]; then
      while IFS= read -r -d '' d; do
        ver="$(basename "$d")"
        if echo "$KEEP" | grep -qx "$ver"; then
          msg "  ⋯ conservado (en uso): gradle $ver" "  ⋯ kept (in use): gradle $ver"
        else
          del "$d" "gradle cache $ver ($(txt 'huérfana' 'orphan'))"
          del "$HOME/.gradle/daemon/$ver" "gradle daemon $ver"
        fi
      done < <(find "$GC" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*.[0-9]*' -print0 2>/dev/null)
    fi
    del "$GC/build-cache-1" "gradle build-cache"
  fi
  while IFS= read -r -d '' d; do del "$d" "gradle daemon log"; done \
    < <(find "$HOME/.gradle/daemon" -type f -name '*.out.log' -print0 2>/dev/null)

  # npm / node-gyp (solo deep: son cachés compartidas entre TODOS tus proyectos)
  if [ "$lvl" -ge 2 ]; then
    if [ "$MODE" = "run" ]; then
      command -v npm >/dev/null 2>&1 && npm cache clean --force >/dev/null 2>&1 \
        && msg "  ✓ caché de npm limpiada" "  ✓ npm cache cleaned"
    else
      [ -d "$HOME/.npm/_cacache" ] \
        && msg "  • liberaría $(human "$(size_of "$HOME/.npm/_cacache")"): caché de npm" \
               "  • would free $(human "$(size_of "$HOME/.npm/_cacache")"): npm cache"
    fi
    del "$HOME/Library/Caches/node-gyp" "node-gyp cache"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  GIT PRIMERO / GIT FIRST — ofrecer checkpoint antes de limpiar
# ═══════════════════════════════════════════════════════════════════════════
offer_git_checkpoint() { # $1=git_root
  local g="$1" dirty ahead r
  dirty=$(git -C "$g" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  ahead=$(git -C "$g" rev-list --count '@{u}..HEAD' 2>/dev/null || echo "")
  [ "${dirty:-0}" -eq 0 ] && { [ -z "$ahead" ] || [ "${ahead:-0}" -eq 0 ]; } && return 0
  echo ""
  msg "  ⚠ $(basename "$g"): $dirty cambio(s) sin commit${ahead:+, $ahead commit(s) sin push}." \
      "  ⚠ $(basename "$g"): $dirty uncommitted change(s)${ahead:+, $ahead unpushed commit(s)}."
  is_tty || { msg "    (no interactivo: sigo sin tocar git)" "    (non-interactive: continuing without touching git)"; return 0; }
  if [ "${dirty:-0}" -gt 0 ]; then
    printf '%s' "$(txt '    ¿Hacer commit de todo ahora? [s/N]: ' '    Commit everything now? [y/N]: ')"
    read -r r
    case "$r" in
      s|S|y|Y)
        git -C "$g" add -A && git -C "$g" commit -m "dev-knifesweep: checkpoint $(ts)" >/dev/null 2>&1 \
          && msg "    ✓ commit hecho" "    ✓ committed" \
          || msg "    ✗ commit falló — revisa a mano" "    ✗ commit failed — check manually" ;;
    esac
  fi
  ahead=$(git -C "$g" rev-list --count '@{u}..HEAD' 2>/dev/null || echo "")
  if [ -n "$ahead" ] && [ "${ahead:-0}" -gt 0 ]; then
    printf '%s' "$(txt '    ¿Push al remoto? [s/N]: ' '    Push to remote? [y/N]: ')"
    read -r r
    case "$r" in
      s|S|y|Y) git -C "$g" push >/dev/null 2>&1 && msg "    ✓ push hecho" "    ✓ pushed" \
               || msg "    ✗ push falló — revisa a mano" "    ✗ push failed — check manually" ;;
    esac
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  SCAN
# ═══════════════════════════════════════════════════════════════════════════
cmd_scan() {
  local root="$1"
  echo "═══════════════════════════════════════════════════════════════"
  msg "  DEV-KnifeSweep v$KNIFESWEEP_VERSION — proyectos en: $root" \
      "  DEV-KnifeSweep v$KNIFESWEEP_VERSION — projects in: $root"
  echo "═══════════════════════════════════════════════════════════════"
  discover_projects "$root"
  if [ ${#PROJ_ROOTS[@]} -eq 0 ]; then
    msg "  No encontré proyectos (busco .git, *.xcodeproj, package.json, gradle, Cargo.toml, pubspec.yaml)." \
        "  No projects found (I look for .git, *.xcodeproj, package.json, gradle, Cargo.toml, pubspec.yaml)."
    return 1
  fi
  local i sz art total_art=0
  for i in "${!PROJ_ROOTS[@]}"; do
    sz=$(size_of "${PROJ_ROOTS[$i]}")
    art=0
    local d
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      art=$(( art + $(size_of "$d") ))
    done < <(project_artifacts "${PROJ_ROOTS[$i]}")
    total_art=$(( total_art + art ))
    printf '  %2d) %-34s %-14s %8s  %s\n' "$((i+1))" \
      "$(basename "${PROJ_ROOTS[$i]}")" "[${PROJ_TYPES[$i]}]" "$(human "$sz")" \
      "$(txt 'artefactos:' 'artifacts:') $(human "$art")"
  done
  echo ""
  msg "  Disco libre: $(free_now) · Artefactos regenerables detectados: ~$(human "$total_art")" \
      "  Free disk: $(free_now) · Regenerable artifacts detected: ~$(human "$total_art")"
  msg "  (más las cachés globales: DerivedData, SPM, gradle, npm)" \
      "  (plus global caches: DerivedData, SPM, gradle, npm)"
  rule
}

# ═══════════════════════════════════════════════════════════════════════════
#  CLEAN (no interactivo / non-interactive)
# ═══════════════════════════════════════════════════════════════════════════
cmd_clean() { # usa globals: ROOT LEVEL MODE ASSUME_YES DO_GLOBAL
  local lname; lname="$([ "$LEVEL" -ge 2 ] && echo deep || echo safe)"
  echo "═══════════════════════════════════════════════════════════════"
  msg "  DEV-KnifeSweep clean — nivel: $lname · modo: $MODE · raíz: $ROOT" \
      "  DEV-KnifeSweep clean — level: $lname · mode: $MODE · root: $ROOT"
  echo "═══════════════════════════════════════════════════════════════"
  msg "  Disco libre antes: $(free_now)" "  Free disk before: $(free_now)"

  if [ "$MODE" = "run" ]; then
    require_accept
    logln "===== RUN level=$lname root=$ROOT ====="
    if [ "$ASSUME_YES" -ne 1 ]; then
      is_tty || { msg "Sin terminal: usa --yes (tras aceptar el aviso) para correr sin preguntar." \
                      "No terminal: use --yes (after accepting the notice) to run unattended."; exit 1; }
      show_protections; echo ""
      printf '%s' "$(txt '  ¿Confirmas la limpieza? [S/N]: ' '  Confirm cleanup? [Y/N]: ')"
      local r; read -r r
      r=$(printf '%s' "$r" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
      case "$r" in s|si|sí|y|yes) : ;; *) msg "  Cancelado." "  Cancelled."; exit 0 ;; esac
    fi
  fi

  discover_projects "$ROOT"
  local i
  for i in "${!PROJ_ROOTS[@]}"; do
    echo ""
    msg "▸ ${PROJ_ROOTS[$i]#$ROOT/} [${PROJ_TYPES[$i]}]" "▸ ${PROJ_ROOTS[$i]#$ROOT/} [${PROJ_TYPES[$i]}]"
    clean_project "${PROJ_ROOTS[$i]}" "$LEVEL"
  done
  echo ""
  [ "$DO_GLOBAL" -eq 1 ] && clean_global "$LEVEL" "$ROOT"

  echo ""
  rule
  if [ "$MODE" = "run" ]; then
    msg "  Disco libre después: $(free_now) · liberado ~$(human "$FREED_K") en $ITEMS elemento(s)" \
        "  Free disk after: $(free_now) · freed ~$(human "$FREED_K") across $ITEMS item(s)"
    logln "freed ~$(human "$FREED_K") items=$ITEMS"
    osascript -e "display notification \"$(txt 'Liberado' 'Freed') ~$(human "$FREED_K")\" with title \"DEV-KnifeSweep\"" 2>/dev/null || true
  else
    msg "  Liberaría ~$(human "$FREED_K") en $ITEMS elemento(s). Nada fue borrado." \
        "  Would free ~$(human "$FREED_K") across $ITEMS item(s). Nothing was deleted."
    msg "  Para ejecutar:  dev-knifesweep clean --root \"$ROOT\" --$lname --run" \
        "  To execute:  dev-knifesweep clean --root \"$ROOT\" --$lname --run"
  fi
  rule
}

# ═══════════════════════════════════════════════════════════════════════════
#  ASISTENTE INTERACTIVO / INTERACTIVE WIZARD
# ═══════════════════════════════════════════════════════════════════════════
cmd_wizard() {
  is_tty || { msg "El asistente necesita una terminal. Usa: dev-knifesweep scan / clean --root …" \
                  "The wizard needs a terminal. Use: dev-knifesweep scan / clean --root …"; exit 1; }
  echo ""
  msg "🔪🧹 DEV-KnifeSweep v$KNIFESWEEP_VERSION — asistente de mantenimiento" \
      "🔪🧹 DEV-KnifeSweep v$KNIFESWEEP_VERSION — maintenance wizard"
  msg "   creado por j0suedaniel · JDMC.TECH" \
      "   created by j0suedaniel · JDMC.TECH"
  echo ""

  # 1) raíz / root
  printf '%s' "$(txt "¿Dónde están tus proyectos? [Enter = $PWD]: " "Where are your projects? [Enter = $PWD]: ")"
  local root; read -r root
  root="${root:-$PWD}"
  root="${root/#\~/$HOME}"
  [ -d "$root" ] || { msg "  ✗ No existe: $root" "  ✗ Not found: $root"; exit 1; }

  # 2) descubrir / discover
  echo ""
  msg "Analizando $root …" "Analyzing $root …"
  cmd_scan "$root" || exit 1

  # 3) selección / selection
  printf '%s' "$(txt 'Números a limpiar (ej: 1 3 5) o "a" = todos: ' 'Numbers to clean (e.g. 1 3 5) or "a" = all: ')"
  local pick; read -r pick
  local SEL=() i
  if [ "$pick" = "a" ] || [ "$pick" = "A" ] || [ -z "$pick" ]; then
    for i in "${!PROJ_ROOTS[@]}"; do SEL[${#SEL[@]}]="$i"; done
  else
    for i in $pick; do
      case "$i" in (*[!0-9]*) continue ;; esac
      [ "$i" -ge 1 ] && [ "$i" -le ${#PROJ_ROOTS[@]} ] && SEL[${#SEL[@]}]=$((i-1))
    done
  fi
  [ ${#SEL[@]} -gt 0 ] || { msg "Nada seleccionado." "Nothing selected."; exit 0; }

  # 4) git primero / git first
  echo ""
  msg "▸ Revisión git (recomendado hacer commit antes de limpiar)" \
      "▸ Git review (committing before cleaning is recommended)"
  local done_gits=""
  for i in "${SEL[@]}"; do
    local g="${PROJ_GITS[$i]}"
    [ -n "$g" ] || continue
    case "$done_gits" in *"|$g|"*) continue ;; esac
    done_gits="$done_gits|$g|"
    offer_git_checkpoint "$g"
  done

  # 5) nivel / level
  echo ""
  msg "Nivel de limpieza:" "Cleanup level:"
  msg "  1) safe — artefactos sin tocar en +$SAFE_TTL días (builds recientes siguen incrementales)" \
      "  1) safe — artifacts untouched for $SAFE_TTL+ days (recent builds stay incremental)"
  msg "  2) deep — TODOS los artefactos regenerables (máximo espacio; próximo build completo)" \
      "  2) deep — ALL regenerable artifacts (max space; next build is a full one)"
  printf '%s' "$(txt 'Elige [1/2, Enter=1]: ' 'Choose [1/2, Enter=1]: ')"
  local lv; read -r lv
  LEVEL=1; [ "$lv" = "2" ] && LEVEL=2

  printf '%s' "$(txt '¿Incluir cachés globales (DerivedData, SPM, gradle, npm)? [S/n]: ' 'Include global caches (DerivedData, SPM, gradle, npm)? [Y/n]: ')"
  local gg; read -r gg
  DO_GLOBAL=1; case "$gg" in n|N) DO_GLOBAL=0 ;; esac

  # 6) reporte primero, siempre / report first, always
  echo ""
  msg "▸ REPORTE (nada se borra todavía)…" "▸ REPORT (nothing gets deleted yet)…"
  MODE="report"; FREED_K=0; ITEMS=0; SEEN_TARGETS=""
  for i in "${SEL[@]}"; do
    echo ""
    msg "▸ $(basename "${PROJ_ROOTS[$i]}") [${PROJ_TYPES[$i]}]" "▸ $(basename "${PROJ_ROOTS[$i]}") [${PROJ_TYPES[$i]}]"
    clean_project "${PROJ_ROOTS[$i]}" "$LEVEL"
  done
  [ "$DO_GLOBAL" -eq 1 ] && { echo ""; clean_global "$LEVEL" "$root"; }
  echo ""
  msg "TOTAL que se liberaría: ~$(human "$FREED_K") en $ITEMS elemento(s)" \
      "TOTAL that would be freed: ~$(human "$FREED_K") across $ITEMS item(s)"
  [ "$ITEMS" -eq 0 ] && { msg "Nada que limpiar. 🎉" "Nothing to clean. 🎉"; exit 0; }

  # 7) confirmación / confirmation
  echo ""
  require_accept
  show_protections
  echo ""
  printf '%s' "$(txt '¿Ejecutar la limpieza de verdad? [S/N]: ' 'Run the real cleanup? [Y/N]: ')"
  local ok; read -r ok
  ok=$(printf '%s' "$ok" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
  case "$ok" in s|si|sí|y|yes) : ;; *) msg "Cancelado. Nada fue borrado." "Cancelled. Nothing was deleted."; exit 0 ;; esac

  # 8) ejecutar / execute
  MODE="run"; FREED_K=0; ITEMS=0; SEEN_TARGETS=""
  logln "===== WIZARD RUN level=$LEVEL root=$root ====="
  for i in "${SEL[@]}"; do
    echo ""
    msg "▸ $(basename "${PROJ_ROOTS[$i]}")" "▸ $(basename "${PROJ_ROOTS[$i]}")"
    clean_project "${PROJ_ROOTS[$i]}" "$LEVEL"
  done
  [ "$DO_GLOBAL" -eq 1 ] && { echo ""; clean_global "$LEVEL" "$root"; }
  echo ""
  rule
  msg "✓ Listo. Liberado ~$(human "$FREED_K") · disco libre: $(free_now)" \
      "✓ Done. Freed ~$(human "$FREED_K") · free disk: $(free_now)"
  msg "  Recuerda: el próximo build de cada proyecto limpiado será completo." \
      "  Remember: each cleaned project's next build will be a full one."
  logln "wizard freed ~$(human "$FREED_K")"
  osascript -e "display notification \"$(txt 'Liberado' 'Freed') ~$(human "$FREED_K")\" with title \"DEV-KnifeSweep\"" 2>/dev/null || true
  rule

  # 9) ofrecer rutina / offer routine
  if [ ! -f "$PLIST_ROUTINE" ]; then
    echo ""
    printf '%s' "$(txt '¿Quieres programar esto como rutina automática? [s/N]: ' 'Want to schedule this as an automatic routine? [y/N]: ')"
    local sr; read -r sr
    case "$sr" in s|S|y|Y) cmd_schedule "$root" ;; esac
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  RUTINA PROGRAMADA / SCHEDULED ROUTINE (launchd)
# ═══════════════════════════════════════════════════════════════════════════
write_plist_routine() { # $1=root $2=freq(d|3|w)
  local root="$1" freq="$2" cal=""
  case "$freq" in
    d) cal="<key>StartCalendarInterval</key><dict><key>Hour</key><integer>3</integer><key>Minute</key><integer>0</integer></dict>" ;;
    3) cal="<key>StartInterval</key><integer>259200</integer>" ;;
    w) cal="<key>StartCalendarInterval</key><dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>3</integer><key>Minute</key><integer>0</integer></dict>" ;;
  esac
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.dev-knifesweep.routine</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string>
    <string>$HOME/.local/bin/dev-knifesweep</string>
    <string>clean</string><string>--root</string><string>$root</string>
    <string>--safe</string><string>--run</string><string>--yes</string>
  </array>
  $cal
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict></plist>
PLIST
}

cmd_schedule() {
  local root="${1:-}"
  require_accept
  if ! is_tty; then
    msg "schedule es interactivo; córrelo tú en la terminal." \
        "schedule is interactive; run it yourself in the terminal."
    exit 1
  fi
  if [ -z "$root" ]; then
    printf '%s' "$(txt "¿Raíz de proyectos para la rutina? [Enter = $PWD]: " "Project root for the routine? [Enter = $PWD]: ")"
    read -r root; root="${root:-$PWD}"; root="${root/#\~/$HOME}"
  fi
  [ -d "$root" ] || { msg "  ✗ No existe: $root" "  ✗ Not found: $root"; exit 1; }
  msg "Frecuencia:  d) diaria 3AM   3) cada 3 días   w) semanal (domingo 3AM)" \
      "Frequency:  d) daily 3AM   3) every 3 days   w) weekly (Sunday 3AM)"
  printf '%s' "$(txt 'Elige [d/3/w, Enter=w]: ' 'Choose [d/3/w, Enter=w]: ')"
  local f; read -r f; f="${f:-w}"
  case "$f" in d|3|w) : ;; *) f=w ;; esac
  mkdir -p "$HOME/Library/LaunchAgents"
  write_plist_routine "$root" "$f" > "$PLIST_ROUTINE"
  launchctl bootout "gui/$(id -u)" "$PLIST_ROUTINE" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST_ROUTINE" 2>/dev/null \
    && msg "✓ Rutina instalada (nivel safe, solo artefactos +$SAFE_TTL días). Log: $LOG" \
           "✓ Routine installed (safe level, only $SAFE_TTL+ day-old artifacts). Log: $LOG" \
    || msg "✗ No pude cargar el agente; revisa: launchctl bootstrap gui/\$(id -u) $PLIST_ROUTINE" \
           "✗ Could not load the agent; check: launchctl bootstrap gui/\$(id -u) $PLIST_ROUTINE"
  msg "  (la rutina automática NUNCA usa nivel deep — eso es siempre manual)" \
      "  (the automatic routine NEVER uses deep level — that one is always manual)"
}

# ═══════════════════════════════════════════════════════════════════════════
#  MONITOR DE ESPACIO / FREE-SPACE MONITOR
# ═══════════════════════════════════════════════════════════════════════════
cmd_monitor() {
  require_accept
  is_tty || { msg "monitor es interactivo; córrelo tú en la terminal." \
                  "monitor is interactive; run it yourself in the terminal."; exit 1; }
  printf '%s' "$(txt '¿Umbral de espacio libre en GB para avisarte? [Enter = 30]: ' 'Free-space threshold in GB to alert you? [Enter = 30]: ')"
  local th; read -r th; th="${th:-30}"
  case "$th" in (*[!0-9]*) th=30 ;; esac
  mkdir -p "$HOME/Library/LaunchAgents" "$STATE_DIR"
  echo "$th" > "$STATE_DIR/threshold-gb"
  cat > "$PLIST_MONITOR" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.dev-knifesweep.monitor</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string>
    <string>$HOME/.local/bin/dev-knifesweep</string>
    <string>_monitor-check</string>
  </array>
  <key>StartInterval</key><integer>21600</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict></plist>
PLIST
  launchctl bootout "gui/$(id -u)" "$PLIST_MONITOR" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST_MONITOR" 2>/dev/null \
    && msg "✓ Monitor instalado: revisa cada 6h y te avisa si el disco libre baja de ${th}GB." \
           "✓ Monitor installed: checks every 6h and alerts you when free disk drops below ${th}GB." \
    || msg "✗ No pude cargar el monitor." "✗ Could not load the monitor."
  msg "  (solo AVISA con una notificación — nunca limpia por su cuenta)" \
      "  (it only ALERTS with a notification — it never cleans on its own)"
}

cmd_monitor_check() {
  local th=30
  [ -f "$STATE_DIR/threshold-gb" ] && th=$(cat "$STATE_DIR/threshold-gb")
  local fg; fg=$(free_gb)
  logln "monitor: free=${fg}G threshold=${th}G"
  if [ "${fg:-999}" -lt "$th" ]; then
    osascript -e "display notification \"$(txt "Disco libre: ${fg}GB (umbral ${th}GB). Corre 'dev-knifesweep' para limpiar." "Free disk: ${fg}GB (threshold ${th}GB). Run 'dev-knifesweep' to clean up.")\" with title \"DEV-KnifeSweep\"" 2>/dev/null || true
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  STATUS / UNSCHEDULE / UNINSTALL
# ═══════════════════════════════════════════════════════════════════════════
cmd_status() {
  msg "DEV-KnifeSweep v$KNIFESWEEP_VERSION · disco libre: $(free_now)" \
      "DEV-KnifeSweep v$KNIFESWEEP_VERSION · free disk: $(free_now)"
  if is_accepted; then
    msg "  aviso: aceptado ($(grep accepted= "$ACCEPT_FILE" | cut -d= -f2))" \
        "  notice: accepted ($(grep accepted= "$ACCEPT_FILE" | cut -d= -f2))"
  else
    msg "  aviso: PENDIENTE — corre 'dev-knifesweep accept'" "  notice: PENDING — run 'dev-knifesweep accept'"
  fi
  local a
  for a in com.dev-knifesweep.routine com.dev-knifesweep.monitor; do
    if launchctl print "gui/$(id -u)/$a" >/dev/null 2>&1; then
      msg "  $a: cargado" "  $a: loaded"
    else
      msg "  $a: no instalado" "  $a: not installed"
    fi
  done
  [ -f "$STATE_DIR/threshold-gb" ] && msg "  umbral monitor: $(cat "$STATE_DIR/threshold-gb")GB" "  monitor threshold: $(cat "$STATE_DIR/threshold-gb")GB"
  [ -f "$LOG" ] && { msg "  últimas líneas del log:" "  last log lines:"; tail -3 "$LOG" | sed 's/^/    /'; }
  return 0
}

cmd_unschedule() {
  local a
  for a in "$PLIST_ROUTINE" "$PLIST_MONITOR"; do
    [ -f "$a" ] || continue
    launchctl bootout "gui/$(id -u)" "$a" 2>/dev/null || true
    rm -f "$a"
    msg "  ✓ quitado: $(basename "$a")" "  ✓ removed: $(basename "$a")"
  done
  msg "Listo." "Done."
}

cmd_uninstall() {
  cmd_unschedule
  rm -rf "$STATE_DIR"
  rm -f "$HOME/.local/bin/dev-knifesweep"
  rm -rf "$HOME/.claude/skills/dev-knifesweep"
  rm -f "$HOME/.codex/prompts/dev-knifesweep.md"
  msg "✓ DEV-KnifeSweep desinstalado. (El log $LOG se conserva por si lo quieres.)" \
      "✓ DEV-KnifeSweep uninstalled. (The log $LOG is kept in case you want it.)"
}

# ═══════════════════════════════════════════════════════════════════════════
#  DISPATCH
# ═══════════════════════════════════════════════════════════════════════════
CMD="wizard"; ROOT="$PWD"; LEVEL=1; MODE="report"; ASSUME_YES=0; DO_GLOBAL=1
while [ $# -gt 0 ]; do
  case "$1" in
    scan|clean|schedule|monitor|status|accept|unschedule|uninstall|_monitor-check) CMD="$1" ;;
    --root)      shift; ROOT="${1:-$PWD}"; ROOT="${ROOT/#\~/$HOME}" ;;
    --safe)      LEVEL=1 ;;
    --deep)      LEVEL=2 ;;
    --report)    MODE="report" ;;
    --run)       MODE="run" ;;
    --yes|-y)    ASSUME_YES=1 ;;
    --global)    DO_GLOBAL=1 ;;
    --no-global) DO_GLOBAL=0 ;;
    --version|-V) echo "dev-knifesweep $KNIFESWEEP_VERSION · $(txt 'creado por' 'created by') j0suedaniel · JDMC.TECH"; exit 0 ;;
    -h|--help)   sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) msg "Opción desconocida: $1 (usa --help)" "Unknown option: $1 (use --help)"; exit 1 ;;
  esac
  shift
done

[ -d "$ROOT" ] || { msg "✗ Raíz no existe: $ROOT" "✗ Root not found: $ROOT"; exit 1; }

case "$CMD" in
  wizard)         cmd_wizard ;;
  scan)           cmd_scan "$ROOT" ;;
  clean)          cmd_clean ;;
  schedule)       cmd_schedule "$ROOT" ;;
  monitor)        cmd_monitor ;;
  status)         cmd_status ;;
  accept)         cmd_accept ;;
  unschedule)     cmd_unschedule ;;
  uninstall)      cmd_uninstall ;;
  _monitor-check) cmd_monitor_check ;;
esac
````

## Archivo 2/3: `~/.claude/skills/dev-knifesweep/SKILL.md`  (skill de Claude Code)

````markdown
---
name: dev-knifesweep
description: Mantenimiento y optimización de directorios de proyectos en macOS — limpieza segura de artefactos de build (DerivedData, build/, dist/, cachés de Gradle/SPM/npm) con asistente, rutina programada y monitor de espacio. Use when the user asks to clean or optimize project storage, free disk space taken by builds/caches, analyze which projects use the most space, or schedule automatic cleanup routines. / Úsalo cuando el usuario pida limpiar u optimizar el almacenamiento de sus proyectos, liberar espacio de builds/cachés, o programar rutinas de limpieza.
---

# DEV-KnifeSweep — guía para el agente / agent guide

DEV-KnifeSweep es un CLI (`dev-knifesweep`) que limpia SOLO artefactos de build regenerables.
Tu papel es ser la capa conversacional: tú analizas y presentas; el motor borra
con sus propias salvaguardas. **Nunca borres artefactos con `rm -rf` a mano —
usa siempre el motor**, porque él aplica las 8 salvaguardas (gitignore-check,
node_modules, montajes virtuales, lista protegida, etc.).

## Si no está instalado

`command -v dev-knifesweep` falla → ofrece instalarlo:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/j0suedaniel/DEV-KnifeSweep/main/install.sh)"
```

## Flujo que debes seguir (en el idioma del usuario)

1. **Pregunta la raíz** de proyectos si no es obvia (o usa el directorio actual).
2. **Escanea**: `dev-knifesweep scan --root <dir>` y muestra la tabla al usuario.
   Pregunta cuáles proyectos quiere optimizar.
3. **Git primero**: para cada proyecto con cambios sin commit o sin push,
   recomienda hacer commit/push ANTES de limpiar y ofrécete a hacerlo
   (con el permiso explícito del usuario).
4. **Reporte primero, siempre**:
   `dev-knifesweep clean --root <dir> --safe|--deep --report` y presenta el resumen
   (qué se liberaría, qué se omite y por qué). `--safe` = solo artefactos con
   +7 días sin tocar; `--deep` = todos los regenerables (el próximo build será
   completo — dile esto al usuario).
5. **Confirmación humana**: pide al usuario un "sí" explícito EN EL CHAT antes
   de ejecutar. Solo entonces corre
   `dev-knifesweep clean --root <dir> --safe|--deep --run --yes`.
6. **Reporta el resultado** con el espacio liberado y recuérdale que el próximo
   build de los proyectos limpiados será completo.

## Reglas duras (no negociables)

- La **primera vez**, el propio usuario debe correr `dev-knifesweep accept` en su
  terminal (es interactivo a propósito: la aceptación del aviso legal es
  humana, no del agente). Si `--run` falla por eso, explícaselo.
- **Nunca** pases `--yes` sin que el usuario haya confirmado esa limpieza
  concreta en el chat, en este turno o el anterior.
- **Nunca** uses nivel `deep` en rutinas programadas — el motor tampoco lo
  permite; no lo rodees.
- Si el usuario quiere automatizar: `dev-knifesweep schedule` (rutina) y
  `dev-knifesweep monitor` (aviso por umbral de espacio) — ambos los corre el
  usuario en su terminal porque son interactivos.
- No toques `~/.dev-knifesweep/disclaimer-accepted` ni los LaunchAgents a mano.

## Comandos útiles

| Comando | Qué hace |
|---|---|
| `dev-knifesweep scan --root D` | tabla de proyectos, tipo, tamaño y artefactos |
| `dev-knifesweep clean --root D --safe --report` | dry-run conservador |
| `dev-knifesweep clean --root D --deep --report` | dry-run completo |
| `... --run --yes` | ejecuta (requiere aceptación previa + tu confirmación en chat) |
| `... --no-global` | omite cachés globales (DerivedData, SPM, gradle, npm) |
| `dev-knifesweep status` | estado de aviso, rutina, monitor y log |
| `dev-knifesweep unschedule` / `uninstall` | quitar agentes / desinstalar todo |
````

## Archivo 3/3: `~/.codex/prompts/dev-knifesweep.md`  (prompt de Codex CLI)

````markdown
# /dev-knifesweep — mantenimiento seguro de proyectos (macOS)

Eres la capa conversacional de DEV-KnifeSweep, un CLI (`dev-knifesweep`) que limpia SOLO
artefactos de build regenerables (DerivedData, build/, dist/, cachés de
Gradle/SPM/npm). Responde en el idioma del usuario.

Si `command -v dev-knifesweep` falla, ofrece instalarlo:
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/j0suedaniel/DEV-KnifeSweep/main/install.sh)"`

## Flujo

1. Pregunta la carpeta raíz de proyectos (o usa la actual).
2. `dev-knifesweep scan --root <dir>` → muestra la tabla; pregunta qué proyectos optimizar.
3. Antes de limpiar, recomienda commit/push de todo lo pendiente y ofrécete a
   hacerlo con permiso explícito del usuario.
4. Siempre reporte primero: `dev-knifesweep clean --root <dir> --safe|--deep --report`.
   Explica: `--safe` = artefactos +7 días; `--deep` = todo lo regenerable
   (próximo build completo).
5. Pide confirmación explícita en el chat; solo entonces:
   `dev-knifesweep clean --root <dir> --safe|--deep --run --yes`.
6. Reporta espacio liberado.

## Reglas duras

- NUNCA borres artefactos con `rm -rf` a mano: usa el motor (aplica
  gitignore-check, protección de node_modules, montajes virtuales y lista
  protegida).
- La primera aceptación del aviso (`dev-knifesweep accept`) la hace el USUARIO en su
  terminal; no la simules ni toques `~/.dev-knifesweep/`.
- Jamás `--yes` sin confirmación del usuario para ESA limpieza.
- `dev-knifesweep schedule` y `dev-knifesweep monitor` los corre el usuario (interactivos).
- Las rutinas programadas solo usan nivel safe; no lo rodees.
````

---

**Agente:** al terminar, muestra al usuario este resumen:

- Motor: `~/.local/bin/dev-knifesweep` (añade `~/.local/bin` al PATH si hace falta)
- Primer paso humano: `dev-knifesweep accept` (leer y aceptar el aviso)
- Asistente: `dev-knifesweep` · Rutina: `dev-knifesweep schedule` · Monitor: `dev-knifesweep monitor`
- Todo borrado pasa por 8 salvaguardas y siempre hay reporte antes de ejecutar.
- Repo canónico (para actualizaciones): https://github.com/j0suedaniel/DEV-KnifeSweep
