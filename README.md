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
- Lives in your panel — one click away at all times

## Preview

```
┌─────────────────────────────┐
│ ⟨/⟩  Proyectos          [+] │
├─────────────────────────────┤
│ [code] my-app           [−] │
│ [code] api-service      [−] │
│ [code] dotfiles         [−] │
└─────────────────────────────┘
```

## Requirements

- KDE Plasma 6
- VS Code installed and registered as URI handler for `vscode://`

## Installation

### Manual

```bash
git clone https://github.com/Gu7i/kde-code-projects.git
cp -r kde-code-projects ~/.local/share/plasma/plasmoids/com.guti.codeprojects
systemctl --user restart plasma-plasmashell
```

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
com.guti.codeprojects/
├── metadata.json          # Plasma plugin metadata
└── contents/
    ├── config/
    │   └── main.xml       # Configuration schema (project list)
    └── ui/
        └── main.qml       # Widget UI
```

## License

MIT
