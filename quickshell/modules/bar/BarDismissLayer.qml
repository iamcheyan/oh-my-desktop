pragma ComponentBehavior: Bound

import qs
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.services

Scope {
    id: root

    function dismiss() {
        console.log("[DISMISSLAYER] dismiss() called, screenshotActive=" + BarRuntime.screenshotActive + " barPopupType=" + GlobalStates.barPopupType + " activeContextMenu=" + GlobalStates.activeContextMenu);
        if (BarRuntime.screenshotActive) return;
        if (GlobalStates.activeContextMenu !== "")
            GlobalStates.activeContextMenu = "";
        if (GlobalStates.barPopupType !== "") {
            GlobalStates.barPopupDismissedAt = Date.now();
            GlobalStates.barPopupType = "";
        }
        GlobalFocusGrab.dismiss();
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dismissWindow
            required property ShellScreen modelData

            screen: modelData
            visible: BarRuntime.dismissLayerActive && !BarRuntime.screenshotActive
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:bar-dismiss"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property bool barOnBottom: Config.options.bar.bottom
            readonly property int barGap: Appearance.sizes.barHeight

            anchors {
                top: !barOnBottom
                bottom: barOnBottom
                left: true
                right: true
            }
            // Leave a gap on the bar side so clicks reach the bar buttons
            // directly, enabling toggle (click again to close) behavior.
            // Without this gap the full-screen dismiss layer intercepts the
            // second click and only closes - never toggles.
            margins {
                top: barOnBottom ? 0 : barGap
                bottom: barOnBottom ? barGap : 0
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
