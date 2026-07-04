pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property bool active: !GlobalStates.screenLocked
        && (GlobalStates.activeContextMenu !== "" || GlobalStates.barPopupType !== "")

    function dismiss() {
        if (GlobalStates.activeContextMenu !== "")
            GlobalStates.activeContextMenu = "";
        if (GlobalStates.barPopupType !== "")
            GlobalStates.barPopupType = "";
        GlobalFocusGrab.dismiss();
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dismissWindow
            required property ShellScreen modelData

            screen: modelData
            visible: root.active
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:bar-dismiss"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: event => {
                    event.accepted = true;
                    root.dismiss();
                }
            }
        }
    }
}
