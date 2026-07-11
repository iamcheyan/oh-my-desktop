import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PageBody {
    id: pageRoot
    property var settingsRoot: null

    // ── Notification Popups ──────────────────────────────────────
            SettingsCard {
                title: "Notification Popups"
                subtitle: `${Notifications.list.length} entries`

                SettingsToggleRow {
                    label: "Do not disturb"
                    description: "Suppress notification alerts"
                    checked: Notifications.silent
                    onToggled: Notifications.silent = !Notifications.silent
                }

                SettingsDropdownRow {
                    label: "Low Priority Timeout"
                    description: "Auto-dismiss timeout for low urgency"
                    currentValue: String(Config.options.notifications.timeoutLow ?? 5000)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "1000", label: "1s"},
                        {value: "3000", label: "3s"},
                        {value: "5000", label: "5s"},
                        {value: "8000", label: "8s"},
                        {value: "10000", label: "10s"},
                        {value: "15000", label: "15s"},
                        {value: "30000", label: "30s"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.timeoutLow", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Normal Priority Timeout"
                    description: "Auto-dismiss timeout for normal urgency"
                    currentValue: String(Config.options.notifications.timeoutNormal ?? 7000)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "1000", label: "1s"},
                        {value: "3000", label: "3s"},
                        {value: "5000", label: "5s"},
                        {value: "7000", label: "7s"},
                        {value: "10000", label: "10s"},
                        {value: "15000", label: "15s"},
                        {value: "30000", label: "30s"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.timeoutNormal", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Critical Priority Timeout"
                    description: "Auto-dismiss timeout for critical urgency"
                    currentValue: String(Config.options.notifications.timeoutCritical ?? 0)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "5000", label: "5s"},
                        {value: "10000", label: "10s"},
                        {value: "15000", label: "15s"},
                        {value: "30000", label: "30s"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.timeoutCritical", parseInt(v))
                }

                SettingsToggleRow {
                    label: "Compact mode"
                    description: "Smaller notification cards"
                    checked: Config.options.notifications.compactMode ?? false
                    onToggled: Config.setNestedValue("notifications.compactMode", !Config.options.notifications.compactMode)
                }

                SettingsToggleRow {
                    label: "Timeout progress bar"
                    description: "Show a progress bar on popups"
                    checked: Config.options.notifications.showTimeoutBar ?? true
                    onToggled: Config.setNestedValue("notifications.showTimeoutBar", !Config.options.notifications.showTimeoutBar)
                }

                SettingsToggleRow {
                    label: "Suppress duplicates"
                    description: "Hide duplicate notifications within a short window"
                    checked: Config.options.notifications.dedupe ?? true
                    onToggled: Config.setNestedValue("notifications.dedupe", !Config.options.notifications.dedupe)
                }

                ButtonRow {
                    SettingsButton { label: "Mark Read"; iconName: "done_all"; onClicked: Notifications.markAllRead() }
                    SettingsButton { label: "Clear Popups"; iconName: "clear_all"; onClicked: Notifications.timeoutAll() }
                }
            }

            // ── Notification History ─────────────────────────────────────
            SettingsCard {
                title: "Notification History"
                subtitle: "Persisted notification log"

                SettingsToggleRow {
                    label: "Enable history"
                    description: "Keep a log of past notifications"
                    checked: Config.options.notifications.historyEnabled ?? true
                    onToggled: Config.setNestedValue("notifications.historyEnabled", !Config.options.notifications.historyEnabled)
                }

                SettingsSlider {
                    from: 10
                    to: 200
                    stepSize: 10
                    value: Config.options.notifications.historyMaxCount ?? 50
                    onValueChanged: Config.setNestedValue("notifications.historyMaxCount", Math.round(value))
                }

                SettingsDropdownRow {
                    label: "History retention"
                    description: "How long to keep notifications"
                    currentValue: String(Config.options.notifications.historyMaxAgeDays ?? 0)
                    options: [
                        {value: "0", label: "Forever"},
                        {value: "1", label: "1 day"},
                        {value: "3", label: "3 days"},
                        {value: "7", label: "7 days"},
                        {value: "14", label: "14 days"},
                        {value: "30", label: "30 days"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.historyMaxAgeDays", parseInt(v))
                }
            }

            // ── Clipboard ────────────────────────────────────────────────
            SettingsCard {
                title: "Clipboard"
                subtitle: `${Cliphist.entries.length} entries`
                SettingsRow {
                    label: "Latest item"
                    description: Cliphist.entries.length > 0 ? StringUtils.cleanCliphistEntry(Cliphist.entries[0]).slice(0, 120) : "--"
                }
                ButtonRow {
                    SettingsButton { label: "Open Picker"; iconName: "content_paste"; onClicked: Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-clipboard`, "toggle"]) }
                    SettingsButton { label: "Refresh"; iconName: "refresh"; onClicked: Cliphist.refresh() }
                }
            }


            SettingsCard {
                title: "On-Screen Display"
                subtitle: "Position and global OSD preferences"

                SettingsDropdownRow {
                    label: "OSD position"
                    description: "Where the OSD appears on screen"
                    currentValue: Config.options.osd.position ?? "top_right"
                    options: [
                        {value: "top_right", label: "Top Right"},
                        {value: "top_left", label: "Top Left"},
                        {value: "top_center", label: "Top Center"},
                        {value: "bottom_right", label: "Bottom Right"},
                        {value: "bottom_left", label: "Bottom Left"},
                        {value: "bottom_center", label: "Bottom Center"},
                        {value: "left_center", label: "Left Center"},
                        {value: "right_center", label: "Right Center"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("osd.position", v)
                }

                SettingsToggleRow {
                    label: "Always show percentage"
                    description: "Display the numeric value on every OSD"
                    checked: Config.options.osd.alwaysShowValue ?? false
                    onToggled: Config.setNestedValue("osd.alwaysShowValue", !Config.options.osd.alwaysShowValue)
                }

                SettingsToggleRow {
                    label: "Caps Lock"
                    description: "Show OSD when caps lock is toggled"
                    checked: Config.options.osd.capsLockEnabled ?? false
                    onToggled: Config.setNestedValue("osd.capsLockEnabled", !Config.options.osd.capsLockEnabled)
                }
            }
}
