# Unused Runtime Code Audit - 2026-07-11

Scope: current split Quickshell session. Runtime evidence came from `qs list --all`,
`bin/omd-restart`, Hyprland bindings, and static imports.

## Current Runtime Entry Points

Currently running / launched by OMD:

- `apps/omd-bar/shell.qml`
- `apps/omd-desktop/shell.qml`
- `apps/omd-overview/shell.qml`
- `apps/omd-applauncher/shell.qml` on demand via `bin/omd-applauncher`
- `apps/omd-clipboard/shell.qml` on demand via `bin/omd-clipboard`
- `bin/omd-clipboard-store`

Currently not started by `bin/omd-restart`:

- `apps/omd-corners/shell.qml`

Legacy/default entry point:

- `quickshell/shell.qml` loads the old monolithic `panelFamilies/IllogicalImpulseFamily.qml`.
  The current session does not run this path.

## Removed In This Pass

- `quickshell/modules/appLauncher/`
  - Duplicate of the current app launcher implementation.
  - Current runtime uses `apps/omd-applauncher/modules/appLauncher/`.
  - Old monolithic panel family no longer embeds `AppLauncher`.
- `GlobalStates.appLauncherOpen`
  - No remaining consumers.
  - The current launcher is controlled by `bin/omd-applauncher` and IPC.
- `quickshell/shell.qml`
  - Legacy monolithic shell entry point.
  - Current runtime starts split apps from `apps/omd-*`.
- `quickshell/panelFamilies/`
  - Only used by the deleted monolithic `quickshell/shell.qml`.
- Legacy monolith kill rules in `scripts/omd-quickshell-stop.sh`
  - Removed `pkill` rules for `.../quickshell` and `~/.config/quickshell`
    monolith instances.
- `quickshell/services/HyprlandKeybinds.qml`
  - Static search found no references outside the service file.
  - The old cheatsheet/keybind consumer is no longer part of the current split
    runtime.
- `quickshell/services/SessionWarnings.qml`
  - Static search found no references outside the service file.
  - No current shell imports or calls it.
- `apps/omd-corners/`
  - Not started by `bin/omd-restart`.
  - Its underlying `ScreenCorners.qml` had `hotCornersEnabled: false`.
- `quickshell/modules/screenCorners/`
  - Only used by the removed `apps/omd-corners` process.
- `bin/omd-corners`
  - Launcher for the removed corners process.
- `Config.options.interactions.hotCorner`
  - Only used by the removed screen-corners module.
- `Config.options.sidebar.cornerOpen` and `Config.options.sidebar.keepRightSidebarLoaded`
  - Only used by the removed screen-corners/sidebar-corner path.
- `omd-corners` references in restart/stop/theme-refresh scripts.
- `quickshell/modules/common/widgets/widgetCanvas/`
  - Only served the removed desktop clock/weather widget system.
  - No remaining QML imports or component references.
- `quickshell/scripts/images/least_busy_region.py`
- `quickshell/scripts/images/least-busy-region-venv.sh`
  - Only supported old "least busy wallpaper region" widget placement.
  - Current region selector uses `find-regions-venv.sh`, which is kept.
- `quickshell/scripts/cava/raw_output_config.txt`
  - No remaining runtime references.
- `quickshell/scripts/colors/random/`
  - Old random wallpaper downloader scripts.
  - Current wallpaper randomization is handled by `bin/omd-wallpaper`.
- `quickshell/modules/bar/ClipboardHoverPopup.qml`
  - The current clipboard bar button launches `bin/omd-clipboard` and no longer
    instantiates this hover popup.
- `quickshell/modules/overview/OverviewSearch.qml`
  - File was explicitly marked as a legacy backup.
  - Current overview keeps search inline in `OverviewWidget`.
- `quickshell/modules/lock/PasswordChars.qml`
  - Old animated password-character renderer.
  - Current lock surface uses `TextInput.Password` directly.
