pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

BarContextMenu {
    id: root
    menuName: "voice"

    readonly property string omdRoot: `${FileUtils.trimFileProtocol(Directories.config)}/omd`

    BarContextMenuItem {
        iconName:  "status/microphone-sensitivity-high-symbolic"
        label:     Translation.tr("Voice Recognition")
        releaseAction: () => { VoiceInput.toggle(); root.close() }
    }

    BarContextMenuItem {
        iconName:  "actions/media-record-symbolic"
        iconColor: TuiStyle.info
        label:     Translation.tr("Test Voice Input")
        releaseAction: () => {
            Quickshell.execDetached(["omarchy-launch-tui", `${root.omdRoot}/scripts/voice-test-tui`]);
            root.close();
        }
    }

    BarContextMenuItem {
        iconName:  "devices/input-keyboard-symbolic"
        iconColor: TuiStyle.warning
        label:     Translation.tr("Key Capture")
        releaseAction: () => {
            Quickshell.execDetached([`${root.omdRoot}/scripts/key-test`]);
            root.close();
        }
    }

    Rectangle {
        Layout.fillWidth:    true
        implicitHeight:      1
        color:               TuiStyle.line
        opacity:             TuiStyle.dividerOpacity
        Layout.topMargin:    root.separatorMargin
        Layout.bottomMargin: root.separatorMargin
    }

    BarContextMenuItem {
        iconName:  "categories/preferences-system-symbolic"
        iconColor: TuiStyle.accent
        label:     Translation.tr("Diagnose Voice Service")
        releaseAction: () => {
            Quickshell.execDetached(["omarchy-launch-tui", `${root.omdRoot}/scripts/voice-diagnose`]);
            root.close();
        }
    }
}
