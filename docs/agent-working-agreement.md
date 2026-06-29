# Agent Working Agreement

This project is now `oh-my-desktop`, rooted at:

```text
~/development/OMD
```

Agents should treat this as the only active project root unless the user
explicitly says otherwise.

## Active Runtime Paths

The live desktop uses symlinks:

```text
~/.config/quickshell -> ~/development/OMD/quickshell
~/.config/omarchy    -> ~/development/OMD/omarchy
~/.config/walker     -> ~/development/OMD/omarchy/walker
~/.config/omd        -> ~/development/OMD
~/.local/share/omarchy -> ~/development/OMD/share
```

The old path `~/.config/hypr` is legacy. Do not use it for current work.

## Current State

Current runtime is split into independent Quickshell processes:

```sh
quickshell -p ~/.config/omd/apps/omd-bar
quickshell -p ~/.config/omd/apps/omd-desktop
quickshell -p ~/.config/omd/apps/omd-overview
quickshell -p ~/.config/omd/apps/omd-switcher
quickshell -p ~/.config/omd/apps/omd-applauncher
quickshell -p ~/.config/omd/apps/omd-corners
quickshell -p ~/.config/omd/apps/omd-clipboard
```

The launcher at `quickshell/scripts/quickshell` accepts an optional config
directory:

```sh
quickshell/scripts/quickshell ~/.config/quickshell
```

Split modules use the same launcher with their own app root so Wayland/Hyprland
session discovery stays consistent.

The legacy monolithic root `~/.config/quickshell` remains as source/fallback
during migration. Omarchy autostart should use `~/.config/omd/bin/omd-restart`.

## Privacy Rules

Before committing or pushing, check for private/runtime data.

Never commit:

- `.migration-backups/`
- nested `.git/`
- browser profiles such as `omarchy/chromium/Default/`
- caches or runtime state
- `omarchy/current/background` absolute symlink
- API keys, tokens, secrets, private keys
- local absolute paths pointing at the current user's home directory
- machine-local wallpaper folders selected through `omd-wallpaper`

Use `$HOME` or runtime XDG paths in tracked config where possible.

## Git Rules

- Remote is `git@github.com:iamcheyan/oh-my-desktop.git`.
- Main branch is `main`.
- Prefer small commits that correspond to one migration or feature.
- Run privacy checks before every push.
- Do not rewrite published history unless the user explicitly asks.

Useful checks:

```sh
git status -sb
git ls-files | rg '(^|/)(Default/|cached_layouts|opencode/|\\.migration-backups/|current/background$|\\.git/)'
home_re=$(printf '%s' "$HOME" | sed 's/[.[\*^$()+?{}|]/\\&/g')
rg -n --hidden -S "(${home_re}|github[_]pat|gh[p]_|s[k]-[A-Za-z0-9_-]{20,}|OPENAI[_]API[_]KEY|ANTHROPIC[_]API[_]KEY)" . -g '!.git/**'
```

## Editing Rules

- Use `apply_patch` for manual file edits.
- Keep the current desktop working after each step.
- Do not delete the monolithic `quickshell/` runtime until the replacement
  module has been verified.
- Avoid large formatting-only rewrites while splitting modules.
- Preserve existing user changes unless the user explicitly asks to discard
  them.

## Verification

For Quickshell changes:

```sh
~/.config/omd/bin/omd-doctor
python -m json.tool quickshell/config.json >/tmp/omd-config-check.json
sh -n quickshell/scripts/quickshell
~/.config/omd/bin/omd-restart
```

For Omarchy/Hyprland changes:

```sh
hyprctl reload
```

Then inspect the active process:

```sh
pgrep -af 'quickshell|qs -p'
```

Expected current processes include:

```text
quickshell -p $HOME/.config/omd/apps/omd-bar
quickshell -p $HOME/.config/omd/apps/omd-desktop
quickshell -p $HOME/.config/omd/apps/omd-overview
quickshell -p $HOME/.config/omd/apps/omd-switcher
quickshell -p $HOME/.config/omd/apps/omd-applauncher
quickshell -p $HOME/.config/omd/apps/omd-corners
quickshell -p $HOME/.config/omd/apps/omd-clipboard
```

## Module Split Direction

Follow `docs/module-split-plan.md`.

Short version:

- First split `omd-bar`.
- Then split `omd-overview` (工作区概览).
- Then split `omd-switcher` (快速切换).
- Keep shared code in `common`.
- Do not duplicate DBus/listener-heavy services across multiple Quickshell
  processes.
