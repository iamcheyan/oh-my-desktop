# oh-my-desktop

Unified desktop configuration for the current Omarchy + Quickshell session.
All runtime files — user config, Quickshell UI, and the Omarchy framework —
live in this single repo. Nothing is installed outside it.

## Quick Start

```sh
git clone git@github.com:iamcheyan/oh-my-desktop.git ~/development/OMD
cd ~/development/OMD && ./Init.sh
```

`Init.sh` creates the runtime symlinks (backing up any existing
targets first). Re-run it safely after pulling changes that add or rename
symlink targets.

## Layout

```
~/development/OMD/
├── Init.sh                   Setup script: creates runtime symlinks
│
├── quickshell/               Quickshell config root (→ ~/.config/quickshell)
│   ├── config.json            Quickshell runtime/user options
│   ├── GlobalStates.qml       Shared global state (bar/overview)
│   ├── killDialog.qml         Quickshell kill dialog
│   ├── ReloadPopup.qml        Hot-reload notification
│   ├── welcome.qml            First-run welcome
│   ├── modules/               UI modules
│   │   ├── background/         Desktop wallpaper layer
│   │   ├── bar/                Status bars (top/bottom, left/right modules)
│   │   ├── common/             Shared widgets (NerdIcon, MaterialSymbol, RippleButton, etc.)
│   │   ├── lock/               Screen lock overlay
│   │   ├── notificationPopup/  Notification popups
│   │   ├── onScreenDisplay/    OSD (volume/brightness/media)
│   │   ├── overview/           Workspace overview / switcher
│   │   ├── polkit/              Polkit authentication agent
│   │   ├── regionSelector/      Screen region selector for screenshots
│   │   ├── schedulePopup/       Notification list content
│   │   └── settings/            Settings Center pages/widgets
│   ├── services/              QML singleton services
│   │   ├── Audio.qml            Volume control
│   │   ├── Battery.qml          Battery status
│   │   ├── BluetoothStatus.qml  Bluetooth state
│   │   ├── Brightness.qml       Brightness control
│   │   ├── Cliphist.qml         Clipboard history
│   │   ├── DateTime.qml         Clock/time formatting
│   │   ├── HyprlandData.qml      Workspace/window data
│   │   ├── Hyprsunset.qml       Nightlight
│   │   ├── Idle.qml             Idle detection
│   │   ├── Network.qml          Network status
│   │   ├── Notifications.qml     Notification service
│   │   ├── PolkitService.qml     Polkit daemon
│   │   ├── ResourceUsage.qml     CPU/RAM usage
│   │   ├── SystemInfo.qml        System info
│   │   ├── Translation.qml       i18n service
│   │   ├── TrayService.qml       System tray
│   │   ├── Updates.qml           System update checker
│   │   └── ...
│   ├── scripts/               Shell-side helper scripts and launcher
│   ├── assets/                Icons and images
│   └── translations/          i18n JSON
│
├── apps/                     Split Quickshell app processes (each runs independently)
│   ├── omd-bar/               Status bar process
│   ├── omd-overview/          Workspace overview process
│   ├── omd-applauncher/       Application launcher process
│   └── omd-clipboard/         Clipboard UI process
│
├── hypr/                     Hyprland Lua config
│   ├── hyprland.lua            Main entry — loads default + user config
│   ├── bindings.lua            Keybindings (application launch, window mgmt, Quickshell)
│   ├── looknfeel.lua           Appearance (opacity, gaps, window rules)
│   ├── monitors.lua            Monitor layout
│   ├── input.lua               Input devices (keyboard, touchpad)
│   ├── autostart.lua           Autostart programs
│   ├── hypridle.conf           Idle behavior config
│   ├── hyprsunset.conf         Nightlight config
│   ├── default/                Default Omarchy Hyprland modules (loaded by hyprland.lua)
│   └── xdph.conf               XDG portal config
│
├── config/                   Terminal/app configs (→ ~/.config/{foot,kitty,…})
│   ├── alacritty/             Alacritty config
│   ├── foot/                  Foot terminal config
│   ├── ghostty/               Ghostty config
│   ├── kitty/                 Kitty config
│   ├── fcitx5/                Fcitx5 input method
│   └── nvim/                  Neovim theme drop-in for LazyVim
│
├── current/                  Active theme snapshot
│   ├── theme/                 Theme files (colors, app styles, wallpapers)
│   │   ├── backgrounds/        Active theme wallpapers
│   │   ├── colors.toml        Color palette
│   │   ├── hyprland.lua       Hyprland border colors
│   │   ├── quickshell.json    Quickshell theme colors
│   │   └── ...
│   ├── theme.name             Active theme name (e.g. "last-horizon")
│   └── background             Symlink to the active wallpaper
│
├── share/                    Omarchy framework (→ ~/.local/share/omd)
│   ├── bin/                   264 omarchy-* command scripts (legacy, wrapped via
│   │   │                       bin/omd-legacy-omarchy); called transitively by OMD
│   │   ├── omarchy-theme-*      Theme management (set/install/switcher)
│   │   ├── omarchy-hyprland-*   Hyprland control (toggles, monitors, windows)
│   │   ├── omarchy-launch-*     Application launchers
│   │   ├── omarchy-restart-*   Service restarters
│   │   ├── omarchy-toggle-*     Feature toggles
│   │   ├── omarchy-voice-*      Voice input (sherpa-onnx) setup/transcribe
│   │   ├── omarchy-keyboard-*   Keyboard remap helpers
│   │   └── ...
│   ├── themes/                22 complete themes
│   │   ├── catppuccin/
│   │   ├── everforest/
│   │   ├── gruvbox/
│   │   ├── last-horizon/        ← default theme
│   │   ├── tokyo-night/
│   │   └── ...                  (22 total, each with backgrounds/, colors, styles)
│   ├── polkit-1/rules.d/      Polkit rules (keyboard remap)
│   ├── version                OMD version (4.0.0.alpha)
│   └── icon.txt / logo.txt    Branding assets
│
├── bin/                      OMD launcher scripts
│   ├── omd-restart            Restart all Quickshell apps
│   ├── omd-bar                Launch bar process
│   ├── omd-overview           Launch overview process
│   ├── omd-applauncher       Launch app launcher
│   ├── omd-clipboard          Launch clipboard UI process
│   ├── omd-clipboard-store    Launch clipboard store watcher
│   ├── omd-wallpaper          Wallpaper picker/rotation helper
│   ├── omd-session            Workspace snapshot save/restore helper
│   ├── omd-settings-theme     Settings Center theme list/apply helper
│   ├── omd-settings-windows-vm Settings Center Windows VM status/action helper
│   └── omd-doctor             Runtime dependency and portability checker
│
├── scripts/                  Helper scripts (launch tools, voice, keyboard, reload)
├── docs/                     Project notes
│   ├── agent-working-agreement.md
│   ├── module-split-plan.md
│   └── ...
├── keyboard-remap/           Keyd configuration and profiles
├── icons/                    OS distro icons (used by ActiveWindow.qml)
└── .migration-backups/       Local migration backups (not tracked)
```

