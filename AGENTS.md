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
│   ├── panelFamilies/       panel loaders
│   ├── scripts/             shell-side helper scripts and launcher
│   ├── assets/              icons/images
│   └── translations/        i18n JSON
├── omarchy/                 Active ~/.config/omarchy contents
├── docs/                    Project notes
└── .migration-backups/      Local migration backups, not source
```

Runtime symlinks:

```
~/.config/quickshell -> ~/development/OMD/quickshell
~/.config/omarchy    -> ~/development/OMD/omarchy
```

`~/.config/hypr` is legacy and not part of the current Omarchy session.

## Runtime

- Hyprland loads Omarchy config from `~/.config/omarchy/hypr/hyprland.lua`.
- Omarchy autostart launches Quickshell via
  `~/.config/quickshell/scripts/quickshell`.
- Quickshell launches with `quickshell -p ~/.config/quickshell`, so there is no
  extra `ii/` directory in the active layout.
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
  `pkill -f 'quickshell.* -p .*/\\.config/quickshell($| )' || true; ~/.config/quickshell/scripts/quickshell &`.
- `quickshell/scripts/quickshell` accepts an optional config directory for
  future split apps, but defaults to `~/.config/quickshell`.

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
