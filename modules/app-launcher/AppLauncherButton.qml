import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell

Item {
    id: root

    function toggleAppLauncher() {
        Quickshell.execDetached([
            "sh", "-c", "$HOME/.config/omd/bin/omd-applauncher toggle"
        ]);
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarTextButton {
        id: button
        text: "Applications"
        onTriggered: root.toggleAppLauncher()
    }
}
