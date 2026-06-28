# oh-my-desktop

Unified desktop configuration for the current Omarchy + Quickshell session.
All runtime files — user config, Quickshell UI, and the Omarchy framework —
live in this single repo. Nothing is installed outside it.

## Quick Start

```sh
git clone git@github.com:iamcheyan/oh-my-desktop.git ~/development/OMD
cd ~/development/OMD && ./Init.sh
```

`Init.sh` creates the four runtime symlinks (backing up any existing
targets first). Re-run it safely after pulling changes that add or rename
symlink targets.

## Layout

```
~/development/OMD/
├── Init.sh                   Setup script: creates runtime symlinks
│
├── quickshell/               Quickshell config root (→ ~/.config/quickshell)
│   ├── shell.qml              ShellRoot, imports modules/services/panelFamilies
│   ├── config.json            Quickshell runtime/user options
│   ├── GlobalStates.qml       Shared global state (bar/overview/corners)
│   ├── killDialog.qml         Quickshell kill dialog
│   ├── ReloadPopup.qml        Hot-reload notification
│   ├── welcome.qml            First-run welcome
│   ├── modules/               UI modules
│   │   ├── appLauncher/        Application launcher
│   │   ├── background/         Desktop wallpaper layer
│   │   ├── bar/                Status bars (top/bottom, left/right modules)
│   │   ├── cheatsheet/         Keybinding cheatsheet
│   │   ├── common/             Shared widgets (MaterialSymbol, RippleButton, etc.)
│   │   ├── lock/               Screen lock overlay
│   │   ├── mediaControls/      Media playback controls
│   │   ├── notificationPopup/  Notification popups
│   │   ├── onScreenDisplay/    OSD (volume/brightness/media)
│   │   ├── overview/           Workspace overview / switcher
│   │   ├── polkit/              Polkit authentication agent
│   │   ├── regionSelector/      Screen region selector for screenshots
│   │   ├── schedulePopup/       Schedule/calendar popup
│   │   ├── screenCorners/       Screen corner rounding overlay
│   │   ├── sessionScreen/       Logout/shutdown/reboot screen
│   │   └── sidebarRight/        Right sidebar
│   ├── services/              QML singleton services
│   │   ├── Audio.qml            Volume control
│   │   ├── Battery.qml          Battery status
│   │   ├── BluetoothStatus.qml  Bluetooth state
│   │   ├── Brightness.qml       Brightness control
│   │   ├── Cliphist.qml         Clipboard history
│   │   ├── DateTime.qml         Clock/calendar
│   │   ├── HyprlandConfig.qml   Hyprland config bridge
│   │   ├── HyprlandData.qml      Workspace/window data
│   │   ├── HyprlandKeybinds.qml Keybind state
│   │   ├── Hyprsunset.qml       Nightlight
│   │   ├── Idle.qml             Idle detection
│   │   ├── Network.qml          Network status
│   │   ├── Notifications.qml     Notification service
│   │   ├── PolkitService.qml     Polkit daemon
│   │   ├── ResourceUsage.qml     CPU/RAM usage
│   │   ├── SystemInfo.qml        System info
│   │   ├── TimerService.qml      Timer service
│   │   ├── Translation.qml       i18n service
│   │   ├── TrayService.qml       System tray
│   │   ├── Updates.qml           System update checker
│   │   ├── Weather.qml           Weather service
│   │   └── ...
│   ├── panelFamilies/         Panel loaders
│   │   ├── IllogicalImpulseFamily.qml
│   │   └── PanelLoader.qml
│   ├── scripts/               Shell-side helper scripts and launcher
│   ├── assets/                Icons and images
│   └── translations/          i18n JSON
│
├── apps/                     Split Quickshell app processes (each runs independently)
│   ├── omd-bar/               Status bar process
│   ├── omd-overview/          Workspace overview process
│   ├── omd-switcher/          Window switcher process
│   ├── omd-applauncher/       Application launcher process
│   └── omd-corners/           Screen corners process
│
├── omarchy/                  User config overlay (→ ~/.config/omarchy)
│   ├── hypr/                  Hyprland Lua config
│   │   ├── hyprland.lua         Main entry — loads default modules + user files
│   │   ├── bindings.lua         Keybindings (application launch, window mgmt, Quickshell)
│   │   ├── looknfeel.lua        Appearance (opacity, gaps, window rules)
│   │   ├── monitors.lua         Monitor layout
│   │   ├── input.lua            Input devices (keyboard, touchpad)
│   │   ├── autostart.lua        Autostart programs
│   │   ├── hyprlock.conf        Screen lock config
│   │   ├── hypridle.conf        Idle behavior config
│   │   └── hyprsunset.conf      Nightlight config
│   ├── current/               Active theme snapshot
│   │   ├── theme/               Theme files (colors, app styles, wallpapers)
│   │   │   ├── backgrounds/      Active theme wallpapers
│   │   │   ├── colors.toml      Color palette
│   │   │   ├── hyprland.lua     Hyprland border colors
│   │   │   ├── hyprlock.conf    Lock screen theme
│   │   │   ├── quickshell.json  Quickshell theme colors
│   │   │   └── ...
│   │   ├── theme.name           Active theme name (e.g. "last-horizon")
│   │   └── background           Active wallpaper binary
│   ├── alacritty/             Alacritty config
│   ├── foot/                  Foot terminal config
│   ├── ghostty/               Ghostty config
│   ├── kitty/                 Kitty config
│   ├── chromium/              Chromium config
│   ├── fastfetch/             Fastfetch config
│   ├── fcitx5/                Fcitx5 input method
│   ├── fontconfig/            Font config
│   ├── git/                   Git config
│   ├── btop/                  btop config
│   ├── walker/                Walker config (→ ~/.config/walker)
│   ├── starship.toml           Starship prompt
│   ├── autostart/              XDG autostart entries
│   └── omarchy/               Omarchy extensions and hooks
│       ├── extensions/         Extension scripts
│       └── themed/             Themed config templates
│
├── share/                    Omarchy framework (→ ~/.local/share/omarchy)
│   ├── bin/                   306 omarchy-* command scripts
│   │   ├── omarchy-theme-*      Theme management (set/list/install/switcher)
│   │   ├── omarchy-hyprland-*   Hyprland control (toggles, monitors, windows)
│   │   ├── omarchy-launch-*     Application launchers
│   │   ├── omarchy-install-*    Package installers
│   │   ├── omarchy-refresh-*    Config refreshers (copy from config/ templates)
│   │   ├── omarchy-restart-*   Service restarters
│   │   ├── omarchy-update-*     System update helpers
│   │   ├── omarchy-toggle-*     Feature toggles
│   │   ├── omarchy-hw-*         Hardware-specific fixes
│   │   └── ...
│   ├── themes/                20 complete themes
│   │   ├── catppuccin/
│   │   ├── everforest/
│   │   ├── gruvbox/
│   │   ├── last-horizon/        ← default theme
│   │   ├── nord/
│   │   ├── tokyo-night/
│   │   ├── retro-82/
│   │   └── ...                  (20 total, each with backgrounds/, colors, styles)
│   ├── default/               Framework default modules
│   │   ├── hypr/                Lua modules loaded by hyprland.lua via require()
│   │   │   ├── omarchy.lua        Core setup (env vars, paths, defaults)
│   │   │   ├── bindings.lua       Default keybindings
│   │   │   ├── input.lua          Default input config
│   │   │   ├── looknfeel.lua      Default appearance
│   │   │   ├── autostart.lua      Default autostart
│   │   │   ├── toggles.lua        Config flag toggles
│   │   │   ├── windows.lua        Window rule helpers
│   │   │   ├── helpers.lua        Utility functions
│   │   │   └── ...
│   │   ├── quickshell/          Default Quickshell snippets
│   │   ├── sddm/                SDDM login theme
│   │   ├── plymouth/            Plymouth boot theme
│   │   ├── walker/               Default walker config
│   │   ├── bash/                 Default bash config
│   │   ├── pacman/               Pacman config
│   │   └── ...
│   ├── config/                Default config templates (used by omarchy-refresh-config)
│   │   ├── hypr/                Default Hyprland configs (reset to these)
│   │   ├── alacritty/           Default Alacritty config
│   │   ├── foot/                Default Foot config
│   │   ├── kitty/               Default Kitty config
│   │   └── ...
│   ├── install/               Install / first-run scripts
│   │   ├── config/              System config setup
│   │   ├── first-run/           First-run initialization
│   │   ├── preflight/           Pre-install checks
│   │   ├── packaging/           Package lists
│   │   ├── post-install/        Post-install steps
│   │   └── helpers/             Install helper functions
│   ├── version                Omarchy version (4.0.0.alpha)
│   ├── icon.txt / logo.txt    Branding assets
│
├── bin/                      OMD launcher scripts
│   ├── omd-restart            Restart all Quickshell apps
│   ├── omd-bar                Launch bar process
│   ├── omd-overview           Launch overview process
│   ├── omd-switcher           Launch switcher process
│   ├── omd-applauncher       Launch app launcher
│   ├── omd-clipboard-pick    Launch clipboard picker (walker + auto-paste)
│   └── omd-corners            Launch corners process
│
├── scripts/                  Helper scripts
│   ├── launch-tui-tool        TUI tool launcher
│   └── reload-quickshell      Quickshell reload helper
│
├── docs/                     Project notes
│   ├── agent-working-agreement.md
│   ├── module-split-plan.md
│   └── ...
│
└── .migration-backups/       Local migration backups (not tracked)
```

