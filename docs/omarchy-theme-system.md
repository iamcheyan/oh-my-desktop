# Omarchy Theme System

This note records how Omarchy themes work in OMD and how the settings center
should integrate theme switching.

## Summary

Omarchy themes are not a Hyprland-native theme feature. They are managed by
shell scripts that build a current theme snapshot under:

```text
~/.config/omarchy/current/theme
```

In this repo, that path is:

```text
omarchy/current/theme
```

Hyprland, hyprlock, terminals, walker, swayosd, browser integrations, and other
apps read generated files from that current theme snapshot.

## Theme Locations

Built-in themes:

```text
share/themes/<theme-name>/
```

`share/themes/oceanblack/` is an OMD-added theme derived from the user's
preferred Neovim `oceanblack` colorscheme. It intentionally has no wallpaper or
image preview; Settings Center displays it with generated color swatches.

User themes:

```text
~/.config/omarchy/themes/<theme-name>/
omarchy/themes/<theme-name>/      # repo path through the symlink
```

Current theme state:

```text
omarchy/current/theme/            # active generated/copied theme files
omarchy/current/theme.name        # active theme name
omarchy/current/background        # active wallpaper symlink/file
```

Typical active theme files:

```text
colors.toml
quickshell.json
hyprland.lua
hyprlock.conf
walker.css
waybar.css
kitty.conf
foot.ini
ghostty.conf
mako.ini
swayosd.css
vscode.json
obsidian.css
backgrounds/
preview.png
light.mode
```

`light.mode` is an empty marker file used by theme integration scripts to detect
light themes.

## Commands

List themes:

```sh
omarchy-theme-list
```

Show current theme:

```sh
omarchy-theme-current
```

Apply a theme:

```sh
omarchy-theme-set <theme-name>
```

Set wallpaper:

```sh
omarchy-theme-bg-set <path-to-image>
```

Cycle wallpaper inside the current theme:

```sh
omarchy-theme-bg-next
```

Open the existing image-based theme switcher:

```sh
omarchy-theme-switcher
```

## Theme Apply Flow

`share/bin/omarchy-theme-set` is the main implementation.

Given a user-facing name such as `Tokyo Night`, it normalizes it to:

```text
tokyo-night
```

Then it:

1. Verifies the theme exists in either the built-in theme directory or the user
   theme directory.
2. Creates a clean staging directory:

   ```text
   ~/.config/omarchy/current/next-theme
   ```

3. Copies the built-in theme into the staging directory.
4. Overlays the user theme on top of it, if one exists with the same name.
5. Generates `colors.toml` from `alacritty.toml` when a theme has no
   `colors.toml`.
6. Runs:

   ```sh
   omarchy-theme-set-templates
   ```

7. Atomically swaps the staged theme into:

   ```text
   ~/.config/omarchy/current/theme
   ```

8. Writes the active theme name to:

   ```text
   ~/.config/omarchy/current/theme.name
   ```

9. Unless `OMARCHY_THEME_SKIP_BACKGROUND=1` is set, changes wallpaper by calling:

   ```sh
   omarchy-theme-bg-next
   ```

10. Restarts or refreshes components:

    ```text
    waybar, swayosd, terminal, hyprctl, btop, opencode, mako, helix
    ```

11. Applies app-specific theme integrations:

    ```text
    foot, alacritty, Neovim, GNOME, Qt/KDE, browser, VS Code/Codium/Cursor, Obsidian, keyboard
    ```

12. Runs the hook:

    ```sh
    omarchy-hook theme-set <theme-name>
    ```

13. Warms the background selector cache in the background.

## Template Generation

`share/bin/omarchy-theme-set-templates` reads:

```text
~/.config/omarchy/current/next-theme/colors.toml
```

It applies color substitutions to templates from:

```text
share/default/themed/*.tpl
omarchy/themed/*.tpl
```

Generated files are written into:

```text
~/.config/omarchy/current/next-theme/
```

Example substitutions:

```text
{{ background }}       -> #0B0C16
{{ background_strip }} -> 0B0C16
{{ background_rgb }}   -> 11,12,22
```

If a theme already provides a generated output file directly, the template step
does not overwrite it.

## Hyprland Integration

Hyprland entry point:

```text
omarchy/hypr/hyprland.lua
```

It loads Omarchy defaults:

```lua
require("default.hypr.omarchy")
```

Inside `share/default/hypr/omarchy.lua`, Omarchy checks:

