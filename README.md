# Code Projects — KDE Plasma Widget

A KDE Plasma 6 panel widget to quickly open your VS Code projects.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6-blue?logo=kde)
![QML](https://img.shields.io/badge/QML-Qt_6-green?logo=qt)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features

- Add any folder as a project with the **+** button (native KDE folder picker)
- Click a project name to open it in a **new VS Code window** (`code --new-window`)
- Remove projects from the list with the **−** button
- Project list persists across reboots (stored in Plasma configuration)
- Tooltips in Spanish on all icon buttons
- **Docker Compose support** — if a project contains a compose file (`docker-compose*.yml/yaml`, `compose*.yml/yaml`):
  - **▶ green** — runs `docker compose up -d`; service tree expands immediately showing live startup status
  - **■ red** — runs `docker compose down`; available during startup to cancel
  - **↓ expand** — reveals the service tree while Docker is up
  - **↓ pull** — runs `docker compose pull` to update images (opens Konsole)
  - **📄 file selector** — when multiple compose files exist, opens a menu to pick which one to use; tooltip shows the active file
  - Spinner while `docker compose down` is in progress
- **Live startup status** — while services are coming up, the tree shows each one with a pulsing yellow dot; transitions to green (running) or red (exited/dead) as each settles; polls every 1s during startup, every 3s otherwise; 60s safety timeout
- **Service tree** (expanded per project when Docker is running):
  - Status dot per service — yellow pulsing (starting) / green (running) / red (exited)
  - Mapped ports shown inline
  - **Ver logs** — `docker compose logs -f <service>` in Konsole
  - **Reiniciar** — `docker compose restart <service>`
  - **Construir imagen** — `docker compose build <service>` in Konsole
  - **Abrir terminal** — `docker compose exec <service> sh` in Konsole (running only)
  - **Abrir en navegador** — opens `http://localhost:<port>` (if ports are exposed)
  - Action buttons hidden per service until it finishes starting

## Preview

```
┌────────────────────────────────────────────────┐
│ ⟨/⟩  Proyectos                             [+] │
├────────────────────────────────────────────────┤
│ [code] my-app         [▾][■][↓][📄][−]        │  ← running, multiple compose files
│   ● api        8080   [≡][↺][⚙][sh][🌐]      │
│   ● db                [≡][↺][⚙]              │  ← no ports exposed
├────────────────────────────────────────────────┤
│ [code] staging        [▾][■][📄][−]           │  ← starting up
│   ◌ api               ...                     │  ← pulsing yellow, no actions yet
│   ◌ db                ...                     │
├────────────────────────────────────────────────┤
│ [code] api-service    [▶][↓][−]               │  ← stopped, single compose file
│ [code] dotfiles       [−]                     │  ← no compose file
└────────────────────────────────────────────────┘
```

## Requirements

- KDE Plasma 6
- `plasma5support` — for Docker Compose buttons (`sudo pacman -S plasma5support`)
- `konsole` — for logs and terminal (`sudo pacman -S konsole`)
- `docker` with Compose v2 (`docker compose` subcommand)
- VS Code with `code` CLI available in `$PATH`

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
    │   └── main.xml       # Configuration schema (project list)
    └── ui/
        └── main.qml       # Widget UI
```

## License

MIT