## Runtime Symlinks

`Init.sh` creates these symlinks from the home directory into the repo:

```
~/.config/quickshell     -> ~/development/OMD/quickshell
~/.config/omarchy        -> ~/development/OMD/omarchy
~/.config/walker         -> ~/development/OMD/omarchy/walker
~/.config/omd            -> ~/development/OMD
~/.local/share/omarchy   -> ~/development/OMD/share
```

`~/.config/hypr` is legacy and not part of the current Omarchy session.

## Runtime

- Hyprland loads Omarchy config from `~/.config/omarchy/hypr/hyprland.lua`.
- `hyprland.lua` loads Omarchy defaults via `require("default.hypr.omarchy")`
  (resolved from `~/.local/share/omarchy/default/`) then loads user modules
  from `~/.config/omarchy/hypr/` (monitors, input, bindings, looknfeel, autostart).
- Omarchy autostart launches Quickshell via
  `~/.config/omd/bin/omd-restart`.
- Quickshell runs as five independent app processes: `omd-bar`, `omd-overview`,
  `omd-switcher`, `omd-applauncher`, `omd-corners`.
- Clipboard is handled by walker (`ALT+V` → `omd-clipboard-pick`), not a
  Quickshell process.
- Quickshell reads options from `~/.config/quickshell/config.json`.
- Walker reads launcher/clipboard options from `~/.config/omarchy/walker`,
  which is managed by `omarchy/walker`.
