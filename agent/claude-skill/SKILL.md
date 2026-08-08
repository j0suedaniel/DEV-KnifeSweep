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
