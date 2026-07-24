import qs
import qs.core.runtime
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

    // ── Battery Status ───────────────────────────────────────────
            SettingsCard {
                title: "Battery Status"
                subtitle: ServiceManager.power.battery.isCharging ? "Charging" : ServiceManager.power.battery.isPluggedIn ? "Plugged in" : "On battery"
                visible: ServiceManager.power.battery.available

                SettingsMeter { value: ServiceManager.power.battery.percentage * 100 }
                SettingsRow { label: "Level"; value: `${Math.round(ServiceManager.power.battery.percentage * 100)}%` }
                SettingsRow {
                    label: ServiceManager.power.battery.isCharging ? "Time to full" : "Time to empty"
                    value: settingsRoot.formatBatteryTime(ServiceManager.power.battery.isCharging ? ServiceManager.power.battery.timeToFull : ServiceManager.power.battery.timeToEmpty)
                }
                SettingsRow { label: "Power"; value: ServiceManager.power.battery.energyRate > 0.01 ? `${ServiceManager.power.battery.energyRate.toFixed(1)}W` : "--" }
                SettingsRow { label: "Health"; value: ServiceManager.power.battery.healthPercentage > 0 ? `${ServiceManager.power.battery.healthPercentage.toFixed(1)}%` : "--" }
            }

            // ── Battery Protection ───────────────────────────────────────
            SettingsCard {
                title: "Battery Protection & Charging"
                subtitle: "Charge limit and low battery alerts"
                visible: ServiceManager.power.battery.available

                SettingsSliderRow {
                    label: "Charge limit"
                    description: "Stop charging at this percentage to preserve battery health"
                    from: 50
                    to: 100
                    stepSize: 5
                    value: Config.options.battery.full ?? 100
                    valueSuffix: "%"
                    onMoved: Config.setNestedValue("battery.full", Math.round(value))
                }

                SettingsToggleRow {
                    label: "Notify when limit reached"
                    description: "Alert when battery reaches the charge limit"
                    checked: Config.options.battery.notifyChargeLimit ?? false
                    onToggled: Config.setNestedValue("battery.notifyChargeLimit", !Config.options.battery.notifyChargeLimit)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                    opacity: 0.4
                }

                SettingsSliderRow {
                    label: "Low battery threshold"
                    description: "Notify when battery drops below this percentage"
                    from: 5
                    to: 40
                    stepSize: 5
                    value: Config.options.battery.low ?? 20
                    valueSuffix: "%"
                    onMoved: Config.setNestedValue("battery.low", Math.round(value))
                }

                SettingsToggleRow {
                    label: "Low battery notifications"
                    description: "Notify when battery drops below the low threshold"
                    checked: Config.options.battery.notifyLow ?? true
                    onToggled: Config.setNestedValue("battery.notifyLow", !Config.options.battery.notifyLow)
                }

                SettingsToggleRow {
                    label: "Auto power saver"
                    description: "Switch to power-saver profile at low battery"
                    checked: Config.options.battery.autoPowerSaver ?? false
                    onToggled: Config.setNestedValue("battery.autoPowerSaver", !Config.options.battery.autoPowerSaver)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                    opacity: 0.4
                }

                SettingsSliderRow {
                    label: "Critical battery threshold"
                    description: "Alert when battery drops critically low"
                    from: 1
                    to: 30
                    stepSize: 1
                    value: Config.options.battery.critical ?? 5
                    valueSuffix: "%"
                    onMoved: Config.setNestedValue("battery.critical", Math.round(value))
                }

                SettingsToggleRow {
                    label: "Critical battery notifications"
                    description: "Alert when battery drops critically low"
                    checked: Config.options.battery.notifyCritical ?? true
                    onToggled: Config.setNestedValue("battery.notifyCritical", !Config.options.battery.notifyCritical)
                }

                SettingsToggleRow {
                    label: "Automatic suspend"
                    description: "Suspend the system at the suspend threshold"
                    checked: Config.options.battery.automaticSuspend ?? true
                    onToggled: Config.setNestedValue("battery.automaticSuspend", !Config.options.battery.automaticSuspend)
                }
            }

            // ── Power Profile ────────────────────────────────────────────
            SettingsCard {
                title: "Power Profile"
                subtitle: ServiceManager.power.powerProfiles.available ? ServiceManager.power.powerProfiles.currentProfile : "Not available"

                ButtonRow {
                    SettingsButton { label: "Saver"; active: ServiceManager.power.powerProfiles.currentProfile === "power-saver"; enabledState: ServiceManager.power.powerProfiles.available; onClicked: ServiceManager.power.powerProfiles.setProfile("power-saver") }
                    SettingsButton { label: "Balanced"; active: ServiceManager.power.powerProfiles.currentProfile === "balanced"; enabledState: ServiceManager.power.powerProfiles.available; onClicked: ServiceManager.power.powerProfiles.setProfile("balanced") }
                    SettingsButton { label: "Performance"; active: ServiceManager.power.powerProfiles.currentProfile === "performance"; enabledState: ServiceManager.power.powerProfiles.available; onClicked: ServiceManager.power.powerProfiles.setProfile("performance") }
                }
            }

            // ── Power Profile Auto-Switching ─────────────────────────────
            SettingsCard {
                title: "Power Profile Auto-Switching"
                subtitle: "Automatically switch profile on AC/battery"
                visible: ServiceManager.power.battery.available && ServiceManager.power.powerProfiles.available

                SettingsDropdownRow {
                    label: "Profile when plugged in (AC)"
                    description: "Switch to this profile when charging"
                    currentValue: Config.options.battery.acProfile ?? ""
                    options: [
                        {value: "", label: "Don't change"},
                        {value: "power-saver", label: "Power Saver"},
                        {value: "balanced", label: "Balanced"},
                        {value: "performance", label: "Performance"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("battery.acProfile", v)
                }

                SettingsDropdownRow {
                    label: "Profile when on battery"
                    description: "Switch to this profile when unplugged"
                    currentValue: Config.options.battery.batteryProfile ?? ""
                    options: [
                        {value: "", label: "Don't change"},
                        {value: "power-saver", label: "Power Saver"},
                        {value: "balanced", label: "Balanced"},
                        {value: "performance", label: "Performance"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("battery.batteryProfile", v)
                }
            }

            // ── Idle & Sleep Timeouts ──────────────────────────────────
            SettingsCard {
                title: "Idle & Sleep"
                subtitle: "Screensaver, lock, monitor off, and suspend timeouts"

                SettingsDropdownRow {
                    label: "Start screensaver after"
                    description: "Blank screen with screensaver animation"
                    currentValue: String(Config.options.idle.screensaverTimeout ?? 150)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "30", label: "30s"},
                        {value: "60", label: "1m"},
                        {value: "90", label: "1m 30s"},
                        {value: "120", label: "2m"},
                        {value: "150", label: "2m 30s"},
                        {value: "180", label: "3m"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.screensaverTimeout", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Lock screen after"
                    description: "Lock the session after inactivity"
                    currentValue: String(Config.options.idle.lockTimeout ?? 152)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "60", label: "1m"},
                        {value: "120", label: "2m"},
                        {value: "152", label: "2m 32s"},
                        {value: "180", label: "3m"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                        {value: "900", label: "15m"},
                        {value: "1800", label: "30m"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.lockTimeout", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Turn off monitor after"
                    description: "DPMS off after inactivity"
                    currentValue: String(Config.options.idle.monitorOffTimeout ?? 300)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "120", label: "2m"},
                        {value: "180", label: "3m"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                        {value: "900", label: "15m"},
                        {value: "1800", label: "30m"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.monitorOffTimeout", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Suspend system after"
                    description: "Suspend after inactivity (0 = never)"
                    currentValue: String(Config.options.idle.suspendTimeout ?? 0)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                        {value: "900", label: "15m"},
                        {value: "1800", label: "30m"},
                        {value: "2700", label: "45m"},
                        {value: "3600", label: "1h"},
                        {value: "7200", label: "2h"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.suspendTimeout", parseInt(v))
                }

                SettingsToggleRow {
                    label: "Lock before suspend"
                    description: "Lock the screen before suspending"
                    checked: Config.options.idle.lockBeforeSuspend ?? true
                    onToggled: Config.setNestedValue("idle.lockBeforeSuspend", !Config.options.idle.lockBeforeSuspend)
                }

                SettingsToggleRow {
                    label: "Prevent sleep (temporary)"
                    description: "Keep the session awake until toggled off"
                    checked: Idle.inhibit
                    onToggled: Idle.toggleInhibit()
                }
            }


            SettingsCard {
                title: "Power OSD"
                subtitle: "On-screen indicators for power-related changes"

                SettingsToggleRow {
                    label: "Power profile"
                    description: "Show OSD when power profile changes"
                    checked: Config.options.osd.powerProfileEnabled ?? true
                    onToggled: Config.setNestedValue("osd.powerProfileEnabled", !Config.options.osd.powerProfileEnabled)
                }

                SettingsToggleRow {
                    label: "Idle inhibitor"
                    description: "Show OSD when toggling idle inhibitor"
                    checked: Config.options.osd.idleInhibitorEnabled ?? true
                    onToggled: Config.setNestedValue("osd.idleInhibitorEnabled", !Config.options.osd.idleInhibitorEnabled)
                }
            }
}