```text
~/.config/omarchy/current/theme/hyprland.lua
```

If it exists, it loads:

```lua
require("omarchy.current.theme.hyprland")
```

So theme-specific Hyprland colors and overrides come from the active current
theme snapshot, not from a hard-coded Hyprland config file.

## Hyprlock Integration

`omarchy/hypr/hyprlock.conf` begins with:

```conf
source = ~/.config/omarchy/current/theme/hyprlock.conf
```

The lockscreen background points at:

```conf
path = ~/.config/omarchy/current/background
```

So theme switching changes hyprlock colors through `hyprlock.conf`, and wallpaper
changes are reflected through the `current/background` symlink.

## Neovim Integration

Each Omarchy theme can provide:

```text
share/themes/<theme-name>/neovim.lua
```

When a theme is applied, that file is copied into:

```text
~/.config/omarchy/current/theme/neovim.lua
```

The file is a Lazy.nvim plugin spec, not a direct Neovim colorscheme command.
For example, it usually returns:

```lua
return {
  { "theme/plugin.nvim", priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "theme-name",
    },
  },
}
```

OMD provides:

```text
omarchy/nvim/lua/plugins/zz-omarchy-theme.lua
share/bin/omarchy-nvim-setup
share/bin/omarchy-theme-set-neovim
```

`omarchy-nvim-setup` links the drop-in into an existing LazyVim config at:

```text
~/.config/nvim/lua/plugins/zz-omarchy-theme.lua
```

This keeps a user's Neovim config owned by their normal dotfiles while letting
Lazy.nvim load the active Omarchy theme. `omarchy-theme-set-neovim` then
best-effort sends `:OmarchyThemeReload` to running Neovim server sockets after
theme changes. New Neovim windows always read the current theme snapshot.

## Wallpaper Integration

`share/bin/omarchy-theme-bg-set`:

1. Resolves the selected image to an absolute path.
2. Updates:

   ```text
   ~/.config/omarchy/current/background
   ```

3. Updates Quickshell's legacy/background config when `jq` is available:

   ```json
   .background.wallpaperPath
   .background.thumbnailPath
   ```

4. Restarts `swaybg`:

   ```sh
   swaybg -i ~/.config/omarchy/current/background -m fill
   ```

OMD's `bin/omd-wallpaper` builds on top of `omarchy-theme-bg-set` for single
image selection and folder rotation.

## Quickshell / OMD Notes

Omarchy's original theme apply flow restarts Waybar and other upstream Omarchy
components, but OMD uses split Quickshell apps instead:

```text
omd-bar
omd-desktop
omd-overview
omd-switcher
omd-applauncher
omd-corners
omd-clipboard
```

When theme switching is added to Settings Center, do not reimplement the theme
copy/template logic in QML. Use the existing Omarchy command:

```sh
omarchy-theme-set <theme-name>
```

Recommended settings center command:

```sh
omarchy-theme-set "<theme-name>"
```

Do not restart OMD Quickshell automatically from the Settings Center theme
page. Restarting `omd-bar` closes the Settings Center itself. If the user wants
to reload Quickshell after applying a theme, expose that as a separate explicit
action such as the existing "Reload Shell" button.

The OMD Settings Center always keeps the current wallpaper while changing
theme:

```sh
OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-set "<theme-name>"
```

Do not expose a "switch wallpaper with theme" option in Settings Center.
Wallpaper selection is handled separately by `bin/omd-wallpaper` on the
Appearance page.

## Settings Center Integration Plan

The Settings Center should add a Theme page that:

1. Reads the current theme from:

   ```text
   omarchy/current/theme.name
   ```

2. Lists themes from both:

   ```text
   omarchy/themes/
   share/themes/
   ```

3. De-duplicates by theme name, with user themes taking precedence.
4. Displays theme previews using this priority:

   ```text
   preview.png / preview.jpg / preview.jpeg / preview.webp / preview.gif / preview.bmp
   first image in backgrounds/
   ```

5. Shows a light/dark marker based on whether the theme has:

   ```text
   light.mode
   ```

6. Applies a theme by shelling out to:

   ```sh
   omarchy-theme-set "<theme-name>"
   ```

7. Shows an "Applying..." state while the command is running.

The QML layer should only orchestrate the UI and execute the existing commands.
Theme file generation and app-specific sync should remain owned by Omarchy's
shell scripts.
