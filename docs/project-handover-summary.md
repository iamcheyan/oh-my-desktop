# OMD (oh-my-desktop) Project Handover Summary

This document summarizes the current state, architecture, recent features/fixes, and outstanding items for the OMD project to ensure a seamless transition for the next AI agent session.

---

## 1. Project Overview & Architecture

OMD is a unified desktop configuration repository for a custom Wayland desktop environment (Hyprland + Quickshell) running on Asahi Linux / Fedora.

### Process Split Architecture
To prevent single-thread QML bottlenecks, Quickshell is split into independent processes, running as transient systemd user services:
*   `omd-bar`: The top/bottom status bar.
*   `omd-desktop`: Desktop wallpaper, active window tracking, and surface interactions.
*   `omd-overview`: Workspace overview, workspace switcher, and cross-monitor dragging.
*   `omd-applauncher`: Clean fullscreen application grid (launched via `omd-applauncher toggle`).
*   `omd-clipboard`: Clipboard history manager (utilizing `cliphist` & `omd-clipboard-store`).

### Services & Styles
*   **Singletons**: Services (e.g. `Audio.qml`, `KeyboardRemap.qml`, `HyprlandData.qml`) are QML singletons under `quickshell/services/` and imported as `import qs.services`.
*   **Styling**: Standard color and layout tokens are defined in `quickshell/modules/common/TuiStyle.qml` and mapped in `quickshell/modules/common/Appearance.qml`.
*   **Config**: Central options are read from `quickshell/config.json` and parsed/deserialized dynamically via `JsonAdapter` in `quickshell/modules/common/Config.qml`.

---

## 2. Recent Accomplishments & Features (This Session)

We worked on the `refactor/settings-center` branch and accomplished the following:

### A. App Launcher Deduplication
*   **Path**: [bin/omd-applauncher-cache](file:///home/tetsuya/development/OMD/bin/omd-applauncher-cache)
*   **Issue**: Duplicate icons appeared for applications installed both globally (e.g. `/usr/share/applications`) and locally (e.g. `~/.local/share/applications`).
*   **Fix**:
    1.  Re-ordered search directories to follow standard XDG precedence (user directories first).
    2.  Added a pure-shell seen IDs checker (`case "$seen_ids" in ...`) to filter out lower-priority duplicates.
    3.  Refactored short-circuit `&&` checks to standard `if` blocks to prevent shell exits under `set -e`.

### B. Screenshot Tool (Region Selector) Optimizations
*   **Paths**: [RegionSelection.qml](file:///home/tetsuya/development/OMD/quickshell/modules/regionSelector/RegionSelection.qml), [ScreenshotAction.qml](file:///home/tetsuya/development/OMD/quickshell/modules/common/utils/ScreenshotAction.qml)
*   **Optimizations**:
    1.  **0ms Instant Activation**: Removed the slow full-screen `grim` pre-capture step and python-based OpenCV image detection. The UI now freezes and opens instantly via `ScreencopyView`.
    2.  **Zero-UI Clean Overlay**: Removed `OptionsToolbar` and the bottom Close button row entirely. The selection layer is completely clean. Press `Esc` to cancel, or release the mouse to save.
    3.  **Square Constraint**: Added `Shift` key constraint to force perfect `1:1` square selection crops.
    4.  **Edit Mode & Swappy/Satty Integration**: Fixed a bug where releasing the Left mouse button would reset the explicitly set `Edit` action back to `Copy`. Added a **"Capture & Edit"** option to the status bar screenshot right-click menu ([ScreenshotContextMenu.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/ScreenshotContextMenu.qml)) which directly launches `swappy`/`satty` upon crop.

---

## 3. Important Design Details & Development Gotchas

### Quickshell Systemd Transient Units
*   Quickshell services are restarted via `scripts/reload-quickshell` (which calls `bin/omd-restart`).
*   **Gotcha**: If a service (like `omd-bar`) crashes with a Segfault, its systemd user transient unit will enter the `failed` state. Systemd refuses to spawn a new service with the same unit name until the failure state is cleared.
*   **Fix**: Run `systemctl --user reset-failed omd-bar` to reset it, or use `scripts/reload-quickshell` which handles teardowns.

### Uncommitted Working Tree Diffs
There are uncommitted changes on the `refactor/settings-center` branch that represent active keyboard remapping work:
1.  **`keyboard-remap/profiles.json`**: Device profile definitions including the user's magic keyboard and SPI keyboard.
2.  **`share/bin/omarchy-keyboard-list`**: Optimizations to keyboard detection heuristics (replacing mouse-sibling checks).
3.  **`share/bin/omarchy-system-logout`**: Updated exit dispatcher call.

---

## 4. Handover & Next Steps

When spawning the next session:
1.  Ensure all quickshell services are active: `pgrep -af '(quickshell)'`.
2.  Test the **"Capture & Edit"** menu item on the top bar's screenshot right-click menu.
3.  Re-integrate the `keyd` warning card into [SettingsCenter.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/SettingsCenter.qml#L1716) if requested.

This summary document is saved at:
`/home/tetsuya/development/OMD/docs/project-handover-summary.md`
