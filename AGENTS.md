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
├── config/                   Theme integration helpers
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
~/.config/quickshell    -> ~/development/OMD/quickshell
~/.config/omd           -> ~/development/OMD
```

`~/.config/omd` is the primary runtime path for finding the repo's `bin/` scripts
and `apps/` directories from QML and shell scripts. It coexists with the real
`~/.config/sumika-shell/` directory (which holds user-authored config like
Quickshell overrides, launchers, and notification mute lists).

Terminal configs (`foot`, `kitty`, `alacritty`, `ghostty`) are **not** managed by OMD's Init.sh — they are personal preferences managed via [chezmoi](https://www.chezmoi.io/) or directly. OMD provides theme files that your terminal config can include. The active theme snapshot lives at `~/.local/state/sumika-shell/theme/current/{foot,kitty,alacritty,ghostty}.*`.

Additional manual symlinks (not created by Init.sh):

```
~/.config/walker         -> ~/development/OMD/config/walker     # (if walker is used)
```

## Runtime
- `hyprland.lua` loads default modules from `hypr/default/`, then user
  modules from `hypr/` (monitors, input, bindings, looknfeel, autostart).
- Autostart launches Quickshell via `~/.config/sumika-shell/bin/omd-restart`.
- Quickshell runs as independent app processes: `omd-bar`, `omd-overview`,
  `omd-applauncher`, and `omd-clipboard`.
- Desktop wallpaper is handled by `swaybg` through Hyprland autostart and
  `bin/omd-wallpaper` / `bin/omd-theme-bg-set`; there is no Quickshell
  `omd-desktop` wallpaper process.
- Clipboard UI is a QML dialog (`CTRL+SHIFT+V` → `omd-clipboard` process);
  clipboard storage is watched by `omd-clipboard-store`.
- Quickshell reads options from `~/.config/sumika-shell/quickshell/config.json`
  (user override) with `defaults/config/quickshell/config.json` as baseline.
- Themes are stored in `~/.local/share/omd/themes/`. The active theme snapshot is
  copied to `~/.local/state/sumika-shell/theme/current/` by `omd-settings-theme`.
- Terminal configs (`foot`, `kitty`, `alacritty`, `ghostty`) are **not** managed by OMD — they are personal preferences managed separately. OMD provides theme files under `~/.local/state/sumika-shell/theme/current/{foot,kitty,alacritty,ghostty}.*` that your terminal config can include via the `include`/`import`/`config-file` directive.
- Neovim theme integration is opt-in. Run the Neovim setup helper to link
  OMD's LazyVim drop-in into `~/.config/nvim/lua/plugins/` so Neovim reads
  `~/.local/state/sumika-shell/theme/current/neovim.lua` without OMD taking over the whole
  Neovim config.

## Planning Docs
> **Rule**: All planning and design documents MUST be written to `docs/` inside this repo.
> Never save docs to `/tmp`, agent scratch dirs, or any path outside the project.
- Module split plan: `docs/module-split-plan.md`
- Go settings TUI: `docs/settings-tui-go.md`
- Go settings TUI visual system: `docs/settings-tui-visual-system.md`
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
- Smart paste (image as path in terminals): `docs/smart-paste.md`
- Theme TUI Python color features (wallpaper preview + tile swatches): `docs/theme-tui-color-impl-plan.md`

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
  `~/.config/sumika-shell/bin/omd-restart` (or legacy `~/.config/omd/bin/omd-restart`).
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
  `qs -p $HOME/.config/sumika-shell/apps/omd-bar ipc call voice toggle` to trigger
  (or `~/.config/omd/apps/omd-bar` for legacy).
  Setup scripts: `share/bin/omarchy-voice-{setup,download,transcribe}`.
  Full docs: `docs/voice-input.md`.
- Wallpaper selection lives in DisplayCTL and calls
  `~/.config/sumika-shell/bin/omd-wallpaper` (or legacy `~/.config/omd/bin/omd-wallpaper`). Single-image changes call
  `omarchy-theme-bg-set`; folder rotation stores machine-local state in
  `~/.local/state/omd/wallpaper/` and rotates every 30 minutes.

### Omarchy / Hyprland

- Active user config is in `hypr/*.lua`.
- Autostart lives in `hypr/autostart.lua`.
- Use `hyprctl reload` to reload Hyprland Lua config.

## TUI Terminal Action Pattern

When a TUI needs to open a new terminal window for a subtask (editing a config
file, viewing remote files, running a diagnostic, etc.):

1. **Use this launcher cascade** (try each in order):
   - `xdg-terminal-exec --app-id=org.omd.<purpose> --title="<Human title>" -- $COMMAND`
   - `foot --app-id=org.omd.<purpose> --title="<Human title>" -e $COMMAND`
   - `kitty --class=org.omd.<purpose> --title="<Human title>" -- $COMMAND`

2. **Always use a unique `app-id` / `class`** so Hyprland can target the window
   with a floating rule. Example from `looknfeel.lua`:
   ```lua
   o.window("org.omd.edit-file-share-backup", { float = true, center = true, size = { 880, 620 } })
   ```

3. **Follow the `org.omd.<purpose>` naming convention** — lower-case,
   dash-separated purpose, scoped under `org.omd.`.

4. **Launch as a detached process** — use `start_new_session=True` and pipe
   stdin/stdout/stderr to `/dev/null` so the terminal survives the TUI:
   ```python
   subprocess.Popen(
       ["bash", "-c", cmd],
       stdin=subprocess.DEVNULL,
       stdout=subprocess.DEVNULL,
       stderr=subprocess.DEVNULL,
       start_new_session=True
   )
   ```

5. **Add the matching Hyprland window rule** in `hypr/looknfeel.lua`:
   ```lua
   o.window("org.omd.<purpose>", { float = true, center = true, size = { 880, 620 } })
   ```

## Git

- Treat `~/development/OMD` as the project root for oh-my-desktop.
- Do not commit `.migration-backups/`, Quickshell `.state/`, or nested `.git`
- Run `~/.config/sumika-shell/bin/omd-doctor` (or legacy `~/.config/omd/bin/omd-doctor`) and the privacy checks in
- No test framework; verify by reloading Hyprland and restarting Quickshell.
