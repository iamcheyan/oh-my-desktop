# oh-my-desktop

Unified desktop configuration for the current Omarchy + Quickshell session.

## Layout

```
~/development/OMD/
├── quickshell/              Quickshell config root (entry: shell.qml)
│   ├── shell.qml            ShellRoot, imports modules/services/panelFamilies
│   ├── config.json          Quickshell runtime/user options
│   ├── modules/             bars, dialogs, overview, sidebars, settings
│   ├── services/            QML singleton services
│   ├── panelFamilies/        panel loaders
│   ├── scripts/             shell-side helper scripts and launcher
│   ├── assets/              icons/images
│   └── translations/        i18n JSON
├── omarchy/                 Active ~/.config/omarchy contents
├── share/                   Active ~/.local/share/omarchy contents (Omarchy framework)
│   ├── bin/                 306 omarchy-* command scripts
│   ├── themes/              20 themes (colors, wallpapers, app styles)
│   ├── default/             Framework Lua modules (loaded via require in hyprland.lua)
│   ├── config/              Default config templates (used by omarchy-refresh-config)
│   ├── install/             Install/first-run scripts
│   └── version              Omarchy version
├── apps/                    Split Quickshell app processes
├── bin/                     OMD launcher scripts (omd-bar, omd-restart, etc.)
├── scripts/                 Helper scripts
├── docs/                    Project notes
└── .migration-backups/      Local migration backups, not source
```

Runtime symlinks:

```
~/.config/quickshell     -> ~/development/OMD/quickshell
~/.config/omarchy        -> ~/development/OMD/omarchy
~/.config/omd            -> ~/development/OMD
~/.local/share/omarchy   -> ~/development/OMD/share
```

`~/.config/hypr` is legacy and not part of the current Omarchy session.

All runtime files now live under `~/development/OMD/` — both the user
config (`omarchy/`, `quickshell/`) and the Omarchy framework (`share/`).
No Omarchy files are installed outside the repo.

## Runtime

- Hyprland loads Omarchy config from `~/.config/omarchy/hypr/hyprland.lua`.
- Omarchy autostart launches Quickshell via
  `~/.config/omd/bin/omd-restart`.
- Quickshell runs as three app processes: `omd-bar`, `omd-overview`, and
  `omd-switcher`.
- Quickshell reads options from `~/.config/quickshell/config.json`.

## Planning Docs

- Module split plan: `docs/module-split-plan.md`
- Agent working agreement: `docs/agent-working-agreement.md`

## Editing

### Quickshell

- Shared widgets live in `quickshell/modules/common/widgets/`.
- Services are QML singletons imported via `import qs.services`.
- Prefer existing widgets such as `MaterialSymbol`, `StyledText`,
  `RippleButton`, `IconImage`, and `CosmicIcon`.
- The shell hot-reloads on QML/config file changes. To force restart:
  `~/.config/omd/bin/omd-restart`.
- `quickshell/scripts/quickshell` accepts an optional config directory for
  split apps, but defaults to `~/.config/quickshell`.

### Omarchy / Hyprland

- Active user config is in `omarchy/hypr/*.lua`.
- Autostart lives in `omarchy/hypr/autostart.lua`.
- Use `hyprctl reload` to reload Hyprland Lua config.

## Git

- Treat `~/development/OMD` as the project root for oh-my-desktop.
- Do not commit `.migration-backups/`, Quickshell `.state/`, or nested `.git`
  directories from copied upstream configs.
- Run the privacy checks in `docs/agent-working-agreement.md` before pushing.
- No test framework; verify by reloading Hyprland and restarting Quickshell.
