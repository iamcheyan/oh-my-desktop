import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell

Item {
    id: root

    readonly property string appLauncherApp: `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-applauncher`

    function toggleAppLauncher() {
        Quickshell.execDetached([
            "qs", "-p", root.appLauncherApp, "ipc", "call", "appLauncher", "toggle"
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