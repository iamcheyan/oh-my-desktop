# Dead Code Cleanup — Execution Log

Tracked cleanup from the 2026-07 audit. Completed 2026-07-11.

## Phase 1 — Delete orphan QML (schedule / controlCenter / bar)

- [x] Delete `schedulePopup/todo/` (3 files)
- [x] Delete `schedulePopup/pomodoro/` (3 files)
- [x] Delete `controlCenter/` dead dialogs; move `TuiNotificationList.qml` → `schedulePopup/notifications/`
- [x] Delete `bar/BatteryPopup.qml`, `BatteryDialog.qml`, `NotificationUnreadCount.qml`
- [x] Delete `bar/Resources.qml`, `Resource.qml`

## Phase 2 — Delete orphan services

- [x] Delete `services/Todo.qml`, `services/TimerService.qml`

## Phase 3 — Live code fixes

- [x] `BarStatusPopup.qml`: remove `large`, `notifications`/`resources` branches, debug log, unused import; simplify `openDialog`; IPC `notifications` → `schedule`
- [x] `GlobalStates.qml`: remove `scheduleOpen`, `workspaceShowNumbers`, `barAudioIsSink`, `onScheduleOpenChanged`
- [x] `BarContent.qml`: remove `scheduleOpen` guard
- [x] `KeyboardRemap.qml`: refresh timer binds to `barDialogType === "keyremap"`
- [x] `Weather.qml`: read `Config.options.bar.weather`
- [x] `RightModuleRegistry.qml`: fix stale sidebar description
- [x] `MicButton.qml`: remove `barAudioIsSink` write
- [x] `apps/omd-bar/shell.qml`: drop redundant `schedulePopup` import

## Phase 4 — Config / persistence schema

- [x] `Config.qml`: remove `bar.autoHide`, `bar.indicators.notifications`, `bar.showOnFocusedMonitorOnly`, `bar.tooltips`, `time.pomodoro`; drop `weather` from default `rightModules`
- [x] `config.json`: mirror removals
- [x] `Directories.qml`: remove `todoPath`
- [x] `Persistent.qml`: remove `states.timer`, `states.sidebar.bottomGroup`

## Phase 5 — Settings widgets (unused)

- [x] Delete `SettingsToggleCard.qml`, `SettingsSliderCard.qml`, `SettingsButtonGroup.qml`; update `widgets/qmldir`

## Phase 6 — Documentation

- [x] Update `docs/quickshell-cleanup-audit.md` (schedule section)
- [x] This execution log

## Deferred (out of scope — needs separate decision)

- [~] `quickshell/shell.qml` + `panelFamilies/` — monolith fallback; keep until explicitly retired
- [~] Settings page stub toggles (~35 keys written but not read by services) — UI remains; wire or strip in a follow-up
- [~] `share/bin/` scripts not called from Quickshell — may be used by Hyprland keybinds

## Verification

```sh
~/.config/omd/bin/omd-restart
qs -p ~/.config/omd/apps/omd-bar ipc call barPopup open schedule
```

Verified: `omd-restart` succeeds; schedule panel opens without QML errors (2026-07-11).