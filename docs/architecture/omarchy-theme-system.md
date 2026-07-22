# Theme Runtime System

The public product is Sumika Shell, while the compatibility command names keep
the `omd`/`omarchy` prefix. The active implementation is owned by
`bin/omd-settings-theme`; older Omarchy `current/theme` paths are not part of
the Sumika runtime contract.

## Theme Sources

Themes are discovered in this order:

1. `<repo>/themes/<slug>/` for optional user-provided repository themes;
2. `<repo>/share/themes/<slug>/` for bundled themes.

Each theme is identified by a slug and must provide `colors.toml`. Optional
files such as editor or application themes may be included. Runtime files are
generated from the color definition when the theme is applied.

## Runtime State

```text
~/.local/state/sumika-shell/theme/
├── current-name
└── current/
    ├── colors.toml
    ├── hyprland.lua
    ├── quickshell.json
    ├── foot.ini
    ├── kitty.conf
    ├── alacritty.toml
    ├── ghostty.conf
    └── neovim.lua
```

The exact derivative set may grow, but the root is always
`SUMIKA_SHELL_STATE_HOME/theme/current`. Generated files are machine state and
must not be committed.

## Apply Flow

```sh
omd-settings-theme apply <theme-slug>
```

The command:

1. resolves the theme source;
2. replaces the runtime `current/` snapshot;
3. generates missing application derivatives;
4. writes `current-name`;
5. reloads supported Quickshell processes;
6. reloads Hyprland border colors;
7. reloads terminal, Helix, and reachable Neovim instances.

Applying a theme does not select or replace the user's wallpaper. Wallpaper
selection and rotation are independent; see
[`wallpaper-runtime.md`](wallpaper-runtime.md).

## Effects

`omd-settings-theme effects` accepts:

- `performance`: blur and animations disabled;
- `balanced`: animations enabled, one blur pass;
- `visuals`: animations enabled, two blur passes.

The selected effect mode is runtime state, not a property of an individual
theme pack.

## Consumer Contract

- Quickshell reads generated theme state and exposes shared tokens.
- Hyprland imports the generated `hyprland.lua`.
- Terminal/editor configurations include or read the generated files.
- Feature QML uses shared style tokens; it must not parse theme packs directly.

Do not add references to `~/.config/omarchy/current/theme`,
`~/.config/omarchy/current/background`, or `next-theme`. Those belong to the
superseded Omarchy implementation.

## Commands

```sh
omd-settings-theme list
omd-settings-theme current
omd-settings-theme appearance-status
omd-settings-theme apply <slug>
omd-settings-theme effects <performance|balanced|visuals>
omd-settings-theme repair
```

`repair` regenerates derivatives for the active slug and refreshes consumers.
