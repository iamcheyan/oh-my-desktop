# Input Method Integration

This document describes the top-bar input language indicator and switcher,
its Fcitx5/Rime integration, and the ownership boundary between OMD and the
separate Rime configuration repository.

## Goal

The top bar provides one keyboard control for selecting complete input
languages, rather than only toggling Rime's ASCII mode:

| UI label | Rime schema | Badge | Purpose |
| --- | --- | --- | --- |
| Chinese / Natural input | `sbzr` | `中` | Chinese natural input |
| Chinese / Mixed input | `sbzr_mix` | `中` | Mixed Chinese input |
| English / Easy English | `easy_en` | `A` | English schema |
| Japanese / Romaji | `jaroomaji` | `あ` | Japanese Romaji input |

The badge follows external changes too. Switching the schema through an
existing Fcitx/Rime shortcut updates the top bar on its next poll.

This is deliberately different from switching between the Fcitx input
methods `keyboard-us` and `rime`. Chinese, English, and Japanese are complete
Rime schemas and are selected through Rime itself.

## Ownership Boundary

### OMD owns

- The keyboard icon and language badge in the top bar.
- The unified bar popup containing the language choices.
- Polling Fcitx5 and mapping a schema ID to a display name and badge.
- Calling the Fcitx5 Rime D-Bus service to select a schema.
- Restoring application focus before changing a schema.
- The `omd-input-method` command-line adapter.

### Fcitx5 owns

- The input method daemon and per-application input contexts.
- Activating the `rime` input method.
- The D-Bus service exposed by the installed `fcitx5-rime` addon.
- Delivering keyboard input and candidate windows to applications.

### The separate Rime repository owns

- Schema definitions and schema IDs.
- Dictionaries, translators, filters, key bindings, and candidate behavior.
- Rime deployment/build output and user preferences.
- The files below `~/.local/share/fcitx5/rime/`.

OMD did **not** add, copy, generate, or edit the four Rime schemas listed
above. They already exist in the user's Rime installation. OMD only refers to
their stable schema IDs. The Rime repository remains independently managed
and is not being brought into the OMD repository by this feature.

If a schema is renamed or removed in the Rime repository, update the mapping
in both `bin/omd-input-method` and the choices displayed by
`BarStatusPopup.qml`.

## Files

### `bin/omd-input-method`

Small Python adapter between QML and Fcitx5/Rime.

Commands:

```sh
omd-input-method status
omd-input-method set sbzr
omd-input-method set sbzr_mix
omd-input-method set easy_en
omd-input-method set jaroomaji
omd-input-method config
```

`status` prints JSON:

```json
{
  "available": true,
  "inputMethod": "rime",
  "schema": "jaroomaji",
  "language": "ja",
  "displayName": "Japanese",
  "variant": "Romaji"
}
```

The helper uses:

- `fcitx5-remote -n` to read the active Fcitx input method.
- `fcitx5-remote -s rime` to activate Rime before selecting a schema.
- `gdbus` to call the Rime service.
- `fcitx5-configtool` for the popup's configuration link.

After `SetSchema`, the helper reads the current schema again. It reports an
error instead of claiming success when Rime kept the previous schema.

### `quickshell/services/InputMethod.qml`

Quickshell singleton used by the bar process. It exposes:

```text
available
busy
inputMethod
schema
language
displayName
variant
badge
summary
lastError
```

It polls status every two seconds, refreshes when the popup opens, invokes the
helper for changes, and updates the UI from the helper's JSON output.

The service delays a requested schema change briefly after restoring the
original application window. This is required because Rime applies its D-Bus
operation to the most recent Fcitx input context.

### `quickshell/modules/bar/modules/InputMethodButton.qml`

Top-bar button. It uses the standard fixed right-side icon slot, shows the
keyboard icon, overlays the current language badge, and toggles the unified
bar popup with type `inputMethod`.

### `quickshell/modules/bar/BarContent.qml`

Places `InputMethodButton` in the right-side module row after Wi-Fi and before
the clipboard button.

### `quickshell/modules/bar/BarStatusPopup.qml`

Contains `inputMethodContent`. No separate input-method popup window is
created. This preserves the project's single popup implementation and shared
TUI styling.

The popup:

