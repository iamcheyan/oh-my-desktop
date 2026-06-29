# TUI Style System

OMD Quickshell surfaces use `quickshell/modules/common/TuiStyle.qml` as the
single style token source for the current GNOME Shell inspired dark UI.

Do not add new `Appearance.tiling` usage. Do not hard-code new shell colors in
feature modules unless the value is genuinely content-specific.

## Token Ownership

`TuiStyle.qml` owns these style groups:

```text
Base palette        bg, panel, panelAlt, fg, dim, line
Semantic aliases    accent, success, warning, info, muted, danger
Shell chrome        shellGradientTop/Mid/Bottom, shellBorder, shellRadius
Interior surfaces   surfaceSubtle, surfaceRaised, surfaceHover, surfacePressed
Controls            control, controlHover, controlMuted, controlActiveBorder
Mini controls       miniControlHover, miniControlPressed, miniRadius
Meters              meterTrack
Separators          dividerOpacity
Layout              borderWidth, radius, panelPadding, rowHeight, buttonHeight
```

When changing the global look, start in `TuiStyle.qml`. Feature files should
compose these tokens instead of declaring their own palette.

## Shared Components

Prefer these shared components for new UI:

```text
TuiShell          outer shell/dialog surface
WindowDialog      right/top anchored detailed dialogs
TuiActionButton   primary text actions
TuiMeterBar       battery/volume/brightness meters
TuiDetailRow      key/value rows
TuiSegmentedTabs  segmented tab controls
PasswordTextField password input with built-in reveal/hide eye button
```

If a new component needs a color that does not exist in `TuiStyle.qml`, add a
named token there first. Avoid duplicating literals such as `#181818`,
`#303030`, `#8f8f8f`, or ad-hoc opacity values in feature modules.

## Password Fields

Use `quickshell/modules/common/widgets/PasswordTextField.qml` for ordinary
settings dialogs that ask for a saved or connection password:

```qml
PasswordTextField {
    label: "PSK"
    text: root.connectionPassword
    onTextChanged: root.connectionPassword = text
    onAccepted: root.connectSelected()
}
```

`PasswordTextField` always includes the right-side eye button and defaults to
hidden password text. Calling code should use `focusInput()` when it needs to
place the caret inside the field.

Do not automatically replace lock-screen or polkit authentication prompts with
this component. Those are security-sensitive one-shot prompts, and revealing
the typed password there should be a deliberate product decision rather than a
style-system default.

## Frosted Glass

The frosted glass effect is implemented in two layers:

```text
QML alpha surface  TuiStyle glass tokens make shell/dialog backgrounds translucent
Hyprland blur      omarchy/hypr/looknfeel.lua enables blur for quickshell layers
```

The QML side is controlled from `TuiStyle.qml`:

```text
bg
panel / panelAlt
shellGradientTop / shellGradientMid / shellGradientBottom
shellBorder
surfaceSubtle / surfaceRaised / surfaceHover / surfacePressed
control / controlHover / controlMuted
meterTrack
```

`TuiShell` and `WindowDialog` consume the shell gradient and border tokens.
Bar popups and detailed dialogs should use those shared wrappers instead of
declaring their own glass backgrounds.

The compositor side is configured in `omarchy/hypr/looknfeel.lua`:

```lua
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true, ignore_alpha = 0.1 })
```

`ignore_alpha` prevents Hyprland from blurring fully transparent or near
transparent pixels. This keeps rounded corners transparent instead of filling
the corner rectangle with blurred content. Increase the threshold if corner
pixels still pick up blur; lower it if the panel edge loses too much blur.

Do not add `ignore_zero`, `ignorezero`, or similar guessed fields; they are not
valid in the current runtime and will make `hyprctl reload` report
configuration errors.

To tune the glass effect:

```text
More transparent   lower the alpha in TuiStyle shell/surface/control tokens
More solid         raise the alpha in those same tokens
Softer blur        tune decoration.blur in share/default/hypr/looknfeel.lua or an override
Sharper edges      adjust shellBorder, borderWidth, shellRadius
```

## Current Migration State

The main active UI surfaces have been migrated to `TuiStyle`:

```text
BarStatusPopup
ControlCenterContent
BluetoothDialog
WifiDialog
NightLightDialog
VolumeDialog
ClipboardDialog / ClipboardItem
AppLauncher
OverviewSearch
WindowDialog
TuiMeterBar / TuiActionButton / notification widgets
common config widgets
```

`Appearance.tiling` is considered retired for runtime QML. It may still appear
in old documentation only as historical context.

## Review Checklist

Before finishing a style change:

```sh
rg -n "Appearance\\.tiling" quickshell apps -g '*.qml'
rg -n "#[0-9A-Fa-f]{6,8}|Qt\\.rgba\\(" quickshell/modules apps -g '*.qml'
git diff --check -- quickshell apps docs
~/.config/omd/bin/omd-restart
```

Hard-coded colors in `TuiStyle.qml` itself are expected. Hard-coded colors in
feature modules should be justified or moved into `TuiStyle.qml`.