## Runtime Symlinks

`Init.sh` creates these symlinks from the home directory into the repo:

```
~/.config/quickshell     -> ~/development/OMD/quickshell
~/.config/foot           -> ~/development/OMD/config/foot
~/.config/kitty          -> ~/development/OMD/config/kitty
~/.config/alacritty      -> ~/development/OMD/config/alacritty
~/.config/ghostty        -> ~/development/OMD/config/ghostty
~/.config/omd            -> ~/development/OMD
```

Additional manual symlinks (not created by Init.sh):

```
~/.config/walker         -> ~/development/OMD/config/walker     # (if walker is used)
~/.config/fcitx5         -> ~/development/OMD/config/fcitx5     # (if fcitx5 is used)
```

`~/.config/hypr` is legacy and not part of the current session.

## Runtime

- Hyprland loads config from `~/.config/omd/hypr/hyprland.lua`.
- `hyprland.lua` loads default modules from `hypr/default/`, then user
  modules from `hypr/` (monitors, input, bindings, looknfeel, autostart).
- Autostart launches Quickshell via `~/.config/omd/bin/omd-restart`.
- Quickshell runs as independent app processes: `omd-bar`, `omd-overview`,
  `omd-applauncher`, and `omd-clipboard`.
- Desktop wallpaper is handled by `swaybg` through Hyprland autostart and
  `bin/omd-wallpaper` / `bin/omd-theme-bg-set`; there is no Quickshell
  `omd-desktop` wallpaper process.
