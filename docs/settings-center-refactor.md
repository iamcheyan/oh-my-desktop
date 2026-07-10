# Settings Center Refactor — Execution Checklist

Branch: `refactor/settings-center`

Goal: simplify information architecture, remove duplicate entry points, split the
5089-line monolith, and align styles with `TuiStyle`.

Status legend: `[ ]` pending · `[x]` done

---

## Phase 0 — Cleanup (low risk)

- [x] **0.1** Delete unused `displayPage` Component from `SettingsCenter.qml`
- [x] **0.2** Remove dead `controlCenter` imports from `BarDialogOverlay.qml`
- [x] **0.3** Remove wallpaper Card from `display/DisplayPage.qml` (canonical: Appearance)
- [x] **0.4** Grep-verify no orphaned `controlCenter` dialog loaders remain in bar path

## Phase 1 — File split

- [x] **1.1** Add `settings/SettingsTokens.qml` — cosmic palette mapped from `TuiStyle`
- [x] **1.2** Extract inline shell widgets to `settings/widgets/` (individual files:
      `PageBody`, `SettingsNavItem`, `SettingsCard`, `SettingsRow`, `SettingsToggleRow`,
      `SettingsButton`, `SettingsIconButton`, `SettingsMeter`, `SettingsStatusPill`,
      `SettingsSlider`, `SettingsDropdownRow`, `SettingsTextFieldRow`, `ButtonRow`)
- [x] **1.3** Update `settings/widgets/qmldir` and slim `SettingsCenter.qml` shell to import widgets
- [x] **1.4** Extract `settings/pages/OverviewPage.qml`
- [x] **1.5** Extract `settings/pages/AppearancePage.qml` (merged themes + wallpaper + font)
- [x] **1.6** Extract `settings/pages/SoundPage.qml` (merged sounds + audio OSD toggles)
- [x] **1.7** Extract `settings/pages/NotificationsPage.qml` (renamed session + OSD position/prefs)
- [x] **1.8** Extract `settings/pages/PowerPage.qml`
- [x] **1.9** Extract `settings/pages/SystemPage.qml` (autostart + window rules + default apps)
- [x] **1.10** Route remaining pages via Loader map in `SettingsCenter.qml` (network, bluetooth, display, voice, keyremap, windows)

## Phase 2 — Style unification

- [x] **2.1** `SettingsTokens` uses `TuiStyle` / `OmarchyTheme` — no new hard-coded accent blues
- [x] **2.2** `DisplayPage` `PanelCard` colors reference `SettingsTokens` / `TuiStyle`
- [x] **2.3** Run style grep checklist from `docs/tui-style-system.md` (settings shell/pages clean; `display/OutputCard.qml` and `MonitorCanvas.qml` literals remain for a follow-up)

## Phase 3 — Information architecture

- [x] **3.1** Merge **Appearance + Themes** → single `appearance` page
- [x] **3.2** Merge **Sound + Sounds** → single `sound` page; rename nav to "Sound & Feedback"
- [x] **3.3** Dissolve standalone **OSD** page — relocate toggles to Sound / Display / Notifications / Power
- [x] **3.4** Rename **Session** → **Notifications** (`session` key kept as alias)
- [x] **3.5** Merge **Autostart + Window Rules + Default Apps** → **System** page
- [x] **3.6** Sidebar: primary pages + collapsible **Advanced** (Voice, Keyremap, Windows VM)
- [x] **3.7** Overview quick links cover all primary categories
- [x] **3.8** Update `normalizePage()` aliases and `docs/settings-center.md`
- [x] **3.9** Remove redundant OMD app shortcut fields for network/bluetooth/volume (link to settings pages)

## Phase 4 — Verify

- [x] **4.1** `~/.config/omd/bin/omd-restart` — no QML errors
- [x] **4.2** `rg "Appearance\\.tiling" quickshell/modules/settings` — clean
- [ ] **4.3** Manual page smoke: appearance, sound, notifications, power, system, display
- [ ] **4.4** Commit + push `refactor/settings-center`

---

## Target navigation (after Phase 3)

```text
Overview
Network & Wireless
Bluetooth
Sound & Feedback
Displays
Appearance
Power & Battery
Notifications
System
— Advanced —
  Voice Input
  Keyboard Remap
  Windows VM
```