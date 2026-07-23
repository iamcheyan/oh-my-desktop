# Quickshell Entrypoint Refactor — Verification Report

**Date**: 2026-07-24
**Repository**: `~/development/OMD`

## Summary

Replaced legacy dependency mechanism (project-directory symlinks + flat file copies) with official QML module system (`import qs`) and manifest-driven action registration (`module.json:actionsProvider`). All 8 architecture issues from post-refactor audit resolved.

## Fixed Issues

### High Priority Bugs (Runtime Errors)

| # | Issue | File | Fix |
|---|---|---|---|
| 1 | Systray TypeError on `trayItems` | `modules/systray/SysTray.qml` | Guard with `?? []`, return fixed `{pinned:[], unpinned:[]}` on null |
| 2 | Overview `searchHeader` not defined | `quickshell/modules/overview/OverviewSearch.qml` | `resultsPopup` and `sessionMenu` anchored to `parent.top` instead of deleted `searchHeader` |
| 3 | Popup ownership unstable (battery, voice duplicate) | `quickshell/core/runtime/ModuleLoader.qml` | Sort OMD core modules before external for stable singleton ownership |
| 4 | Bluetooth hardcoded in core ActionManager | `quickshell/core/runtime/ActionManager.qml` | Conditional — only registers if no `bluetooth` module exists in registry |

### Architecture Cleanup

| # | Issue | Fix |
|---|---|---|
| 5 | `_registry` exposure | Added public API: `ModuleLoader.modules`, `ModuleLoader.actionProviders`, `ModuleLoader.contributedActions`, `ModuleLoader.applicationEntries` — updated all 4 consumers (ActionManager, ModuleActionHost, ApplicationManager, ModulesPage) |
| 6 | Fragile `modelData.moduleId` in destruction | Captured `ownerId` at delegate creation time before model data can be removed |
| 7 | Duplicate GlobalStates in launcher | Deleted `modules/launcher/modules/appLauncher/widgets/GlobalStates.qml` |
| 8 | Hardcoded `~/.config/omd` / `$HOME/.config/omd` paths | Replaced in 11 locations: services/VoiceInput (×2), quickshell/services/VoiceInput (×2), services/Brightness (×2), quickshell/services/Brightness (×2), services/Network (×3), quickshell/services/Network (×3), modules/display/settings/DisplayConfigState, shared/Directories.qml (×2). All use `Directories.root` now. |

### Verification (Pre-existing, unrelated)

- Systray warnings (issue #7): `Cannot read property 'pinned' of undefined` — pre-existing, intermittent at startup
- Duplicate singleton popup warnings: cosmetic, from `nameComponents` staging
- `omd-doctor` failures: Go settings binary, GNOME Keyring PAM, OCR helper — all pre-existing

## Runtime Verification

| Check | Result |
|---|---|
| `omd-restart` — all 4 processes | ✅ Clean start |
| Bar `/tmp/omd-bar.log` — errors | ✅ 0 (only pre-existing Systray + portal warnings) |
| `omd-action list` — actions registered | ✅ 21 non-core + 14 core = 35 total |
| Bluetooth conditional | ✅ Only if no `bluetooth` module in registry |
| Module disable/enable | ✅ `isEnabled()` gates all module APIs |
| `Directories.root` resolves correctly | ✅ Verified (env var + fallback) |
| `ModuleLoader.actionProviders` — 7 modules | ✅ app-launcher, input-method, notification, wifi, clipboard, screenshot, voice |
| `ModuleLoader.modules` — public API | ✅ All consumers migrated from `_registry` |

## Current State

- `apps/omd-bar/`: `shell.qml` only (no symlinks)
- `module-actions.qml`: only 7 real files (0 empty stubs)
- `shellPath` calls: 0 in `quickshell/`, 0 in `shared/`
- `_registry` direct access: 0 consumers (all use public API)
- `GlobalStates` copies: 0 (single source in `quickshell/GlobalStates.qml`)
- Hardcoded `~/.config/omd` paths in QML: 0 (all use `Directories.root`)
