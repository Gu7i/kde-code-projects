# Code Projects — KDE Plasma Widget

A KDE Plasma 6 panel widget to quickly open your VS Code projects.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6-blue?logo=kde)
![QML](https://img.shields.io/badge/QML-Qt_6-green?logo=qt)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features

- Add any folder as a project with the **+** button (native KDE folder picker)
- Click a project name to open it in VS Code
- Remove projects from the list with the **−** button
- Project list persists across reboots (stored in Plasma configuration)
- Tooltips in Spanish on all icon buttons
- **Docker Compose support** — if a project contains a compose file (`docker-compose.yml`, `docker-compose.yaml`, `compose.yml`, `compose.yaml`):
  - **▶ green** — runs `docker compose up -d` when services are stopped
  - **■ red** — runs `docker compose down` when services are running
  - **↓ expand** — reveals the service tree while Docker is up
  - **↓ pull** — runs `docker compose pull` to update images (opens Konsole)
  - Spinner while a command is in progress
- **Service tree** (expanded per project when Docker is running):
  - Status dot per service — green (running) / red (exited)
  - Mapped ports shown inline
  - **Ver logs** — `docker compose logs -f <service>` in Konsole
  - **Reiniciar** — `docker compose restart <service>`
  - **Construir imagen** — `docker compose build <service>` in Konsole
  - **Abrir terminal** — `docker compose exec <service> sh` in Konsole (running only)
  - **Abrir en navegador** — opens `http://localhost:<port>` (if ports are exposed)

## Preview

```
┌────────────────────────────────────────────────┐
│ ⟨/⟩  Proyectos                             [+] │
├────────────────────────────────────────────────┤
│ [code] my-app         [▾][■][↓][−]            │  ← compose running, tree collapsed
│   ● api        8080   [⌨][↺][⚙][>][🌐]       │
│   ● db                [⌨][↺][⚙]              │  ← no ports exposed
├────────────────────────────────────────────────┤
│ [code] api-service    [▶][↓][−]               │  ← compose stopped
│ [code] dotfiles       [−]                     │  ← no compose file
└────────────────────────────────────────────────┘
```

## Requirements

- KDE Plasma 6
- `plasma5support` — for Docker Compose buttons (`sudo pacman -S plasma5support`)
- `konsole` — for logs and terminal (`sudo pacman -S konsole`)
- `docker` with Compose v2 (`docker compose` subcommand)
- VS Code installed and registered as URI handler for `vscode://`

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

## VS Code URI handler

VS Code registers itself as the handler for `vscode://` URIs on install. If opening projects does not work, run:

```bash
xdg-mime default code.desktop x-scheme-handler/vscode
```

Verify with:

```bash
xdg-mime query default x-scheme-handler/vscode
# should output: code.desktop
```

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