- Shows the current language and variant in its header.
- Lists the four supported Rime schemas.
- Highlights the selected schema.
- Closes before switching.
- Restores the previously active Hyprland window.
- Provides a link to `fcitx5-configtool`.

For this popup, `WlrKeyboardFocus.None` is used. Mouse interaction continues
to work, but the popup does not become Fcitx's newest keyboard input context.

## Runtime Flow

### Status flow

```text
InputMethod.qml timer
    -> omd-input-method status
    -> fcitx5-remote -n
    -> org.fcitx.Fcitx5 /rime GetCurrentSchema
    -> JSON
    -> top-bar badge and selected popup row
```

### Switching flow

```text
User clicks a schema row
    -> remember HyprlandData.activeWindow.address
    -> close the bar popup
    -> restore the application window focus
    -> wait for its Fcitx input context to become current
    -> fcitx5-remote -s rime
    -> org.fcitx.Fcitx5 /rime SetSchema(schema ID)
    -> GetCurrentSchema verification
    -> refresh the badge
```

## Why Focus Handling Is Necessary

The `fcitx5-rime` D-Bus implementation obtains
`mostRecentInputContext()` and changes the Rime state associated with that
context. It is not an unconditional global schema setter.

If a Quickshell popup takes keyboard focus before `SetSchema`, the operation
can target the popup's context instead of the application in which the user
will type. The UI then appears to accept the click while the original
application remains unchanged.

OMD prevents this in two ways:

1. The input-method popup does not request keyboard focus.
2. Selection closes the popup, restores the original application, waits
   briefly, and only then calls `SetSchema`.

Do not remove this sequence when refactoring the popup or service.

## Dependencies

Required runtime commands and addons:

```text
fcitx5
fcitx5-remote
fcitx5-rime
gdbus
fcitx5-configtool (only for the configuration link)
```

The top bar can still load when these are unavailable. The service reports an
unavailable state and uses `?` as its badge.

## Adding or Renaming a Schema

1. Add and deploy the schema in the separate Rime repository.
2. Confirm that Rime exposes it through `ListAllSchemas`.
3. Add its ID and metadata to `SCHEMAS` in `bin/omd-input-method`.
4. Add its user-facing row to `inputMethodContent` in
   `BarStatusPopup.qml`.
5. Test the switch while a text input in a normal application has focus.
6. Test an external schema change and wait up to two seconds for the badge.

OMD should eventually obtain labels from a data file or from Rime metadata if
the list grows. For the current four stable schemas, the explicit mapping is
small and makes language badges predictable.

## Verification

Static checks:

```sh
python3 -m py_compile bin/omd-input-method
git diff --check
```

Runtime status:

```sh
~/.config/omd/bin/omd-input-method status
```

Manual behavior test:

1. Focus a text field in a regular application.
2. Open the keyboard popup from the top bar.
3. Select each Chinese, English, and Japanese row.
4. Confirm the popup closes and the original application receives input.
5. Confirm the badge changes to `中`, `A`, or `あ`.
6. Change the schema using an existing Rime shortcut and confirm the badge
   follows within two seconds.

## Troubleshooting

### The badge updates, but clicking a language does not change the application

This usually means the schema change targeted the wrong Fcitx input context.
Check that the input-method popup still uses `WlrKeyboardFocus.None` and that
the selection path closes the popup and restores the application before
calling `selectSchema`.

### The popup reports that Fcitx5 is unavailable

Check:

```sh
fcitx5-remote -n
gdbus call --session \
  --dest org.fcitx.Fcitx5 \
  --object-path /rime \
  --method org.fcitx.Fcitx.Rime1.GetCurrentSchema
```

### A row is visible but cannot be selected

Confirm that the schema is deployed by the external Rime repository:

```sh
gdbus call --session \
  --dest org.fcitx.Fcitx5 \
  --object-path /rime \
  --method org.fcitx.Fcitx.Rime1.ListAllSchemas
```

If the ID differs, update the OMD mapping. Do not duplicate the Rime schema
inside OMD.

### Testing from a restricted shell reports a D-Bus connection error

The helper requires access to the user's session bus. A sandboxed agent shell
may not be allowed to open `/run/user/$UID/bus`, even though the live
Quickshell process can. Validate actual switching from the running desktop
session.
