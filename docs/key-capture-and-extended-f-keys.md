# Key Capture and Extended F Keys

This note records the decisions from the keyboard-remap / voice-hotkey debugging session.

## Two Capture Modes

OMD uses one GTK capture tool with two explicit modes:

```sh
scripts/key-test --remap-source
scripts/key-test --hotkey
```

Use `--remap-source` only when editing Keyboard Remap source keys. It temporarily stops keyd, captures the physical key, then restores keyd. This prevents current remaps from changing what the source capture sees.

Use `--hotkey` for Voice Input and application shortcuts. It leaves keyd running and captures the final key seen by normal applications.

## Draft vs Apply

Keyboard Remap edits are a draft until the user presses **Apply changes**.

- Add / Update / Remove / Preset edit `~/.config/omd/keyboard-remap/profiles.json`.
- Apply renders with `~/.config/omd/share/bin/omarchy-keyboard-render`.
- Apply installs `/etc/keyd/omd.conf` with `omarchy-keyboard-apply`.
- UI pending state compares render output with `/etc/keyd/omd.conf`.

If a deleted remap still works, the draft has not been applied yet.

## Updating Existing Remaps

Within one device profile, `from` is unique. Capturing an already-mapped physical key should update that row, not create a duplicate. The Add card shows Update and prefills the current target.

## F13 to F24

keyd supports `f13` through `f24`, and the Keyboard Remap target dropdown exposes them. They are useful internal targets for spare keys:

```ini
leftmeta = f13
muhenkan = f18
```

Do not assume the app-level hotkey name is always `F13`. The active XKB layout can expose keyd `f13` as another keysym. On the current JP layout, keyd `f13` appears as GDK `Tools`, and Hyprland wants `XF86Tools`.

Rule:

- keyd target: `f13`
- app / Hyprland hotkey: whatever `key-test --hotkey` captures, e.g. `XF86Tools`

Bad binding:

```text
TOOLS
```

Good binding for the current JP layout:

```text
XF86Tools
```

Fix a broken Voice binding:

```sh
sed -i 's/^TOOLS$/XF86Tools/' ~/.config/omarchy/voice_bindings.txt
hyprctl reload
```

## Useful Checks

Check the keyd draft render:

```sh
~/.config/omd/share/bin/omarchy-keyboard-render
```

Check installed keyd config:

```sh
cat /etc/keyd/omd.conf
```

Check Hyprland registered Voice bindings:

```sh
hyprctl -j binds \
  | jq -r '.[] | select((.description // "") == "Voice input toggle") | [.modmask, .key, .keycode] | @tsv'
```

Check whether keyd supports a target key:

```sh
keyd list-keys | rg '^f(1[3-9]|2[0-4])$'
```

Related docs:

- `docs/keyboard-remap.md`
- `docs/voice-input.md`
