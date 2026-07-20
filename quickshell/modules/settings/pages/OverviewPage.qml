import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

PageBody {
    id: pageRoot
    property var settingsRoot: null

    SettingsCard {
        title: "Desktop Tools"
        subtitle: "Each tool opens as a focused settings panel"

        ButtonRow {
            SettingsButton {
                label: "Themes"
                iconName: "palette"
                onClicked: {
                    if (settingsRoot) settingsRoot.dismiss();
                    Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-settings-theme-tui`]);
                }
            }
            SettingsButton {
                label: "Voice Input"
                iconName: "keyboard_voice"
                onClicked: {
                    if (settingsRoot) settingsRoot.dismiss();
                    Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-settings-voice-tui`]);
                }
            }
        }
    }
}
