# Deployment and Portability

This repo is intended to be the single source of truth for OMD desktop
configuration. A clone plus `Init.sh` should recreate the same configuration
layout, but some runtime assets and system packages are intentionally external.

## What Is Tracked

- Quickshell UI code and split app roots under `quickshell/` and `apps/`
- Omarchy/Hyprland user configuration under `omarchy/`
- Walker configuration under `omarchy/walker/`
- Terminal configuration under `omarchy/foot`, `omarchy/kitty`,
  `omarchy/alacritty`, and `omarchy/ghostty`
- Neovim theme drop-in under `omarchy/nvim`
- OMD launchers under `bin/`
- Omarchy helper scripts under `share/bin/`
- Built-in themes and bundled theme wallpapers under `share/themes/` and
  `omarchy/current/theme/backgrounds/`

The default wallpaper path in `quickshell/config.json` must point at a tracked
or symlinked repo path such as:

```json
"wallpaperPath": "~/.config/omarchy/current/theme/backgrounds/4-new-horizons.jpg"
```

Do not commit paths to user download folders or machine-local wallpaper
directories.

## What Is Not Tracked

These are runtime state or cache and should be recreated on each machine:

- `~/.cache/omd-voice/venv/` Python virtual environment
- `~/.cache/omd-voice/sense-voice-small-int8/` SenseVoice model files
- `/tmp/omd-voice.sock`, `/tmp/omd-voice-rec.wav`, and other temporary voice
  files
- `~/.local/state/omd/wallpaper/` selected wallpaper rotation source
- downloaded TUI binaries such as `impala` and `bluetui`
- clipboard history and generated previews

Voice setup scripts are tracked, but the model and venv are not. First use can
create them through:

```sh
~/.config/omd/share/bin/omarchy-voice-setup
~/.config/omd/share/bin/omarchy-voice-download
```

## System Dependencies

`Init.sh` creates symlinks; it does not install OS packages. Run:

```sh
~/.config/omd/bin/omd-doctor
```

The doctor checks the expected runtime commands and reports missing pieces.
Core dependencies include:

- `hyprctl`, `qs`/`quickshell`, `swaybg`
- `wlr-randr` for transactional display mode, scale, rotation, and layout
  changes through `wlr-output-management`
- `jq`, `curl`, `systemd-run`
- `wl-copy`, `wl-paste`, `cliphist`, `walker`
- `parecord` for voice recording
- `ydotool` for direct auto-paste; without it, voice text still lands in the
  clipboard
- `kdialog` or `zenity` for wallpaper image/folder selection
- `nvim` and Lazy.nvim/LazyVim for the optional Neovim theme integration

## Login Keyring Auto-Unlock

OMD uses GNOME Keyring through `secret-tool` for small sensitive values. The
keyring should be unlocked by the password already entered in SDDM; a second
prompt after login is not expected.

This requires both parts of GNOME Keyring:

- the `gnome-keyring-daemon` runtime;
- the PAM module that receives the SDDM login password.

The PAM module is packaged separately on some distributions:

| Distribution | Package |
| --- | --- |
| Fedora / Fedora Asahi Remix | `gnome-keyring-pam` |
| Debian / Ubuntu | `libpam-gnome-keyring` |
| Arch Linux | `gnome-keyring` |

`Init.sh` installs the appropriate package. `bin/omd-doctor` also checks that
`pam_gnome_keyring.so` exists and that `/etc/pam.d/sddm` contains both the
`auth` hook and the `session ... auto_start` hook.

The keyring password must match the SDDM login password. If the PAM module is
installed but the prompt still appears, use Seahorse (Passwords and Keys) to
change the `Default Keyring` password to the current login password. This keeps
the stored secrets. Deleting `~/.local/share/keyrings` is a destructive reset
and must not be used as an automatic repair.

## Terminal Theme Behavior

Omarchy themes generate terminal-specific files in:

```text
~/.config/omarchy/current/theme/foot.ini
~/.config/omarchy/current/theme/kitty.conf
~/.config/omarchy/current/theme/alacritty.toml
~/.config/omarchy/current/theme/ghostty.conf
```

OMD terminal configs import those files:

```text
~/.config/foot/foot.ini
~/.config/kitty/kitty.conf
~/.config/alacritty/alacritty.toml
~/.config/ghostty/config
```

`omarchy-theme-set` swaps the active theme directory, runs
`omarchy-restart-terminal`, then applies Foot and Alacritty live colors through
OSC escape sequences. Kitty is signaled with `SIGUSR1`, Ghostty with `SIGUSR2`,
and Alacritty also reloads new windows through the imported theme file.

For this to work after cloning on a new machine, `Init.sh` must own the terminal
config symlinks. Existing real config directories are backed up before linking.

## Neovim Theme Behavior

Omarchy themes already ship a Lazy.nvim-compatible Neovim theme spec:

```text
~/.config/omarchy/current/theme/neovim.lua
```

That file returns Lazy plugin specs. A typical theme file installs the theme
plugin and sets the `LazyVim/LazyVim` `colorscheme` option.

OMD does not symlink or replace the whole `~/.config/nvim` directory. Instead,
it provides a single drop-in plugin spec:

```text
omarchy/nvim/lua/plugins/zz-omarchy-theme.lua
```

Connect it to an existing LazyVim config with:

```sh
~/.config/omd/share/bin/omarchy-nvim-setup
```

The setup script links the drop-in into:

```text
~/.config/nvim/lua/plugins/zz-omarchy-theme.lua
```

On startup, Lazy.nvim reads the active Omarchy theme spec. After switching
themes, `omarchy-theme-set` calls `omarchy-theme-set-neovim`, which best-effort
sends `:OmarchyThemeReload` to running Neovim server sockets. If the newly
selected theme plugin is not installed yet, run `:Lazy sync` or restart Neovim.

## Wallpaper Behavior

`bin/omd-wallpaper` is tracked and wraps the existing Omarchy wallpaper setter.

- Single image: `omd-wallpaper pick-file` or `omd-wallpaper set-file <image>`
- Folder rotation: `omd-wallpaper pick-folder` or
  `omd-wallpaper set-folder <folder>`
- Stop rotation: `omd-wallpaper stop`

Folder rotation stores only the selected folder path in
`~/.local/state/omd/wallpaper/`. That path is machine-local and not portable. If
another user wants the exact same custom folder rotation, the images must be
tracked in this repo or copied to the same machine-local path before enabling
rotation.

## Portability Rules

- Use `~/.config/omd`, `~/.config/omarchy`, `$HOME`, or XDG paths in tracked
  files.
- Do not commit `/home/<user>/...` paths except in docs that explain examples.
- Do not commit cache, state, downloaded models, virtual environments, or
  nested git repos.
- Keep defaults pointed at bundled repo assets.

Before pushing, run:

```sh
~/.config/omd/bin/omd-doctor
git status -sb
home_re=$(printf '%s' "$HOME" | sed 's/[.[\*^$()+?{}|]/\\&/g')
rg -n --hidden -S "$home_re" . -g '!.git/**' -g '!docs/**'
```
