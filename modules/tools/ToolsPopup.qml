// ToolsPopup.qml — OMD Tools launcher popup.
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.bar
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: popup
    spacing: 0
    width: parent?.width ?? implicitWidth

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.wrench
        title: "OMD Tools"
        subtitle: "Advanced desktop tools"
    }

    ToolLauncherRow {
        icon: "palette"
        title: "Themes"
        subtitle: "Colors, fonts and desktop appearance"
        onClicked: {
            GlobalStates.barPopupType = "";
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-settings-theme-tui`]);
        }
    }

    ToolLauncherRow {
        icon: "keyboard_voice"
        title: "Voice Input"
        subtitle: "Speech engine, model and shortcuts"
        onClicked: {
            GlobalStates.barPopupType = "";
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-settings-voice-tui`]);
        }
    }

    ToolLauncherRow {
        icon: "text_snippet"
        title: "OCR Recognition"
        subtitle: "PaddleOCR engine, model and test"
        onClicked: {
            GlobalStates.barPopupType = "";
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-settings-ocr-tui`]);
        }
    }

    ToolLauncherRow {
        icon: "keyboard"
        title: "Keyboard Remap"
        subtitle: "Devices, profiles and key mappings"
        onClicked: popup.openDialog("keyremap")
    }

    ToolLauncherRow {
        icon: "desktop_windows"
        title: "Windows VM"
        subtitle: "Install, run and manage Windows"
        onClicked: {
            GlobalStates.barPopupType = "";
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-settings-windows-tui`]);
        }
    }

    ToolLauncherRow {
        icon: "cloud_upload"
        title: "File Share / Backup"
        subtitle: "SMB backup, sync and file sharing"
        onClicked: {
            GlobalStates.barPopupType = "";
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-settings-backup-tui`]);
        }
    }
}
