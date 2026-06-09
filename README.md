# Code Projects — KDE Plasma Widget

A KDE Plasma 6 panel widget to quickly open your VS Code projects.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6-blue?logo=kde)
![QML](https://img.shields.io/badge/QML-Qt_6-green?logo=qt)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features

- Add any folder as a project with the **+** button (native KDE folder picker)
- Click a project name or icon to open it in VS Code
- Remove projects from the list with the **−** button
- Project list persists across reboots (stored in Plasma configuration)
- **Docker Compose support** — if a project contains a compose file (`docker-compose.yml`, `docker-compose.yaml`, `compose.yml`, `compose.yaml`):
  - Shows a **▶ green** button when services are stopped → runs `docker compose up -d`
  - Shows a **■ red** button when services are running → runs `docker compose down`
  - Shows a **terminal** button when running → opens Konsole with `docker compose logs -f`
  - A spinner appears while the command is in progress
- Lives in your panel — one click away at all times

## Preview

```
┌──────────────────────────────────────┐
│ ⟨/⟩  Proyectos                   [+] │
├──────────────────────────────────────┤
│ [code] my-app          [■][⌨][−]    │  ← compose running
│ [code] api-service     [▶][−]       │  ← compose stopped
│ [code] dotfiles        [−]          │  ← no compose file
└──────────────────────────────────────┘
```

## Requirements

- KDE Plasma 6
- `plasma5support` — for Docker Compose buttons (`sudo pacman -S plasma5support`)
- `konsole` — for the Docker logs terminal (`sudo pacman -S konsole`)
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