- Themes are stored in `~/.local/share/omarchy/themes/`. The active theme is
  copied to `~/.config/omarchy/current/` by `omarchy-theme-set`.
- `omarchy-refresh-config` resets a config file by copying from
  `~/.local/share/omarchy/config/` to `~/.config/`.

## Planning Docs

- Module split plan: `docs/module-split-plan.md`
- Agent working agreement: `docs/agent-working-agreement.md`
- TUI style system: `docs/tui-style-system.md`

## Editing

### Quickshell

- Shared widgets live in `quickshell/modules/common/widgets/`.
- Services are QML singletons imported via `import qs.services`.
- Prefer existing widgets such as `MaterialSymbol`, `StyledText`,
  `RippleButton`, `IconImage`, and `CosmicIcon`.
- The current Quickshell visual system is centralized in
  `quickshell/modules/common/TuiStyle.qml`; follow `docs/tui-style-system.md`
  and add new style tokens there before hard-coding colors in feature modules.
- The shell hot-reloads on QML/config file changes. To force restart:
  `~/.config/omd/bin/omd-restart`.
- `quickshell/scripts/quickshell` accepts an optional config directory for
  split apps, but defaults to `~/.config/quickshell`.
- Bar status popups are unified through `quickshell/modules/bar/BarStatusPopup.qml`.
  Do not add new per-module `XxxInfoPopup.qml` files; add a content component or
  section to `BarStatusPopup.qml` instead.

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
