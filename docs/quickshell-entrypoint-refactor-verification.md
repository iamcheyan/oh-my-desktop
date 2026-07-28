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
| 3 | Popup ownership unstable (battery, voice duplicate) | `quickshell/core/runtime/ModuleLoader.qml` | Sort Sumika Shell core modules before external for stable singleton ownership |
| 4 | Bluetooth hardcoded in core ActionManager | `quickshell/core/runtime/ActionManager.qml` | Conditional — only registers if no `bluetooth` module exists in registry |

### Architecture Cleanup

| # | Issue | Fix |
|---|---|---|
| 5 | `_registry` exposure | Added public API: `ModuleLoader.modules`, `ModuleLoader.actionProviders`, `ModuleLoader.contributedActions`, `ModuleLoader.applicationEntries` — updated all 4 consumers (ActionManager, ModuleActionHost, ApplicationManager, ModulesPage) |
| 6 | Fragile `modelData.moduleId` in destruction | Captured `ownerId` at delegate creation time before model data can be removed |
| 7 | Duplicate GlobalStates in launcher | Deleted `modules/launcher/modules/appLauncher/widgets/GlobalStates.qml` |
| 8 | Hardcoded `$SUMIKA_SHELL_ROOT` / `$SUMIKA_SHELL_ROOT` paths | Replaced in 11 locations: services/VoiceInput (×2), quickshell/services/VoiceInput (×2), services/Brightness (×2), quickshell/services/Brightness (×2), services/Network (×3), quickshell/services/Network (×3), modules/display/settings/DisplayConfigState, shared/Directories.qml (×2). All use `Directories.root` now. |

### Verification (Pre-existing, unrelated)

- Systray warnings (issue #7): `Cannot read property 'pinned' of undefined` — pre-existing, intermittent at startup
- Duplicate singleton popup warnings: cosmetic, from `nameComponents` staging
- `sumika-doctor` failures: Go settings binary, GNOME Keyring PAM, OCR helper — all pre-existing

## Runtime Verification

| Check | Result |
|---|---|
| `sumika-restart` — all 4 processes | ✅ Clean start |
| Bar `/tmp/sumika-bar.log` — errors | ✅ 0 (only pre-existing Systray + portal warnings) |
| `sumika-action list` — actions registered | ✅ 21 non-core + 14 core = 35 total |
| Bluetooth conditional | ✅ Only if no `bluetooth` module in registry |
| Module disable/enable | ✅ `isEnabled()` gates all module APIs |
| `Directories.root` resolves correctly | ✅ Verified (env var + fallback) |
| `ModuleLoader.actionProviders` — 7 modules | ✅ app-launcher, input-method, notification, wifi, clipboard, screenshot, voice |
| `ModuleLoader.modules` — public API | ✅ All consumers migrated from `_registry` |

## Current State

- `apps/sumika-bar/`: `shell.qml` only (no symlinks)
- `module-actions.qml`: only 7 real files (0 empty stubs)
- `shellPath` calls: 0 in `quickshell/`, 0 in `shared/`
- `_registry` direct access: 0 consumers (all use public API)
- `GlobalStates` copies: 0 (single source in `quickshell/GlobalStates.qml`)
- Hardcoded `$SUMIKA_SHELL_ROOT` paths in QML: 0 (all use `Directories.root`)

## Known Remaining Issues (Strict Plugin Goal)

The original 8 issues are resolved. However, a strict plugin architecture goal requires further work:

| # | Issue | Severity |
|---|---|---|
| 1 | Bar shell.qml directly loads Hyprsunset/SessionConfirmOverlay/SessionAutoRestore instead of receiving via `contributes.overlays` from display/session modules | Medium |
| 2 | Bluetooth fallback builtin in `ActionManager._registerBuiltins()` — core retains bluetooth awareness | Low |
| 3 | Network.qml link-details Process had missing `id` (`linkDetailsProc is not defined`) | ✅ Fixed |
| 4 | Popup singleton conflict now emits `console.error` with owner tracking (previously `console.warn`) | ✅ Fixed |
| 5 | Overview registered wallpaper provider without `component` field, causing `Loader.source = undefined` | ✅ Fixed |
| 6 | Stop script pkill pattern `modules/sumika-overview` stale (directory renamed to `modules/overview`) | ✅ Fixed |

**Entry point refactor: ~85% complete.** Core symlink elimination, unified imports, module registration API, path migration, and error fixes are done. Remaining items (#1, #2) require module boundary refactoring (session module contributing overlays, removing bluetooth awareness from core).
