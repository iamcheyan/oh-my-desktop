# Module Split — Services & Remaining Items

## Completed

### Phase A: Freeze Inventory
- Mapped all OMD/modules/ → 10 product-floor modules identified for external migration
- Mapped quickshell/modules/ (shared QML imports)
- Mapped apps/, bin/, quickshell/services/, external modules state
- Ownership matrix written

### Phase B: External Module Migration (10 modules)
All migrated from `OMD/modules/` to `$SUMIKA_MODULES_HOME` (sumika-modules/):

1. launcher — bin shims created (omd-applauncher, omd-applauncher-cache), QML paths fixed
2. clock — simple copy/delete (no external QML refs)
3. notification-popup — simple copy/delete
4. power-indicator — simple copy/delete
5. systray — simple copy/delete
6. workspaces — simple copy/delete
7. audio — QML refs fixed (ActionManager.qml), bin script hardened (omd-swayosd-client)
8. display — QML refs fixed (DisplayConfigState.qml, Brightness.qml), bin paths updated
9. overview — bin script hardened (omd-overview prefers SUMIKA_MODULES_HOME)
10. wifi — QML refs fixed (ActionManager.qml, BluetoothStatus.qml, Network.qml, WifiPopup.qml, module-actions.qml)

### Phase C: Clean OMD Business Tree
- AGENTS.md updated: data layout table, module descriptions, Path API table
- modules/README.md rewritten for new architecture (empty OMD/modules/)
- apps/omd-settings was already a thin shim (no change needed)
- Bar audit: no direct imports of now-external modules
- quickshell/modules/ core imports (settings, overview, onScreenDisplay, notificationPopup) remain as shared QML libraries

### Phase D: Discovery & Floor Config
- ModuleLoader.productFloorModuleIds ✅ all 10 IDs
- Config.qml required list ✅ all 10 IDs
- bin/omd-restart _PRODUCT_FLOOR ✅ fixed (was missing notification-popup, display)
- default config.json ✅ has all 10 required
- user sumika.json ✅ has correct required list
- quickshell/scripts/quickshell startup script scans SUMIKA_MODULES_HOME and generates registry correctly

### Phase E: Shim Audit
- All bin/ scripts already use SUMIKA_MODULES_HOME or OMD_ROOT patterns
- hypr/ bindings use `omd-action` dispatch — no stale module paths
- No hardcoded `OMD/modules/X/bin/` paths remain in QML or scripts

### Phase F: Negative Verification
- OMD/modules/ ✅ empty (README only)
- No duplicate module IDs between OMD/modules/ and sumika-modules/
- All 27 sumika-modules validate ✅
- grep for stale `modules/X/` paths: no actionable hits found

## Remaining (non-blocking / optional)

### QML Merge: quickshell/modules/ → sumika-modules/
- quickshell/modules/onScreenDisplay/ and sumika-modules/display/onScreenDisplay/ have duplicate OSD QML files
- quickshell/modules/notificationPopup/ and sumika-modules/notification-popup/ have different NotificationPopup.qml
- quickshell/modules/overview/ is canonical import for external overview/shell.qml
- quickshell/modules/settings/pages/ still has pages for external modules (NetworkPage, SoundPage, BluetoothPage, KeyboardRemapPage, WindowsVmPage)
- These shared QML dirs are the canonical import source for `qs.modules.*` — safe to keep as framework libraries

### Settings Page Contribution Migration
- Settings pages for now-external modules (NetworkPage, SoundPage, etc.) still hardcoded in SettingsDialog.qml
- Some modules already register settingsPages in module.json (display, battery-power, keyboard-remap, windows-vm)
- Migration plan: add settingsPages to remaining external modules, then remove pages from quickshell/modules/settings/pages/ and update SettingsDialog.qml

### GUI Testing (requires Hyprland session)
- No smoke test possible without GPU/display session
- Enabled=false/true module loading behavior cannot be exercised headless
- omd-module-validate --all only checks manifest schema, not runtime loading

### Git Commits
Organize into logical groups:
1. Module migration: all 10 modules moved to sumika-modules
2. QML reference fixes: ActionManager, DisplayConfigState, Brightness, BluetoothStatus, Network, WifiPopup
3. Bin shims: omd-applauncher, omd-applauncher-cache
4. Config updates: omd-restart _PRODUCT_FLOOR
5. Documentation: AGENTS.md, modules/README.md
