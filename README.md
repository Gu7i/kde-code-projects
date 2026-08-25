# Code Projects — KDE Plasma Widget

A KDE Plasma 6 panel widget to quickly open your code projects in any editor, with Docker Compose integration and a custom HUD-style interface.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6-blue?logo=kde)
![QML](https://img.shields.io/badge/QML-Qt_6-green?logo=qt)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Design

Industrial HUD aesthetic: gray background (`#c0c0c0`), hairline black borders, monospace font. Each project is a scan card with a `PROJECT_ID  NOMBRE` header.

The palette follows four rules:

1. **One accent, one meaning.** Green (`#2fbf4a`) means *"this is alive"* and nothing else — the card's left rail, the `RUNNING` badge, the status bar, the per-service dot, and the `ACTIVOS` counter. It is never used for actions, selection, hover or counts.
2. **Signal green, not neon.** `#2fbf4a` instead of `#00ff00`, so it stops vibrating against the gray. `#0f5c22` for green text on a light ground.
3. **Three button tiers.** Ink fill (`#111111`) = primary (`+ ADD`, `▶ LAUNCH`, active toggles); 1 px hairline only = secondary (`OPEN`, `↓ PULL`, `LOG`, `SH`, `BLD`); red outline (`#a32d16`) = destructive (`■ STOP`, `✕ DEL`).
4. **The label steps back.** Field labels (`PATH`, `STATUS`, `FILE`, `EDITOR`) are 9 px, normal weight, gray; their values are 12 px bold ink. Hierarchy comes from size and color, not from two competing bolds.

The black card header bar is a **state signal, not decoration**: only a running project gets it, so the list can be scanned without reading a single badge. Barcodes and part numbers sit at 32 % opacity — texture, not data.

Dropdowns for editor and compose file selection use a custom dark HUD overlay instead of the system menu; the selected item is marked in white, since on a black surface white is the ink.

## Features

- Add any folder as a project with **+ ADD** (native KDE folder picker)
- **Per-project editor selector** — toggle with `✎ EDIT`; opens a custom HUD dropdown per card
- **Editor management** — configure the global editor list from widget settings (right-click → Configure)
- **Search/filter** — toggle `⌕ SRCH`; filters by project name, Escape to clear
- **Drag to reorder** — toggle `⇅ MOVE`; grab the handle on the left side of the card header
- **Delete mode** — toggle `✕ DEL`; reveals the remove button per card
- Project list and editor selections persist across reboots (stored in Plasma configuration)
- Tooltips in Spanish on all buttons (requires hover)
- **Docker Compose support** — if a project contains a compose file (`docker-compose*.yml/yaml`, `compose*.yml/yaml`):
  - **OPEN / ↓ PULL / ▶ LAUNCH** — stacked vertically on the right side of each card
  - **▶ LAUNCH** (ink) — runs `docker compose up -d`; service panel expands with live startup status
  - **■ STOP** — runs `docker compose down` across *all* profiles, regardless of which one is selected, so no profile-gated service (e.g. `ngrok`) is left running orphaned; also available during startup to cancel
  - **↓ PULL** — runs `docker compose pull` to update images (opens Konsole)
  - **▼/▲** — expand/collapse the service panel while Docker is running
  - **File selector** — when multiple compose files exist, the FILE row opens a custom HUD dropdown to pick the active one
  - **Profile selector** — when the compose file declares `profiles:` (e.g. a service gated behind `--profile fintoc`), a PROFILE dropdown appears next to FILE; picking one adds `--profile <name>` to every compose command (`up`, `ps`, `pull`, etc.) so those services become visible and launchable. Defaults to none, matching plain `docker compose` behavior
  - Spinner (`BusyIndicator`) while `docker compose down` is in progress
- **Live startup status** — while services start, each shows a pulsing status square; transitions to solid green (running) or red (exited/dead); polls every 1s during startup, every 3s otherwise; 60s safety timeout
- **Service panel** (shown per project when Docker is running):
  - Status square per service — pulsing gray (starting) / solid green (running) / red (exited)
  - Port badge outlined when exposed
  - **LOG** — `docker compose logs -f <service>` in Konsole
  - **↺** — `docker compose restart <service>`
  - **SH** — `docker compose exec <service> sh` in Konsole (running only)
  - **BLD** — `docker compose build <service>` in Konsole
  - **🌐** — opens `http://localhost:<port>` in the browser (running + port exposed only)
  - All service buttons hidden while the service is still starting

## Preview

```
╔══════════════════════════════════════════════════════╗
║  ▌▌▌ DEV PROJECTS        TOTAL  ACTIVOS    OFF      ║
║  PLASMA WIDGET // PROJECT LAUNCHER  06   ■ 04   02  ║
╠══════════════════════════════════════════════════════╣
║  [⌕ SRCH] [⇅ MOVE] [✎ EDIT] [✕ DEL]     [+ ADD]   ║
╠══════════════════════════════════════════════════════╣
║  ┌─ PROJECT_ID  MY-APP              [OFFLINE] ─┐    ║   ← apagado: cabecera clara
║  │  path    ~/Code/my-app              [OPEN ] │    ║
║  │  status  ░░░░░░░░░░░░              [↓ PULL] │    ║
║  │  file    compose.yml ▾             [▶LAUNCH]│    ║
║  └──────────────────────────────────────────────┘   ║
║  ▐┏━ PROJECT_ID  BACKEND            [RUNNING] ▼ ┓   ║   ← vivo: cabecera negra
║  ▐┃  path    ~/Code/backend              [OPEN ] ┃   ║      y raíl verde
║  ▐┃  status  ████████████████           [↓ PULL] ┃   ║
║  ▐┃  ┌─ SERVICIOS ─────────────────┐   [■ STOP] ┃   ║
║  ▐┃  │ ■ api  RUNNING :3000 LOG ↺ SH BLD 🌐    ┃   ║
║  ▐┃  │ ■ db   RUNNING :5432 LOG ↺ SH BLD       ┃   ║
║  ▐┃  └─────────────────────────────┘            ┃   ║
║  ▐┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛   ║
╚══════════════════════════════════════════════════════╝
```

## Requirements

- KDE Plasma 6
- `plasma5support` — for Docker Compose buttons (`sudo pacman -S plasma5support`)
- `konsole` — for logs and terminal (`sudo pacman -S konsole`)
- `docker` with Compose v2 (`docker compose` subcommand)
- At least one editor with its CLI available in `$PATH` (VS Code `code`, Kate `kate`, etc.)

## Installation

```bash
git clone https://github.com/Gu7i/kde-code-projects.git
cd kde-code-projects
./install.sh
```

The script installs all dependencies, copies the widget to `~/.local/share/plasma/plasmoids/` and restarts Plasma automatically.

### Add to panel

1. Right-click on the panel → **Add Widgets**
2. Search for **Code Projects**
3. Drag it to the panel or double-click

## Project structure

```
kde-code-projects/
├── install.sh             # Installation script
├── metadata.json          # Plasma plugin metadata
└── contents/
    ├── config/
    │   ├── config.qml     # Configuration pages definition
    │   └── main.xml       # Configuration schema
    └── ui/
        ├── main.qml       # Widget UI
        └── configEditors.qml  # Editors management settings page
```

## License

MIT