- `quickshell/modules/common/models/quickToggles/`
  - Old quick-toggle model set from the removed control-center/sidebar path.
  - No current bar, settings, or split-app module instantiates these models.
- `quickshell/services/HyprlandAntiFlashbangShader.qml`
  - Became zero-reference after removing the old quick-toggle models.
- `quickshell/services/EasyEffects.qml`
  - Became zero-reference after removing the old quick-toggle models.
- `quickshell/services/SongRec.qml`
- `quickshell/scripts/musicRecognition/`
- `Config.options.musicRecognition`
  - Music recognition was only reachable through the removed quick-toggle model.
- `quickshell/modules/common/models/hyprland/HyprlandConfigOption.qml`
- `quickshell/services/HyprlandConfig.qml`
- `quickshell/scripts/hyprland/hyprconfigurator.py`
  - Old dynamic Hyprland override writer used by the removed quick-toggle
    models.
  - No current settings page or split app calls this bridge.
- `quickshell/modules/common/widgets/shapes/example.qml`
- `quickshell/modules/common/widgets/shapes/example-squircle.qml`
  - Manual demo files for the vendored shape library.
  - Runtime shape components and JavaScript geometry helpers are kept.
- `icons/OS (副本)/`
  - Stray copied OS icon directory tracked by Git.
  - Runtime OS icons are loaded from `icons/OS/` by `ActiveWindow.qml`; no code
    references the copied path.
- Legacy zero-reference `quickshell/modules/common/widgets/` controls:
  - Removed old config/sidebar controls such as `Config*`, `Content*`,
    `NavigationRail*`, `SecondaryTab*`, `WindowDialog*` subcontrols,
    `StyledComboBox`, `StyledSwitch`, and related helper widgets.
  - Current Settings Center uses `quickshell/modules/settings/widgets/` instead.
- `quickshell/modules/common/models/AdaptedMaterialScheme.qml`
- `quickshell/modules/common/models/NestableObject.qml`
  - No current QML instantiates these models.
- `quickshell/modules/common/widgets/shapes/`
  - Vendored Material shape library became unreachable after removing the old
    placeholder/material-shape widgets.
- `quickshell/modules/bar/modules/VoiceButton.qml`
- `quickshell/modules/bar/VoiceHoverPopup.qml`
  - Old standalone voice button.
  - Current bar registry uses `AudioButton.qml`, which combines audio popup and
    voice-input state/actions, plus `AudioVoiceHoverPopup.qml`.
- `quickshell/modules/common/Icons.qml`
- `quickshell/modules/common/Images.qml`
  - Zero-reference common singletons.
  - Current runtime uses local icon/image helpers in active components instead.
- `Config.options.cheatsheet`
- `Persistent.states.cheatsheet`
  - Cheatsheet module and `HyprlandKeybinds` service were already removed.
  - Remaining config/state keys had no runtime readers.

## Confirmed Already Removed Or In Progress

- Desktop/background clock widget code.
- Desktop/background weather widget code.
- Weather service and weather icon maps.
- Calendar UI under the old schedule popup.
- Top-bar clock calendar/schedule click behavior.

The notification list remains intentionally kept. It is now the only remaining
consumer under `quickshell/modules/schedulePopup/notifications/`.

## Strong Cleanup Candidates

These appear unused in the current split session and should be reviewed for
deletion in the next cleanup pass.

## Documentation / Translation Debris

The following are not runtime code, but still contain stale weather/calendar or
old launcher references:

- `quickshell/docs/config-guide.md`
- `quickshell/docs/slimming-guide.md`
- `docs/quickshell-cleanup-audit.md`
- `docs/bar-right-modules.md`
- `docs/module-split-plan.md`
- `docs/process-split-log.md`
- `quickshell/translations/*.json`

Suggested action: clean docs/translations after runtime cleanup, otherwise they
will keep pointing future work back to deleted features.
