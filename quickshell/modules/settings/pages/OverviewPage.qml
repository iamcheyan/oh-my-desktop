import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts

PageBody {
    id: pageRoot
    property var settingsRoot: null

    SettingsCard {
        title: "Desktop Tools"
        subtitle: "Each tool opens as a focused settings panel"

        ButtonRow {
            SettingsButton { label: "Themes"; iconName: "palette"; onClicked: settingsRoot.currentPage = "appearance" }
            SettingsButton { label: "Voice Input"; iconName: "keyboard_voice"; onClicked: settingsRoot.currentPage = "voice" }
            SettingsButton { label: "Keyboard Remap"; iconName: "keyboard"; onClicked: settingsRoot.currentPage = "keyremap" }
            SettingsButton { label: "Windows VM"; iconName: "desktop_windows"; onClicked: settingsRoot.currentPage = "windows" }
        }
    }
}