- Clipboard UI is a QML dialog (`CTRL+SHIFT+V` → `omd-clipboard` process);
  clipboard storage is watched by `omd-clipboard-store`.
- Quickshell reads options from `~/.config/quickshell/config.json`.
- Themes are stored in `~/.local/share/omd/themes/`. The active theme is
  copied to `~/.config/omd/current/` by `omarchy-theme-set`.
- Terminal configs are managed by OMD symlinks under `~/.config/{foot,kitty,alacritty,ghostty}`.
  They import theme files from `~/.config/omd/current/theme/`, so theme
  changes apply to new terminal windows and to supported live-reload paths.
- Neovim theme integration is opt-in. Run the Neovim setup helper to link
  OMD's LazyVim drop-in into `~/.config/nvim/lua/plugins/` so Neovim reads
  `~/.config/omd/current/theme/neovim.lua` without OMD taking over the whole
  Neovim config.

## Planning Docs

- Module split plan: `docs/module-split-plan.md`
- Agent working agreement: `docs/agent-working-agreement.md`
- TUI style system: `docs/tui-style-system.md`
- Settings center: `docs/settings-center.md`
- Settings panel layout: `docs/settings-layout-system.md`
- Voice settings redesign: `docs/voice-settings-redesign.md`
- Windows VM settings layout: `docs/windows-vm-settings-layout.md`
- Appearance settings layout: `docs/appearance-settings-layout.md`
- Keyboard remap settings layout: `docs/keyboard-remap-settings-layout.md`
- Wi-Fi connect flow: `docs/wifi-connect-flow.md`
- Bar popup height stability: `docs/bar-popup-height-stability.md`
- Network settings layout: `docs/network-settings-layout.md`
- Omarchy theme system: `docs/omarchy-theme-system.md`
- Session persistence: `docs/session-persistence.md`
- Input method integration: `docs/input-method-integration.md`
- Overview command palette: `docs/overview-command-palette.md`
- Deployment/portability: `docs/deployment-portability.md`
- Quickshell cold-start recovery: `docs/quickshell-cold-start-recovery.md`
- Wallpaper runtime contract: `docs/wallpaper-runtime.md`

## Editing

### Quickshell

- Shared widgets live in `quickshell/modules/common/widgets/`.
- Services are QML singletons imported via `import qs.services`.
- Prefer existing widgets such as `NerdIcon`, `StyledText`,
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
- Height-variable bar popups (device lists, optional rows) must follow
  `docs/bar-popup-height-stability.md`: do not animate `PanelWindow` /
  `Layout.preferredHeight`; prefer always-visible structure or constant geometry.
- Voice input is integrated into `quickshell/modules/bar/modules/AudioButton.qml`
  and `quickshell/modules/bar/BarStatusPopup.qml`. It uses
  `VoiceInput` singleton service for state machine: nomodel → venv → downloading
  → idle → recording → transcribing → paste (wl-copy + ydotool Ctrl+V). Python
  inference via sherpa-onnx over Unix socket. Hotkey: ALT+A. Use
  `qs -p $HOME/.config/omd/apps/omd-bar ipc call voice toggle` to trigger.
  Setup scripts: `share/bin/omarchy-voice-{setup,download,transcribe}`.
  Full docs: `docs/voice-input.md`.
- Wallpaper selection lives in DisplayCTL and calls
  `~/.config/omd/bin/omd-wallpaper`. Single-image changes call
  `omarchy-theme-bg-set`; folder rotation stores machine-local state in
  `~/.local/state/omd/wallpaper/` and rotates every 30 minutes.

### Omarchy / Hyprland

- Active user config is in `hypr/*.lua`.
- Autostart lives in `hypr/autostart.lua`.
- Use `hyprctl reload` to reload Hyprland Lua config.

## Git

- Treat `~/development/OMD` as the project root for oh-my-desktop.
- Do not commit `.migration-backups/`, Quickshell `.state/`, or nested `.git`
  directories from copied upstream configs.
- Run `~/.config/omd/bin/omd-doctor` and the privacy checks in
  `docs/agent-working-agreement.md` before pushing.
- No test framework; verify by reloading Hyprland and restarting Quickshell.
