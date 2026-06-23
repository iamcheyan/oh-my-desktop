# Slimming Phase 1 Removal Plan

Baseline commit: `ce95e33 baseline: save current quickshell state before slimming`

## Goal

Remove disabled or low-value shell features that still carry imports, loaders, services, and settings surface.
This phase only removes features that are already unused in the current setup or have an obvious external replacement.

## Deletion Scope

1. `modules/ii/verticalBar/`
   - Current config uses the horizontal top bar.
   - Remove the vertical bar loader and remove settings entries that can switch the bar to left/right placement.
   - Keep the low-level `bar.vertical` config key as a false compatibility value while other shared bar components still read it.

2. `modules/ii/onScreenKeyboard/`
   - Remove the on-screen keyboard panel, quick toggle models, and bar keyboard button.
   - Remove global state and keyboard layout sync that only existed for this panel.

3. `modules/ii/screenTranslator/` and `services/GoogleCloud.qml`
   - `sidebar.translator.enable` is disabled.
   - Remove the translator panel and its Google Cloud model files.

4. `modules/ii/wallpaperSelector/` and `services/Wallpapers.qml`
   - Wallpaper management is handled outside Quickshell.
   - Remove the selector panel, wallpaper service startup, and launcher actions that open it.

## Verification

- Search for removed component names and global states after deletion.
- Run `git diff --check`.
- Prefer a short runtime reload after the deletion commit if the desktop session can tolerate it.

## Follow-Up Candidates

- Remove remaining wallpaper download shortcuts if they are no longer useful.
- Trim translation strings for deleted settings after the UI settles.
- Revisit `bar.vertical` readers once horizontal bar code no longer shares placement helpers with old vertical behavior.
