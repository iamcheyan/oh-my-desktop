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

    SettingsCard {
        title: "System"
        subtitle: "Current session"
        SettingsRow { iconName: "battery_charging_full"; label: "Battery"; value: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--" }
        SettingsRow { iconName: "speed"; label: "Power profile"; value: PowerProfiles.currentProfile }
        SettingsRow { iconName: "wifi"; label: "Network"; value: Network.networkName || Network.wifiStatus }
        SettingsRow { iconName: "volume_up"; label: "Audio"; value: `${Math.round((Audio.sink?.audio.volume ?? 0) * 100)}%` }
        SettingsRow { iconName: "memory"; label: "Memory"; value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%` }
        SettingsRow { iconName: "developer_board"; label: "CPU"; value: `${Math.round(ResourceUsage.cpuUsage)}%` }
    }

    SettingsCard {
        title: "Quick Links"
        subtitle: "Open a category"
        ButtonRow {
            SettingsButton { label: "Devices"; iconName: "wifi"; onClicked: settingsRoot.currentPage = "network" }
            SettingsButton { label: "Sound"; iconName: "volume_up"; onClicked: settingsRoot.currentPage = "sound" }
            SettingsButton { label: "Displays"; iconName: "desktop_windows"; onClicked: settingsRoot.currentPage = "display" }
            SettingsButton { label: "Appearance"; iconName: "palette"; onClicked: settingsRoot.currentPage = "appearance" }
            SettingsButton { label: "Power"; iconName: "battery_charging_full"; onClicked: settingsRoot.currentPage = "power" }
            SettingsButton { label: "System"; iconName: "settings_applications"; onClicked: settingsRoot.currentPage = "system" }
        }
    }
}